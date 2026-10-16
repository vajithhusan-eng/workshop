/// Tests for the trace model: warm-up gaps, key drift, and draw ordering.
///
/// These exist because the failure modes are invisible rather than loud. A
/// drifted key drops a line off the chart and the chart still looks fine. A
/// bridged warm-up draws a convincing RSI that was never computed. A reversed
/// draw order puts Bollinger on top of price. None of those throw.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:omnivest/chart/traces.dart';

/// The tail of a real `/api/analysis/symbol?symbol=RELIANCE` payload, captured
/// from the live backend and rounded to 4dp.
///
/// Captured rather than hand-written on purpose. A hand-written fixture only
/// proves the parser agrees with the fixture's author; a captured one proves it
/// agrees with the backend. If the backend renames `rsi_14` to something else,
/// this test fails — which is the entire reason it exists.
const _realPanel = <String, dynamic>{
  'bollinger_upper': <dynamic>[
    1340.9057,
    1339.9369,
    1339.5786,
    1336.8073,
    1332.46,
    1330.0605,
    1331.1332,
    1330.2422,
    1332.6084,
    1330.9633,
    1325.5283,
    1322.6057,
  ],
  'bollinger_lower': <dynamic>[
    1238.5443,
    1232.5831,
    1223.9814,
    1220.5127,
    1217.2,
    1214.5995,
    1207.2268,
    1202.0178,
    1191.7116,
    1180.6567,
    1173.4817,
    1162.9243,
  ],
  'sma_50': <dynamic>[
    1297.742,
    1297.024,
    1295.396,
    1294.406,
    1293.354,
    1292.404,
    1290.856,
    1288.832,
    1286.322,
    1283.888,
    1281.856,
    1279.766,
  ],
  'sma_20': <dynamic>[
    1289.725,
    1286.26,
    1281.78,
    1278.66,
    1274.83,
    1272.33,
    1269.18,
    1266.13,
    1262.16,
    1255.81,
    1249.505,
    1242.765,
  ],
  'ema_21': <dynamic>[
    1283.2824,
    1279.7022,
    1274.8566,
    1272.3605,
    1269.455,
    1267.5046,
    1263.1132,
    1259.7393,
    1254.0903,
    1247.5366,
    1242.0333,
    1235.2757,
  ],
  'ema_9': <dynamic>[
    1265.5062,
    1261.1849,
    1254.2279,
    1252.8624,
    1250.3699,
    1249.8959,
    1243.7567,
    1240.2054,
    1231.6843,
    1221.7474,
    1214.798,
    1205.3784,
  ],
  'rsi_14': <dynamic>[
    34.2116,
    35.8748,
    31.9692,
    40.36,
    38.6488,
    41.5466,
    34.8325,
    37.4047,
    31.7655,
    29.1646,
    31.1115,
    27.9214,
  ],
  'macd': <dynamic>[
    -14.8984,
    -16.034,
    -18.137,
    -17.9028,
    -18.0737,
    -17.3953,
    -18.963,
    -19.4327,
    -21.8448,
    -24.7301,
    -26.31,
    -28.7876,
  ],
  'macd_signal': <dynamic>[
    -7.7142,
    -9.3782,
    -11.13,
    -12.4845,
    -13.6024,
    -14.3609,
    -15.2814,
    -16.1116,
    -17.2583,
    -18.7526,
    -20.2641,
    -21.9688,
  ],
};

/// Every key the live backend returns. A drift guard in the same direction as
/// the key set: if the backend stops sending `rsi_14`, the trace silently
/// disappears from the chart and nothing anywhere reports it.
const _backendKeys = <String>{
  'adx_14',
  'atr_14',
  'atr_percent',
  'bollinger_lower',
  'bollinger_middle',
  'bollinger_upper',
  'bollinger_width',
  'donchian_lower',
  'donchian_upper',
  'ema_21',
  'ema_9',
  'macd',
  'macd_histogram',
  'macd_signal',
  'minus_di',
  'obv',
  'percent_b',
  'plus_di',
  'returns',
  'rsi_14',
  'sma_20',
  'sma_50',
  'stoch_d',
  'stoch_k',
  'supertrend',
  'supertrend_direction',
  'vwap_20',
};

void main() {
  group('segmentsOf', () {
    test('splits a series into runs of real values', () {
      final segs = segmentsOf(<double?>[null, null, 1, 2, null, 3, 4, 5]);
      expect(segs.length, 2);
      expect(segs[0].startIndex, 2);
      expect(segs[0].points.length, 2);
      expect(segs[1].startIndex, 5);
      expect(segs[1].points.length, 3);
    });

    test('a leading null produces no leading segment', () {
      // A zero-length segment at the front would render as a dot at the axis.
      final segs = segmentsOf(<double?>[null, null, 1, 2, 3]);
      expect(segs.length, 1);
      expect(segs.single.startIndex, 2);
    });

    test('a single point is returned, not dropped', () {
      // Whether a lone point is worth drawing is a rendering decision. Deleting
      // it here would make the segment count depend on an invisible rule.
      final segs = segmentsOf(<double?>[1]);
      expect(segs.length, 1);
      expect(segs.single.isDrawable, isFalse);
    });

    test('an isolated point between two runs is not drawable but is counted',
        () {
      final segs = segmentsOf(<double?>[1, 2, null, 7, null, 9, 10]);
      expect(segs.length, 3);
      expect(segs[1].isDrawable, isFalse);
      expect(segs[1].points.single.$1, 3);
    });

    test('empty and all-null inputs produce no segments', () {
      expect(segmentsOf(const []), isEmpty);
      expect(segmentsOf(<double?>[null, null, null]), isEmpty);
    });

    test('a trailing null flushes the run in progress', () {
      final segs = segmentsOf(<double?>[1, 2, null]);
      expect(segs.length, 1);
      expect(segs.single.points.length, 2);
    });

    test('consecutive nulls do not produce empty segments between them', () {
      final segs = segmentsOf(<double?>[1, 2, null, null, null, 3, 4]);
      expect(segs.length, 2, reason: 'three nulls in a row are one gap');
    });

    test('points carry index, not position in the segment', () {
      // The candle-to-timestamp mapping lives in exactly one place.
      final segs = segmentsOf(<double?>[null, 5, 6, null]);
      expect(segs.single.points[0], (1, 5.0));
      expect(segs.single.points[1], (2, 6.0));
    });
  });

  group('asNum', () {
    test('accepts int and double', () {
      expect(asNum(7), 7.0);
      expect(asNum(27.92), 27.92);
    });

    test('rejects a numeric string', () {
      // A backend that starts emitting "27.92" instead of 27.92 is a bug worth
      // seeing as a dropped series, not something to paper over.
      expect(asNum('27.92'), isNull);
      expect(asNum(''), isNull);
    });

    test('rejects null, bool, list and map', () {
      expect(asNum(null), isNull);
      expect(asNum(true), isNull);
      expect(asNum(<int>[1]), isNull);
      expect(asNum(<String, int>{'a': 1}), isNull);
    });

    test('rejects NaN and infinity', () {
      expect(asNum(double.nan), isNull);
      expect(asNum(double.infinity), isNull);
      expect(asNum(double.negativeInfinity), isNull);
    });
  });

  group('key set', () {
    test('every drawn key exists in the backend payload', () {
      // The drift guard. Fails loudly the day the backend renames something,
      // instead of silently dropping a line off the chart.
      for (final key in const [
        'bollinger_upper',
        'bollinger_lower',
        'sma_50',
        'sma_20',
        'ema_21',
        'ema_9',
        'rsi_14',
        'macd',
        'macd_signal',
      ]) {
        expect(_backendKeys, contains(key),
            reason:
                'traces.dart draws "$key" but the backend does not send it');
        expect(isDrawn(key), isTrue, reason: '"$key" is drawn but not marked');
      }
    });

    test('the captured fixture keys are a subset of the backend payload', () {
      for (final k in _realPanel.keys) {
        expect(_backendKeys, contains(k), reason: 'fixture invented key "$k"');
      }
    });

    test('an unknown key is not drawn', () {
      expect(isDrawn('not_a_indicator'), isFalse);
      expect(isDrawn(''), isFalse);
      expect(isDrawn('rsi'), isFalse, reason: 'rsi is a pane, not a key');
    });

    test('RSI and MACD get their own pane; moving averages share price', () {
      expect(paneFor('rsi_14'), 'rsi');
      expect(paneFor('macd'), 'macd');
      expect(paneFor('macd_signal'), 'macd');
      expect(paneFor('sma_20'), isNull);
      expect(paneFor('bollinger_upper'), isNull);
      expect(paneFor('adx_14'), isNull, reason: 'not drawn, so no pane');
    });

    test('traceFor refuses an undrawn key', () {
      expect(traceFor('obv', const [1, 2]), isNull);
      expect(traceFor('rsi_14', const [1, 2]), isNotNull);
    });

    test('every drawn trace has a human label, not a raw key', () {
      for (final k in const [
        'bollinger_upper',
        'bollinger_lower',
        'sma_50',
        'sma_20',
        'ema_21',
        'ema_9',
        'rsi_14',
        'macd',
        'macd_signal',
      ]) {
        final t = traceFor(k, const [1, 2])!;
        expect(t.label, isNot(equals(k)), reason: '"$k" shown raw to the user');
        expect(t.label, isNotEmpty);
      }
    });
  });

  group('buildTraces', () {
    test('a null or empty panel is no traces, not a crash', () {
      expect(buildTraces(null), isEmpty);
      expect(buildTraces(const {}), isEmpty);
    });

    test('a real panel produces exactly the drawn series', () {
      final traces = buildTraces(_realPanel);
      expect(traces.map((t) => t.key).toSet(), _realPanel.keys.toSet());
      expect(traces.length, 9);
    });

    test('a series with no defined value is skipped, not drawn empty', () {
      // Nine bars of warm-up is a real state, not a bug. Drawing an empty line
      // leaves a legend entry that promises a number it does not have.
      final traces = buildTraces(const {
        'rsi_14': <dynamic>[null, null, null],
        'sma_20': <dynamic>[null, 1.0, 2.0],
      });
      expect(traces.map((t) => t.key), ['sma_20']);
    });

    test('an empty list, a non-list and a null value are all skipped', () {
      final traces = buildTraces(const {
        'rsi_14': <dynamic>[],
        'sma_20': 'not a list',
        'ema_9': <dynamic>[null, null],
      });
      expect(traces, isEmpty);
    });

    test('undrawn keys in the payload are ignored', () {
      final traces = buildTraces(const {
        'obv': <dynamic>[1.0, 2.0, 3.0],
        'supertrend_direction': <dynamic>[1.0, 1.0, 1.0],
        'sma_20': <dynamic>[null, 1.0, 2.0],
      });
      expect(traces.map((t) => t.key), ['sma_20']);
    });

    test('a numeric string inside a real series drops the whole series', () {
      // Strictness has to survive contact with a real panel: one string
      // anywhere turns that trace into a partial one.
      final traces = buildTraces(const {
        'rsi_14': <dynamic>[1.0, '2.0', 3.0],
        'sma_20': <dynamic>[null, 1.0, 2.0],
      });
      expect(traces.map((t) => t.key), ['sma_20']);
    });

    test('draw order puts the first-listed price trace on top', () {
      // Reversed so the trace listed first in the source order paints last.
      // Where Bollinger crosses SMA the envelope should read behind, not over.
      final traces = buildTraces(_realPanel);
      final keys = traces.map((t) => t.key).toList();
      expect(keys.last, 'bollinger_upper');
      expect(keys.indexOf('sma_20'), lessThan(keys.indexOf('bollinger_lower')));
    });

    test('each trace keeps its own pane assignment', () {
      final byKey = {for (final t in buildTraces(_realPanel)) t.key: t};
      expect(byKey['rsi_14']!.pane, 'rsi');
      expect(byKey['macd']!.pane, 'macd');
      expect(byKey['macd_signal']!.pane, 'macd');
      expect(byKey['sma_20']!.pane, isNull);
    });

    test('trace values are the same length as the panel row', () {
      for (final t in buildTraces(_realPanel)) {
        expect(t.values.length, (_realPanel[t.key] as List).length,
            reason: '${t.key} must stay index-aligned with the candles');
      }
    });

    test('MACD and its signal are visually distinct', () {
      // Same pane, same units — if they shared a colour the crossing would be
      // invisible, which is the one thing the pane exists to show.
      final byKey = {for (final t in buildTraces(_realPanel)) t.key: t};
      expect(byKey['macd']!.color, isNot(byKey['macd_signal']!.color));
    });
  });

  group('Trace', () {
    test('definedIndices and hasData agree with the values', () {
      final t = traceFor('rsi_14', <double?>[null, null, 30.0, null, 70.0])!;
      expect(t.definedIndices, [2, 4]);
      expect(t.hasData, isTrue);
      expect(traceFor('rsi_14', const [null, null])!.hasData, isFalse);
    });
  });
}
