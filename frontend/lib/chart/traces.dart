/// The trace model: indicator traces to draw on top of, or beneath, price.
///
/// Pure Dart with no JS imports, deliberately. The rendering is web-only but
/// the *reasoning* about a warm-up gap is not, and this is where that reasoning
/// lives so it can be tested without a browser.
///
/// Two charting behaviours quietly corrupt a terminal, and both are guarded
/// here rather than left to the renderer:
///
/// 1. **A null in a line series is a gap, not a zero.** Passing `value: null`
///    for a warm-up bar is how a 14-period RSI draws a line plunging from the
///    axis on bar 1. The warm-up is *unknown*, and the only honest rendering is
///    not to draw it.
/// 2. **Connecting across that gap is worse than the zero** — it implies the
///    oscillator was there and rising. It was not.
///
/// So [segmentsOf] splits a series into contiguous runs of real values, and each
/// run is drawn as its own line. No bridge, no fill, no invented point.
library;

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../theme/terminal.dart';

/// One indicator trace, index-aligned with the candles it annotates.
@immutable
class Trace {
  const Trace({
    required this.key,
    required this.label,
    required this.color,
    required this.values,
    this.pane,
    this.width = 1.5,
  });

  /// Must match a key in the backend's `indicator_series` payload. Drift here
  /// makes the trace silently vanish rather than error, so the tests assert
  /// the keys against a real payload instead of trusting them.
  final String key;

  /// What the legend and HUD call this trace. Not the backend key — `bollinger
  /// _upper` is not a thing a human reads.
  final String label;

  final Color color;

  /// `values[i]` belongs to `candles[i]`. A null is an unknown warm-up value,
  /// never a zero.
  final List<double?> values;

  /// Null shares the price scale. A non-null value names a pane of its own —
  /// RSI between 0 and 100 has no meaning plotted against a share price.
  final String? pane;

  final double width;

  /// Indices where a real value exists. Empty is a normal state during warm-up,
  /// not an error.
  List<int> get definedIndices => <int>[
        for (var i = 0; i < values.length; i++)
          if (values[i] != null) i,
      ];

  bool get hasData => values.any((v) => v != null);
}

/// A contiguous run of real values, carrying **index not timestamp**.
///
/// The candle-to-timestamp mapping lives in one place; duplicating it here
/// would be another way for two parts of the chart to disagree.
@immutable
class Segment {
  const Segment(this.startIndex, this.points);

  final int startIndex;
  final List<(int, double)> points;

  bool get isDrawable => points.length >= 2;
}

/// Split [values] into runs of consecutive non-null values.
///
/// A leading null produces no leading segment, and each null flushes the run in
/// progress. Single points are returned rather than dropped: whether a lone
/// point is worth drawing is a rendering decision, and quietly deleting it here
/// would make the segment count depend on an invisible rule.
List<Segment> segmentsOf(List<double?> values) {
  final out = <Segment>[];
  var current = <(int, double)>[];
  var start = 0;

  void flush() {
    if (current.isEmpty) return;
    out.add(Segment(start, List.of(current)));
    current = <(int, double)>[];
  }

  for (var i = 0; i < values.length; i++) {
    final v = values[i];
    if (v == null) {
      flush();
      continue;
    }
    if (current.isEmpty) start = i;
    current.add((i, v));
  }
  flush();
  return out;
}

/// Coerce a JSON value to a double, or null when it is not one.
///
/// Deliberately strict about strings. A backend that starts emitting
/// `"27.92"` instead of `27.92` is a bug worth seeing as a *dropped series* on
/// the chart, not something to paper over — a silently coerced string is
/// indistinguishable from a value that was always there, and this file exists to
/// make exactly that class of thing visible.
double? asNum(Object? v) {
  if (v is! num) return null;
  final d = v.toDouble();
  if (d.isNaN || d.isInfinite) return null;
  return d;
}

/// Traces drawn on the price scale, in stacking order.
///
/// Deliberately a subset. Plotting all 27 produces a chart nobody can read,
/// which is its own kind of dishonesty. These are the ones that answer "what is
/// the state of this instrument", not every number the engine can compute.
const _pricePanes = <String>[
  'bollinger_upper',
  'bollinger_lower',
  'sma_50',
  'sma_20',
  'ema_21',
  'ema_9',
];

/// Traces that get their own pane, keyed by indicator name.
const _separatePanes = <String, String>{
  'rsi_14': 'rsi',
  'macd': 'macd',
  // The signal line shares the MACD pane. A MACD pane holding only the MACD
  // line is missing the half of the indicator that produces the reading.
  //
  // `macd_histogram` is deliberately not drawn: it is a histogram, and drawing
  // it as a line would misrepresent what it is.
  'macd_signal': 'macd',
};

const _labels = <String, String>{
  'sma_20': 'SMA 20',
  'sma_50': 'SMA 50',
  'ema_9': 'EMA 9',
  'ema_21': 'EMA 21',
  'rsi_14': 'RSI 14',
  'macd': 'MACD',
  'macd_signal': 'Signal',
  'bollinger_upper': 'BB+',
  'bollinger_lower': 'BB−',
};

/// Which pane an indicator belongs in, or null if it is not drawn.
String? paneFor(String key) => _separatePanes[key];

/// True when [key] is one this app draws. Kept separate from [traceFor] so a
/// test can assert the drawn set without constructing anything.
bool isDrawn(String key) =>
    _pricePanes.contains(key) || _separatePanes.containsKey(key);

/// Build one trace, or null if the key is not drawn.
Trace? traceFor(String key, List<double?> values) {
  if (!isDrawn(key)) return null;
  return Trace(
    key: key,
    label: _labels[key] ?? key,
    color: _colorFor(key),
    values: values,
    pane: _separatePanes[key],
  );
}

/// Colours come from the theme rather than being defined here.
///
/// Duplicating them would mean the chart and the HUD could disagree about what
/// "the RSI line" looks like — and two parts of one screen showing the same
/// indicator in different colours is exactly the class of quiet contradiction
/// this app is built to catch.
Color _colorFor(String key) => switch (key) {
      'sma_20' => Terminal.sma20,
      'sma_50' => Terminal.sma50,
      'ema_9' => Terminal.ema9,
      'ema_21' => Terminal.ema21,
      'rsi_14' => Terminal.rsi,
      'macd' => Terminal.macdLine,
      'macd_signal' => Terminal.macdSignal,
      'bollinger_upper' || 'bollinger_lower' => Terminal.bb,
      _ => Terminal.ink2,
    };

/// Turn the backend's `indicator_series` panel into drawable traces.
///
/// Returns them in draw order: later entries paint over earlier ones, so the
/// returned list is reversed relative to [_pricePanes] to keep the first-listed
/// trace on top where two of them cross.
List<Trace> buildTraces(Map<String, dynamic>? panel) {
  if (panel == null || panel.isEmpty) return const [];
  final out = <Trace>[];

  void add(String key) {
    final raw = panel[key];
    if (raw is! List || raw.isEmpty) return;

    // Any unparseable entry drops the *whole* series, rather than nulling that
    // one point. A null point on a chart reads as a gap in the market data;
    // a string in the payload is a bug, and rendering it as a gap would let
    // the bug pose as a market fact. A missing line is loud. A plausible lie
    // is not — and this is an app whose entire argument is about not doing
    // the second thing.
    final values = <double?>[];
    var broken = false;
    for (final v in raw) {
      if (v == null) {
        values.add(null);
        continue;
      }
      final d = asNum(v);
      if (d == null) {
        broken = true;
        break;
      }
      values.add(d);
    }
    if (broken) return;

    final trace = traceFor(key, values);
    if (trace != null && trace.hasData) out.add(trace);
  }

  for (final k in _pricePanes) {
    add(k);
  }
  for (final k in _separatePanes.keys) {
    add(k);
  }
  return out.reversed.toList();
}
