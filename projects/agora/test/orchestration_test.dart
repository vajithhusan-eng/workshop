import 'package:agora/core/orchestration/budget.dart';
import 'package:agora/core/orchestration/convergence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConvergenceScorer — similarity', () {
    test('identical text is 1.0', () {
      expect(
        ConvergenceScorer.similarity(
          'the cathode is stable',
          'the cathode is stable',
        ),
        1.0,
      );
    });

    test('disjoint text is 0.0', () {
      expect(
        ConvergenceScorer.similarity('alpha beta', 'gamma delta epsilon'),
        0.0,
      );
    });

    test('partial overlap lands between 0 and 1', () {
      final s = ConvergenceScorer.similarity(
        'lithium iron phosphate is safer than NMC',
        'lithium iron phosphate costs less than NMC',
      );
      expect(s, greaterThan(0.0));
      expect(s, lessThan(1.0));
    });

    test('is case and punctuation insensitive', () {
      expect(ConvergenceScorer.similarity('Hello, World!', 'hello world'), 1.0);
    });

    test('empty vs empty is 1.0, empty vs text is 0.0', () {
      expect(ConvergenceScorer.similarity('', ''), 1.0);
      expect(ConvergenceScorer.similarity('', 'anything'), 0.0);
    });
  });

  group('ConvergenceScorer — verdict parsing', () {
    test('parses a well formed council_score block', () {
      const reply = '''
Looks good overall.

```council_score
{"score": 8, "confidence": 0.9, "reason": "chemistry checks out"}
```
''';
      final v = ConvergenceScorer.parseVerdict('gemini', reply);
      expect(v, isNotNull);
      expect(v!.score, 8.0);
      expect(v.confidence, 0.9);
      expect(v.reason, 'chemistry checks out');
      expect(v.agentKind, 'gemini');
      expect(v.satisfied, isTrue);
    });

    test('absent block means no vote, never an error', () {
      expect(ConvergenceScorer.parseVerdict('gemini', 'just prose'), isNull);
    });

    test('normalises "8" confidence into 0.8', () {
      const reply = '```council_score\n{"score":7,"confidence":8}\n```';
      final v = ConvergenceScorer.parseVerdict('x', reply);
      expect(v!.confidence, closeTo(0.8, 1e-9));
    });

    test('clamps an out-of-range score', () {
      expect(
        ConvergenceScorer.parseVerdict(
          'x',
          '```council_score\n{"score":50}\n```',
        )!.score,
        10.0,
      );
    });

    test('requires a score field', () {
      expect(
        ConvergenceScorer.parseVerdict(
          'x',
          '```council_score\n{"confidence":0.5}\n```',
        ),
        isNull,
      );
    });

    test('uses the LAST block when several are present', () {
      const reply = '''
```council_score
{"score": 2, "confidence": 0.1, "reason": "early"}
```
reconsidering...
```council_score
{"score": 9, "confidence": 0.9, "reason": "later"}
```
''';
      expect(ConvergenceScorer.parseVerdict('x', reply)!.score, 9.0);
    });
  });

  group('ConvergenceScorer — round recording', () {
    late ConvergenceScorer s;

    setUp(() => s = ConvergenceScorer(minRoundsBeforeConverge: 2));

    test('no answers -> gathering, does not record a point', () {
      final r = s.record(round: 1, answers: const {});
      expect(r.state, ConvergenceState.gathering);
      expect(s.points, isEmpty);
    });

    test('refuses to converge before minRounds', () {
      final v = <AgentVerdict>[
        AgentVerdict(
          agentKind: 'a',
          score: 9,
          confidence: 0.9,
          reason: '',
          text: '',
        ),
        AgentVerdict(
          agentKind: 'b',
          score: 9,
          confidence: 0.9,
          reason: '',
          text: '',
        ),
      ];
      final r = s.record(
        round: 1,
        answers: const {'a': 'same answer', 'b': 'same answer'},
        verdicts: v,
      );
      expect(r.state, ConvergenceState.gathering);
      expect(r.reason, contains('at least 2'));
    });

    test('converges when votes are satisfied and texts agree', () {
      final v = <AgentVerdict>[
        AgentVerdict(
          agentKind: 'a',
          score: 9,
          confidence: 0.9,
          reason: '',
          text: '',
        ),
        AgentVerdict(
          agentKind: 'b',
          score: 8,
          confidence: 0.8,
          reason: '',
          text: '',
        ),
      ];
      // Round 1: gathering.
      s.record(
        round: 1,
        answers: const {'a': 'alpha one', 'b': 'alpha one'},
        verdicts: v,
      );
      // Round 2: identical answers -> similarity 1.0, agreement 1.0.
      final r = s.record(
        round: 2,
        answers: const {'a': 'alpha one', 'b': 'alpha one'},
        verdicts: v,
      );
      expect(r.state, ConvergenceState.converged);
      expect(r.shouldStop, isTrue);
      expect(r.latest!.meanScore, closeTo(8.5, 1e-9));
    });

    test('does NOT converge while the answer is still MOVING', () {
      final v = <AgentVerdict>[
        AgentVerdict(
          agentKind: 'a',
          score: 9,
          confidence: 0.9,
          reason: '',
          text: '',
        ),
        AgentVerdict(
          agentKind: 'b',
          score: 9,
          confidence: 0.9,
          reason: '',
          text: '',
        ),
      ];
      s.record(
        round: 1,
        answers: const {'a': 'alpha one', 'b': 'alpha one'},
        verdicts: v,
      );
      final r = s.record(
        round: 2,
        answers: const {
          'a': 'completely different topic about turtles',
          'b': 'completely different topic about turtles',
        },
        verdicts: v,
      );
      // They agree with EACH OTHER but not with last round -> stagnant territory,
      // but only 1 round of it, so not yet a stop.
      expect(r.state, isNot(ConvergenceState.converged));
      expect(r.shouldStop, isFalse);
    });

    test('does NOT converge while agents disagree with EACH OTHER', () {
      final v = <AgentVerdict>[
        AgentVerdict(
          agentKind: 'a',
          score: 9,
          confidence: 0.9,
          reason: '',
          text: '',
        ),
        AgentVerdict(
          agentKind: 'b',
          score: 9,
          confidence: 0.9,
          reason: '',
          text: '',
        ),
      ];
      const split = {'a': 'use LFP chemistry', 'b': 'use NMC chemistry'};
      s.record(round: 1, answers: split, verdicts: v);
      // Same answers every round (so it counts as settled) but the two agents
      // say different things inside the round -> low agreement.
      final r = s.record(round: 2, answers: split, verdicts: v);
      expect(r.latest!.similarity, closeTo(1.0, 1e-9)); // settled
      expect(r.latest!.agreement, lessThan(0.82)); // but they disagree
      expect(r.state, isNot(ConvergenceState.converged));
      expect(r.reason, contains('disagree'));
    });

    test('does NOT converge when agents are unsatisfied', () {
      final v = <AgentVerdict>[
        AgentVerdict(
          agentKind: 'a',
          score: 3,
          confidence: 0.9,
          reason: '',
          text: '',
        ),
        AgentVerdict(
          agentKind: 'b',
          score: 4,
          confidence: 0.9,
          reason: '',
          text: '',
        ),
      ];
      s.record(
        round: 1,
        answers: const {'a': 'same', 'b': 'same'},
        verdicts: v,
      );
      final r = s.record(
        round: 2,
        answers: const {'a': 'same', 'b': 'same'},
        verdicts: v,
      );
      expect(r.state, isNot(ConvergenceState.converged));
      expect(r.reason, contains('satisfied'));
    });

    test('low-confidence verdicts never converge', () {
      final v = <AgentVerdict>[
        AgentVerdict(
          agentKind: 'a',
          score: 10,
          confidence: 0.2,
          reason: '',
          text: '',
        ),
        AgentVerdict(
          agentKind: 'b',
          score: 10,
          confidence: 0.3,
          reason: '',
          text: '',
        ),
      ];
      s.record(
        round: 1,
        answers: const {'a': 'same', 'b': 'same'},
        verdicts: v,
      );
      final r = s.record(
        round: 2,
        answers: const {'a': 'same', 'b': 'same'},
        verdicts: v,
      );
      expect(r.state, isNot(ConvergenceState.converged));
    });

    test('declares STAGNANT after the configured repeated rounds', () {
      final stagnant = ConvergenceScorer(
        stagnationRoundsToStop: 2,
        minRoundsBeforeConverge: 1,
      );
      const same = <String, String>{'a': 'identical answer text'};
      // Round 1 seeds _previousText but is not a movement sample, so two
      // stagnant crossRound points require rounds 2 AND 3.
      stagnant.record(round: 1, answers: same);
      final r2 = stagnant.record(round: 2, answers: same);
      expect(r2.state, isNot(ConvergenceState.stagnant));
      final r3 = stagnant.record(round: 3, answers: same);
      expect(r3.state, ConvergenceState.stagnant);
      expect(r3.shouldStop, isTrue);
      expect(r3.stagnantRounds, greaterThanOrEqualTo(2));
      expect(r3.reason, contains('not changed'));
    });

    test('moving answers reset the stagnation counter', () {
      final stagnant = ConvergenceScorer(
        stagnationRoundsToStop: 2,
        minRoundsBeforeConverge: 1,
      );
      stagnant.record(round: 1, answers: const {'a': 'aaaa bbbb cccc'});
      stagnant.record(round: 2, answers: const {'a': 'aaaa bbbb cccc'});
      // A genuinely different round breaks the run.
      final r = stagnant.record(
        round: 3,
        answers: const {'a': 'zzzz yyyy xxxx wwwww vvvvv uuuuu'},
      );
      expect(r.state, isNot(ConvergenceState.stagnant));
      expect(r.stagnantRounds, 0);
    });

    test('graph series are exposed for the Convergence Graph widget', () {
      final v = <AgentVerdict>[
        AgentVerdict(
          agentKind: 'a',
          score: 5,
          confidence: 0.5,
          reason: '',
          text: '',
        ),
      ];
      s.record(round: 1, answers: const {'a': 'one two three'}, verdicts: v);
      s.record(round: 2, answers: const {'a': 'one two four'}, verdicts: v);
      expect(s.points.length, 2);
      expect(rScoreSeries(s).length, 2);
      expect(rScoreSeries(s).first, closeTo(5.0, 1e-9));
    });

    test('reset clears history', () {
      s.record(round: 1, answers: const {'a': 'x y z'});
      s.reset();
      expect(s.points, isEmpty);
    });
  });

  group('BudgetGuard — hard stops', () {
    late DateTime now;
    DateTime clock() => now;

    setUp(() => now = DateTime(2026, 1, 1, 12, 0, 0));

    test('allows work inside every limit', () {
      final g = BudgetGuard(
        maxRounds: 5,
        timeBudget: const Duration(minutes: 10),
        clock: clock,
      );
      g.startRound();
      expect(g.check().allowed, isTrue);
    });

    test('round cap stops the council', () {
      final g = BudgetGuard(
        maxRounds: 2,
        timeBudget: const Duration(minutes: 10),
        clock: clock,
      );
      expect(g.startRound(), isTrue);
      expect(g.startRound(), isTrue);
      expect(g.startRound(), isFalse, reason: 'third round must be refused');
      final d = g.check();
      expect(d.allowed, isFalse);
      expect(d.stop, BudgetStop.roundCap);
    });

    test('time budget stops the council', () {
      final g = BudgetGuard(
        maxRounds: 99,
        timeBudget: const Duration(seconds: 60),
        clock: clock,
      );
      now = now.add(const Duration(seconds: 61));
      final d = g.check();
      expect(d.allowed, isFalse);
      expect(d.stop, BudgetStop.timeBudget);
      expect(g.remaining.inSeconds, lessThan(0));
    });

    test('invite cap stops runaway fan-out', () {
      final g = BudgetGuard(
        maxRounds: 99,
        timeBudget: const Duration(minutes: 10),
        clock: clock,
      );
      g.startRound();
      // Default cap is 3 invites per round.
      expect(g.reserveInvite(), isTrue);
      expect(g.reserveInvite(), isTrue);
      expect(g.reserveInvite(), isTrue);
      expect(g.reserveInvite(), isFalse);
      expect(g.check().stop, BudgetStop.inviteCap);
    });

    test('invite counter resets each round', () {
      final g = BudgetGuard(
        maxRounds: 99,
        timeBudget: const Duration(minutes: 10),
        clock: clock,
      );
      g.startRound();
      g.reserveInvite();
      g.startRound();
      expect(g.invitesThisRound, 0);
      expect(g.check().allowed, isTrue);
    });

    test('two consecutive transport errors stop the council', () {
      final g = BudgetGuard(
        maxRounds: 99,
        timeBudget: const Duration(minutes: 10),
        clock: clock,
      );
      g.recordTransportError();
      expect(g.check().allowed, isTrue, reason: 'one error is tolerated');
      g.recordTransportError();
      expect(g.check().stop, BudgetStop.transportErrors);
    });

    test('a success clears the transport error streak', () {
      final g = BudgetGuard(
        maxRounds: 99,
        timeBudget: const Duration(minutes: 10),
        clock: clock,
      );
      g.recordTransportError();
      g.clearTransportErrors();
      g.recordTransportError();
      expect(g.check().allowed, isTrue);
    });

    test('daily message cap protects the account', () {
      final g = BudgetGuard(
        maxRounds: 99,
        timeBudget: const Duration(minutes: 10),
        dailyMessageCap: 2,
        clock: clock,
      );
      expect(g.reserveMessage('gemini'), isTrue);
      expect(g.reserveMessage('gemini'), isTrue);
      expect(
        g.reserveMessage('gemini'),
        isFalse,
        reason: 'third exceeds cap of 2',
      );
      expect(
        g.sentToday('gemini'),
        3,
        reason: 'still counted so UI can show overrun',
      );
      expect(g.sentToday('chatgpt'), 0, reason: 'caps are per agent');
    });

    test('daily counters reset on a new day', () {
      final g = BudgetGuard(
        maxRounds: 99,
        timeBudget: const Duration(minutes: 10),
        dailyMessageCap: 2,
        clock: clock,
      );
      g.reserveMessage('gemini');
      g.reserveMessage('gemini');
      expect(g.reserveMessage('gemini'), isFalse);
      now = now.add(const Duration(days: 1));
      expect(g.sentToday('gemini'), 0);
      expect(g.reserveMessage('gemini'), isTrue);
    });

    test('toJson reports the whole budget for the UI', () {
      final g = BudgetGuard(
        maxRounds: 3,
        timeBudget: const Duration(minutes: 5),
        clock: clock,
      );
      g.startRound();
      g.reserveInvite();
      final j = g.toJson();
      expect(j['round'], 1);
      expect(j['maxRounds'], 3);
      expect(j['timeBudgetSeconds'], 300);
      expect(j['invitesThisRound'], 1);
    });
  });

  group('Deadline', () {
    test('fires and can be cancelled', () async {
      var fired = 0;
      final d = Deadline(const Duration(milliseconds: 20), () => fired++);
      d.start();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(fired, 1);
      expect(d.fired, isTrue);

      final d2 = Deadline(const Duration(milliseconds: 20), () => fired++);
      d2.start();
      d2.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(fired, 1, reason: 'cancelled deadline must not fire');
    });
  });
}

/// Small helper so the graph-series assertion reads clearly.
List<double> rScoreSeries(ConvergenceScorer s) =>
    s.points.map((p) => p.meanScore).toList();
