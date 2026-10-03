/// "How Dead Is This?" — the Signal Autopsy.
///
/// This is the product's wedge. Everyone else in India will show you a
/// backtest. Nobody will hand you the backtest's corpse and explain the
/// autopsy. So this screen does three things in order:
///
///   1. renders the verdict before any of the arithmetic,
///   2. shows every number with the paper that justifies it, and
///   3. explains what each number *means* in language that does not require
///      a quant background — because a verdict you cannot check is just
///      another authority telling you what to do.
library;

import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

class AutopsyPage extends StatefulWidget {
  const AutopsyPage({super.key, required this.api});
  final Api api;

  @override
  State<AutopsyPage> createState() => _AutopsyPageState();
}

class _AutopsyPageState extends State<AutopsyPage> {
  // Defaults are a mediocre retail factor on purpose. If the button is hit
  // without typing anything, the honest answer is "this does not survive",
  // not "great, your Sharpe of 0.68 works".
  final _tech = TextEditingController(text: 'Momentum 12-1');
  final _sharpe = TextEditingController(text: '0.68');
  final _trials = TextEditingController(text: '47');
  final _nObs = TextEditingController(text: '756');
  final _btBps = TextEditingController(text: '309');
  final _liveBps = TextEditingController(text: '-150');

  Map<String, dynamic>? _result;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_tech, _sharpe, _trials, _nObs, _btBps, _liveBps]) {
      c.dispose();
    }
    super.dispose();
  }

  double _d(TextEditingController c, double fallback) =>
      double.tryParse(c.text.trim()) ?? fallback;

  int _i(TextEditingController c, int fallback) {
    final v = double.tryParse(c.text.trim());
    return v == null ? fallback : v.round();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await widget.api.autopsy(
      technique: _tech.text.trim().isEmpty
          ? 'Unnamed signal'
          : _tech.text.trim(),
      sharpe: _d(_sharpe, 0.68),
      trials: _i(_trials, 47),
      nObs: _i(_nObs, 756),
      backtestBps: _i(_btBps, 309),
      liveBps: _i(_liveBps, -150),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok) {
        _result = r.value;
      } else {
        _error = r.error;
        _result = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _inputCard(),
        if (_error != null) ErrorBox(_error!, onRetry: _run),
        if (_result != null) ..._render(_result!),
      ],
    );
  }

  Widget _inputCard() => SectionCard(
    title: 'Hand it a signal',
    subtitle:
        'Anyone can hand you a backtest. The question is what is left of it '
        'after you account for how many times someone already tried this.',
    children: [
      TextField(
        controller: _tech,
        decoration: const InputDecoration(
          labelText: 'What is it called?',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > 520;
          final fields = [
            Expanded(
              child: NumField(
                label: 'Sharpe ratio',
                controller: _sharpe,
                fallback: 0.68,
                helper: 'Return per unit of risk. Above 1 is meant to be good.',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NumField(
                label: 'How many tries?',
                controller: _trials,
                fallback: 47,
                helper:
                    'Variations of this that were tested before you saw it. '
                    'This is the number people leave out.',
              ),
            ),
          ];
          if (!wide) {
            return Column(
              children: [fields[0], const SizedBox(height: 10), fields[2]],
            );
          }
          return Row(children: fields);
        },
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, box) {
          final fields = [
            Expanded(
              child: NumField(
                label: 'Backtest excess (bps)',
                controller: _btBps,
                fallback: 309,
                helper: 'Beating the index by this much, historically.',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NumField(
                label: 'Live excess (bps)',
                controller: _liveBps,
                fallback: -150,
                helper: 'Beating it by this much once real money was at risk.',
              ),
            ),
          ];
          if (box.maxWidth <= 520) {
            return Column(
              children: [fields[0], const SizedBox(height: 10), fields[2]],
            );
          }
          return Row(children: fields);
        },
      ),
      const SizedBox(height: 10),
      NumField(
        label: 'Observations behind it',
        controller: _nObs,
        fallback: 756,
        helper: 'Trading days in the test. 756 ≈ 3 years.',
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: RunButton(
              onPressed: _run,
              busy: _busy,
              busyLabel: 'Running the autopsy…',
              label: 'How dead is this?',
              icon: Icons.biotech,
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    _tech.clear();
                    _result = null;
                    setState(() {});
                  },
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear'),
          ),
        ],
      ),
    ],
  );

  // ── results ──────────────────────────────────────────────────────────────

  List<Widget> _render(Map<String, dynamic> r) {
    final decay = _map(r['decay']);
    final dsr = _map(r['deflated_sharpe']);
    final minbtl = _map(r['min_backtest_length']);
    final fdr = r['fdr'] is Map ? _map(r['fdr']) : null;
    final reasons = (r['reasons'] as List?)?.cast<String>() ?? const [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: VerdictBanner(
          severity: r['severity'],
          headline: (r['verdict'] ?? '').toString(),
          detail: reasons.isEmpty
              ? null
              : 'What killed it:\n\n• ${reasons.join('\n• ')}',
          source:
              'Deflated Sharpe (Bailey & López de Prado 2014) · Backtest overfitting '
              '(Bailey et al. 2017) · Decay (McLean & Pontiff 2016)',
        ),
      ),

      // ── the headline number ──
      SectionCard(
        title: 'Is this better than luck?',
        subtitle:
            'Compared against what pure chance produces when someone tries this '
            'many variations of this many times.',
        children: [
          VerdictBanner(
            severity: dsr['significant'] == true
                ? 'LOW'
                : dsr['indistinguishable_from_luck'] == true
                ? 'HIGH'
                : 'MEDIUM',
            headline: dsr['significant'] == true
                ? 'Yes — it clears the bar that ${dsr['n_trials']} lucky tries would not reach.'
                : dsr['indistinguishable_from_luck'] == true
                ? 'No — this is what ${dsr['n_trials']} lucky tries would hand you anyway.'
                : 'Not enough evidence either way.',
            detail:
                'Deflated Sharpe Ratio ${fmt(dsr['dsr'], places: 4)}\n'
                'Your Sharpe ${fmt(dsr['observed_sharpe'])}  vs  '
                'the luck line ${fmt(dsr['frontier_sharpe'])}\n\n'
                'Read it as: of everything you could have found by trying '
                '${dsr['n_trials']} things, the best result would have been about '
                '${fmt(dsr['frontier_sharpe'])} on its own. Beating that line is '
                'the only part of a backtest that means anything.',
            source: 'Deflated Sharpe Ratio — Bailey & López de Prado, JPM 40(5), 2014',
          ),
        ],
      ),

      // ── decay ──
      SectionCard(
        title: 'What happened when real money showed up?',
        subtitle: 'The gap between the test and the reality.',
        children: [
          Kv('Backtest excess', '${decay['backtest_excess_bps']} bps'),
          Kv(
            'Live excess',
            '${decay['live_excess_bps']} bps',
            severity: (decay['live_excess_bps'] as num? ?? 0) < 0
                ? 'HIGH'
                : 'LOW',
          ),
          const Divider(height: 18),
          Kv(
            'Lost',
            '${fmt(decay['decay_pct'], places: 0)}% of the edge',
            severity: (decay['decay_pct'] as num? ?? 0) >= 50
                ? 'HIGH'
                : (decay['decay_pct'] as num? ?? 0) >= 25
                ? 'MEDIUM'
                : 'LOW',
            bold: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Published research already tells you to expect this much decay, '
            'before you add your own bad luck.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Kv(
            'Out-of-sample, expected',
            '−${decay['expected_out_of_sample_penalty_pct']}%',
          ),
          Kv(
            'After publication, expected',
            '−${decay['expected_post_publication_penalty_pct']}%',
            severity: 'MEDIUM',
          ),
          const SizedBox(height: 6),
          Source(
            '${decay['source']} — the strongest predictors decayed the most.',
          ),
        ],
      ),

      // ── sample length ──
      SectionCard(
        title: 'Was the test long enough to tell?',
        children: [
          VerdictBanner(
            severity: minbtl['sufficient'] == true ? 'LOW' : 'HIGH',
            headline: minbtl['sufficient'] == true
                ? 'Yes. ${minbtl['observations_needed']} observations needed, you had ${minbtl['observations_have']}.'
                : 'No. You needed ${minbtl['observations_needed']} observations. You had ${minbtl['observations_have']}.',
            detail: minbtl['sufficient'] == true
                ? null
                : 'That is about ${fmt(minbtl['years_needed'], places: 1)} years of daily data '
                      'to tell a real Sharpe of ${fmt(dsr['observed_sharpe'])} apart from the noise '
                      'of ${dsr['n_trials']} attempts. Most published Indian "signals" were tested on '
                      'two or three. That is not enough to know.',
            source: 'Minimum Backtest Length — derived from Bailey & López de Prado 2012',
          ),
        ],
      ),

      // ── FDR, only if a t-stat was supplied ──
      if (fdr != null)
        SectionCard(
          title: 'Would this survive being published?',
          subtitle:
              'Hundreds of factor papers a year are published. Most of them are '
              'wrong, and the standard bar is far too low.',
          children: [
            Kv('t-statistic', '${fdr['t_stat']}'),
            Kv('Papers searched', '${fdr['n_tests']}'),
            Kv(
              'Chance this is a fluke',
              '1 in ${_oneIn(fdr['fdr_adjusted_p'])}',
              severity: fdr['passes'] == true ? 'LOW' : 'HIGH',
              bold: true,
            ),
            const SizedBox(height: 8),
            Kv(
              'Clears the recommended bar of t > 3',
              fdr['clears_hlz_3'] == true ? 'yes' : 'no',
              severity: fdr['clears_hlz_3'] == true ? 'LOW' : 'HIGH',
            ),
            const SizedBox(height: 8),
            Source(
              '${fdr['method']}. Harvey, Liu & Zhu (2016) showed the usual t > 2.0 '
              'hurdle is meaningless once you have searched this many papers.',
            ),
          ],
        ),
    ];
  }

  /// "1 in 500" reads far better to a human than "0.002", and the whole point
  /// is that the number lands.
  String _oneIn(Object? p) {
    final v = (p as num?)?.toDouble();
    if (v == null || v <= 0) return '∞';
    return (1 / v).round().toString();
  }
}

Map<String, dynamic> _map(Object? v) => Map<String, dynamic>.from(v! as Map);
