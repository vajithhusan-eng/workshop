/// Thin, typed client for the OMNIVEST backend.
///
/// Two rules this file exists to enforce:
///
///  1. **Never throw into a widget.** Every method returns a [Result] so a
///     backend that is down renders as a readable message instead of a red
///     error box and a dead tab.
///  2. **Never let the server answer from defaults we did not send.** The
///     backend rejects unknown fields (422) precisely so a typo cannot be
///     answered with plausible-looking numbers. That guarantee is worthless if
///     the client is sloppy, so payloads are built explicitly and a 422 is
///     surfaced verbatim rather than swallowed.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Base URL. Overridable for the Android emulator, where 127.0.0.1 is the
/// emulator itself and the host is 10.0.2.2.
const String apiBase = String.fromEnvironment(
  'OMNIVEST_API',
  defaultValue: 'http://127.0.0.1:8123/api',
);

/// A successful or failed call. Deliberately not an exception.
class Result<T> {
  Result.ok(this.value)
      : error = null,
        status = 200;
  Result.fail(this.error, [this.status = 0]) : value = null;

  final T? value;
  final String? error;
  final int status;

  bool get ok => error == null;
}

/// Turns a response into a [Result], preferring the server's own `detail`
/// text because pydantic's 422 body is the most useful thing we can show a
/// user who mistyped a field.
Result<T> _decode<T>(http.Response r, T Function(dynamic) parse) {
  dynamic body;
  try {
    body = jsonDecode(r.body);
  } catch (_) {
    return Result.fail(
      'Backend returned non-JSON (HTTP ${r.statusCode})',
      r.statusCode,
    );
  }
  if (r.statusCode != 200) {
    return Result.fail(_describe(body, r.statusCode), r.statusCode);
  }
  try {
    return Result.ok(parse(body));
  } catch (e) {
    return Result.fail(
      'Response did not match what the UI expects: $e',
      r.statusCode,
    );
  }
}

String _describe(dynamic body, int status) {
  final detail = body is Map ? body['detail'] : null;
  if (detail is String) return detail;
  if (detail is List && detail.isNotEmpty) {
    final parts = <String>[];
    for (final item in detail) {
      if (item is Map) {
        final loc = (item['loc'] as List?)?.whereType<String>().join('.') ?? '';
        final msg = item['msg'] ?? 'invalid';
        parts.add(loc.isEmpty ? '$msg' : '$loc — $msg');
      }
    }
    if (parts.isNotEmpty) return 'Rejected (422): ${parts.join('; ')}';
  }
  return 'Request failed (HTTP $status)';
}

Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);

class Api {
  Api({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 12);

  Uri _u(String path) => Uri.parse('$apiBase$path');

  Future<Result<T>> get<T>(String path, T Function(dynamic) parse) async {
    try {
      final r = await _client.get(_u(path)).timeout(_timeout);
      return _decode(r, parse);
    } catch (e) {
      return Result.fail(_offline(e));
    }
  }

  Future<Result<T>> post<T>(
    String path,
    Map<String, dynamic> payload,
    T Function(dynamic) parse,
  ) async {
    try {
      final r = await _client
          .post(
            _u(path),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
      return _decode(r, parse);
    } catch (e) {
      return Result.fail(_offline(e));
    }
  }

  String _offline(Object e) => 'Cannot reach the backend at $apiBase.\n'
      'Start it with:  cd backend && ./.venv/bin/python run.py\n\n'
      '($e)';

  // ── reads ────────────────────────────────────────────────────────────────

  Future<Result<Map<String, dynamic>>> health() =>
      get('/health', (v) => _map(v));

  Future<Result<Map<String, dynamic>>> sebi() =>
      get('/sebi/summary', (v) => _map(v));

  Future<Result<List<dynamic>>> techniques() =>
      get('/techniques', (v) => (v as Map)['items'] as List<dynamic>);

  Future<Result<Map<String, dynamic>>> consensus() =>
      get('/canon/consensus', (v) => _map(v));

  Future<Result<Map<String, dynamic>>> debates() =>
      get('/canon/debates', (v) => _map(v));

  Future<Result<Map<String, dynamic>>> watchRules() =>
      get('/watch/rules', (v) => _map(v));

  Future<Result<Map<String, dynamic>>> journalStats() =>
      get('/journal/stats', (v) => _map(v));

  Future<Result<List<dynamic>>> journalEntries() =>
      get('/journal/entries', (v) => (v as Map)['items'] as List<dynamic>);

  Future<Result<Map<String, dynamic>>> crowding({
    double comomentum = 0.5,
    double vol = 0.5,
  }) =>
      get(
        '/forensics/crowding?comomentum=$comomentum&vol_percentile=$vol',
        (v) => _map(v),
      );

  // ── writes ───────────────────────────────────────────────────────────────

  /// Autopsy payload keys mirror the backend's `forensics.autopsy()`
  /// signature exactly. They are not interchangeable synonyms: the backend
  /// rejects unknown fields, so a drifting name is a 422, not a silent
  /// default.
  Future<Result<Map<String, dynamic>>> autopsy({
    required String technique,
    required double sharpe,
    required int trials,
    required int nObs,
    required int backtestBps,
    required int liveBps,
    double skew = 0,
    double kurtosis = 3,
    double? tStat,
    int? nTests,
  }) =>
      post(
          '/forensics/autopsy',
          {
            'technique': technique,
            'sharpe_ratio': sharpe,
            'n_trials': trials,
            'n_obs': nObs,
            'backtest_excess_bps': backtestBps,
            'live_excess_bps': liveBps,
            'skew': skew,
            'kurtosis': kurtosis,
            if (tStat != null) 't_stat': tStat,
            if (nTests != null) 'n_tests': nTests,
          },
          (v) => _map(v));

  Future<Result<Map<String, dynamic>>> watchDetect({
    List<Map<String, dynamic>> events = const [],
    String asOf = '',
    List<String> circle = const [],
    List<Map<String, dynamic>> journal = const [],
    List<Map<String, dynamic>> positions = const [],
    double? portfolioInvested,
    double? costsYtd,
  }) =>
      post(
          '/watch/detect',
          {
            'events': events,
            'as_of': asOf,
            'circle': circle,
            'journal': journal,
            'positions': positions,
            if (portfolioInvested != null)
              'portfolio_invested': portfolioInvested,
            if (costsYtd != null) 'costs_ytd': costsYtd,
          },
          (v) => _map(v));

  Future<Result<Map<String, dynamic>>> brief({
    String name = 'Investor',
    List<Map<String, dynamic>> events = const [],
  }) =>
      post('/brief/daily', {'name': name, 'events': events}, (v) => _map(v));

  Future<Result<Map<String, dynamic>>> addJournalEntry({
    required String symbol,
    required String why,
    String side = 'buy',
    double qty = 0,
    double price = 0,
    String tag = 'value',
    String invalidation = '',
  }) =>
      post(
          '/journal/entries',
          {
            'symbol': symbol,
            'side': side,
            'qty': qty,
            'price': price,
            'tag': tag,
            'why': why,
            'invalidation': invalidation,
          },
          (v) => _map(v));

  /// Order keys are the ones `execution.classify_order()` reads:
  /// symbol, side, order_type, bid, ask, reference_price, limit_price,
  /// fill_price.
  Future<Result<Map<String, dynamic>>> auditOrders({
    required List<Map<String, dynamic>> orders,
    double? portfolioValue,
    double? ordersPerYear,
    double fillProbability = 0.30,
  }) =>
      post(
          '/execution/audit',
          {
            'orders': orders,
            if (portfolioValue != null) 'portfolio_value': portfolioValue,
            if (ordersPerYear != null) 'orders_per_year': ordersPerYear,
            'fill_probability': fillProbability,
          },
          (v) => _map(v));

  Future<Result<Map<String, dynamic>>> classifyOrder(
    Map<String, dynamic> order,
  ) =>
      post('/execution/classify', {'order': order}, (v) => _map(v));

  Future<Result<Map<String, dynamic>>> pbo({
    required List<List<double>> returnsMatrix,
    String name = 'screen',
    int nSplits = 8,
  }) =>
      post(
          '/forensics/pbo',
          {
            'name': name,
            'returns_matrix': returnsMatrix,
            'n_splits': nSplits,
          },
          (v) => _map(v));
}
