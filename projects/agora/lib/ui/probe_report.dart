import 'package:flutter/material.dart';

import '../core/adapters/selector_prober.dart';
import 'theme.dart';

/// Renders a [SiteProbe] as evidence.
///
/// Split from the Calibration Studio so it can be widget-tested without a
/// browser: the studio owns the button, this owns the answer.
class ProbeReport extends StatelessWidget {
  const ProbeReport(this.probe, {super.key});

  final SiteProbe probe;

  @override
  Widget build(BuildContext context) {
    final good = probe.allMatched && probe.error == null;
    final color = good ? AgoraTheme.ok : AgoraTheme.danger;
    final detail = probe.error != null
        ? probe.error!
        : '${probe.url}\nloaded: ${probe.loaded} · '
              '${probe.matchedCount} matched · ${probe.scoredCount} checkable · '
              '${probe.shadowRoots} shadow root(s)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    good ? Icons.check_circle : Icons.report_problem,
                    size: 15,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      probe.headline,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(detail, style: AgoraTheme.caption),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final o in probe.outcomes) _Row(o, probe),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.outcome, this.probe);

  final ProbeOutcome outcome;
  final SiteProbe probe;

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    late final IconData icon;
    late final Color color;
    late final String summary;

    if (o.isEmptySpec) {
      icon = Icons.remove_circle_outline;
      color = AgoraTheme.dim;
      summary = 'not declared — Agora will not look for it';
    } else if (o.error != null) {
      icon = Icons.error_outline;
      color = AgoraTheme.danger;
      summary = o.error!;
    } else if (o.hasInvalidSelector) {
      icon = Icons.code_off;
      color = AgoraTheme.danger;
      final bad = o.hits.firstWhere((SelectorHit h) => h.invalid);
      summary = 'invalid CSS — ${bad.selector}';
    } else if (o.matched) {
      icon = Icons.check_circle;
      color = AgoraTheme.ok;
      summary = 'matched on ${o.winningSelector}';
    } else if (probe.broken.contains(o)) {
      icon = Icons.close;
      color = AgoraTheme.danger;
      summary = 'no candidate resolved — the site changed';
    } else if (probe.unverifiable.contains(o)) {
      icon = Icons.help_outline;
      color = AgoraTheme.dim;
      summary = 'absent on an empty thread — send a message, then probe again';
    } else {
      icon = Icons.remove;
      color = AgoraTheme.dim;
      summary = 'did not match';
    }

    // Every tier is printed, including the ones that missed: a dead CSS tier
    // behind a working text tier is the early warning that matters.
    final tiers = o.hits
        .map(
          (SelectorHit h) =>
              '${h.kind == 'css' ? 'css' : 'text'} '
              '${h.verdict}: ${h.selector}'
              '${h.sample.isEmpty ? '' : '  ->  "${h.sample}"'}',
        )
        .join('\n');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.slot,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(summary, style: AgoraTheme.caption),
                if (tiers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 2),
                    child: Text(tiers, style: AgoraTheme.mono),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
