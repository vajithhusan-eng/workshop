/// Learn — the canon, the arguments inside it, and the techniques worth a look.
///
/// Two things live here that a search box cannot do:
///
///  * **Where they disagree.** The serious books agree on very little
///    specific and contradict each other on the parts that matter. Showing
///    only the consensus would be marketing, not education — the
///    disagreements are where the actual decisions are.
///  * **The techniques table.** Each carries what it claimed, what it did
///    afterwards, and which paper explains the gap. A strategy list without
///    the "afterwards" column is a referral list.
library;

import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

class LearnPage extends StatelessWidget {
  const LearnPage({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) {
    // Pushed as a route from the app bar, so it supplies its own Scaffold and
    // back button — there is no ambient one to inherit.
    return Scaffold(
      appBar: AppBar(title: const Text('The canon')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [_techniques(), _consensus(), _debates()],
      ),
    );
  }

  Widget _techniques() => SectionCard(
    title: 'Techniques, and what happened next',
    subtitle:
        'A strategy list without the "afterwards" column is a referral list.',
    children: [
      AsyncSection<List<dynamic>>(
        future: api.techniques,
        builder: (context, items) {
          if (items.isEmpty) return const EmptyBox('No techniques loaded.');
          return Column(
            children: [
              for (final raw in items)
                Builder(
                  builder: (context) {
                    final t = Map<String, dynamic>.from(raw as Map);
                    final live = '${t['live_1y']}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t['name']}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          _line(context, 'Claimed', '${t['in_sample']}'),
                          _line(
                            context,
                            'Actually did',
                            live,
                            warn:
                                live.contains('⚠️') ||
                                live.contains('underperform'),
                          ),
                          _line(context, 'Regime', '${t['regime']}'),
                          _line(context, 'Risk', '${t['decay_note']}'),
                          if ('${t['pbo_hint']}'.isNotEmpty)
                            _line(context, 'Crowding', '${t['pbo_hint']}'),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    ],
  );

  Widget _line(
    BuildContext c,
    String k,
    String v, {
    bool warn = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: RichText(
      text: TextSpan(
        style: Theme.of(c).textTheme.bodySmall?.copyWith(height: 1.4),
        children: [
          TextSpan(
            text: '$k  ',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
          ),
          TextSpan(
            text: v,
            style: TextStyle(
              fontSize: 12,
              color: warn ? sevColor(Sev.warn, Theme.of(c).colorScheme) : null,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _consensus() => SectionCard(
    title: 'What everyone agrees on',
    subtitle:
        'Eight points where the serious books genuinely do not disagree. '
        'Rare, and worth knowing.',
    children: [
      AsyncSection<Map<String, dynamic>>(
        future: api.consensus,
        builder: (context, r) {
          final items =
              (r['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
          if (items.isEmpty) return const EmptyBox('Nothing loaded.');
          return Column(
            children: [
              for (final x in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${x['rule']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${x['line']}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  Widget _debates() => SectionCard(
    title: 'Where they fight',
    subtitle:
        'Graded in 12 months against what actually happened. That is '
        'the only honest way to settle them.',
    children: [
      AsyncSection<Map<String, dynamic>>(
        future: api.debates,
        builder: (context, r) {
          final items =
              (r['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
          if (items.isEmpty) return const EmptyBox('Nothing loaded.');
          return Column(
            children: [
              for (final x in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${x['question']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _side(x, 'Buffett', 'buffett'),
                        _side(x, 'Dalio', 'dalio'),
                        if ('${x['evidence'] ?? ''}'.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'What the evidence says: ${x['evidence']}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).colorScheme.outline,
                                height: 1.35,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  Widget _side(Map<String, dynamic> x, String who, String key) {
    final v = '${x[key] ?? ''}';
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        '$who: $v',
        style: const TextStyle(fontSize: 12, height: 1.4),
      ),
    );
  }
}
