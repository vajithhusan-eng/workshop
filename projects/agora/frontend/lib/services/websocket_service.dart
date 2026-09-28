import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../utils/constants.dart';
import '../utils/helpers.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final Map<String, Completer<void>> _pendingCompleters = {};
  bool _isManualDisconnect = false;
  final void Function(String, Map<String, dynamic>)? _onMessageCallback;
  final void Function(String)? _onDisconnectCallback;
  final void Function(String)? _onErrorCallback;

  WebSocketService({
    void Function(String, Map<String, dynamic>)? onMessage,
    void Function(String)? onDisconnect,
    void Function(String)? onError,
  }) : _onMessageCallback = onMessage,
       _onDisconnectCallback = onDisconnect,
       _onErrorCallback = onError;

  bool get isConnected => _channel?.sink.isClosed == false;

  Future<void> connect() async {
    try {
      final wsUrl = AppConstants.wsBaseUrl;
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // Wait for connection confirmation
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      throw Exception('WebSocket connection failed: $e');
    }
  }

  void disconnect() {
    _isManualDisconnect = true;
    _subscription?.cancel();
    _channel?.sink.close(ws_status.goingAway);
    _channel = null;
    _pendingCompleters.clear();
    _isManualDisconnect = false;
  }

  void send(String event, Map<String, dynamic> data) {
    if (_channel == null || _channel?.sink.isClosed == true) {
      throw Exception('WebSocket not connected');
    }

    final message = jsonEncode({
      'event': event,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });

    _channel!.sink.add(message);
  }

  void sendMessage(String event, Map<String, dynamic> data) {
    send(event, data);
  }

  Stream<dynamic> get stream => _channel?.stream ?? const Stream.empty();

  Future<void> sendWithAck(String event, Map<String, dynamic> data) async {
    final completer = Completer<void>();
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    _pendingCompleters[messageId] = completer;

    send(event, {...data, 'message_id': messageId});

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingCompleters.remove(messageId);
        throw TimeoutException('Acknowledgment timed out');
      },
    );
  }

  void _onMessage(dynamic message) {
    try {
      final data = message is String ? jsonDecode(message) : message;
      final eventType = data['event'] as String?;
      final eventData = data['data'];

      _onMessageCallback?.call(eventType ?? '', eventData ?? {});
    } catch (e) {
      // Handle parse errors
    }
  }

  void _onError(dynamic error) {
    _onErrorCallback?.call(error.toString());
  }

  void _onDone() {
    if (!_isManualDisconnect) {
      _onDisconnectCallback?.call('disconnected');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _pendingCompleters.clear();
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
