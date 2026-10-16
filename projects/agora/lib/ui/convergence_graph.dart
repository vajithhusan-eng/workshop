import 'package:flutter/material.dart';

import '../core/orchestration/convergence.dart';
import 'theme.dart';

/// §18.3 HUD — the convergence read-out.
///
/// Pure presentation over numbers the orchestrator already produces: the mean
/// self-reported score and the cross-round text similarity, one point per
/// round. Nothing here invents a value — an empty series draws nothing and the
/// card still tells the truth ("Gathering", no graph).
class ConvergenceCard extends StatelessWidget {
  const ConvergenceCard({super.key, required this.report, this.height = 64});

  final ConvergenceReport report;
  final double height;

  @override
  Widget build(BuildContext context) {
    final state = report.state;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AgoraTheme.dim.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, size: 14, color: convergenceColor(state)),
              const SizedBox(width: 6),
              Text(
                convergenceLabel(state),
                style: TextStyle(
                  color: convergenceColor(state),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${report.points.length} round'
                '${report.points.length == 1 ? '' : 's'}',
                style: AgoraTheme.caption,
              ),
            ],
          ),
          if (report.points.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(
                painter: _ConvergencePainter(
                  scores: report.scoreSeries,
                  similarities: report.similaritySeries,
                ),
              ),
            ),
          ],
          if (report.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(report.reason, style: AgoraTheme.caption),
          ],
        ],
      ),
    );
  }
}

/// A one-word reading of a convergence state, for the HUD chip.
String convergenceLabel(ConvergenceState state) => switch (state) {
  ConvergenceState.gathering => 'Gathering',
  ConvergenceState.converged => 'Converged',
  ConvergenceState.stagnant => 'Stagnant',
  ConvergenceState.unknown => 'Unknown',
};

/// The colour that reads the state at a glance.
Color convergenceColor(ConvergenceState state) => switch (state) {
  ConvergenceState.converged => AgoraTheme.ok,
  ConvergenceState.stagnant => AgoraTheme.danger,
  ConvergenceState.gathering => AgoraTheme.accent,
  ConvergenceState.unknown => AgoraTheme.dim,
};

/// Map a series of 0..1 samples onto points inside a box of [size].
///
/// Index runs across the width; value runs up the height, with 1.0 at the top
/// and 0.0 at the bottom. Out-of-range samples are clamped, never dropped.
/// Exposed for tests: the graph is only honest if this mapping is the one the
/// axis implies.
List<Offset> normalizedPolyline(List<double> series, Size size) {
  if (series.isEmpty) return const <Offset>[];
  if (series.length == 1) {
    final y = (1 - series.first.clamp(0.0, 1.0)) * size.height;
    return <Offset>[Offset(0, y)];
  }
  final dx = size.width / (series.length - 1);
  return <Offset>[
    for (var i = 0; i < series.length; i++)
      Offset(i * dx, (1 - series[i].clamp(0.0, 1.0)) * size.height),
  ];
}

class _ConvergencePainter extends CustomPainter {
  _ConvergencePainter({required this.scores, required this.similarities});

  final List<double> scores;
  final List<double> similarities;

  @override
  void paint(Canvas canvas, Size size) {
    // A 0.5 gridline, so a flat series is readable rather than just a line.
    final grid = Paint()
      ..color = AgoraTheme.dim.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      grid,
    );

    _line(canvas, size, similarities, AgoraTheme.dim);
    _line(canvas, size, scores, AgoraTheme.accent);
  }

  void _line(Canvas canvas, Size size, List<double> series, Color color) {
    final pts = normalizedPolyline(series, size);
    if (pts.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ConvergencePainter old) =>
      !_same(old.scores, scores) || !_same(old.similarities, similarities);

  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
