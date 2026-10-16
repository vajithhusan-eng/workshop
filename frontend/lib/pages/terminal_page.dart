/// The OMNIVEST terminal: tape, watchlist, chart, analysis rail, blotter.
///
/// This is not a learning app's home screen with a chart bolted on. The layout
/// is the argument — price in the middle, judgement beside it, and the
/// provenance of both always on screen — because a terminal that shows a
/// verdict without showing what it was computed from is a fortune cookie with
/// a candlestick behind it.
///
/// **One request feeds the chart and the rail.** `/api/analysis/symbol` returns
/// candles, the 27-series indicator panel and the verdict together, so the
/// picture and the prose are provably the same computation. Fetching them
/// separately would turn a bug into a race.
library;

import 'package:flutter/material.dart';

import '../api.dart';
import '../chart/tradingview.dart';
import '../theme/terminal.dart';
import '../terminal/hud.dart';
import '../terminal/narration.dart';

/// Symbols on the watchlist. Cheap to change; the list is data, not design.
const kWatchlist = <String>[
  'RELIANCE',
  'TCS',
  'HDFCBANK',
  'INFY',
  'SBIN',
  'ICICIBANK',
  'ITC',
  'BHARTIARTL',
  'LT',
  'TATAMOTORS',
];

const _intervals = <String, String>{
  '15m': '15M',
  '1h': '1H',
  '1d': '1D',
  '1wk': '1W',
};
const _ranges = <String, String>{
  '3mo': '3M',
  '6mo': '6M',
  '1y': '1Y',
  '5y': '5Y',
};

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final _query = TextEditingController();

  String _symbol = 'RELIANCE';
  String _interval = '1d';
  String _range = '1y';

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _payload;

  bool _scanLoading = false;
  Map<String, dynamic>? _scan;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _load();
    _loadScan();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load([String? symbol]) async {
    final sym = (symbol ?? _symbol).trim().toUpperCase();
    if (sym.isEmpty) {
      setState(() => _error = 'Type a symbol first.');
      return;
    }
    setState(() {
      _symbol = sym;
      _loading = true;
      _error = null;
    });
    final r = await api.analysis(sym, interval: _interval, range: _range);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!r.ok) {
        _error = r.error;
        _payload = null;
        return;
      }
      _payload = r.value;
    });
  }

  Future<void> _loadScan() async {
    setState(() {
      _scanLoading = true;
      _scanError = null;
    });
    final r = await api.scan(symbols: kWatchlist, range: '3mo');
    if (!mounted) return;
    setState(() {
      _scanLoading = false;
      if (!r.ok) {
        _scanError = r.error;
        _scan = null;
      } else {
        _scan = r.value;
      }
    });
  }

  // ── layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final results = _scanResults();

    return Column(
      children: [
        TickerTape(
          items: [
            for (final r in results)
              TickerItem(
                symbol: r.symbol,
                last: r.lastClose,
                action: r.action,
                conviction: r.conviction,
                onTap: () => _load(r.symbol),
              ),
          ],
          asOf: _scan == null ? null : 'scan as of ${_asOfLabel(_scan)}',
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 1180;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 208, child: _watchlist(results)),
                    const _VRule(),
                    Expanded(child: _centre()),
                    const _VRule(),
                    SizedBox(width: 336, child: _rail()),
                  ],
                );
              }
              // Narrow: the chart still comes first — it is the thing being
              // explained — and the rail follows it rather than being hidden
              // behind a tab.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _centre()),
                  const _VRule(),
                  SizedBox(
                    width: box.maxWidth < 780 ? 280 : 336,
                    child: _rail(),
                  ),
                ],
              );
            },
          ),
        ),
        _blotter(),
      ],
    );
  }

  List<_Result> _scanResults() {
    final raw = _scan?['results'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => _Result(
              (m['symbol'] ?? '').toString(),
              _d(m['last_close']) ?? 0,
              (m['action'] ?? '').toString(),
              _d(m['conviction']) ?? 0,
            ))
        .where((r) => r.symbol.isNotEmpty)
        .toList();
  }

  // ── watchlist ─────────────────────────────────────────────────────────────

  Widget _watchlist(List<_Result> results) {
    return Container(
      color: Terminal.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Text('WATCHLIST', style: Terminal.label(size: 10)),
          ),
          if (_scanLoading && results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Scanning…', style: TextStyle(fontSize: 12)),
            ),
          if (_scanError != null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                _scanError!,
                style: Terminal.body(size: 11, color: Terminal.sell),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (_, i) => _watchRow(results[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _watchRow(_Result r) {
    final selected = r.symbol == _symbol;
    return InkWell(
      onTap: () => _load(r.symbol),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        color: selected ? Terminal.hover : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  r.symbol,
                  style: Terminal.label(
                    size: 10.5,
                    color: selected ? Terminal.ink : Terminal.ink2,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  r.lastClose.toStringAsFixed(2),
                  style: Terminal.num(size: 12, color: Terminal.ink),
                ),
              ],
            ),
            const SizedBox(height: 4),
            VerdictBadge(
                action: r.action, conviction: r.conviction, compact: true),
          ],
        ),
      ),
    );
  }

  // ── centre: header + chart ────────────────────────────────────────────────

  Widget _centre() {
    if (_error != null) {
      return _panel(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: Terminal.body(size: 13, color: Terminal.sell)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_payload == null) {
      return _panel(
        child: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Text('Pick a symbol.', style: Terminal.body()),
        ),
      );
    }

    final p = _payload!;
    final quote = p['quote'] is Map ? (p['quote'] as Map) : const {};
    final bars = parseCandles(p['candles']);
    // A panel with any non-String key cannot be typed as the payload shape, so
    // it is dropped whole rather than half-traced — same rule as a series
    // containing an unparseable entry.
    final rawPanel = p['indicator_series'];
    final panel = rawPanel is Map && rawPanel.keys.every((k) => k is String)
        ? Map<String, dynamic>.from(rawPanel)
        : null;
    final traces = buildTraces(panel);
    final synthetic = p['is_synthetic'] == true;
    final last = _d(quote['last']) ?? (bars.isNotEmpty ? bars.last.close : 0.0);
    final chg = _d(quote['change_pct']) ?? 0;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(p, quote, last, chg),
          if (synthetic) _syntheticBanner(p['data_warning']?.toString()),
          Expanded(
            child: bars.isEmpty
                ? Center(
                    child:
                        Text('No bars for $_symbol.', style: Terminal.body()),
                  )
                : CandlestickChart(
                    candles: bars,
                    traces: traces,
                    height: double.infinity,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(
    Map<String, dynamic> p,
    Map quote,
    double last,
    double chg,
  ) {
    final tone = signColor(chg);
    final sign = chg > 0 ? '+' : '';

    return Container(
      color: Terminal.base,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_symbol,
                  style: Terminal.label(size: 12, color: Terminal.ink)),
              const SizedBox(width: 10),
              Text(
                last.toStringAsFixed(2),
                style: Terminal.num(
                    size: 22, color: tone, weight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                '$sign${chg.toStringAsFixed(2)}%',
                style: Terminal.num(
                    size: 13, color: tone, weight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${p['source'] ?? 'unknown'} · ${_asOfLabel(p)}',
                style: Terminal.label(size: 9, color: Terminal.ink4),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final e in _intervals.entries)
                _chip(e.value, _interval == e.key, () {
                  setState(() => _interval = e.key);
                  _load();
                }),
              const SizedBox(width: 8),
              for (final e in _ranges.entries)
                _chip(e.value, _range == e.key, () {
                  setState(() => _range = e.key);
                  _load();
                }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback tap) {
    return InkWell(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: on ? Terminal.hover : null,
          border: Border.all(color: on ? Terminal.divider : Terminal.hairline),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: Terminal.label(
              size: 10, color: on ? Terminal.ink : Terminal.ink3),
        ),
      ),
    );
  }

  Widget _syntheticBanner(String? warning) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Terminal.avoid.withValues(alpha: 0.10),
        border: Border.all(
            color: Terminal.avoid.withValues(alpha: 0.75), width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Terminal.avoid, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SYNTHETIC DATA — THESE CANDLES ARE NOT REAL',
                  style: Terminal.label(
                      size: 11, color: Terminal.avoid, weight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  warning ??
                      'No price feed was reachable, so the backend returned a '
                          'deterministic random walk with no relationship to any '
                          'market. Do not draw any conclusion from this chart.',
                  style: Terminal.body(size: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── right rail: the analysis ──────────────────────────────────────────────

  Widget _rail() {
    final p = _payload;
    final verdict = p != null && p['verdict'] is Map
        ? (p['verdict'] as Map<String, dynamic>)
        : null;

    return Container(
      color: Terminal.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text('ANALYSIS', style: Terminal.label(size: 10)),
          ),
          Expanded(
            // Tested together: `verdict != null` does not imply `p != null` to
            // the flow analyser, so a separate check leaves `p` nullable at the
            // call site even though `verdict` was built from it.
            child: p == null || verdict == null
                ? Center(
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          )
                        : Text('No analysis yet.',
                            style: Terminal.body(size: 12)),
                  )
                : _verdictBody(verdict, p),
          ),
        ],
      ),
    );
  }

  Widget _verdictBody(Map<String, dynamic> v, Map<String, dynamic> p) {
    final n = narrate(v);
    final snap = v['snapshot'] is Map
        ? (v['snapshot'] as Map)
        : const <String, dynamic>{};
    final rules = v['reasons'] is List ? (v['reasons'] as List) : const [];
    final vetoes = v['vetoes'] is List ? (v['vetoes'] as List) : const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        // ── verdict ──
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Terminal.raised,
            border: Border.all(color: Terminal.hairline),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  VerdictBadge(
                    action: (v['action'] ?? '').toString(),
                    conviction: _d(v['conviction']),
                  ),
                  Text(
                    (v['regime'] ?? '').toString().replaceAll('_', ' '),
                    style: Terminal.label(size: 10, color: Terminal.ink2),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ConvictionMeter(
                conviction: _d(v['conviction']) ?? 0,
                action: (v['action'] ?? '').toString(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── HUD tiles ──
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            SizedBox(
              width: 100,
              child: HudTile(
                label: 'REGIME',
                value: (v['regime'] ?? '—').toString().replaceAll('_', ' '),
              ),
            ),
            SizedBox(
              width: 100,
              child: HudTile(
                label: 'VOLATILITY',
                value: (v['volatility'] ?? '—').toString(),
              ),
            ),
            SizedBox(
              width: 100,
              child: HudTile(
                label: 'RSI 14',
                value: _fmt(snap['rsi_14']),
                tone: _rsiTone(_d(snap['rsi_14'])),
              ),
            ),
            SizedBox(
              width: 100,
              child: HudTile(
                label: 'ADX 14',
                value: _fmt(snap['adx_14']),
                hint: 'Trend strength; under 20 is no trend at all.',
              ),
            ),
            SizedBox(
              width: 100,
              child: HudTile(label: 'ATR %', value: _fmt(snap['atr_percent'])),
            ),
            SizedBox(
              width: 100,
              child: HudTile(label: '%B', value: _fmt(snap['percent_b'])),
            ),
            SizedBox(
              width: 100,
              child: HudTile(label: 'SMA 20', value: _fmt(snap['sma_20'])),
            ),
            SizedBox(
              width: 100,
              child: HudTile(label: 'SMA 50', value: _fmt(snap['sma_50'])),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── vetoes beat arithmetic ──
        if (vetoes.isNotEmpty) ...[
          Text('VETO', style: Terminal.label(size: 10, color: Terminal.sell)),
          const SizedBox(height: 4),
          for (final x in vetoes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('$x',
                  style: Terminal.body(size: 12, color: Terminal.sell)),
            ),
          const SizedBox(height: 8),
        ],

        // ── rules ──
        Text('RULES', style: Terminal.label(size: 10)),
        const SizedBox(height: 2),
        const Divider(),
        for (final r in rules)
          if (r is Map)
            RuleRow(
              rule: (r['rule'] ?? '').toString(),
              direction: _i(r['direction']) ?? 0,
              weight: _d(r['weight']) ?? 0,
              text: (r['text'] ?? '').toString(),
            ),
        const SizedBox(height: 10),

        // ── narration ──
        _narration(n),

        // ── the disclaimer the engine shipped with the verdict ──
        //
        // Rendered unconditionally and last, so it is on screen after every
        // number above it. Discarding this field would leave the terminal
        // asserting a verdict while the payload it came from says in plain
        // words that it is not a recommendation.
        _disclaimer(v['disclaimer']?.toString()),
      ],
    );
  }

  Widget _disclaimer(String? text) {
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Terminal.void0,
        border: Border.all(color: Terminal.hairline),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NOT ADVICE', style: Terminal.label(size: 10)),
          const SizedBox(height: 5),
          Text(text, style: Terminal.body(size: 11, color: Terminal.ink3)),
        ],
      ),
    );
  }

  Widget _narration(Narration n) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Terminal.base,
        border: Border.all(color: Terminal.hairline),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ADVISER', style: Terminal.label(size: 10)),
          const SizedBox(height: 6),
          Text(
            n.headline,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: narrationTone(n),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(n.body, style: Terminal.body(size: 12.5)),
          const SizedBox(height: 10),
          Text('WHAT WOULD CHANGE THIS', style: Terminal.label(size: 9.5)),
          const SizedBox(height: 4),
          Text(n.counter, style: Terminal.body(size: 12, color: Terminal.ink3)),
          if (n.caveat.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(n.caveat,
                style: Terminal.body(size: 11, color: Terminal.ink4)),
          ],
          const SizedBox(height: 10),
          const Divider(),
          Text(
            narrationProvenance,
            style: Terminal.body(size: 10.5, color: Terminal.ink4),
          ),
        ],
      ),
    );
  }

  // ── blotter ───────────────────────────────────────────────────────────────

  Widget _blotter() {
    final summary = _scan?['summary'];
    final unavailable = _scan?['unavailable'];
    final un = unavailable is List ? unavailable : const [];

    return Container(
      color: Terminal.void0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text('BLOTTER', style: Terminal.label(size: 9, color: Terminal.ink4)),
          const SizedBox(width: 14),
          if (summary is Map)
            for (final e in summary.entries)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: actionColor(e.key.toString()),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${e.key} ${e.value}',
                      style: Terminal.label(
                        size: 9.5,
                        color: Terminal.ink2,
                      ),
                    ),
                  ],
                ),
              ),
          if (_scanLoading) ...[
            const SizedBox(width: 6),
            Text('scanning…',
                style: Terminal.label(size: 9, color: Terminal.ink4)),
          ],
          const Spacer(),
          if (un.isNotEmpty)
            Text(
              '${un.length} unavailable — ${un.map((e) => e is Map ? e['symbol'] : '?').join(', ')}',
              style: Terminal.label(size: 9, color: Terminal.avoid),
            ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
        color: Terminal.void0,
        padding: const EdgeInsets.all(12),
        child: child,
      );
}

class _VRule extends StatelessWidget {
  const _VRule();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, color: Terminal.hairline);
}

class _Result {
  const _Result(this.symbol, this.lastClose, this.action, this.conviction);
  final String symbol;
  final double lastClose;
  final String action;
  final double conviction;
}

Color _rsiTone(double? v) {
  if (v == null) return Terminal.ink;
  if (v >= 70) return Terminal.sell;
  if (v <= 30) return Terminal.buy;
  return Terminal.ink;
}

String _fmt(dynamic v) {
  final d = _d(v);
  if (d == null) return '—';
  final abs = d.abs();
  if (abs >= 1000000) return '${(d / 1000000).toStringAsFixed(2)}M';
  if (abs >= 1000) return d.toStringAsFixed(abs >= 10000 ? 0 : 1);
  return d.toStringAsFixed(2);
}

double? _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _i(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// `as of` label for the tape and the chart header, from the scan's own
/// timestamp — never from the local clock, which would claim a freshness the
/// data does not have.
String _asOfLabel(Map<String, dynamic>? scan) {
  final t = scan?['as_of'];
  if (t is! num) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(t.toInt() * 1000, isUtc: true);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)} UTC';
}
