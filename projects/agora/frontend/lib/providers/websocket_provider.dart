import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/websocket_service.dart';
import '../utils/constants.dart';

// WebSocket State
class WebSocketState {
  final bool isConnected;
  final String? connectionId;
  final String? lastError;
  final DateTime? lastConnected;
  final int retryCount;
  final Map<String, dynamic> pendingMessages;

  const WebSocketState({
    this.isConnected = false,
    this.connectionId,
    this.lastError,
    this.lastConnected,
    this.retryCount = 0,
    this.pendingMessages = const {},
  });

  WebSocketState copyWith({
    bool? isConnected,
    String? connectionId,
    String? lastError,
    DateTime? lastConnected,
    int? retryCount,
    Map<String, dynamic>? pendingMessages,
  }) {
    return WebSocketState(
      isConnected: isConnected ?? this.isConnected,
      connectionId: connectionId,
      lastError: lastError,
      lastConnected: lastConnected,
      retryCount: retryCount ?? this.retryCount,
      pendingMessages: pendingMessages ?? this.pendingMessages,
    );
  }
}

final websocketServiceProvider =
    StateNotifierProvider<WebSocketNotifier, WebSocketState>(
      (ref) => WebSocketNotifier(ref),
    );

class WebSocketNotifier extends StateNotifier<WebSocketState> {
  WebSocketService? _websocketService;

  WebSocketNotifier(this._websocketService) : super(const WebSocketState());

  Future<void> connect() async {
    state = state.copyWith(lastError: null);
    try {
      await _websocketService?.connect();
      state = state.copyWith(
        isConnected: true,
        lastConnected: DateTime.now(),
        retryCount: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isConnected: false,
        lastError: e.toString(),
        retryCount: state.retryCount + 1,
      );
    }
  }

  void disconnect() {
    _websocketService?.disconnect();
    state = state.copyWith(isConnected: false, connectionId: null);
  }

  void sendMessage(String event, Map<String, dynamic> data) {
    _websocketService?.send(event, data);
  }

  void reconnect() async {
    disconnect();
    await Future.delayed(const Duration(seconds: 2));
    await connect();
  }

  void clearError() {
    state = state.copyWith(lastError: null);
  }
}

// WebSocket providers for consumption
final websocketConnectedProvider = Provider<bool>((ref) {
  return ref.watch(websocketServiceProvider).isConnected;
});

final websocketStateProvider = Provider<WebSocketState>((ref) {
  return ref.watch(websocketServiceProvider);
});
