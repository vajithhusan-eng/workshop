import 'dart:convert';

/// What the leader is asking Agora to do next.
enum CouncilAction { invite, decide, comment, needInput }

extension CouncilActionX on CouncilAction {
  String get wire => switch (this) {
    CouncilAction.invite => 'invite',
    CouncilAction.decide => 'decide',
    CouncilAction.comment => 'comment',
    CouncilAction.needInput => 'need_input',
  };
}

/// A successfully parsed ```council block.
class CouncilBlock {
  const CouncilBlock({
    required this.action,
    this.agent,
    this.task,
    this.context,
    this.expect,
    this.why,
    this.status,
    this.answer,
    this.confidence,
    this.dissent = const [],
  });

  final CouncilAction action;

  /// Target agent kind, for [CouncilAction.invite].
  final String? agent;
  final String? task;
  final String? context;
  final String? expect;
  final String? why;

  /// For [CouncilAction.decide]: 'solved' | 'blocked'.
  final String? status;
  final String? answer;
  final double? confidence;
  final List<String> dissent;

  bool get isSolved => action == CouncilAction.decide && status == 'solved';
  bool get isBlocked => action == CouncilAction.decide && status == 'blocked';

  @override
  String toString() => 'CouncilBlock(${action.wire}, agent=$agent)';
}

class CouncilParse {
  const CouncilParse({this.block, this.fence, this.error, this.participants});

  /// Parsed block, or null when there was none.
  final CouncilBlock? block;

  /// The raw fenced text as it appeared, kept for the audit trail.
  final String? fence;

  /// Set when a block was present but unusable. Free text must never dispatch,
  /// so a malformed block is surfaced rather than guessed at.
  final String? error;

  /// Participants that [CouncilBlock.agent] was checked against.
  final List<String>? participants;

  bool get hasBlock => block != null;
  bool get hasError => error != null;
  bool get isUsable => block != null && error == null;
}

/// Parses and validates the machine-readable ```council blocks that drive
/// orchestration.
///
/// Free-text detection of "please ask Gemini" is unreliable, so Agora uses one
/// strict format and treats everything else as prose.
class CouncilProtocol {
  const CouncilProtocol._();

  static const _openTag = 'council';

  /// Find the last ```council fence in [reply] and parse it.
  ///
  /// [participants] is the set of agent kinds allowed in this session; an
  /// invite naming anyone else is rejected instead of dispatched.
  static CouncilParse parse(String reply, {List<String>? participants}) {
    final fence = _lastFence(reply);
    if (fence == null) {
      return CouncilParse(participants: participants);
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(fence.body);
      if (decoded is! Map<String, dynamic>) {
        return CouncilParse(
          fence: fence.raw,
          error: 'council block must be a JSON object',
          participants: participants,
        );
      }
      json = decoded;
    } on FormatException catch (e) {
      return CouncilParse(
        fence: fence.raw,
        error: 'invalid JSON: ${e.message}',
        participants: participants,
      );
    }

    final rawAction = json['action'];
    if (rawAction is! String) {
      return CouncilParse(
        fence: fence.raw,
        error: 'missing "action"',
        participants: participants,
      );
    }
    final action = switch (rawAction) {
      'invite' => CouncilAction.invite,
      'decide' => CouncilAction.decide,
      'comment' => CouncilAction.comment,
      'need_input' => CouncilAction.needInput,
      _ => null,
    };
    if (action == null) {
      return CouncilParse(
        fence: fence.raw,
        error: 'unknown action "$rawAction"',
        participants: participants,
      );
    }

    // Validate the invite target before anything is dispatched.
    if (action == CouncilAction.invite) {
      final target = json['agent'];
      if (target is! String || target.isEmpty) {
        return CouncilParse(
          fence: fence.raw,
          error: 'invite requires "agent"',
          participants: participants,
        );
      }
      if (participants != null && !participants.contains(target)) {
        return CouncilParse(
          fence: fence.raw,
          error: '"$target" is not a participant in this session',
          participants: participants,
        );
      }
    }

    double? confidence;
    final rawConf = json['confidence'];
    if (rawConf is num) {
      confidence = rawConf.toDouble().clamp(0.0, 1.0);
    } else if (rawConf is String) {
      final parsed = double.tryParse(rawConf);
      if (parsed != null) confidence = parsed.clamp(0.0, 1.0);
    }

    final dissent = <String>[];
    final rawDissent = json['dissent'];
    if (rawDissent is List) {
      for (final d in rawDissent) {
        if (d is String && d.trim().isNotEmpty) dissent.add(d.trim());
      }
    } else if (rawDissent is String && rawDissent.trim().isNotEmpty) {
      dissent.add(rawDissent.trim());
    }

    return CouncilParse(
      fence: fence.raw,
      participants: participants,
      block: CouncilBlock(
        action: action,
        agent: action == CouncilAction.invite ? json['agent'] as String : null,
        task: _str(json['task']),
        context: _str(json['context']),
        expect: _str(json['expect']),
        why: _str(json['why']),
        status: _str(json['status']),
        answer: _str(json['answer']),
        confidence: confidence,
        dissent: dissent,
      ),
    );
  }

  /// Strip the ```council fence from a reply, leaving the human-facing prose.
  ///
  /// The prose is stored verbatim too — Agora never deletes what an agent said,
  /// it only separates the machine part from the human part.
  static String proseOf(String reply) {
    final fence = _lastFence(reply);
    if (fence == null) return reply;
    return reply.replaceRange(fence.start, fence.end, '').trimRight();
  }

  /// The preamble Agora sends to whichever agent is leading a session.
  ///
  /// Everything the orchestrator depends on lives here, so a leader always
  /// knows the contract even in a brand-new chat.
  static String leaderInstructions({
    required String displayName,
    required List<AgentBrief> participants,
    required int maxRounds,
    required bool requireDissent,
  }) {
    final roster = participants
        .map(
          (a) =>
              '  - ${a.kind}  "${a.displayName}"'
              '${a.roleCard == null || a.roleCard!.isEmpty ? '' : '\n      role: ${a.roleCard}'}',
        )
        .join('\n');

    final dissentRule = requireDissent
        ? '''
Before you emit a "decide" with status "solved", at least one other agent
must have challenged the current answer. If nobody has, keep inviting.'''
        : '';

    return '''
You are the LEADER of an AI council called Agora. You coordinate a panel of
other AI assistants on behalf of one human user.

Your participants:
$roster

HOW TO CONTROL THE COUNCIL
At the very end of every reply, output exactly one fenced block tagged
\`\`\`council containing one JSON object. This block is the only thing Agora
reads. Everything outside the block is shown to the user as normal prose.

Actions:
  invite      — ask one participant to speak
  decide      — the question is settled
  comment     — no action needed, just reporting progress
  need_input  — you need a decision from the human user

Example — invite:
\`\`\`council
{"action":"invite","agent":"gemini","task":"Critique this cathode spec",
 "context":"Previous two rounds, plus the open question","expect":"5 risks, each with a severity","why":"Needs independent physics validation"}
\`\`\`

Example — decide:
\`\`\`council
{"action":"decide","status":"solved","answer":"The final answer goes here.",
 "confidence":0.82,"dissent":["gemini disagrees on electrolyte choice"]}
\`\`\`

Rules:
  - "agent" must be exactly one of the participant kinds listed above.
  - Status must be "solved" or "blocked".
  - Emit exactly one council block per reply, as the last thing you write.
  - Answer questions asked of you directly before emitting the block.
  - This session has a hard cap of $maxRounds rounds.${dissentRule.isEmpty ? '' : '\n$dissentRule'}

Your name in this council is "$displayName". Begin.
''';
  }

  static String? _str(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;

  /// Locate the final ```council ... ``` fence in [text].
  static _Fence? _lastFence(String text) {
    final lower = text.toLowerCase();
    var searchFrom = 0;
    _Fence? found;
    while (true) {
      final open = lower.indexOf('```', searchFrom);
      if (open < 0) break;
      // Language tag runs to the end of the opening line.
      final tagEnd = text.indexOf('\n', open);
      if (tagEnd < 0) break;
      final tag = text.substring(open + 3, tagEnd).trim().toLowerCase();
      if (tag != _openTag) {
        searchFrom = tagEnd;
        continue;
      }
      final close = lower.indexOf('```', tagEnd);
      if (close < 0) {
        found = _Fence(
          body: text.substring(tagEnd).trim(),
          raw: text.substring(open, text.length),
          start: open,
          end: text.length,
        );
        break;
      }
      found = _Fence(
        body: text.substring(tagEnd, close).trim(),
        raw: text.substring(open, close + 3),
        start: open,
        end: close + 3,
      );
      searchFrom = close + 3;
    }
    return found;
  }
}

class _Fence {
  const _Fence({
    required this.body,
    required this.raw,
    required this.start,
    required this.end,
  });

  final String body;
  final String raw;
  final int start;
  final int end;
}

/// Minimal participant description used when writing the leader preamble.
class AgentBrief {
  const AgentBrief({
    required this.kind,
    required this.displayName,
    this.roleCard,
  });

  final String kind;
  final String displayName;
  final String? roleCard;
}
