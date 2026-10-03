import 'dart:convert';

import '../adapters/agent_adapter.dart';
import '../../data/database.dart' as db;
import '../../data/session_repository.dart';
import '../util/hashing.dart';

/// One row of `journal_events`, decoded into something replayable.
///
/// Only two kinds are replayable: `dispatch` (Agora sent something to an agent)
/// and `capture` (that agent answered). Everything else — phases, warnings,
/// snapshots — is narration the run wrote about itself.
class ReplayAction {
  ReplayAction({required this.kind, required this.payload});

  /// Returns null for a row that is not a replayable action.
  static ReplayAction? tryParse(db.JournalEvent row) {
    if (row.kind != 'dispatch' && row.kind != 'capture') return null;
    var payload = <String, dynamic>{};
    if (row.payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(row.payload);
        if (decoded is Map<String, dynamic>) payload = decoded;
      } on FormatException {
        // A malformed payload must not abort a replay of the rows around it.
      }
    }
    return ReplayAction(kind: row.kind, payload: payload);
  }

  final String kind;
  final Map<String, dynamic> payload;

  bool get isDispatch => kind == 'dispatch';

  /// The agent kind this action belongs to. `dispatch` calls it `target`,
  /// `capture` calls it `kind` — normalised here so the caller never branches.
  String? get agentKind =>
      payload['target'] as String? ?? payload['kind'] as String?;

  String? get body => payload['body'] as String?;

  String? get expectedHash => payload['hash'] as String?;
}

/// How one replayed turn came out.
enum ReplayStatus {
  /// The sandbox reproduced the recorded answer exactly.
  match,

  /// It answered, but differently — the site changed, or the sandbox drifted.
  differs,

  /// No adapter was supplied for that agent kind. Skipped, not failed.
  noAdapter,

  /// The adapter threw. Replay is best-effort; it must never throw upward.
  failed,
}

/// One dispatch and the reply it produced.
class ReplayStep {
  ReplayStep({
    required this.target,
    required this.body,
    required this.status,
    this.expectedHash,
    this.actualHash,
    this.replyChars = 0,
    this.detail = '',
  });

  final String target;
  final String body;
  final ReplayStatus status;
  final String? expectedHash;
  final String? actualHash;
  final int replyChars;
  final String detail;

  /// Short truth for a UI row: never a stack trace, always the next action.
  String get verdict => switch (status) {
    ReplayStatus.match => 'reproduced exactly',
    ReplayStatus.differs => 'answered differently',
    ReplayStatus.noAdapter => 'no adapter for this site',
    ReplayStatus.failed => detail.isEmpty ? 'failed' : detail,
  };
}

/// What a replay found.
class ReplayReport {
  ReplayReport({
    required this.steps,
    required this.dispatched,
    required this.captured,
  });

  final List<ReplayStep> steps;

  /// Counted from the journal, before any replay, so a session with turns but
  /// no replies is distinguishable from one with nothing at all.
  final int dispatched;
  final int captured;

  int get matched => steps.where((s) => s.status == ReplayStatus.match).length;
  int get differs =>
      steps.where((s) => s.status == ReplayStatus.differs).length;
  int get skipped =>
      steps.where((s) => s.status == ReplayStatus.noAdapter).length;
  int get failed => steps.where((s) => s.status == ReplayStatus.failed).length;

  /// A journal written before the Time Machine existed has turns but no replies.
  bool get missingCaptures => dispatched > 0 && captured == 0;

  String get headline {
    if (dispatched == 0) return 'This session has no recorded turns to replay.';
    if (missingCaptures) {
      return 'The journal has $dispatched turn(s) but no recorded replies — it '
          'was written before the Time Machine was added.';
    }
    if (steps.isEmpty) {
      return '$dispatched turn(s) recorded, but nothing had a local adapter to '
          'replay against.';
    }
    return '${steps.length} turn(s) replayed: $matched reproduced exactly, '
        '$differs answered differently, $skipped skipped, $failed failed.';
  }
}

/// Replays a recorded council against local adapters instead of real AI sites.
///
/// The point is not to re-run the debate. It is to answer one question: if we
/// feed the exact packet Agora sent to a stand-in site, do we get the exact
/// answer that site gave? A `differs` is the earliest possible warning that a
/// site changed underneath us — long before a selector probe would notice.
class JournalReplay {
  JournalReplay({
    required SessionRepository repo,
    required Map<String, AgentAdapter> adapters,
  }) : _repo = repo,
       _adapters = adapters;

  final SessionRepository _repo;
  final Map<String, AgentAdapter> _adapters;

  /// Replays in strict journal order. A dispatch is sent as it is reached; the
  /// reply is compared against the next capture recorded for that same agent,
  /// FIFO, so two rounds between the same pair cannot cross over.
  Future<ReplayReport> replay(String sessionId) async {
    final rows = await _repo.journalFor(sessionId);
    final actions = <ReplayAction>[
      for (final r in rows)
        if (ReplayAction.tryParse(r) case final a?) a,
    ];
    final dispatched = actions.where((a) => a.isDispatch).length;
    final captured = actions.where((a) => !a.isDispatch).length;

    final steps = <ReplayStep>[];
    final pending = <String, List<_Reply>>{};

    for (final action in actions) {
      final kind = action.agentKind;
      if (kind == null) continue;
      if (action.isDispatch) {
        final body = action.body;
        if (body == null) continue;
        final adapter = _adapters[kind];
        if (adapter == null) {
          steps.add(
            ReplayStep(
              target: kind,
              body: body,
              status: ReplayStatus.noAdapter,
            ),
          );
          continue;
        }
        final reply = await _turn(adapter, body);
        (pending[kind] ??= <_Reply>[]).add(reply);
        continue;
      }

      // A capture with no dispatch ahead of it cannot be replayed — the packet
      // was never recorded, so there is nothing to feed a stand-in site.
      final queue = pending[kind];
      if (queue == null || queue.isEmpty) continue;
      final reply = queue.removeAt(0);
      steps.add(
        ReplayStep(
          target: kind,
          body: reply.sent,
          expectedHash: action.expectedHash,
          actualHash: reply.hash,
          replyChars: reply.chars,
          status: reply.error != null
              ? ReplayStatus.failed
              : (reply.hash != null && reply.hash == action.expectedHash
                    ? ReplayStatus.match
                    : ReplayStatus.differs),
          detail: reply.error ?? '',
        ),
      );
    }
    // A turn Agora sent but never got a journalled reply for is the most
    // interesting failure there is, so it must be visible rather than silently
    // dropped by the capture-driven loop above.
    for (final entry in pending.entries) {
      for (final orphan in entry.value) {
        steps.add(
          ReplayStep(
            target: entry.key,
            body: orphan.sent,
            status: ReplayStatus.failed,
            detail:
                orphan.error ??
                'the run recorded this turn but never journalled a reply for '
                    'it, so there is nothing to compare against',
          ),
        );
      }
    }

    return ReplayReport(
      steps: steps,
      dispatched: dispatched,
      captured: captured,
    );
  }

  Future<_Reply> _turn(AgentAdapter adapter, String body) async {
    try {
      await adapter.send(body);
      final v = await adapter.awaitCompletion();
      return _Reply(
        sent: body,
        hash: contentHash(v.rawText),
        chars: v.rawText.length,
      );
    } on Object catch (e) {
      // Replay is a diagnostic. A broken stand-in site is a finding to report,
      // not a reason to abort the rest of the replay.
      return _Reply(sent: body, error: '$e');
    }
  }
}

class _Reply {
  _Reply({required this.sent, this.hash, this.chars = 0, this.error});

  final String sent;
  final String? hash;
  final int chars;
  final String? error;
}
