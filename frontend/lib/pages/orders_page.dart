/// The Aggressive Order Audit.
///
/// Barber & Odean (2000, 2004, 2009) found that virtually all individual losses
/// trace to aggressive orders — orders that cross the spread instead of resting
/// in it. The size of the penalty grew with each republication. It is the most
/// actionable fact ever measured about retail trading, no broker surfaces it,
/// and acting on it costs nothing.
///
/// This screen exists to convert it into rupees, because a drag nobody has
/// named in currency is a drag nobody acts on.
///
/// The design constraint that matters most: **missing data is never scored as
/// patience.** An order we cannot measure returns NEUTRAL with the reason
/// spelled out, never PASS. Marking an unmeasurable order "good" is exactly how
/// an audit becomes a machine that lies to its user.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.api});
  final Api api;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _pv = TextEditingController(text: '500000');
  final _opy = TextEditingController(text: '60');
  final _json = TextEditingController(text: _sample);
  Map<String, dynamic>? _result;
  String? _error;
  bool _busy = false;

  /// A worked example, not an empty box. The value of this screen only lands
  /// once you have watched it refuse to flatter you.
  static const _sample = '''[
  {"symbol":"RELIANCE","side":"buy","limit_price":2880,"bid":2872,"ask":2876,"fill_price":2876,"qty":40},
  {"symbol":"RELIANCE","side":"buy","limit_price":2900,"bid":2872,"ask":2876,"fill_price":2876,"qty":60},
  {"symbol":"TCS","side":"sell","limit_price":3410,"bid":3452,"ask":3456,"fill_price":3452,"qty":25},
  {"symbol":"INFY","side":"buy","limit_price":1490,"bid":1502,"ask":1505,"fill_price":1505,"qty":100}
]''';

  @override
  void dispose() {
    _pv.dispose();
    _opy.dispose();
    _json.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    List<dynamic> orders;
    try {
      final decoded = jsonDecode(_json.text);
      if (decoded is! List) {
        setState(() => _error = 'Expected a JSON array of orders.');
        return;
      }
      orders = decoded;
    } catch (e) {
      setState(() => _error = 'That is not valid JSON.\n\n$e');
      return;
    }
    if (orders.isEmpty) {
      setState(
        () => _error = 'The array is empty. Paste at least one execution.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await widget.api.auditOrders(
      orders: orders.cast<Map<String, dynamic>>(),
      portfolioValue: double.tryParse(_pv.text.trim()),
      ordersPerYear: double.tryParse(_opy.text.trim()),
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
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _input(),
          if (_error != null) ErrorBox(_error!),
          if (_result != null) ..._render(_result!),
        ],
      );

  Widget _input() => SectionCard(
        title: 'What did your orders actually cost you?',
        subtitle: 'Paste executions from your broker. Keys: symbol, side, '
            'limit_price, fill_price, bid, ask.',
        children: [
          NumField(
            label: 'Portfolio value (₹)',
            controller: _pv,
            fallback: 500000,
            decimals: 0,
            helper: 'Used to turn basis points into rupees. Optional.',
          ),
          const SizedBox(height: 10),
          NumField(
            label: 'Orders per year',
            controller: _opy,
            fallback: 60,
            decimals: 0,
            helper: 'Turns a per-order cost into an annual drag. Optional.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _json,
            maxLines: 10,
            minLines: 5,
            style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              labelText: 'Executions (JSON array)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RunButton(
                  onPressed: _run,
                  busy: _busy,
                  busyLabel: 'Measuring…',
                  label: 'Audit my execution',
                  icon: Icons.receipt_long,
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed:
                    _busy ? null : () => setState(() => _json.text = _sample),
                child: const Text('Example'),
              ),
            ],
          ),
        ],
      );

  List<Widget> _render(Map<String, dynamic> r) {
    final bySymbol = (r['by_symbol'] as Map?) ?? const {};
    final perOrder =
        (r['orders'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final nUnmeasurable = (r['n_unmeasurable'] as num?)?.toInt() ?? 0;
    final dragRupees = (r['annualised_drag_rupees'] as num?)?.toDouble();

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: VerdictBanner(
          severity: r['verdict'],
          headline: '${r['verdict']}',
          detail: '${r['narrative']}',
          source: 'Barber, Lee, Liu & Odean: "Do Day Traders Rationally Learn '
              'About Their Ability?" (2000); "Rational Trading and the '
              'Irrationality of the Crowd" (2004); "How Individual Traders Can '
              'Profit from the Options Markets" (2009).',
        ),
      ),
      SectionCard(
        title: 'In rupees, not basis points',
        subtitle: 'A drag you can name is a drag you can decide about.',
        children: [
          Kv('Orders examined', '${r['n_orders']}'),
          Kv(
            'Could actually be measured',
            '${r['n_priced']}',
            severity: nUnmeasurable > 0 ? 'MEDIUM' : 'LOW',
          ),
          Kv(
            'Aggressive (crossed the spread)',
            '${r['n_aggressive']}',
            severity: ((r['n_aggressive'] as num?) ?? 0) > 0 ? 'HIGH' : 'LOW',
          ),
          Kv('Patient (rested in the book)', '${r['n_passive']}'),
          const Divider(height: 20),
          Kv(
            'Aggressive share',
            fmt(r['aggressive_share'], places: 0, suffix: '%'),
            bold: true,
          ),
          Kv(
            'Average cost per aggressive order',
            '${fmt(r['mean_cost_bps'], places: 1)} bps',
          ),
          const Divider(height: 20),
          StatTile(
            label: 'Annualised drag on your portfolio',
            value: '${fmt(r['annualised_drag_bps'], places: 0)} bps'
                '${(dragRupees ?? 0) != 0 ? '  ·  ${rupees(dragRupees)}' : ''}',
            severity: ((r['annualised_drag_bps'] as num?) ?? 0) >= 100
                ? 'HIGH'
                : ((r['annualised_drag_bps'] as num?) ?? 0) >= 25
                    ? 'MEDIUM'
                    : 'LOW',
          ),
          if (r['annualisation_assumed'] == false)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Not annualised — you gave no portfolio value or order frequency, '
                'so we will not invent one.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (r['countermodel'] != null) ...[
            const Divider(height: 20),
            Text(
              'What the same trades would have cost',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text('${r['countermodel']}'),
            if ('${r['countermodel_caveat'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 6),
              Source('${r['countermodel_caveat']}'),
            ],
          ],
        ],
      ),
      if (nUnmeasurable > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
          child: VerdictBanner(
            severity: 'MEDIUM',
            headline:
                '$nUnmeasurable of ${r['n_orders']} orders could not be measured.',
            detail:
                'We need a reference price — bid, ask, or the mid — to know whether '
                'you crossed the spread. We will not guess one, and we will not count '
                'an unmeasured order as a good one. Send bid and ask and the whole '
                'picture resolves.',
          ),
        ),
      if (bySymbol.isNotEmpty)
        SectionCard(
          title: 'Where it went',
          children: [
            for (final e in bySymbol.entries)
              if (e.value is Map)
                Kv(
                  e.key,
                  '${(e.value as Map)['aggressive']}/${(e.value as Map)['n']} aggressive',
                  severity: ((e.value as Map)['aggressive'] as num?) != 0
                      ? 'HIGH'
                      : 'LOW',
                ),
          ],
        ),
      if (perOrder.isNotEmpty)
        SectionCard(
          title: 'Order by order',
          subtitle: 'The reason matters more than the score.',
          children: [
            for (final o in perOrder)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          sevIcon(sevFrom(o['verdict'])),
                          size: 16,
                          color: sevColor(
                            sevFrom(o['verdict']),
                            Theme.of(context).colorScheme,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${o['symbol']} · ${o['verdict']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (((o['cost_bps'] as num?) ?? 0) > 0)
                          Text(
                            '${fmt(o['cost_bps'], places: 1)} bps',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${o['reason']}',
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
          ],
        ),
    ];
  }
}
