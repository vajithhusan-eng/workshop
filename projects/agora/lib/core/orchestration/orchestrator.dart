/// The council state machine.
///
/// Wires together everything the engine has built so far:
///
///   * [AgentAdapter]          — talks to a real AI site over CDP
///   * [CouncilProtocol]       — what the leader is allowed to ask for
///   * [PromptCompiler]        — what actually gets sent (delta packets)
///   * [SafetyFirewall]        — what may be relayed between agents
///   * [BudgetGuard]           — the hard stops
///   * [ConvergenceScorer]     — when the council is genuinely done
///
/// Design rules this file obeys without exception:
///
///   1. **Verbatim.** Nothing here edits an agent's words. The safety firewall
///      reports threats but never rewrites a colleague's answer; only PII
///      masking is allowed to alter a relayed string, and only when the user
///      explicitly turned it on.
///   2. **Never guess.** A dispatch happens only when [CouncilProtocol.parse]
///      produced a usable `invite` block. Free text is stored and shown, and
///      then ignored for control purposes.
///   3. **Always terminates.** Every loop iteration starts by asking
///      [BudgetGuard] whether we may continue.
///
/// The orchestrator is transport-agnostic: it never imports CDP or Flutter.
library;

import 'dart:async';

import '../adapters/agent_adapter.dart';
import '../logging.dart';
import 'budget.dart';
import 'convergence.dart';
import 'council_protocol.dart';
import 'prompt_compiler.dart';
import 'safety.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

enum OrchestratorPhase {
  idle,
  leaderTurn,
  parsing,
  dispatching,
  awaiting,
  judging,
  finalizing,
  stopped,
  failed,
}

/// Everything the UI needs to know. The orchestrator never touches widgets.
sealed class CouncilEvent {
  const CouncilEvent(this.round);

  /// 1-based council round this event belongs to.
  final int round;
}

class PhaseChanged extends CouncilEvent {
  const PhaseChanged(super.round, this.phase, [this.detail = '']);

  final OrchestratorPhase phase;
  final String detail;

  @override
  String toString() => 'PhaseChanged(r$round, ${phase.name}, $detail)';
}

/// An agent finished speaking. [verbatim] is untouched — the UI decides how to
/// draw it, but the raw text is the record.
class MessageCaptured extends CouncilEvent {
  const MessageCaptured(
    super.round,
    this.kind,
    this.displayName,
    this.verbatim,
  );

  final String kind;
  final String displayName;
  final Verbatim verbatim;

  @override
  String toString() =>
      'MessageCaptured(r$round, $kind, ${verbatim.rawText.length} chars)';
}

/// A packet is about to be typed into a real browser tab.
class PacketDispatched extends CouncilEvent {
  const PacketDispatched(super.round, this.target, this.packet);

  final String target;
  final TaskPacket packet;

  @override
  String toString() =>
      'PacketDispatched(r$round, $target, ${packet.byteSize}B, '
      'pressure=${packet.pressure.toStringAsFixed(2)})';
}

/// The protocol block was missing or invalid. Surfaced, never guessed at.
class ProtocolWarning extends CouncilEvent {
  const ProtocolWarning(super.round, this.message);

  final String message;

  @override
  String toString() => 'ProtocolWarning(r$round, $message)';
}

/// The firewall had something to say about relayed content.
class SafetyWarning extends CouncilEvent {
  const SafetyWarning(super.round, this.report);

  final RelayInspection report;

  @override
  String toString() => 'SafetyWarning(r$round, ${report.toString()})';
}

class ConvergenceUpdated extends CouncilEvent {
  const ConvergenceUpdated(super.round, this.report);

  final ConvergenceReport report;

  @override
  String toString() =>
      'ConvergenceUpdated(r$round, ${report.state.name}: ${report.reason})';
}

/// Round bookkeeping, handy for the round markers in the transcript.
class RoundCompleted extends CouncilEvent {
  const RoundCompleted(super.round, this.speakers, this.elapsed);

  final List<String> speakers;
  final Duration elapsed;

  @override
  String toString() => 'RoundCompleted(r$round, $speakers)';
}

/// The council is over. [answer] is the leader's final text, verbatim.
class CouncilFinished extends CouncilEvent {
  const CouncilFinished(
    super.round,
    this.stop,
    this.answer,
    this.confidence,
    this.dissent,
    this.reason,
  );

  final BudgetStop stop;
  final String? answer;
  final double? confidence;
  final List<String> dissent;
  final String reason;

  bool get solved => stop == BudgetStop.solved;

  @override
  String toString() => 'CouncilFinished(r$round, ${stop.name}: $reason)';
}

class CouncilFailed extends CouncilEvent {
  const CouncilFailed(super.round, this.message);

  final String message;

  @override
  String toString() => 'CouncilFailed(r$round, $message)';
}

// ---------------------------------------------------------------------------
// Participants
// ---------------------------------------------------------------------------

/// One seat at the table: an agent plus the role it is playing this session.
class CouncilSeat {
  CouncilSeat({
    required this.kind,
    required this.displayName,
    required this.adapter,
    this.roleCard,
    bool isLeader = false,
  }) : _isLeader = isLeader;

  final String kind;
  final String displayName;
  final AgentAdapter adapter;

  /// Upgrade A1 (Role Cards): the persona this agent argues from.
  final String? roleCard;

  bool _isLeader;

  /// You can change who is in charge mid-session.
  bool get isLeader => _isLeader;
  set isLeader(bool value) => _isLeader = value;

  AgentBrief get brief =>
      AgentBrief(kind: kind, displayName: displayName, roleCard: roleCard);

  @override
  String toString() => 'CouncilSeat($kind${_isLeader ? ', leader' : ''})';
}

/// The result of a whole council run, for the Decision Record (A5).
class CouncilOutcome {
  const CouncilOutcome({
    required this.stop,
    required this.rounds,
    required this.answer,
    required this.confidence,
    required this.dissent,
    required this.transcript,
    required this.convergence,
  });

  final BudgetStop stop;
  final int rounds;
  final String? answer;
  final double? confidence;
  final List<String> dissent;
  final List<Exchange> transcript;
  final List<ConvergencePoint> convergence;
}

// ---------------------------------------------------------------------------
// Orchestrator
// ---------------------------------------------------------------------------

class Orchestrator {
  Orchestrator({
    required this.seats,
    required String leaderKind,
    required this.budget,
    PromptCompiler? compiler,
    SafetyFirewall? firewall,
    ConvergenceScorer? scorer,
    this.contextStrategy = ContextStrategy.delta,
    this.requireDissent = true,
    this.maskPiiOnRelay = true,
    this.collectVerdicts = true,
  }) : _leaderKind = leaderKind,
       compiler = compiler ?? PromptCompiler(),
       firewall = firewall ?? SafetyFirewall(),
       scorer = scorer ?? ConvergenceScorer() {
    if (seats.isEmpty) {
      throw ArgumentError('An orchestrator needs at least one seat.');
    }
    if (byKind[_leaderKind] == null) {
      throw ArgumentError('Leader "$_leaderKind" is not one of the seats.');
    }
  }

  final List<CouncilSeat> seats;
  final BudgetGuard budget;
  final PromptCompiler compiler;
  final SafetyFirewall firewall;
  final ConvergenceScorer scorer;
  final ContextStrategy contextStrategy;

  /// Upgrade A2 depends on this: the leader must surface at least one dissent
  /// before declaring victory.
  final bool requireDissent;

  /// Upgrade C2. When false, PII is reported but sent as-is.
  final bool maskPiiOnRelay;

  /// Upgrade A3: ask every delegate for a ```council_score block.
  final bool collectVerdicts;

  String _leaderKind;
  CouncilSeat? get leader => byKind[_leaderKind];
  set leaderKind(String kind) => _leaderKind = kind;

  Map<String, CouncilSeat> get byKind => <String, CouncilSeat>{
    for (final s in seats) s.kind: s,
  };

  final StreamController<CouncilEvent> _events =
      StreamController<CouncilEvent>.broadcast();
  Stream<CouncilEvent> get events => _events.stream;

  OrchestratorPhase _phase = OrchestratorPhase.idle;
  OrchestratorPhase get phase => _phase;

  bool _interrupted = false;
  bool get interrupted => _interrupted;

  final List<Exchange> _transcript = <Exchange>[];
  List<Exchange> get transcript => List<Exchange>.unmodifiable(_transcript);

  CouncilOutcome? _outcome;
  CouncilOutcome? get outcome => _outcome;

  bool _running = false;
  bool get isRunning => _running;

  /// The leader's verbatim reply from the round that asked the question.
  String? _openQuestion;

  /// The user's opening request, verbatim. Every packet quotes it back so a
  /// delegate never drifts from the original intent.
  String _originalPrompt = '';

  void _setPhase(OrchestratorPhase phase, int round, [String detail = '']) {
    _phase = phase;
    if (!_events.isClosed) {
      _events.add(PhaseChanged(round, phase, detail));
    }
  }

  // -- public control -------------------------------------------------------

  /// Stop the council at the next safe point. Never throws, never blocks.
  void interrupt() {
    if (_interrupted) return;
    _interrupted = true;
    log.w('orchestrator: user interrupt requested');
  }

  Future<void> dispose() async {
    _interrupted = true;
    await _events.close();
  }

  /// Drive the council to completion. Safe to await; never throws — failures
  /// surface as [CouncilFailed] and a `BudgetStop.fatalError` outcome.
  Future<CouncilOutcome> run(String userPrompt) async {
    if (_running) {
      throw StateError('This orchestrator is already running.');
    }
    _running = true;
    _interrupted = false;
    _transcript.clear();
    scorer.reset();

    final originalPrompt = userPrompt.trim();
    _originalPrompt = originalPrompt;
    final briefing = CouncilProtocol.leaderInstructions(
      displayName: _leaderSeat.displayName,
      participants: seats.map((s) => s.brief).toList(),
      maxRounds: budget.maxRounds,
      requireDissent: requireDissent,
    );
    final opening = Brief(
      objective: _objectiveOf(originalPrompt),
      deliverables: const <String>[
        'A decision the user can act on, with the reasoning that got there.',
      ],
      acceptance: const <String>[
        'Every claim is traceable to a specific round of this transcript.',
        'Disagreements are named, not smoothed over.',
      ],
    );

    try {
      return await _loop(originalPrompt, briefing, opening);
    } catch (error, stack) {
      log.e('orchestrator crashed', error, stack);
      _emit(CouncilFailed(budget.round, '$error'), budget.round);
      return _outcomeFor(BudgetStop.fatalError, answer: null, reason: '$error');
    } finally {
      _running = false;
    }
  }

  // -- the loop -------------------------------------------------------------

  Future<CouncilOutcome> _loop(
    String originalPrompt,
    String briefing,
    Brief opening,
  ) async {
    final lastSeen = <String, int>{};

    while (true) {
      if (_interrupted) {
        return _finish(BudgetStop.userInterrupt, 'you stopped the council');
      }

      final gate = budget.check();
      if (!gate.allowed) {
        return _finish(gate.stop!, gate.detail ?? 'budget exhausted');
      }
      if (!budget.startRound()) {
        return _finish(
          BudgetStop.roundCap,
          'reached the round cap (${budget.maxRounds})',
        );
      }

      final round = budget.round;
      final roundAnswers = <String, String>{};
      var roundSpeakers = <String>[];

      // ---------------- LEADER TURN ----------------
      _setPhase(OrchestratorPhase.leaderTurn, round, _leaderSeat.displayName);
      final leaderPacket = _packetFor(
        seat: _leaderSeat,
        brief: _leaderBriefFor(round, originalPrompt, briefing, opening),
        round: round,
        history: _transcript,
        lastSeen: lastSeen[_leaderKind],
        strategy: round == 1 ? ContextStrategy.full : contextStrategy,
      );
      final leaderReply = await _speak(
        seat: _leaderSeat,
        packet: leaderPacket,
        round: round,
        roundAnswers: roundAnswers,
        roundSpeakers: () => roundSpeakers,
      );
      if (leaderReply == null) {
        return _failure(round, 'the leader never answered');
      }
      lastSeen[_leaderKind] = round;
      _openQuestion = CouncilProtocol.proseOf(leaderReply.rawText);
      _relayGuard(leaderReply.rawText, _leaderKind);

      // ---------------- PARSE PROTOCOL ----------------
      _setPhase(OrchestratorPhase.parsing, round);
      final parse = CouncilProtocol.parse(
        leaderReply.rawText,
        participants: byKind.keys.toList(),
      );
      if (parse.hasError) {
        _emit(ProtocolWarning(round, parse.error!), round);
        log.w('round $round: protocol error — ${parse.error}');
      }

      final block = parse.block;
      final action = block?.action ?? CouncilAction.comment;

      // ---------------- DECIDE ----------------
      if (action == CouncilAction.decide && block != null) {
        final solved = block.isSolved;
        final blocked = block.isBlocked;
        final answer = block.answer;

        if (blocked) {
          return _finish(
            BudgetStop.userInterrupt,
            'the leader is blocked: $answer',
          );
        }
        if (solved && answer != null && answer.trim().isNotEmpty) {
          _transcript.add(
            Exchange(
              round: round,
              agentKind: _leaderKind,
              displayName: _leaderSeat.displayName,
              text: answer,
              isLeader: true,
            ),
          );
          return _finish(
            BudgetStop.solved,
            'the leader declared the problem solved',
            answer: answer,
            confidence: block.confidence,
            dissent: block.dissent,
          );
        }
      }

      // ---------------- NEED INPUT ----------------
      if (action == CouncilAction.needInput) {
        return _finish(
          BudgetStop.userInterrupt,
          'the leader needs your input before continuing',
        );
      }

      // ---------------- DISPATCH INVITES ----------------
      if (action == CouncilAction.invite && block != null) {
        final target = byKind[block.agent];
        if (target == null) {
          _emit(
            ProtocolWarning(round, 'unknown invite target "${block.agent}"'),
            round,
          );
        } else {
          _emit(
            ProtocolWarning(round, 'invite → ${target.displayName}'),
            round,
          );
          if (!budget.reserveInvite()) {
            log.w('round $round: invite cap reached, ignoring further invites');
          } else if (!budget.reserveMessage(target.kind)) {
            _emit(
              ProtocolWarning(
                round,
                'daily message cap reached for ${target.displayName} — skipped',
              ),
              round,
            );
          } else {
            _setPhase(OrchestratorPhase.dispatching, round, target.displayName);
            final packet = _packetFor(
              seat: target,
              brief: _inviteBrief(block, target),
              round: round,
              history: _transcript,
              lastSeen: lastSeen[target.kind],
              strategy: contextStrategy,
            );
            _emit(PacketDispatched(round, target.kind, packet), round);

            final reply = await _speak(
              seat: target,
              packet: packet,
              round: round,
              roundAnswers: roundAnswers,
              roundSpeakers: () => roundSpeakers,
            );
            if (reply == null) {
              return _failure(round, '${target.displayName} never answered');
            }
            lastSeen[target.kind] = round;
            _relayGuard(reply.rawText, target.kind);
          }
        }
      }

      // ---------------- JUDGE ----------------
      _setPhase(OrchestratorPhase.judging, round);
      final report = _judge(round, roundAnswers);
      _emit(ConvergenceUpdated(round, report), round);
      _emit(
        RoundCompleted(round, roundSpeakers, const Duration(seconds: 1)),
        round,
      );

      if (report.shouldStop) {
        final converged = report.state == ConvergenceState.converged;
        return _finish(
          converged ? BudgetStop.solved : BudgetStop.roundCap,
          'stopping early: ${report.reason}',
          convergenceReason: report.reason,
        );
      }
    }
  }

  // -- helpers --------------------------------------------------------------

  CouncilSeat get _leaderSeat => byKind[_leaderKind]!;

  /// One send → wait → capture cycle against a real browser tab.
  Future<Verbatim?> _speak({
    required CouncilSeat seat,
    required TaskPacket packet,
    required int round,
    required Map<String, String> roundAnswers,
    required List<String> Function() roundSpeakers,
  }) async {
    _setPhase(OrchestratorPhase.awaiting, round, seat.displayName);
    try {
      await seat.adapter.send(packet.body);
    } catch (error) {
      budget.recordTransportError();
      _emit(
        CouncilFailed(round, 'could not reach ${seat.displayName}: $error'),
        round,
      );
      return null;
    }

    Verbatim verbatim;
    try {
      verbatim = await seat.adapter.awaitCompletion();
    } catch (error) {
      budget.recordTransportError();
      _emit(
        CouncilFailed(round, '${seat.displayName} did not finish: $error'),
        round,
      );
      return null;
    }
    budget.clearTransportErrors();

    _emit(MessageCaptured(round, seat.kind, seat.displayName, verbatim), round);
    roundAnswers[seat.kind] = verbatim.rawText;
    roundSpeakers().add(seat.displayName);

    _transcript.add(
      Exchange(
        round: round,
        agentKind: seat.kind,
        displayName: seat.displayName,
        text: verbatim.rawText,
        roleCard: seat.roleCard,
        isLeader: seat.isLeader,
      ),
    );
    return verbatim;
  }

  TaskPacket _packetFor({
    required CouncilSeat seat,
    required Brief brief,
    required int round,
    required List<Exchange> history,
    int? lastSeen,
    required ContextStrategy strategy,
  }) {
    final packet = compiler.compile(
      target: seat.brief,
      brief: brief,
      strategy: strategy,
      round: round,
      maxRounds: budget.maxRounds,
      history: history,
      lastSeen: lastSeen,
      roleCards: seats
          .map((s) => '${s.displayName}: ${s.roleCard ?? 'no assigned role'}')
          .toList(),
      originalPrompt: _originalPrompt,
    );
    return packet;
  }

  /// Round 1 gets the full protocol briefing; later rounds only need the state.
  Brief _leaderBriefFor(
    int round,
    String originalPrompt,
    String briefing,
    Brief opening,
  ) {
    if (round != 1) {
      return Brief(
        objective: _openQuestion?.isNotEmpty == true
            ? 'Advance the council: $_openQuestion'
            : opening.objective,
        constraints: opening.constraints,
        deliverables: opening.deliverables,
        acceptance: opening.acceptance,
        openQuestion: _openQuestion,
      );
    }
    return Brief(
      objective: briefing,
      constraints: opening.constraints,
      deliverables: opening.deliverables,
      acceptance: opening.acceptance,
      knownUnknowns: const <String>['Nothing has been investigated yet.'],
      openQuestion: originalPrompt,
    );
  }

  /// The delegate's task, built from the leader's invite block.
  Brief _inviteBrief(CouncilBlock block, CouncilSeat target) {
    final constraints = <String>[
      if (block.expect != null && block.expect!.trim().isNotEmpty)
        'Deliver exactly this: ${block.expect!.trim()}',
      'You are ${target.displayName}'
          '${target.roleCard == null ? '' : ', acting as ${target.roleCard}'}.',
      'Answer the task. Do not attempt to invite other agents yourself.',
    ];
    return Brief(
      objective: (block.task ?? 'Respond to the council.').trim(),
      constraints: constraints,
      deliverables: const <String>[
        'Your answer in your own voice — Agora does not rewrite it.',
      ],
      acceptance: const <String>[
        'Every claim traceable to something you can justify.',
      ],
      openQuestion: block.context,
    );
  }

  ConvergenceReport _judge(int round, Map<String, String> answers) {
    final verdicts = <AgentVerdict>[];
    if (collectVerdicts) {
      for (final entry in answers.entries) {
        final verdict = ConvergenceScorer.parseVerdict(entry.key, entry.value);
        if (verdict != null) verdicts.add(verdict);
      }
    }
    return scorer.record(round: round, answers: answers, verdicts: verdicts);
  }

  /// Run relayed text past the firewall and surface anything it finds.
  void _relayGuard(String text, String fromKind) {
    final report = firewall.relay(
      text: text,
      fromAgent: fromKind,
      toAgent: 'council',
      maskPii: maskPiiOnRelay,
    );
    if (!report.isClean) {
      final summary = SafetyFirewall.summarize(report);
      log.w('firewall: $summary');
      _emit(SafetyWarning(budget.round, report), budget.round);
    }
  }

  CouncilOutcome _outcomeFor(
    BudgetStop stop, {
    String? answer,
    double? confidence,
    List<String> dissent = const <String>[],
    required String reason,
  }) {
    return CouncilOutcome(
      stop: stop,
      rounds: budget.round,
      answer: answer,
      confidence: confidence,
      dissent: dissent,
      transcript: List<Exchange>.unmodifiable(_transcript),
      convergence: scorer.points,
    );
  }

  CouncilOutcome _finish(
    BudgetStop stop,
    String reason, {
    String? answer,
    double? confidence,
    List<String> dissent = const <String>[],
    String? convergenceReason,
  }) {
    final round = budget.round;
    _setPhase(OrchestratorPhase.finalizing, round, reason);
    _emit(
      CouncilFinished(round, stop, answer, confidence, dissent, reason),
      round,
    );
    _setPhase(OrchestratorPhase.stopped, round, stop.label);
    final outcome = _outcomeFor(
      stop,
      answer: answer,
      confidence: confidence,
      dissent: dissent,
      reason: reason,
    );
    _outcome = outcome;
    log.i(
      'council finished after ${budget.round} round(s): ${stop.name} — $reason'
      '${convergenceReason == null ? '' : ' ($convergenceReason)'}',
    );
    return outcome;
  }

  CouncilOutcome _failure(int round, String why) {
    _setPhase(OrchestratorPhase.failed, round, why);
    _emit(CouncilFailed(round, why), round);
    return _outcomeFor(BudgetStop.fatalError, reason: why);
  }

  void _emit(CouncilEvent event, int round) {
    if (!_events.isClosed) _events.add(event);
  }

  /// The leader's first objective is the user's own words, trimmed to a
  /// sentence so the brief stays readable.
  static String _objectiveOf(String prompt) {
    final line = prompt
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => prompt.trim());
    return line.length <= 240 ? line : '${line.substring(0, 237)}...';
  }
}
