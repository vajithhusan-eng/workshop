/// The chart's data model — deliberately free of any web-only import.
///
/// `Candle` and [seriesChanged] live here rather than in the interop file so
/// that `package:web` and `dart:js_interop` stay confined to the platform
/// implementation. That split is not tidiness: `dart:js_interop` does not
/// compile on the Dart VM, so a file importing it cannot be covered by
/// `flutter test` at all. Keeping the model here means the parsing, ordering
/// and change-detection rules are all testable on the VM, and the page's
/// fallback rendering is tested too.
library;

import 'package:flutter/foundation.dart';

/// One OHLCV bar, ordered and de-duplicated before it reaches here.
@immutable
class Candle {
  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// Epoch **seconds** — the unit TradingView expects, and the one the backend
  /// emits. Passing milliseconds produces a chart with no bars at all, and
  /// nothing in the browser tells you why.
  final int time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  /// True when the bar is internally consistent. The renderer trusts this
  /// relationship completely, so a violation means the upstream parser let a
  /// broken bar through.
  bool get isCoherent =>
      low <= (open < close ? open : close) &&
      high >= (open < close ? close : open) &&
      low > 0;

  @override
  String toString() =>
      'Candle(${DateTime.fromMillisecondsSinceEpoch(time * 1000)}, '
      'o=$open h=$high l=$low c=$close)';
}

/// True when the bars differ enough to warrant a repaint.
///
/// Compares the *shape* rather than the contents, so it stays O(1) on a
/// 2000-bar series, and so the crosshair and zoom do not jump on every
/// unrelated rebuild.
bool seriesChanged(List<Candle> a, List<Candle> b) {
  if (a.length != b.length) return true;
  if (a.isEmpty) return false;
  return a.first.time != b.first.time || a.last.time != b.last.time;
}

/// Sort ascending by time and drop duplicate timestamps, in one pass.
///
/// Lightweight Charts **silently drops** out-of-order bars rather than drawing
/// them, so unsorted input does not produce a visibly broken chart — it
/// produces a chart that is quietly missing data. Deduplicating here is the
/// only place that bug can be caught.
List<Candle> normaliseBars(Iterable<Candle> bars) {
  final sorted = bars.toList()..sort((a, b) => a.time.compareTo(b.time));
  final seen = <int>{};
  return sorted.where((c) => seen.add(c.time)).toList();
}

/// Turn the backend's `candles` array into bars, discarding anything malformed.
///
/// Every field is required. A bar missing its high, or carrying a non-numeric
/// close, is **dropped rather than patched** — a candle with a null high is
/// worse than a missing candle, because the renderer trusts the OHLC
/// relationship absolutely and will happily draw something impossible.
///
/// Accepts numbers as JSON numbers or strings: a hand-written fixture and a real
/// backend response both have to work.
List<Candle> parseCandles(Object? raw) {
  if (raw is! List) return const [];
  final out = <Candle>[];
  for (final e in raw) {
    if (e is! Map) continue;
    double? num_(Object? k) {
      final v = e[k];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final t = num_('time');
    final o = num_('open');
    final h = num_('high');
    final l = num_('low');
    final c = num_('close');
    if (t == null || o == null || h == null || l == null || c == null) {
      continue;
    }
    out.add(Candle(
      time: t.toInt(),
      open: o,
      high: h,
      low: l,
      close: c,
      volume: num_('volume') ?? 0,
    ));
  }
  return normaliseBars(out);
}
