/// Chart tests.
///
/// These exist because of one specific hazard, not for coverage numbers.
///
/// **TradingView Lightweight Charts silently drops malformed input.** A bar with
/// a null `high`, a negative `low`, or a timestamp out of order does not raise —
/// it produces a chart that looks complete and is quietly missing bars. Nothing
/// in the browser tells you. A trader looking at a chart with holes in it does
/// not know the holes are holes.
///
/// So the parsing, ordering and de-duplication rules are asserted directly, and
/// the page's synthetic-data banner is asserted in text. That banner is the
/// difference between "no feed, chart is fake" and a confident picture of a
/// market that never happened.
///
/// Note this file runs on the Dart VM, where the real chart cannot load
/// (`dart:js_interop` does not compile there). It exercises the stub path —
/// which is why the conditional-import split exists. A page whose only tested
/// path is the untestable one is a page with no tests.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnivest/api.dart';
import 'package:omnivest/chart/tradingview.dart';
import 'package:omnivest/pages/chart_page.dart';
import 'package:omnivest/ui.dart';

/// A well-formed bar. Overridable per field so a test can break exactly one.
Map<String, dynamic> bar(
  int t, {
  Object? o = 100.0,
  Object? h = 110.0,
  Object? l = 95.0,
  Object? c = 105.0,
  Object? v = 1000,
}) =>
    {'time': t, 'open': o, 'high': h, 'low': l, 'close': c, 'volume': v};

/// Swap in a client that answers every request with [payload].
void _serve(Map<String, dynamic> payload) {
  api = Api(
    client: MockClient(
      (_) async => http.Response(jsonEncode(payload), 200,
          headers: {'content-type': 'application/json'}),
    ),
  );
}

Widget _app() => const MaterialApp(home: Scaffold(body: ChartPage()));

void main() {
  tearDown(useRealApi);

  group('Candle', () {
    test('a normal bar is coherent', () {
      expect(parseCandles([bar(1000)])[0].isCoherent, isTrue);
    });

    test('a red bar with open above close is still coherent', () {
      final c =
          parseCandles([bar(1000, o: 105.0, c: 100.0, h: 110.0, l: 95.0)])[0];
      expect(c.open, greaterThan(c.close));
      expect(c.isCoherent, isTrue);
    });

    test('high below the body is incoherent', () {
      expect(parseCandles([bar(1000, h: 101.0)])[0].isCoherent, isFalse);
    });

    test('low above the body is incoherent', () {
      expect(parseCandles([bar(1000, l: 108.0)])[0].isCoherent, isFalse);
    });

    test('a zero or negative low is incoherent', () {
      expect(parseCandles([bar(1000, l: 0.0)])[0].isCoherent, isFalse);
    });
  });

  group('parseCandles', () {
    test('non-list input yields nothing rather than throwing', () {
      expect(parseCandles(null), isEmpty);
      expect(parseCandles('nope'), isEmpty);
      expect(parseCandles(42), isEmpty);
      expect(parseCandles({'not': 'a list'}), isEmpty);
    });

    test('entries that are not maps are skipped', () {
      expect(parseCandles([bar(1), 'junk', null, 7]), hasLength(1));
    });

    // The rule that matters most: a bar missing any required field is DROPPED,
    // not patched. Patching a null high to the close would draw a bar whose
    // wick the renderer believes in.
    test('a missing field drops the bar entirely', () {
      for (final missing in ['time', 'open', 'high', 'low', 'close']) {
        final good = bar(1);
        final broken = Map<String, dynamic>.of(good)..remove(missing);
        expect(parseCandles([good, broken]), hasLength(1),
            reason: 'bar missing "$missing" should have been dropped');
      }
    });

    test('a null field drops the bar', () {
      expect(parseCandles([bar(1, h: null)]), isEmpty);
    });

    test('numeric strings are accepted so hand-built fixtures work', () {
      final b = parseCandles([
        {
          'time': '1000',
          'open': '100',
          'high': '110',
          'low': '95',
          'close': '105'
        }
      ]);
      expect(b, hasLength(1));
      expect(b.single.close, 105.0);
    });

    test('an unparseable string drops the bar', () {
      expect(parseCandles([bar(1, c: 'not-a-number')]), isEmpty);
    });

    test('a missing volume defaults to zero rather than dropping the bar', () {
      final m = Map<String, dynamic>.of(bar(1))..remove('volume');
      final b = parseCandles([m]);
      expect(b, hasLength(1));
      expect(b.single.volume, 0);
    });

    test('an integer price is widened, not truncated', () {
      expect(parseCandles([bar(1, c: 105)]).single.close, 105.0);
    });
  });

  group('normaliseBars', () {
    // TradingView drops out-of-order bars without complaint, so this is not
    // cosmetic: unsorted input yields a chart with invisible holes.
    test('sorts ascending by time', () {
      final out = normaliseBars([
        parseCandles([bar(3)]).single,
        parseCandles([bar(1)]).single,
        parseCandles([bar(2)]).single,
      ]);
      expect(out.map((c) => c.time).toList(), [1, 2, 3]);
    });

    test('drops duplicate timestamps, keeping the first', () {
      final out = normaliseBars([
        parseCandles([bar(1, c: 105)]).single,
        parseCandles([bar(1, c: 999)]).single,
      ]);
      expect(out, hasLength(1));
      expect(out.single.close, 105.0, reason: 'the first of a duplicate wins');
    });

    test('an empty list stays empty', () {
      expect(normaliseBars(const []), isEmpty);
    });
  });

  group('seriesChanged', () {
    final a = parseCandles([bar(1), bar(2), bar(3)]);

    test('identical series are unchanged', () {
      expect(seriesChanged(a, List.of(a)), isFalse);
    });

    test('a different length counts as changed', () {
      expect(seriesChanged(a, parseCandles([bar(1)])), isTrue);
    });

    test('a different first bar counts as changed', () {
      expect(seriesChanged(a, parseCandles([bar(9), bar(2), bar(3)])), isTrue);
    });

    test('a different last bar counts as changed', () {
      expect(seriesChanged(a, parseCandles([bar(1), bar(2), bar(9)])), isTrue);
    });

    // O(1) by design: comparing 2000 bars on every rebuild is what makes a
    // chart feel like it jumps. Shape equality is the cheap sufficient test.
    test('equal shape with different closes is treated as unchanged', () {
      final b = parseCandles([bar(1, c: 1), bar(2, c: 2), bar(3, c: 3)]);
      expect(seriesChanged(a, b), isFalse);
    });

    test('two empty series are unchanged', () {
      expect(seriesChanged(const [], const []), isFalse);
    });
  });

  group('CandlestickChart without the web bundle', () {
    testWidgets('explains itself instead of throwing', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: CandlestickChart(candles: parseCandles([bar(1)]))),
      ));
      expect(find.textContaining('web build'), findsOneWidget);
    });

    testWidgets('says so when there are simply no bars', (t) async {
      await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: CandlestickChart(candles: [])),
      ));
      expect(find.text('No bars to chart.'), findsOneWidget);
    });

    test('chartsAvailable is false off the web', () {
      expect(chartsAvailable, isFalse);
    });
  });

  group('ChartPage', () {
    testWidgets('starts empty and invites a symbol', (t) async {
      _serve({'candles': []});
      await t.pumpWidget(_app());
      expect(find.textContaining('Pick a symbol'), findsOneWidget);
    });

    testWidgets('renders bars and the range summary', (t) async {
      _serve({
        'symbol': 'RELIANCE.NS',
        'display': 'RELIANCE',
        'source': 'yfinance',
        'is_synthetic': false,
        'warning': null,
        'candles': [bar(1000, c: 100.0), bar(2000, c: 150.0)],
      });
      await t.pumpWidget(_app());
      await t.tap(find.widgetWithText(RunButton, 'Chart'));
      await t.pumpAndSettle();

      expect(find.text('150.00'), findsOneWidget, reason: 'last close shown');
      expect(find.textContaining('+50.00'), findsOneWidget);
      expect(find.text('2 bars'), findsNothing);
      expect(find.textContaining('2 bars'), findsOneWidget);
      expect(find.textContaining('SYNTHETIC'), findsNothing);
    });

    // The single most important assertion in this file.
    testWidgets('synthetic data is labelled, loudly', (t) async {
      _serve({
        'display': 'RELIANCE',
        'source': 'synthetic',
        'is_synthetic': true,
        'warning': 'SYNTHETIC DATA',
        'candles': [bar(1000)],
      });
      await t.pumpWidget(_app());
      await t.tap(find.widgetWithText(RunButton, 'Chart'));
      await t.pumpAndSettle();

      expect(find.textContaining('SYNTHETIC DATA'), findsWidgets);
      expect(find.textContaining('not real'), findsOneWidget);
      expect(find.textContaining('no relationship to any'), findsOneWidget);
    });

    testWidgets('a transport failure becomes a retryable error', (t) async {
      api = Api(client: MockClient((_) async => throw Exception('offline')));
      await t.pumpWidget(_app());
      await t.tap(find.widgetWithText(RunButton, 'Chart'));
      await t.pumpAndSettle();

      expect(find.textContaining('Cannot reach the backend'), findsOneWidget);
      expect(find.textContaining('Start it with'), findsOneWidget);
    });

    testWidgets('a 422 shows the server message', (t) async {
      api = Api(
        client: MockClient(
          (_) async => http.Response(
            '{"detail":"no price data available for ZZZ"}',
            422,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await t.pumpWidget(_app());
      await t.tap(find.widgetWithText(RunButton, 'Chart'));
      await t.pumpAndSettle();

      expect(find.textContaining('no price data available'), findsOneWidget);
    });

    testWidgets('a 200 with no bars is empty, not an error', (t) async {
      _serve({'display': 'RELIANCE', 'is_synthetic': false, 'candles': []});
      await t.pumpWidget(_app());
      await t.tap(find.widgetWithText(RunButton, 'Chart'));
      await t.pumpAndSettle();

      expect(find.textContaining('No bars'), findsOneWidget);
    });

    testWidgets('malformed bars are dropped without crashing', (t) async {
      _serve({
        'display': 'RELIANCE',
        'is_synthetic': false,
        'candles': [
          bar(1000),
          {'time': 2000, 'close': 105.0},
          'junk',
          null
        ],
      });
      await t.pumpWidget(_app());
      await t.tap(find.widgetWithText(RunButton, 'Chart'));
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.textContaining('1 bars'), findsOneWidget);
    });

    testWidgets('out-of-order bars are repaired, not silently dropped',
        (t) async {
      _serve({
        'display': 'RELIANCE',
        'is_synthetic': false,
        'candles': [
          bar(3000, c: 105.0),
          bar(1000, c: 100.0),
          bar(2000, c: 102.0)
        ],
      });
      await t.pumpWidget(_app());
      await t.tap(find.widgetWithText(RunButton, 'Chart'));
      await t.pumpAndSettle();

      expect(find.textContaining('3 bars'), findsOneWidget);
      expect(find.text('105.00'), findsOneWidget,
          reason: 'the header shows the newest bar, which only holds once the '
              'series has been sorted');
      expect(find.textContaining('+5.00'), findsOneWidget,
          reason: 'delta runs from the earliest close to the newest');
    });

    testWidgets('an empty symbol is refused without a request', (t) async {
      _serve({
        'candles': [bar(1000)]
      });
      await t.pumpWidget(_app());

      await t.enterText(find.widgetWithText(TextField, 'RELIANCE'), '');
      await t.tap(find.widgetWithText(RunButton, 'Chart'));
      await t.pumpAndSettle();

      expect(find.text('Type a symbol first.'), findsOneWidget);
    });

    testWidgets('an unknown symbol is reported honestly', (t) async {
      _serve({
        'query': 'ZZZZ',
        'count': 0,
        'items': [],
        'note': 'Not in the built-in universe. You can still chart any symbol '
            'directly; it just will not be name-checked.',
      });
      await t.pumpWidget(_app());

      await t.enterText(find.widgetWithText(TextField, 'Search NSE'), 'ZZZZ');
      await t.pumpAndSettle();

      expect(find.textContaining('1 bar'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });
}
