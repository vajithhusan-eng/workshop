import 'package:flutter/material.dart';

import '../api.dart';
import '../chart/tradingview.dart';
import '../ui.dart';

/// The chart. Symbol search, timeframe controls, and a hard, unmissable
/// warning whenever the bars came from the synthetic fallback rather than a
/// real feed.
class ChartPage extends StatefulWidget {
  const ChartPage({super.key});
  @override
  State<ChartPage> createState() => _ChartPageState();
}

const _intervals = <String, String>{
  '15m': '15m',
  '1h': '1H',
  '1d': '1D',
  '1wk': '1W',
};
const _ranges = <String, String>{
  '3mo': '3M',
  '6mo': '6M',
  '1y': '1Y',
  '5y': '5Y',
  'max': 'MAX',
};

class _ChartPageState extends State<ChartPage> {
  final _symbol = TextEditingController(text: 'RELIANCE');
  final _search = TextEditingController();

  String _interval = '1d';
  String _range = '1y';

  Future<Result<Map<String, dynamic>>>? _candles;
  List<Candle> _bars = const [];
  bool _synthetic = false;
  String? _source;
  String? _error;
  List<_Hit> _hits = const [];
  bool _busy = false;

  static const _popular = [
    'RELIANCE',
    'TCS',
    'INFY',
    'HDFCBANK',
    'SBIN',
    'ITC'
  ];

  @override
  void dispose() {
    _symbol.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sym = _symbol.text.trim().toUpperCase();
    if (sym.isEmpty) {
      setState(() => _error = 'Type a symbol first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _candles = api.candles(sym, interval: _interval, range: _range);
    });
    final r = await _candles!;
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!r.ok) {
        _error = r.error;
        _bars = const [];
        _synthetic = false;
        return;
      }
      final d = r.value!;
      _synthetic = d['is_synthetic'] == true;
      _source = d['source']?.toString();
      _bars = parseCandles(d['candles']);
      if (_bars.isEmpty) _error = 'No bars returned for $sym.';
    });
  }

  Future<void> _doSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _hits = const []);
      return;
    }
    final r = await api.searchSymbols(q);
    if (!mounted || !r.ok) return;
    setState(() {
      _hits = ((r.value!['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => _Hit(
                m['symbol']?.toString() ?? '',
                m['name']?.toString() ?? '',
                m['sector']?.toString() ?? '',
              ))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _controls(),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _symbol,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _load(),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Symbol',
                    hintText: 'RELIANCE',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RunButton(
                label: 'Chart',
                busy: _busy,
                onPressed: _load,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: _doSearch,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Search NSE',
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          if (_hits.isNotEmpty) ...[
            const SizedBox(height: 6),
            ..._hits.take(6).map((h) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${h.symbol} — ${h.name}',
                      style: const TextStyle(fontSize: 13)),
                  subtitle:
                      Text(h.sector, style: const TextStyle(fontSize: 11)),
                  onTap: () {
                    _symbol.text = h.symbol;
                    setState(() => _hits = const []);
                    _load();
                  },
                )),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _chips(_intervals, _interval, (v) {
                setState(() => _interval = v);
                _load();
              }),
            ],
          ),
          const SizedBox(height: 6),
          Row(children: [
            _chips(_ranges, _range, (v) {
              setState(() => _range = v);
              _load();
            }),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _popular
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            _symbol.text = s;
                            _load();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chips(
      Map<String, String> map, String active, ValueChanged<String> on) {
    return Wrap(
      spacing: 6,
      children: map.entries
          .map((e) => ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontSize: 11)),
                selected: e.key == active,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => on(e.key),
              ))
          .toList(),
    );
  }

  Widget _body() {
    if (_error != null) {
      return ErrorBox(_error!, onRetry: _load);
    }
    if (_candles == null) {
      return const EmptyBox('Pick a symbol and press Chart.');
    }
    if (_busy && _bars.isEmpty) {
      return const LoadingBox(label: 'Loading candles…');
    }
    if (_bars.isEmpty) {
      return const EmptyBox('No bars for that symbol and timeframe.');
    }

    final first = _bars.first.close;
    final last = _bars.last.close;
    final up = last >= first;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // The single most important line on this page. A chart of invented
        // prices that does not say so is the exact failure this app exists to
        // prevent, so it is a banner, not a footnote.
        if (_synthetic)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: VerdictBanner(
              severity: 'HIGH',
              headline: 'SYNTHETIC DATA — these candles are not real.',
              detail: 'No price feed was reachable, so the backend returned a '
                  'deterministic random walk with no relationship to any '
                  'market. Do not draw any conclusion from this chart.',
              source: 'source: ${_source ?? 'synthetic'}',
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: SectionCard(
            title:
                '${_symbol.text.trim().toUpperCase()} · ${_interval.toUpperCase()}',
            subtitle: '${_bars.length} bars · $_range',
            children: [
              Row(
                children: [
                  Text(
                    last.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: up
                          ? const Color(0xFF1B7F4B)
                          : const Color(0xFFBE185D),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${up ? '+' : ''}${(last - first).toStringAsFixed(2)} over range',
                    style: TextStyle(
                      fontSize: 12,
                      color: up
                          ? const Color(0xFF1B7F4B)
                          : const Color(0xFFBE185D),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: CandlestickChart(candles: _bars),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: SectionCard(
            title: 'Before you trust this chart',
            subtitle: 'The chart is not the analysis.',
            children: [
              Text(
                '1.  A picture of price is not a thesis. The reason to hold '
                'goes in the Journal — the chart only tells you what already '
                'happened.\n\n'
                '2.  Check the arithmetic you are about to believe. Barber, '
                'Lee, Liu & Odean found that virtually all individual losses '
                'trace to aggressive orders, not to picking the wrong company.\n\n'
                '3.  If someone sold you this setup, ask how many variants '
                'they tried. A Sharpe ratio found by searching is worth '
                'roughly what the best of N lucky trials is worth — which is '
                'the Autopsy tab, not a yes.',
                style: TextStyle(height: 1.45, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hit {
  const _Hit(this.symbol, this.name, this.sector);
  final String symbol;
  final String name;
  final String sector;
}
