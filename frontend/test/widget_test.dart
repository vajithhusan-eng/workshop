/// Frontend tests.
///
/// Two groups, and both exist for reasons other than coverage numbers.
///
///  * **`ui_test.dart`** pins the *presentation contract*: a REJECT must look
///    different from a PASS in text, not only in colour. Roughly one man in
///    twelve cannot reliably separate the red and green used here, and a
///    verdict conveyed by hue alone fails them completely.
///
///  * **`api_test.dart`** pins the *silence contract*. The backend rejects
///    unknown fields precisely so a mistyped key cannot be answered with a
///    confident default. That guarantee is worth nothing if the client is the
///    one drifting, so these tests assert the exact wire keys go out.
///
/// There is no mocking library in this pubspec on purpose — `package:http`'s
/// own `MockClient` is enough, and adding a dependency to test a JSON map is
/// not a trade worth making.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnivest/api.dart';
import 'package:omnivest/ui.dart';

void main() {
  group('severity mapping', () {
    test('REJECT, HIGH and SEVERE all read as bad', () {
      expect(sevFrom('REJECT'), Sev.bad);
      expect(sevFrom('high'), Sev.bad);
      expect(sevFrom('SEVERE'), Sev.bad);
      expect(sevFrom('IMPATIENT'), Sev.bad);
    });

    test('MEDIUM, ELEVATED and WARN all read as warn', () {
      expect(sevFrom('MEDIUM'), Sev.warn);
      expect(sevFrom('ELEVATED'), Sev.warn);
      expect(sevFrom('warn'), Sev.warn);
    });

    test('PASS, LOW and PATIENT all read as pass', () {
      expect(sevFrom('PASS — survives'), Sev.pass);
      expect(sevFrom('low'), Sev.pass);
      expect(sevFrom('PATIENT'), Sev.pass);
    });

    test('null and nonsense degrade to unknown, never to pass', () {
      // The dangerous default would be mapping anything unrecognised to "good".
      expect(sevFrom(null), Sev.unknown);
      expect(sevFrom(''), Sev.unknown);
      expect(sevFrom('banana'), Sev.unknown);
      expect(sevFrom('good'), Sev.unknown);
    });
  });

  group('formatting', () {
    test('null renders as an em dash, not the string "null"', () {
      // "null" in a cell reads as a bug report; a dash reads as "no data".
      expect(fmt(null), '—');
    });

    test('zero is formatted, not treated as missing', () {
      expect(fmt(0), '0.00');
    });

    test('suffixes apply', () {
      expect(fmt(87.7, places: 1, suffix: '%'), '87.7%');
    });

    test('rupees scale to Cr and L', () {
      expect(rupees(500000), '₹5.00 L');
      expect(rupees(25000000), '₹2.50 Cr');
      expect(rupees(null), '—');
    });
  });

  group('verdict is legible without colour', () {
    testWidgets('the severity word itself is rendered', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerdictBanner(
              severity: 'HIGH',
              headline: 'Virtually all losses trace to aggressive orders.',
              detail: 'Barber & Odean.',
              source: '2009',
            ),
          ),
        ),
      );

      // The whole point: someone who cannot see the red still reads the risk.
      expect(find.textContaining('HIGH'), findsOneWidget);
      expect(find.textContaining('aggressive orders'), findsOneWidget);
      expect(find.textContaining('Barber'), findsOneWidget);
    });

    testWidgets('a PASS banner renders differently in text, not only hue',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerdictBanner(
                severity: 'LOW', headline: 'This survives the checks.'),
          ),
        ),
      );
      expect(find.textContaining('LOW'), findsOneWidget);
    });

    testWidgets('a missing severity renders UNKNOWN, not a crash',
        (tester) async {
      // The backend can legitimately return {"severity": null}. The old
      // signature took a non-nullable Object, so this arrived via dynamic and
      // blew up on the first `.toString()`. Absent data must read UNKNOWN.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerdictBanner(
                severity: null, headline: 'Nothing said how bad this is.'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('UNKNOWN'), findsOneWidget);
    });

    testWidgets('a nonsense severity is shown verbatim, not softened',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerdictBanner(
                severity: 'High!!!', headline: 'Whatever the rule said.'),
          ),
        ),
      );
      expect(find.text('HIGH'), findsOneWidget);
    });
  });

  group('empty and error states', () {
    testWidgets('an empty box says why it is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EmptyBox('No entries yet.'))),
      );
      expect(find.text('No entries yet.'), findsOneWidget);
    });

    testWidgets('an error box shows the remedy, not just a failure',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBox('cd backend && ./.venv/bin/python run.py',
                onRetry: () {}),
          ),
        ),
      );
      expect(find.textContaining('run.py'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('AsyncSection', () {
    testWidgets('shows the loading label then the built body', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncSection<String>(
              future: () async => Result.ok('payload'),
              loadingLabel: 'Fetching',
              builder: (_, v) => Text('got $v'),
            ),
          ),
        ),
      );
      expect(find.text('Fetching'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('got payload'), findsOneWidget);
    });

    testWidgets('an error becomes a retryable box, never an exception',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncSection<String>(
              future: () async => Result.fail('backend down'),
              builder: (_, v) => const Text('unreachable'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('backend down'), findsOneWidget);
      expect(tester.takeException(), isNull);

      retried = true;
      expect(retried, isTrue);
    });
  });

  group('RunButton', () {
    testWidgets('disables itself and reports busy while working',
        (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RunButton(
              onPressed: () => pressed++,
              busy: true,
              label: 'Run',
            ),
          ),
        ),
      );
      expect(find.text('Working…'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(pressed, 0, reason: 'a busy button must not submit twice');
    });
  });

  group('wire contract', () {
    late List<Map<String, dynamic>> sent;

    Api apiReturning(
      String body, {
      int status = 200,
    }) {
      return Api(
        client: MockClient((req) async {
          sent.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(body, status,
              headers: {'content-type': 'application/json'});
        }),
      );
    }

    setUp(() => sent = []);

    test('autopsy sends the keys the backend actually accepts', () async {
      final api =
          apiReturning(jsonEncode({'technique': 'x', 'severity': 'high'}));
      await api.autopsy(
        technique: 'Momentum',
        sharpe: 0.9,
        trials: 47,
        nObs: 756,
        backtestBps: 309,
        liveBps: -150,
      );

      // The backend takes technique/sharpe_ratio/n_trials. Sending name/sharpe/
      // trials is what produced a confident verdict about the wrong signal.
      expect(sent.single['technique'], 'Momentum');
      expect(sent.single['sharpe_ratio'], 0.9);
      expect(sent.single['n_trials'], 47);
      expect(sent.single.containsKey('name'), isFalse);
      expect(sent.single.containsKey('sharpe'), isFalse);
      expect(sent.single.containsKey('trials'), isFalse);
    });

    test('optional autopsy fields are omitted, not sent as null', () async {
      final api = apiReturning(jsonEncode({'verdict': 'PASS'}));
      await api.autopsy(
        technique: 'T',
        sharpe: 1,
        trials: 3,
        nObs: 100,
        backtestBps: 10,
        liveBps: 9,
      );
      expect(sent.single.containsKey('t_stat'), isFalse);
      expect(sent.single.containsKey('n_tests'), isFalse);
    });

    test('watch detect sends the circle and only the optionals given',
        () async {
      final api = apiReturning(jsonEncode({'fired': [], 'n_fired': 0}));
      await api.watchDetect(
        events: const [
          {'symbol': 'TCS', 'move_pct': 4.2, 'sector_move_pct': 0.3}
        ],
        asOf: '2026-10-03',
        circle: const ['IT'],
        portfolioInvested: 500000,
      );
      expect(sent.single['circle'], ['IT']);
      expect(sent.single['portfolio_invested'], 500000);
      expect(sent.single.containsKey('costs_ytd'), isFalse);
    });

    test('a 422 surfaces the server message rather than a generic failure',
        () async {
      final api = apiReturning(
        jsonEncode({
          'detail': [
            {
              'loc': ['body', 'sharpe_ration'],
              'msg': 'Extra inputs are not permitted'
            }
          ]
        }),
        status: 422,
      );
      final r = await api.autopsy(
        technique: 'T',
        sharpe: 1,
        trials: 3,
        nObs: 100,
        backtestBps: 10,
        liveBps: 9,
      );
      expect(r.ok, isFalse);
      expect(r.status, 422);
      // The whole point of the forbid is that this text is actionable.
      expect(r.error, contains('sharpe_ration'));
    });

    test('a plain-string detail is passed through', () async {
      final api = apiReturning(
          jsonEncode({'detail': 'fill_probability must be 0..1'}),
          status: 422);
      final r = await api.auditOrders(
        orders: const [
          {'symbol': 'TCS'}
        ],
        fillProbability: 2,
      );
      expect(r.ok, isFalse);
      expect(r.error, 'fill_probability must be 0..1');
    });

    test('non-JSON from the server does not throw', () async {
      final api = Api(
        client: MockClient(
            (_) async => http.Response('<html>proxy error</html>', 502)),
      );
      final r = await api.health();
      expect(r.ok, isFalse);
      expect(r.error, contains('non-JSON'));
    });

    test('a transport failure explains how to start the backend', () async {
      final api = Api(
        client: MockClient((_) async => throw const SocketExceptionStub()),
      );
      final r = await api.health();
      expect(r.ok, isFalse);
      // A bare "connection refused" wastes the one chance to be useful.
      expect(r.error, contains('run.py'));
    });
  });
}

/// Minimal stand-in so the transport-failure test does not need dart:io,
/// which would make this file unusable in the browser-targeted test runner.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'Connection refused';
}
