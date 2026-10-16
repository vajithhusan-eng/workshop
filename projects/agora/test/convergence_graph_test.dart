import 'package:agora/core/orchestration/convergence.dart';
import 'package:agora/ui/convergence_graph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ConvergencePoint point(int round, double meanScore, double similarity) =>
    ConvergencePoint(
      round: round,
      similarity: similarity,
      meanScore: meanScore,
      meanConfidence: 0.8,
      agreement: 0.5,
      answered: 2,
      satisfiedFraction: 0.5,
      crossRound: round > 1,
    );

ConvergenceReport report(
  ConvergenceState state, {
  String reason = '',
  List<ConvergencePoint> points = const <ConvergencePoint>[],
}) => ConvergenceReport(
  state: state,
  reason: reason,
  points: points,
  latest: points.isEmpty ? null : points.last,
  verdicts: const <AgentVerdict>[],
  stagnantRounds: 0,
);

void main() {
  group('normalizedPolyline — series to graph points', () {
    test('an empty series draws nothing', () {
      expect(
        normalizedPolyline(const <double>[], const Size(100, 40)),
        isEmpty,
      );
    });

    test('a single sample sits at the left edge', () {
      final pts = normalizedPolyline(<double>[0.5], const Size(100, 40));
      expect(pts, hasLength(1));
      expect(pts.first.dx, 0);
      expect(pts.first.dy, closeTo(20, 0.001));
    });

    test('a full series spans the width left to right', () {
      final pts = normalizedPolyline(<double>[0, 0.5, 1], const Size(100, 40));
      expect(pts, hasLength(3));
      expect(pts.first.dx, 0);
      expect(pts.last.dx, 100);
      expect(pts[1].dx, closeTo(50, 0.001));
    });

    test('a 1.0 sample is at the top and a 0.0 sample at the bottom', () {
      final pts = normalizedPolyline(<double>[1.0, 0.0], const Size(100, 40));
      expect(pts.first.dy, 0); // 1.0 -> top
      expect(pts.last.dy, 40); // 0.0 -> bottom
    });

    test('out-of-range samples are clamped, not dropped', () {
      final pts = normalizedPolyline(<double>[-1, 2], const Size(100, 40));
      expect(pts, hasLength(2));
      expect(pts.first.dy, 40); // -1 clamps to 0.0 -> bottom
      expect(pts.last.dy, 0); // 2 clamps to 1.0 -> top
    });
  });

  group('convergenceLabel — the one-word state', () {
    test('every state has a distinct, non-empty label', () {
      final labels = ConvergenceState.values.map(convergenceLabel).toList();
      expect(labels.toSet(), hasLength(ConvergenceState.values.length));
      expect(labels.every((l) => l.trim().isNotEmpty), isTrue);
    });

    test('names each state for a human', () {
      expect(convergenceLabel(ConvergenceState.gathering), 'Gathering');
      expect(convergenceLabel(ConvergenceState.converged), 'Converged');
      expect(convergenceLabel(ConvergenceState.stagnant), 'Stagnant');
      expect(convergenceLabel(ConvergenceState.unknown), 'Unknown');
    });
  });

  group('ConvergenceCard — the HUD renders the real numbers', () {
    Future<void> pump(WidgetTester t, ConvergenceReport r) => t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConvergenceCard(report: r)),
      ),
    );

    testWidgets('a gathering council shows the state and no graph', (t) async {
      await pump(t, report(ConvergenceState.gathering));
      expect(find.text('Gathering'), findsOneWidget);
      expect(find.text('0 rounds'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a converged council shows the state, rounds and reason', (
      t,
    ) async {
      await pump(
        t,
        report(
          ConvergenceState.converged,
          reason: 'Votes are satisfied and the answers agree.',
          points: <ConvergencePoint>[
            point(1, 0.4, 0.3),
            point(2, 0.8, 0.7),
            point(3, 0.95, 0.9),
          ],
        ),
      );
      expect(find.text('Converged'), findsOneWidget);
      expect(find.text('3 rounds'), findsOneWidget);
      expect(
        find.text('Votes are satisfied and the answers agree.'),
        findsOneWidget,
      );
    });

    testWidgets('a stagnant council still renders rather than throwing', (
      t,
    ) async {
      await pump(
        t,
        report(
          ConvergenceState.stagnant,
          reason: 'Three rounds produced the same answer.',
          points: <ConvergencePoint>[point(1, 0.6, 0.5), point(2, 0.6, 0.98)],
        ),
      );
      expect(find.text('Stagnant'), findsOneWidget);
      expect(find.text('2 rounds'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
