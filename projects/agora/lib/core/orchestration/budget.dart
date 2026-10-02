import 'dart:async';

import '../logging.dart';

/// A hard stop that the council can never argue its way out of.
///
/// This is what makes "talk until it is solved" safe. Every limit in Agora is
/// either a BudgetStop (a hard limit) or a ConvergenceStop (the council is
/// actually done). There is no third option, so a session always terminates.
enum BudgetStop {
  roundCap,
  timeBudget,
  inviteCap,
  transportErrors,
  dailyMessageCap,
  userInterrupt,
  fatalError;

  String get label => switch (this) {
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
}

/// Enforces the hard limits of a session.
///
/// Every check is cheap, synchronous, and has no side effects, so it can be
/// called before every dispatch without affecting timing.
class BudgetGuard {
  BudgetGuard({
    required this.maxRounds,
    required this.timeBudget,
    this.maxInvitesPerRound = 3,
    this.maxTransportErrors = 2,
    this.dailyMessageCap = 60,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int maxRounds;
  final Duration timeBudget;
  final int maxInvitesPerRound;
  final int maxTransportErrors;

  /// Account-safety limit (see the risk register in PLAN.md — automating chat
  /// UIs is against most providers' terms, so Agora stays human-paced).
  final int dailyMessageCap;

  final DateTime Function() _clock;

  final DateTime _startedAt = _bootNow();
  DateTime Function() _bootNow() => DateTime.now;

  int get round => _round;
  int _round = 0;

  int get elapsed => _clock().difference(_startedAt).inSeconds;
  Duration get remaining => timeBudget - Duration(seconds: elapsed);
  bool get timeExhausted => elapsed >= timeBudget.inSeconds;

  int _invitesThisRound = 0;
  int get invitesThisRound => _invitesThisRound;

  int _transportErrors = 0;
  int get transportErrors => _transportErrors;

  final Map<String, int> _todaySent = <String, int>{};
  String get _day => _clock().toIso8601String().substring(0, 10);

  /// Begin a new round. Returns false if the cap is already hit.
  bool startRound() {
    if (_round >= maxRounds) return false;
    _round++;
    _invitesThisRound = 0;
    return true;
  }

  bool get roundCapReached => _round >= maxRounds;
  bool get inviteCapReached => _invitesThisRound >= maxInvitesPerRound;

  bool reserveInvite() {
    if (inviteCapReached) return false;
    _invitesThisRound++;
    return true;
  }

  void recordTransportError() => _transportErrors++;
  void clearTransportErrors() => _transportErrors = 0;

  int sentToday(String agentKind) =>
      _todaySent[_day]?.let((m) => m[agentKind] ?? 0) ?? 0;

  /// Count a message actually sent to an AI site, and report if it would push
  /// that agent over the daily cap.
  bool reserveMessage(String agentKind) {
    final day = _day;
    final map = _todaySent.putIfAbsent(day, () => <String, int>{});
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

  Map<String, dynamic> toJson() => {
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
      'BudgetGuard(r${_round}/$maxRounds, '
      '${elapsed}s/${timeBudget.inSeconds}s, invites $_invitesThisRound)';
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

/// Wall-clock timer that calls back once, and can be cancelled.
///
/// Used for "the leader has been thinking for too long" so a hung tab can
/// never stall a session forever.
class Deadline {
  Deadline(this.duration, this.onExpire);

  final Duration duration;
  final void Function() onExpire;

  Timer? _timer;
  bool _fired = false;

  bool get fired => _fired;

  void start() {
    _timer?.cancel();
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
