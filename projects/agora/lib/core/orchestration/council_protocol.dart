import 'dart:convert';

/// What the leader is asking Agora to do next.
///
/// The first four are the ratified dispatch set from `PLAN.md` §18.1 Amendment
/// R1; `decide`, `comment` and `needInput` close a round rather than open one.
enum CouncilAction { invite, broadcast, dm, decide, comment, needInput }

extension CouncilActionX on CouncilAction {
  String get wire => switch (this) {
    CouncilAction.invite => 'invite',
    CouncilAction.broadcast => 'broadcast',
    CouncilAction.dm => 'dm',
    CouncilAction.decide => 'decide',
    CouncilAction.comment => 'comment',
    CouncilAction.needInput => 'need_input',
  };

  /// True when the action addresses exactly one named agent kind.
  ///
  /// §18.1: `invite` and `dm` both carry an `"agent"` target; `broadcast`
  /// addresses every participant and therefore carries none.
  bool get hasTarget =>
      this == CouncilAction.invite || this == CouncilAction.dm;

  /// True when the action opens a public round.
  bool get opensRound =>
      this == CouncilAction.invite || this == CouncilAction.broadcast;

  /// §18.1 sender rule: every action is leader-only except `dm`, which any
  /// participant may send. `broadcast` in particular is *not* a delegate power
  /// — it is the old GROUPCHAT round-robin, ratified but kept leader-gated so it
  /// dispatches explicitly rather than by free text.
  bool get isLeaderOnly => this != CouncilAction.dm;
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

  /// Target agent kind, for [CouncilAction.invite] and [CouncilAction.dm].
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
      'broadcast' => CouncilAction.broadcast,
      'dm' => CouncilAction.dm,
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

    // Validate the addressed target before anything is dispatched. §18.1: both
    // `invite` and `dm` name exactly one participant; `broadcast` names none.
    if (action.hasTarget) {
      final target = json['agent'];
      if (target is! String || target.isEmpty) {
        return CouncilParse(
          fence: fence.raw,
          error: '${action.wire} requires "agent"',
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
        agent: action.hasTarget ? json['agent'] as String : null,
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
```council containing one JSON object. This block is the only thing Agora
reads. Everything outside the block is shown to the user as normal prose.

Actions:
  invite      — ask one participant to speak (opens a public round)
  broadcast   — send one packet to every other participant (opens a public round)
  dm          — message one participant privately; only you and they see it
  decide      — the question is settled
  comment     — no action needed, just reporting progress
  need_input  — you need a decision from the human user

Example — invite:
```council
{"action":"invite","agent":"gemini","task":"Critique this cathode spec",
 "context":"Previous two rounds, plus the open question","expect":"5 risks, each with a severity","why":"Needs independent physics validation"}
```

Example — broadcast:
```council
{"action":"broadcast","task":"Each of you: give your single biggest risk in this design.",
 "context":"Opening round","expect":"One risk each, no cross-talk","why":"Divergent views before convergence"}
```

Example — decide:
```council
{"action":"decide","status":"solved","answer":"The final answer goes here.",
 "confidence":0.82,"dissent":["gemini disagrees on electrolyte choice"]}
```

Rules:
  - "agent" must be exactly one of the participant kinds listed above.
  - invite and broadcast open a public round; dm is private to you and its target.
  - Status must be "solved" or "blocked".
  - Emit exactly one council block per reply, as the last thing you write.
  - Answer questions asked of you directly before emitting the block.
  - This session has a hard cap of $maxRounds rounds.${dissentRule.isEmpty ? '' : '\n$dissentRule'}

Your name in this council is "$displayName". Begin.
''';
  }

  /// The clause appended to a participant's brief so a delegate knows it may
  /// open a private thread.
  ///
  /// §18.1 gives `dm` to *any* participant while keeping `invite` and
  /// `broadcast` leader-only, so this is the counterpart to
  /// [leaderInstructions] for a seat that is not leading.
  static String delegateDmRule() => '''
You may privately message exactly one other participant. End your reply with
exactly one block:
```council
{"action":"dm","agent":"<participant kind>","task":"what you want from them",
 "context":"what they need in order to answer","expect":"the shape of a good reply"}
```
"agent" must be one of the participant kinds listed in your brief. Only the
leader may open public rounds (invite or broadcast). Everything outside the
block is shown to the user as prose.''';

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
