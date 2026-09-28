import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../logging.dart';

/// A CDP event, scoped either to the browser or to an attached target session.
class CdpEvent {
  const CdpEvent({required this.method, required this.params, this.sessionId});

  final String method;
  final Map<String, dynamic> params;
  final String? sessionId;

  @override
  String toString() => 'CdpEvent($method, session=${sessionId ?? "browser"})';
}

class CdpException implements Exception {
  CdpException(this.method, this.code, this.message, {this.data});

  final String method;
  final int? code;
  final String? message;
  final Object? data;

  @override
  String toString() {
    final m = message ?? 'no message';
    final c = code == null ? '' : ' ($code)';
    return 'CdpException: $method$c: $m';
  }
}

class CdpTimeout implements Exception {
  CdpTimeout(this.method, this.timeout);
  final String method;
  final Duration timeout;

  @override
  String toString() =>
      'CdpTimeout: $method did not respond within ${timeout.inSeconds}s';
}

/// Chrome DevTools Protocol client.
///
/// Agora drives the **system Chrome** over a WebSocket. This class is the
/// transport: it correlates request/response by id, fans events out to
/// subscribers, and guarantees no future is left dangling.
class CdpClient {
  CdpClient._(this._channel, {required this.endpoint});

  final WebSocketChannel _channel;

  /// Human-readable endpoint, e.g. `ws://127.0.0.1:9222/devtools/browser/…`.
  final String endpoint;

  /// Populated from `Browser.getVersion` during [connect].
  String browserVersion = 'unknown';

  final _pending = <int, _PendingCall>{};
  final _eventController = StreamController<CdpEvent>.broadcast();
  final _log = Logger('cdp');

  int _nextId = 1;
  bool _closed = false;

  Stream<CdpEvent> get events => _eventController.stream;
  bool get isClosed => _closed;

  /// Connect to a browser-level CDP endpoint.
  ///
  /// [wsUrl] is the `webSocketDebuggerUrl` reported by `GET /json/version`.
  static Future<CdpClient> connect(
    Uri wsUrl, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final log = Logger('cdp');
    log.i('connecting -> $wsUrl');

    final channel = WebSocketChannel.connect(wsUrl);
    try {
      // Without awaiting `ready`, the first frame can be written into a socket
      // whose handshake has not completed, which Chrome silently drops.
      await channel.ready.timeout(timeout);
    } on Object catch (e) {
      log.e('handshake failed', e);
      unawaited(channel.sink.close());
      rethrow;
    }

    final client = CdpClient._(channel, endpoint: wsUrl.toString());
    client._listen();

    // Probe so a stale or wrong endpoint fails loudly here rather than
    // mysteriously on the first real command.
    final version = await client.sendMap(
      'Browser.getVersion',
      timeout: timeout,
    );
    client.browserVersion = (version['product'] as String?) ?? 'unknown';
    log.i('connected: ${client.browserVersion}');
    return client;
  }

  void _listen() {
    _channel.stream.listen(
      _onData,
      onError: (Object e, StackTrace s) => _log.e('socket error', e, s),
      onDone: () {
        if (!_closed) _log.w('socket closed by peer');
        _failAllPending('connection closed');
      },
      cancelOnError: false,
    );
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } on Object catch (e) {
      _log.w('non-JSON frame dropped', e);
      return;
    }

    final id = msg['id'];
    if (id is int) {
      final call = _pending.remove(id);
      if (call == null) {
        _log.w('response for unknown id $id');
        return;
      }
      call.timer.cancel();
      final error = msg['error'];
      if (error is Map) {
        call.completer.completeError(
          CdpException(
            call.method,
            error['code'] as int?,
            error['message'] as String?,
            data: error['data'],
          ),
        );
      } else {
        call.completer.complete(msg['result'] ?? const <String, dynamic>{});
      }
      return;
    }

    final method = msg['method'];
    if (method is String && !_eventController.isClosed) {
      _eventController.add(
        CdpEvent(
          method: method,
          params:
              (msg['params'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
          sessionId: msg['sessionId'] as String?,
        ),
      );
    }
  }

  void _failAllPending(String reason) {
    if (_pending.isEmpty) return;
    final snapshot = Map<int, _PendingCall>.of(_pending);
    _pending.clear();
    for (final call in snapshot.values) {
      call.timer.cancel();
      if (!call.completer.isCompleted) {
        call.completer.completeError(CdpException(call.method, null, reason));
      }
    }
  }

  /// Invoke a CDP command.
  ///
  /// [sessionId] targets an attached page session; omit it for browser-level
  /// commands such as `Target.createTarget`.
  Future<dynamic> send(
    String method, {
    Map<String, dynamic>? params,
    String? sessionId,
    Duration timeout = const Duration(seconds: 30),
  }) {
    final call = _PendingCall(method, Completer<dynamic>());
    if (_closed) {
      return Future.error(CdpException(method, null, 'client is closed'));
    }
    call.id = _nextId++;

    call.timer = Timer(timeout, () {
      // Guard the race: the response may land in the same turn as the timeout.
      if (_pending.remove(call.id) != null && !call.completer.isCompleted) {
        call.completer.completeError(CdpTimeout(method, timeout));
      }
    });

    _pending[call.id] = call;
    _write({
      'id': call.id,
      'method': method,
      if (params != null && params.isNotEmpty) 'params': params,
      if (sessionId != null) 'sessionId': sessionId,
    });

    return call.completer.future.then(
      (v) {
        _log.d('$method -> ${_truncate(jsonEncode(v))}');
        return v;
      },
      onError: (Object e) {
        _log.d('$method !! $e');
        throw e;
      },
    );
  }

  /// Send a command and return its result as a map (CDP always returns objects).
  Future<Map<String, dynamic>> sendMap(
    String method, {
    Map<String, dynamic>? params,
    String? sessionId,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final r = await send(
      method,
      params: params,
      sessionId: sessionId,
      timeout: timeout,
    );
    return (r as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  }

  void _write(Map<String, dynamic> message) {
    try {
      _channel.sink.add(jsonEncode(message));
    } on Object catch (e) {
      _log.e('write failed for ${message['method']}', e);
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _failAllPending('client closed');
    try {
      await _channel.sink.close();
    } on Object catch (e) {
      _log.w('error closing sink', e);
    }
    if (!_eventController.isClosed) await _eventController.close();
    _log.i('disconnected');
  }

  static String _truncate(String s, [int max = 240]) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}

class _PendingCall {
  _PendingCall(this.method, this.completer);

  final String method;
  final Completer<dynamic> completer;
  late final Timer timer;
  late final int id;
}
