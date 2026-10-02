import 'dart:async';

import '../logging.dart';

/// A hard stop that the council can never argue its way out of.
///
/// This is what makes "talk until it is solved" safe. Every limit in Agora is
/// either a BudgetStop (a hard limit) or a ConvergenceStop (the council is
/// actually done). There is no third option, so a session always terminates.
enum BudgetStop {
  /// The leader emitted a `decide` block with status "solved". This is the
  /// only stop that means the council actually reached an answer.
  solved,
  roundCap,
  timeBudget,
  inviteCap,
  transportErrors,
  dailyMessageCap,
  userInterrupt,
  fatalError;

  String get label => switch (this) {
    BudgetStop.solved => 'Solved',
    BudgetStop.roundCap => 'round cap reached',
    BudgetStop.timeBudget => 'time budget exhausted',
    BudgetStop.inviteCap => 'too many invites this round',
    BudgetStop.transportErrors => 'repeated transport failures',
    BudgetStop.dailyMessageCap => 'daily message cap reached (account safety)',
    BudgetStop.userInterrupt => 'stopped by user',
    BudgetStop.fatalError => 'fatal error',
  };
}

class BudgetDecision {
  BudgetDecision(this.allowed, [this.stop, this.detail]);

  final bool allowed;
  final BudgetStop? stop;
  final String? detail;

  static final BudgetDecision ok = BudgetDecision(true);

  @override
  String toString() => allowed ? 'ok' : 'STOP(${stop?.name}): ${detail ?? ''}';
}

/// Enforces the hard limits of a session.
///
/// Every check is cheap and side-effect free, so the orchestrator can call it
/// before every dispatch without affecting timing. Reserve methods are the
/// only ones that mutate state.
class BudgetGuard {
  BudgetGuard({
    required this.maxRounds,
    required this.timeBudget,
    this.maxInvitesPerRound = 3,
    this.maxTransportErrors = 2,
    this.dailyMessageCap = 60,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _startedAt = _clock();
  }

  final int maxRounds;
  final Duration timeBudget;
  final int maxInvitesPerRound;
  final int maxTransportErrors;

  /// Account-safety limit. See the risk register in PLAN.md: automating chat
  /// UIs is against most providers' terms, so Agora stays human-paced.
  final int dailyMessageCap;

  final DateTime Function() _clock;

  /// Assigned in the constructor body; field initializers cannot read `this`.
  late final DateTime _startedAt;

  int _round = 0;
  int _invitesThisRound = 0;
  int _transportErrors = 0;
  final Map<String, Map<String, int>> _todaySent = <String, Map<String, int>>{};

  int get round => _round;
  int get elapsed => _clock().difference(_startedAt).inSeconds;
  Duration get remaining => timeBudget - Duration(seconds: elapsed);
  bool get timeExhausted => elapsed >= timeBudget.inSeconds;
  bool get roundCapReached => _round >= maxRounds;
  bool get inviteCapReached => _invitesThisRound >= maxInvitesPerRound;
  int get invitesThisRound => _invitesThisRound;
  int get transportErrors => _transportErrors;

  String get _day => _clock().toIso8601String().substring(0, 10);

  /// Begin a new round. Returns false if the cap is already hit.
  bool startRound() {
    if (_round >= maxRounds) return false;
    _round++;
    _invitesThisRound = 0;
    return true;
  }

  bool reserveInvite() {
    if (inviteCapReached) return false;
    _invitesThisRound++;
    return true;
  }

  void recordTransportError() => _transportErrors++;
  void clearTransportErrors() => _transportErrors = 0;

  int sentToday(String agentKind) => _todaySent[_day]?[agentKind] ?? 0;

  /// Count a message actually sent to an AI site.
  ///
  /// Returns false when this message pushes that agent past the daily cap; the
  /// caller must not send. (The counter still increments so the UI can show
  /// "3 over cap".)
  bool reserveMessage(String agentKind) {
    final map = _todaySent.putIfAbsent(_day, () => <String, int>{});
    final next = (map[agentKind] ?? 0) + 1;
    map[agentKind] = next;
    return next <= dailyMessageCap;
  }

  /// The one call the orchestrator makes before every dispatch.
  BudgetDecision check() {
    if (roundCapReached) {
      return BudgetDecision(
        false,
        BudgetStop.roundCap,
        'round $round of $maxRounds',
      );
    }
    if (timeExhausted) {
      return BudgetDecision(
        false,
        BudgetStop.timeBudget,
        '${elapsed}s of ${timeBudget.inSeconds}s',
      );
    }
    if (inviteCapReached) {
      return BudgetDecision(
        false,
        BudgetStop.inviteCap,
        '$maxInvitesPerRound invites already dispatched this round',
      );
    }
    if (_transportErrors >= maxTransportErrors) {
      return BudgetDecision(
        false,
        BudgetStop.transportErrors,
        '$_transportErrors consecutive failures',
      );
    }
    return BudgetDecision.ok;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'round': _round,
    'maxRounds': maxRounds,
    'elapsedSeconds': elapsed,
    'timeBudgetSeconds': timeBudget.inSeconds,
    'remainingSeconds': remaining.inSeconds,
    'invitesThisRound': _invitesThisRound,
    'transportErrors': _transportErrors,
    'sentToday': Map<String, int>.from(
      _todaySent[_day] ?? const <String, int>{},
    ),
  };

  @override
  String toString() =>
      'BudgetGuard(r$_round/$maxRounds, '
      '${elapsed}s/${timeBudget.inSeconds}s, invites $_invitesThisRound)';
}

/// One-shot wall-clock timer that can be cancelled.
///
/// Guards against a hung browser tab stalling a session forever.
class Deadline {
  Deadline(this.duration, this.onExpire);

  final Duration duration;
  final void Function() onExpire;

  Timer? _timer;
  bool _fired = false;

  bool get fired => _fired;

  void start() {
    cancel();
    _timer = Timer(duration, () {
      _fired = true;
      log.w('deadline fired after ${duration.inSeconds}s');
      onExpire();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
