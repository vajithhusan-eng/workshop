/// Real TradingView Lightweight Charts, embedded in Flutter web.
///
/// Why interop rather than a hand-rolled `CustomPainter`: the chart *is* the
/// product now. Lightweight Charts gives us crosshairs, pan/zoom inertia, price
/// and time scaling, autoscale, and a decade of edge-case handling around gaps
/// and weekends. Reimplementing that would be strictly worse and would own the
/// bugs.
///
/// Why these exact bindings: v5 **removed** `addCandlestickSeries()` in favour
/// of `chart.addSeries(LightweightCharts.CandlestickSeries, opts)`. Code written
/// against v4 throws here. Verified against 5.0.9.
///
/// Web-only, and that is fine — this app ships as a web app. The stub at
/// `tradingview_stub.dart` covers every other target.
library;

import 'dart:js_interop';
// Brings `operator []` / `operator []=`, used to build the plain option objects
// Lightweight Charts expects.
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'overlays.dart';

import 'candle.dart';

export 'candle.dart';

// ── JS surface ──────────────────────────────────────────────────────────────
//
// Declared as top-level `@JS` functions rather than `callMethod` so the whole
// boundary is one readable block and a typo in a method name fails at compile
// time rather than as an undefined-property error in the browser console.

@JS('LightweightCharts.createChart')
external JSObject _createChart(JSObject container, JSObject options);

@JS('LightweightCharts.CandlestickSeries')
external JSObject get _candleDef;

@JS('LightweightCharts.HistogramSeries')
external JSObject get _histDef;

extension type _Chart._(JSObject o) implements JSObject {
  external JSObject addSeries(JSObject definition, JSObject options);
  external void applyOptions(JSObject options);
  external void remove();
}

extension type _Series._(JSObject o) implements JSObject {
  external void setData(JSArray<JSObject> data);
  external JSObject priceScale();
}

extension type _PriceScale._(JSObject o) implements JSObject {
  external void applyOptions(JSObject options);
}

/// True when the Lightweight Charts bundle is present. False on a build where
/// the vendored script failed to load — the page says so rather than rendering
/// a blank rectangle.
bool get chartsAvailable =>
    web.window.hasProperty('LightweightCharts'.toJS).toDart;

// ── chart registry ──────────────────────────────────────────────────────────

class _Handle {
  _Handle(this.chart, this.candles, this.volume);

  final _Chart chart;
  final _Series candles;
  final _Series volume;

  void dispose() => chart.remove();
}

/// The factory runs exactly once per view-type, so a rebuild must never rebuild
/// the chart — doing so would throw away the user's zoom and pan position. Data
/// changes therefore go through [chartSetData], which mutates the live series.
final _handles = <String, _Handle>{};
var _seq = 0;

JSObject _row(Candle c) => JSObject()
  ..['time'] = c.time.toJS
  ..['open'] = c.open.toJS
  ..['high'] = c.high.toJS
  ..['low'] = c.low.toJS
  ..['close'] = c.close.toJS;

JSObject _volRow(Candle c) => JSObject()
  ..['time'] = c.time.toJS
  ..['value'] = c.volume.toJS
  // Muted so the volume pane reads as context, not as a second price series.
  ..['color'] =
      (c.close >= c.open ? 'rgba(27,127,75,0.45)' : 'rgba(190,24,93,0.45)')
          .toJS;

/// Push a new series into an already-mounted chart.
void chartSetData(String id, List<Candle> data) {
  final h = _handles[id];
  if (h == null) return;
  final bars = normaliseBars(data);
  h.candles.setData(bars.map(_row).toList().toJS);
  h.volume.setData(bars.map(_volRow).toList().toJS);
}

/// A live candlestick chart with a volume pane.
class CandlestickChart extends StatefulWidget {
  const CandlestickChart({
    super.key,
    required this.candles,
    this.showVolume = true,
    this.height = 380,
  });

  final List<Candle> candles;
  final bool showVolume;
  final double height;

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart> {
  String? _viewType;
  List<Candle> _shown = const [];
  String _overlaySig = '';

  @override
  void initState() {
    super.initState();
    if (!chartsAvailable) return;
    _viewType = 'omnicivest-chart-${_seq++}';
    final id = _viewType!;
    _shown = normaliseBars(widget.candles);
    _overlaySig = _overlaySignature(widget.overlays);

    ui_web.platformViewRegistry.registerViewFactory(id, (int _) {
      // HTMLDivElement already `implements JSObject`, so it passes straight
      // through to the interop boundary with no conversion.
      final el = web.document.createElement('div') as web.HTMLDivElement
        ..style.width = '100%'
        ..style.height = '100%';

      final chart = _createChart(el, _options(widget.candles)) as _Chart;
      final candles = chart.addSeries(_candleDef, _candleOptions()) as _Series;

      _Series volume = candles;
      if (widget.showVolume) {
        volume = chart.addSeries(
          _histDef,
          JSObject()..['priceScaleId'] = 'volume'.toJS,
        ) as _Series;
        // Park it at the bottom so it reads as context rather than competing
        // with price for attention.
        (volume.priceScale() as _PriceScale).applyOptions(
          JSObject()
            ..['scaleMargins'] = JSObject()
            ..['top'] = 0.78.toJS
            ..['bottom'] = 0.0.toJS,
        );
      }

      _handles[id] = _Handle(chart, candles, volume);
      chartSetData(id, widget.candles, widget.overlays);
      return el;
    });
  }

  JSObject _options(List<Candle> candles) {
    final bars = normaliseBars(candles);
    final daily = bars.length > 2 && (bars[1].time - bars[0].time) >= 86400;
    return JSObject()
      ..['layout'] = JSObject()
      ..['background'] = 'transparent'.toJS
      ..['textColor'] = '#9FB0AD'.toJS
      ..['fontSize'] = 11.toJS
      ..['fontFamily'] = 'Roboto, sans-serif'.toJS
      ..['grid'] = JSObject()
      ..['vertLines'] = JSObject()
      ..['color'] = 'rgba(255,255,255,0.04)'.toJS
      ..['horzLines'] = JSObject()
      ..['color'] = 'rgba(255,255,255,0.04)'.toJS
      ..['rightPriceScale'] = JSObject()
      ..['borderColor'] = 'rgba(255,255,255,0.10)'.toJS
      ..['timeScale'] = JSObject()
      ..['borderColor'] = 'rgba(255,255,255,0.10)'.toJS
      // Intraday needs a clock; a daily chart showing 14:32 is noise.
      ..['timeVisible'] = (!daily).toJS
      ..['secondsVisible'] = false.toJS
      ..['localization'] = JSObject()
      ..['locale'] = 'en-IN'.toJS
      ..['crosshair'] = JSObject()
      ..['mode'] = 0.toJS
      ..['vertLine'] = JSObject()
      ..['color'] = 'rgba(159,176,173,0.4)'.toJS
      ..['labelBackgroundColor'] = '#2A3B39'.toJS
      ..['horzLine'] = JSObject()
      ..['color'] = 'rgba(159,176,173,0.4)'.toJS
      ..['labelBackgroundColor'] = '#2A3B39'.toJS;
  }

  JSObject _candleOptions() => JSObject()
    // Green-up/red-down. TradingView's western default is the opposite, and
    // getting this backwards makes every chart feel wrong to the audience this
    // is built for.
    ..['upColor'] = '#1B7F4B'.toJS
    ..['downColor'] = '#BE185D'.toJS
    ..['borderUpColor'] = '#1B7F4B'.toJS
    ..['borderDownColor'] = '#BE185D'.toJS
    ..['wickUpColor'] = '#1B7F4B'.toJS
    ..['wickDownColor'] = '#BE185D'.toJS
    ..['priceLineColor'] = 'rgba(159,176,173,0.5)'.toJS;

  @override
  void didUpdateWidget(CandlestickChart old) {
    super.didUpdateWidget(old);
    final id = _viewType;
    if (id == null) return;
    // Overlays change independently of the candles — toggling RSI off must
    // repaint even though the price series is byte-identical. Comparing the
    // two separately is what keeps a stale indicator from outliving the
    // setting that asked for it.
    final sig = _overlaySignature(widget.overlays);
    if (seriesChanged(_shown, widget.candles) || sig != _overlaySig) {
      chartSetData(id, widget.candles, widget.overlays);
      _shown = normaliseBars(widget.candles);
      _overlaySig = sig;
    }
  }

  /// Identity of the overlay set: which keys are present, not their values.
  /// Values change on every fetch; the shape changes when the user toggles.
  static String _overlaySignature(List<Overlay> overlays) =>
      overlays.map((o) => o.key).join(',');

  @override
  void dispose() {
    if (_viewType != null) _handles.remove(_viewType!)?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_viewType == null || !chartsAvailable) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'The chart bundle did not load. '
            'vendor/lightweight-charts… must be present in web/.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9FB0AD), fontSize: 13),
          ),
        ),
      );
    }
    return SizedBox(
      height: widget.height,
      child: HtmlElementView(viewType: _viewType!),
    );
  }
}
