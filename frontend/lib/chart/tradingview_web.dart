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

import '../theme/terminal.dart';

import 'traces.dart';

import 'candle.dart';

// Parity with `tradingview_stub.dart`, which exports both. The conditional
// export in `tradingview.dart` promises callers the same surface on every
// platform, so a caller that imports only `tradingview.dart` must not compile
// on the VM and fail in the browser.
export 'candle.dart';
export 'traces.dart';

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

/// Indicator traces are line series. Separate from the candle definition
/// because v5's `addSeries` takes the definition object, not a type string.
@JS('LightweightCharts.LineSeries')
external JSObject get _lineDef;

extension type _Chart._(JSObject o) implements JSObject {
  external JSObject addSeries(JSObject definition, JSObject options);
  external void applyOptions(JSObject options);
  external void removeSeries(JSObject series);
  external void remove();
}

extension type _Series._(JSObject o) implements JSObject {
  external void setData(JSArray<JSObject> data);
  external JSObject priceScale();

  /// A horizontal reference line, in this series' own units. RSI's 30 and 70
  /// drawn against a share price would mean nothing, which is precisely the
  /// mistake that makes an indicator look like evidence.
  external JSObject createPriceLine(JSObject options);
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

  /// Null when [CandlestickChart.showVolume] is false.
  ///
  /// Nullable rather than aliased to [candles]: the alias type-checks, looks
  /// like it works, and then `chartSetData` overwrites the candles with
  /// histogram rows on the next update. That is the same shape of bug as
  /// `supertrend()` returning a price in its `direction` key — a field that is
  /// present and correct-typed and completely wrong.
  final _Series? volume;

  /// Every indicator line currently attached, so they can be torn down before
  /// the next set is drawn. Traces are recreated rather than reconciled
  /// because a line carries no per-series interaction state: ~16 JS calls and
  /// sub-millisecond, which is far less code to get wrong than a diff.
  final List<JSObject> traceSeries = [];

  /// Detach every trace line, leaving the candles and volume in place.
  ///
  /// Wrapped because the chart may already be torn down by the time a widget
  /// disposes. Losing an trace line is a cosmetic failure; throwing here would
  /// take down the page.
  void clearTraces() {
    while (traceSeries.isNotEmpty) {
      final s = traceSeries.removeLast();
      try {
        chart.removeSeries(s);
      } catch (_) {
        return;
      }
    }
  }

  void dispose() {
    clearTraces();
    chart.remove();
  }
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
      _rgba(c.close >= c.open ? Terminal.buyDim : Terminal.sellDim, 0.45).toJS;

/// Fraction of chart height given to each stacked pane, stacking upward from
/// the floor.
///
/// Fixed constants rather than computed from the pane list, because computed
/// values are how you end up with RSI drawn on top of volume after one
/// indicator is toggled off.
const _volumeBand = 0.16;
const _indicatorBand = 0.18;

/// Breathing room above the price pane.
const _priceTop = 0.08;

/// The `(bottom, top)` fraction of chart height each sub-pane occupies,
/// keyed by pane name. Volume sits on the floor; indicators stack above it.
Map<String, (double, double)> _paneBands(List<String> panes) {
  final out = <String, (double, double)>{'volume': (0.0, _volumeBand)};
  var cursor = _volumeBand;
  for (final p in panes) {
    out[p] = (cursor, cursor + _indicatorBand);
    cursor += _indicatorBand;
  }
  return out;
}

/// Where the stacked panes end and price begins.
double _stackTop(Map<String, (double, double)> bands) =>
    bands.values.fold<double>(0.0, (a, b) => b.$2 > a ? b.$2 : a);

/// Turn an occupied band into Lightweight Charts' `scaleMargins`.
///
/// LWC's margins are the *empty* space above and below a scale, so a scale
/// carrying `top: 0.16` is squashed into the top sixth of the chart. Passing an
/// occupied band straight through inverts the layout — not cosmetic, it parks
/// RSI at the top of the pane and leaves the rest empty.
JSObject _margins((double, double) band) => JSObject()
  ..['scaleMargins'] = JSObject()
  ..['top'] = (1 - band.$2).toJS
  ..['bottom'] = band.$1.toJS;

/// Push the whole pane layout to the chart: price on top, then each indicator
/// pane, then volume, with no two of them sharing pixels.
///
/// Recomputed on every draw rather than fixed at construction, because the pane
/// list changes whenever an indicator is toggled. Leaving the price scale on
/// its default 10% margin is how RSI ends up drawn straight through the share
/// price, where it reads as a second price series instead of an oscillator.
void _applyPaneBands(_Handle h, List<String> panes) {
  final bands = _paneBands(panes);
  final stack = _stackTop(bands);
  (h.candles.priceScale() as _PriceScale).applyOptions(JSObject()
    ..['scaleMargins'] = JSObject()
    ..['top'] = _priceTop.toJS
    ..['bottom'] = stack.toJS);
  final vol = h.volume;
  if (vol != null) {
    (vol.priceScale() as _PriceScale).applyOptions(_margins(bands['volume']!));
  }
}

/// RSI's oversold and overbought levels, in the oscillator's own units.
const _rsiBands = <double>[30.0, 70.0];

/// Detach the old indicator lines and draw the new set.
///
/// Every warm-up gap becomes a separate line rather than a bridge: a connected
/// RSI implies the oscillator was there and rising, and it was not. See
/// `traces.dart` for why that matters more than the visual tidiness.
void _drawTraces(_Handle h, List<Candle> bars, List<Trace> traces) {
  h.clearTraces();
  final panes = <String>{
    for (final o in traces)
      if (o.pane != null) o.pane!,
  }.toList();
  // Applied before the early return: with no traces the price scale still
  // has to give volume its floor, or the two draw over each other.
  _applyPaneBands(h, panes);
  if (traces.isEmpty || bars.isEmpty) return;

  final bands = _paneBands(panes);

  for (final o in traces) {
    final scaleId = o.pane ?? 'right';
    final series = h.chart.addSeries(
      _lineDef,
      JSObject()
        ..['color'] = _css(o.color).toJS
        ..['lineWidth'] = o.width.toJS
        // The legend and the HUD own the labels; repeating them on the axis is
        // noise fighting the price scale for the same pixels.
        ..['priceLineVisible'] = false.toJS
        ..['lastValueVisible'] = false.toJS
        ..['crosshairMarkerVisible'] = false.toJS
        ..['priceScaleId'] = scaleId.toJS,
    ) as _Series;

    // A pane is just a price scale with its own margins. Applying them to the
    // series rather than the chart is what keeps RSI from rescaling price.
    final band = o.pane == null ? null : bands[o.pane];
    if (band != null) {
      (series.priceScale() as _PriceScale).applyOptions(_margins(band));
    }

    if (o.pane == 'rsi') {
      for (final level in _rsiBands) {
        series.createPriceLine(JSObject()
          ..['price'] = level.toJS
          ..['color'] = _css(o.color).toJS
          ..['lineWidth'] = 1.toJS
          // 2 = dashed. A solid line at the same weight as the trace reads as
          // part of the data rather than as a threshold.
          ..['lineStyle'] = 2.toJS
          ..['axisLabelVisible'] = true.toJS
          ..['title'] = ''.toJS);
      }
    }

    h.traceSeries.add(series);

    // One `setData` for the whole trace, with whitespace points at the warm-up
    // gaps. Calling `setData` once per segment would replace the data each time
    // and leave only the last segment drawn — which is exactly the warm-up
    // region, so the indicator would appear to begin at the most recent bar.
    final rows = <JSObject>[];
    Segment? prev;
    for (final seg in segmentsOf(o.values)) {
      if (!seg.isDrawable) continue;
      final gapAt = seg.startIndex - 1;
      if (prev != null &&
          gapAt >= 0 &&
          gapAt < bars.length &&
          gapAt > prev.startIndex + prev.points.length - 1) {
        // A timestamp with no value. LWC breaks the line here; bridging instead
        // would assert the oscillator existed during the warm-up, which is the
        // one thing it does not.
        rows.add(JSObject()..['time'] = bars[gapAt].time.toJS);
      }
      for (final (i, v) in seg.points) {
        // Defensive: the panel is index-aligned with the candles, but a short
        // panel must clip rather than throw inside a platform-view factory.
        if (i >= bars.length) break;
        rows.add(JSObject()
          ..['time'] = bars[i].time.toJS
          ..['value'] = v.toJS);
      }
      prev = seg;
    }
    if (rows.length >= 2) series.setData(rows.toJS);
  }
}

/// `#AARRGGBB` as a CSS string.
///
/// The theme stores alpha in its own byte because that is what `Color` does;
/// CSS needs it in the string, or a 40%-opacity Bollinger band renders fully
/// opaque and reads as a price level rather than as an envelope.
String _css(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';

/// `rgba(r,g,b,a)` for a theme colour at [opacity].
///
/// Lightweight Charts takes CSS strings, so the theme's packed-ARGB [Color] has
/// to be re-expressed. Every colour the chart draws goes through here or
/// [_css] rather than being typed out: the candle down-colour was still
/// `#BE185D` here after `Terminal.sellDim` moved to `#D61C69`, which is exactly
/// the two-places-disagree failure this app is supposed to be catching in other
/// people's data.
String _rgba(Color c, double opacity) {
  final argb = c.toARGB32();
  return 'rgba(${(argb >> 16) & 0xFF},${(argb >> 8) & 0xFF},${argb & 0xFF},'
      '${(opacity * (argb >> 24) / 255).toStringAsFixed(3)})';
}

/// Push a new series into an already-mounted chart.
void chartSetData(String id, List<Candle> data,
    [List<Trace> traces = const []]) {
  final h = _handles[id];
  if (h == null) return;
  final bars = normaliseBars(data);
  h.candles.setData(bars.map(_row).toList().toJS);
  final vol = h.volume;
  if (vol != null) vol.setData(bars.map(_volRow).toList().toJS);
  _drawTraces(h, bars, traces);
}

/// A live candlestick chart with volume and indicator panes.
class CandlestickChart extends StatefulWidget {
  const CandlestickChart({
    super.key,
    required this.candles,
    this.traces = const [],
    this.showVolume = true,
    this.height = 380,
  });

  final List<Candle> candles;

  /// Indicator traces to draw. [Trace.pane] decides whether a trace shares
  /// the price scale or gets a pane of its own.
  final List<Trace> traces;

  final bool showVolume;
  final double height;

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart> {
  String? _viewType;
  List<Candle> _shown = const [];
  String _traceSig = '';

  @override
  void initState() {
    super.initState();
    if (!chartsAvailable) return;
    _viewType = 'omnicivest-chart-${_seq++}';
    final id = _viewType!;
    _shown = normaliseBars(widget.candles);
    _traceSig = _traceSignature(widget.traces);

    ui_web.platformViewRegistry.registerViewFactory(id, (int _) {
      // HTMLDivElement already `implements JSObject`, so it passes straight
      // through to the interop boundary with no conversion.
      final el = web.document.createElement('div') as web.HTMLDivElement
        ..style.width = '100%'
        ..style.height = '100%';

      final chart = _createChart(el, _options(widget.candles)) as _Chart;
      final candles = chart.addSeries(_candleDef, _candleOptions()) as _Series;

      _Series? volume;
      if (widget.showVolume) {
        volume = chart.addSeries(
          _histDef,
          JSObject()..['priceScaleId'] = 'volume'.toJS,
        ) as _Series;
        // Vertical placement is not set here. It is derived from the live pane
        // list in `_applyPaneBands`, so volume and the indicator panes cannot
        // be laid out by two different sets of numbers.
      }

      _handles[id] = _Handle(chart, candles, volume);
      chartSetData(id, widget.candles, widget.traces);
      return el;
    });
  }

  JSObject _options(List<Candle> candles) {
    final bars = normaliseBars(candles);
    final daily = bars.length > 2 && (bars[1].time - bars[0].time) >= 86400;
    return JSObject()
      ..['layout'] = JSObject()
      ..['background'] = 'transparent'.toJS
      ..['textColor'] = _css(Terminal.ink2).toJS
      ..['fontSize'] = 11.toJS
      ..['fontFamily'] = 'Roboto, sans-serif'.toJS
      ..['grid'] = JSObject()
      ..['vertLines'] = JSObject()
      ..['color'] = _rgba(Terminal.ink, 0.04).toJS
      ..['horzLines'] = JSObject()
      ..['color'] = _rgba(Terminal.ink, 0.04).toJS
      ..['rightPriceScale'] = JSObject()
      ..['borderColor'] = _rgba(Terminal.ink, 0.10).toJS
      ..['timeScale'] = JSObject()
      ..['borderColor'] = _rgba(Terminal.ink, 0.10).toJS
      // Intraday needs a clock; a daily chart showing 14:32 is noise.
      ..['timeVisible'] = (!daily).toJS
      ..['secondsVisible'] = false.toJS
      ..['localization'] = JSObject()
      ..['locale'] = 'en-IN'.toJS
      ..['crosshair'] = JSObject()
      ..['mode'] = 0.toJS
      ..['vertLine'] = JSObject()
      ..['color'] = _rgba(Terminal.ink2, 0.4).toJS
      ..['labelBackgroundColor'] = _css(Terminal.raised).toJS
      ..['horzLine'] = JSObject()
      ..['color'] = _rgba(Terminal.ink2, 0.4).toJS
      ..['labelBackgroundColor'] = _css(Terminal.raised).toJS;
  }

  JSObject _candleOptions() => JSObject()
    // Green-up/red-down. TradingView's western default is the opposite, and
    // getting this backwards makes every chart feel wrong to the audience this
    // is built for.
    ..['upColor'] = _css(Terminal.buyDim).toJS
    ..['downColor'] = _css(Terminal.sellDim).toJS
    ..['borderUpColor'] = _css(Terminal.buyDim).toJS
    ..['borderDownColor'] = _css(Terminal.sellDim).toJS
    ..['wickUpColor'] = _css(Terminal.buyDim).toJS
    ..['wickDownColor'] = _css(Terminal.sellDim).toJS
    ..['priceLineColor'] = _rgba(Terminal.ink2, 0.5).toJS;

  @override
  void didUpdateWidget(CandlestickChart old) {
    super.didUpdateWidget(old);
    final id = _viewType;
    if (id == null) return;
    // Traces change independently of the candles — toggling RSI off must
    // repaint even though the price series is byte-identical. Comparing the
    // two separately is what keeps a stale indicator from outliving the
    // setting that asked for it.
    final sig = _traceSignature(widget.traces);
    if (seriesChanged(_shown, widget.candles) || sig != _traceSig) {
      chartSetData(id, widget.candles, widget.traces);
      _shown = normaliseBars(widget.candles);
      _traceSig = sig;
    }
  }

  /// Identity of the trace set: which keys are present, not their values.
  /// Values change on every fetch; the shape changes when the user toggles.
  static String _traceSignature(List<Trace> traces) =>
      traces.map((o) => o.key).join(',');

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
