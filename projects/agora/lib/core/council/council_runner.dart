import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../adapters/adapter_config.dart';
import '../adapters/web_agent_adapter.dart';
import '../cdp/cdp_client.dart';
import '../chrome/chrome_launcher.dart';
import '../orchestration/budget.dart';
import '../orchestration/orchestrator.dart';
import '../logging.dart';
import 'tab_pool.dart';
import '../../data/session_repository.dart';

/// What the UI knows about a seat before any browser exists.
class SeatBinding {
  const SeatBinding({
    required this.kind,
    required this.displayName,
    this.roleCard,
    this.isLeader = false,
  });

  final String kind;
  final String displayName;
  final String? roleCard;
  final bool isLeader;
}

/// Everything the engine does, in one place: launch Chrome, open a tab per
/// seat, hand the adapters to the orchestrator, and write every single word to
/// the vault as it is captured.
///
/// The orchestrator itself is storage-free so it can be tested with fakes.
/// That is exactly why this class exists — it is the only thing in the app that
/// knows both Chrome and SQLite at the same time.
///
/// Ordering rule (PLAN.md §2.4): the orchestrator decides who speaks next and
/// this class does the speaking. Nothing here parses an agent's text to decide
/// anything; it only records what happened.
class CouncilRunner {
  CouncilRunner({
    required this.repo,
    required this.sessionId,
    required this.kindToAgentId,
    this.cdpPort = 9222,
    this.headless = false,
  });

  final SessionRepository repo;
  final String sessionId;

  /// Adapter kind -> the `agents.id` row, so captured messages can be filed
  /// under the right seat instead of a bare string.
  final Map<String, String> kindToAgentId;

  final int cdpPort;

  /// Chrome runs visible by default (PLAN.md §17 open question 2): a real AI
  /// site may throw a captcha or expire its login, and the user has to be able
  /// to see and fix that. Headless exists for the sandbox harness.
  final bool headless;

  static final Logger _log = Logger('council');

  final _controllers = <StreamSubscription<CouncilEvent>>[];

  CdpClient? _client;
  TabPool? _pool;
  Orchestrator? _orchestrator;
  final _adapters = <WebAgentAdapter>[];

  bool _running = false;
  bool get isRunning => _running;

  CouncilOutcome? _outcome;
  CouncilOutcome? get outcome => _outcome;

  Object? _error;
  Object? get error => _error;

  /// Human-readable progress for the council panel, one line per step.
  final _notes = <String>[];
  List<String> get notes => List<String>.unmodifiable(_notes);

  void _note(String line) {
    _notes.add(line);
    _log.d(line);
  }

  /// Runs the council to completion. Always tears Chrome and every tab down,
  /// even on failure — a council that explodes must not leave eight Chrome tabs
  /// open on the user's desktop.
  Future<CouncilOutcome> run({
    required List<SeatBinding> seats,
    required String leaderKind,
    required String prompt,
    int maxRounds = 12,
    Duration timeBudget = const Duration(minutes: 30),
    int dailyMessageCap = 60,
  }) async {
    if (_running) {
      throw StateError('a council is already running in this session');
    }
    _running = true;
    _outcome = null;
    _error = null;
    _notes.clear();

    await repo.updateSession(sessionId, status: 'running');
    await repo.journal(
      sessionId,
      'council.start',
      payload: <String, dynamic>{
        'leader': leaderKind,
        'seats': seats.map((s) => s.kind).toList(),
        'prompt': prompt,
      },
    );
    _note('Convening ${seats.length} seats under $leaderKind.');

    try {
      await AgoraPaths.ensureDirs();
      _note('Launching Chrome on port $cdpPort.');
      final launched = await _launchChrome();
      _client = launched.client;

      _pool = TabPool(_client!);
      final councilSeats = <CouncilSeat>[];
      for (final seat in seats) {
        final cfg = await loadAdapterConfig(seat.kind);
        final targetId = await _pool!.open(seat.kind);
        final adapter = WebAgentAdapter(
          config: cfg,
          client: _client!,
          targetId: targetId,
        );
        _adapters.add(adapter);

        _note('Connecting to ${seat.displayName}…');
        final login = await adapter.connect();
        if (!login.isReady) {
          throw CouncilBlocked(
            '${seat.displayName} is not ready: '
            '${login.message.isEmpty ? login.status.name : login.message}',
          );
        }
        await adapter.newChat();
        _note('${seat.displayName} is signed in and on a fresh chat.');
        councilSeats.add(
          CouncilSeat(
            kind: seat.kind,
            displayName: seat.displayName,
            adapter: adapter,
            roleCard: seat.roleCard,
            isLeader: seat.isLeader || seat.kind == leaderKind,
          ),
        );
      }

      _orchestrator = Orchestrator(
        seats: councilSeats,
        leaderKind: leaderKind,
        budget: BudgetGuard(
          maxRounds: maxRounds,
          timeBudget: timeBudget,
          dailyMessageCap: dailyMessageCap,
        ),
      );
      _listen(_orchestrator!);

      _note('Council seated. The debate begins.');
      final outcome = await _orchestrator!.run(prompt);
      _outcome = outcome;

      await repo.updateSession(
        sessionId,
        status: outcome.stop == BudgetStop.solved ? 'solved' : 'stopped',
        round: outcome.rounds,
      );
      await repo.journal(
        sessionId,
        'council.finish',
        payload: <String, dynamic>{
          'stop': outcome.stop.name,
          'rounds': outcome.rounds,
          'confidence': outcome.confidence,
        },
      );
      _note('Council ${outcome.stop.name} after ${outcome.rounds} rounds.');
      return outcome;
    } on Object catch (e) {
      _error = e;
      await repo.updateSession(sessionId, status: 'failed');
      await repo.journal(
        sessionId,
        'council.error',
        payload: <String, dynamic>{'error': e.toString()},
      );
      _note('Council failed: $e');
      rethrow;
    } finally {
      _running = false;
      await _teardown();
    }
  }

  /// Interrupts the debate and hard-stops the browser work in flight.
  void interrupt() {
    _orchestrator?.interrupt();
    for (final a in _adapters) {
      a.interrupt();
    }
    _note('Interrupting.');
  }

  /// Every captured word lands here. This is the only path by which an agent's
  /// text enters the database, so "verbatim" is a property of the architecture
  /// rather than a promise in a comment.
  void _listen(Orchestrator o) {
    _controllers.add(
      o.events.listen((event) async {
        try {
          await _onEvent(event);
        } on Object catch (e) {
          // A bookkeeping failure must not derail a debate in progress, but it
          // must be visible rather than swallowed.
          _log.d('event persistence failed for ${event.runtimeType}: $e');
        }
      }),
    );
  }

  Future<void> _onEvent(CouncilEvent event) async {
    if (event is MessageCaptured) {
      final agentId = kindToAgentId[event.kind] ?? event.kind;
      final v = event.verbatim;
      final meta = <String, dynamic>{
        'adapter': event.kind,
        if (v.contentHash != null) 'adapterHash': v.contentHash,
      };
      await repo.record(
        sessionId: sessionId,
        round: event.round,
        agentId: agentId,
        role: 'agent',
        direction: 'in',
        rawText: v.rawText,
        rawHtml: v.rawHtml,
        screenshot: v.screenshotBytes,
        latencyMs: v.latencyMs,
        meta: meta,
      );
      await repo.countMessage(event.kind, v.rawText.length);
      return;
    }
    if (event is PacketDispatched) {
      await repo.recordPacket(
        sessionId: sessionId,
        round: 0,
        targetAgentId: kindToAgentId[event.target] ?? event.target,
        strategy: event.packet.strategy.name,
        body: event.packet.body,
      );
      return;
    }
    if (event is RoundCompleted) {
      final current = await repo.session(sessionId);
      await repo.updateSession(sessionId, round: (current?.round ?? 0) + 1);
      _note(
        'Round over — ${event.speakers.join(', ')} '
        '(${event.elapsed.inSeconds}s).',
      );
      return;
    }
    if (event is ProtocolWarning) {
      await repo.journal(
        sessionId,
        'protocol_warning',
        payload: <String, dynamic>{
          'round': event.round,
          'detail': event.message,
        },
      );
      _note('Protocol warning in round ${event.round}: ${event.message}');
      return;
    }
    if (event is SafetyWarning) {
      await repo.journal(
        sessionId,
        'safety_warning',
        payload: <String, dynamic>{
          'round': event.round,
          'detail': event.report.toString(),
        },
      );
      _note('Safety warning in round ${event.round}: ${event.report}');
      return;
    }
    if (event is PhaseChanged) {
      await repo.journal(
        sessionId,
        'phase',
        payload: <String, dynamic>{'phase': event.phase.name},
      );
    }
  }

  Future<ChromeLaunchResult> _launchChrome() async {
    return ChromeLauncher().launch(
      preferredPort: cdpPort,
      profileDir: AgoraPaths.chromeProfile,
      headless: headless,
    );
  }

  /// Adapters are JSON data, never code. A site redesign is a new file in
  /// `assets/adapters/`, not a new release.
  Future<AdapterConfig> loadAdapterConfig(String kind) async {
    final raw = await rootBundle.loadString('assets/adapters/$kind.json');
    final cfg = AdapterConfig.parse(raw, origin: 'assets/adapters/$kind.json');
    final problems = cfg.validate();
    if (problems.isNotEmpty) {
      throw CouncilBlocked(
        'adapter "$kind" is invalid: ${problems.join('; ')}',
      );
    }
    return cfg;
  }

  /// Screenshots every live tab into the vault and returns kind -> file path.
  ///
  /// Only meaningful while a council is running: the tabs belong to the run and
  /// are closed in `_teardown`, so there is nothing to photograph between runs.
  /// A tab that refuses the capture is skipped, not fatal — the transcript is
  /// the record, the pixels are the corroboration.
  Future<Map<String, String>> snapshotAll() async {
    final pool = _pool;
    if (pool == null) return const <String, String>{};
    final dir = Directory(p.join(AgoraPaths.vaultDir, sessionId));
    await dir.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final out = <String, String>{};
    for (final kind in pool.openKinds) {
      final Uint8List? png = await pool.capture(kind);
      if (png == null) continue;
      final file = File(p.join(dir.path, 'snapshot-$stamp-$kind.png'));
      await file.writeAsBytes(png, flush: true);
      out[kind] = file.path;
    }
    if (out.isNotEmpty) {
      await repo.journal(sessionId, 'snapshot', payload: {'files': out});
      _note('snapshot: ${out.length} tab(s) captured');
    }
    return out;
  }

  Future<void> _teardown() async {
    for (final sub in _controllers) {
      await sub.cancel();
    }
    _controllers.clear();

    final o = _orchestrator;
    _orchestrator = null;
    if (o != null) {
      try {
        await o.dispose();
      } on Object {
        // Nothing left to clean up if the orchestrator is already gone.
      }
    }

    for (final a in _adapters) {
      try {
        await a.close();
      } on Object {
        // Best effort: the tab is about to be closed regardless.
      }
    }
    _adapters.clear();

    final pool = _pool;
    _pool = null;
    if (pool != null) {
      await pool.closeAll();
    }

    final client = _client;
    _client = null;
    if (client != null && !client.isClosed) {
      await client.close();
    }
  }
}

/// A council that cannot start because a precondition failed — a site the user
/// has not logged into, or a broken adapter. Distinct from a crash, because the
/// remedy is always something the user can do.
class CouncilBlocked implements Exception {
  CouncilBlocked(this.reason);

  final String reason;

  @override
  String toString() => 'CouncilBlocked: $reason';
}
