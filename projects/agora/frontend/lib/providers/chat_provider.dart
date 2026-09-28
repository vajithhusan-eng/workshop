import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message_model.dart';
import '../models/chat_room.dart';
import '../models/session_model.dart';
import '../models/agent_model.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

// Chat State
class ChatState {
  final List<MessageModel> messages;
  final bool isTyping;
  final String? typingAgentId;
  final bool isConnected;
  final String? error;
  final Map<String, dynamic> agentResponses;
  final String? currentSessionId;

  const ChatState({
    this.messages = const [],
    this.isTyping = false,
    this.typingAgentId,
    this.isConnected = false,
    this.error,
    this.agentResponses = const {},
    this.currentSessionId,
  });

  ChatState copyWith({
    List<MessageModel>? messages,
    bool? isTyping,
    String? typingAgentId,
    bool? isConnected,
    String? error,
    Map<String, dynamic>? agentResponses,
    String? currentSessionId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      typingAgentId: typingAgentId ?? this.typingAgentId,
      isConnected: isConnected ?? this.isConnected,
      error: error,
      agentResponses: agentResponses ?? this.agentResponses,
      currentSessionId: currentSessionId,
    );
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>(
  (ref) => ChatNotifier(
    ref.read(storageServiceProvider),
    ref.read(websocketServiceProvider.notifier),
    ref,
  ),
);

class ChatNotifier extends StateNotifier<ChatState> {
  final StorageService _storageService;
  final WebSocketNotifier _websocketNotifier;
  final Ref _ref;

  ChatNotifier(this._storageService, this._websocketNotifier, this._ref)
    : super(const ChatState());

  void setMessages(List<MessageModel> messages) {
    state = state.copyWith(messages: messages);
  }

  void addMessage(MessageModel message) {
    final messages = [...state.messages, message];
    state = state.copyWith(messages: messages);
    _persistMessages(messages);
  }

  void addMessages(List<MessageModel> messages) {
    final allMessages = [...state.messages, ...messages];
    state = state.copyWith(messages: allMessages);
    _persistMessages(allMessages);
  }

  void setTyping(bool isTyping, {String? agentId}) {
    state = state.copyWith(isTyping: isTyping, typingAgentId: agentId);
  }

  void setConnected(bool connected) {
    state = state.copyWith(isConnected: connected);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void clearMessages() {
    state = state.copyWith(
      messages: [],
      isTyping: false,
      typingAgentId: null,
      error: null,
      currentSessionId: null,
    );
  }

  void addAgentResponse(String agentId, String content) {
    final responses = Map<String, dynamic>.from(state.agentResponses);
    responses[agentId] = content;
    state = state.copyWith(agentResponses: responses);
  }

  void setCurrentSessionId(String? sessionId) {
    state = state.copyWith(currentSessionId: sessionId);
  }

  Future<void> sendMessage(String sessionId, String content) async {
    final message = MessageModel.create(
      sessionId: sessionId,
      agentId: 'user',
      content: content,
      type: AppConstants.messageTypeUser,
      role: AppConstants.messageTypeUser,
    );
    addMessage(message);

    // Send via WebSocket
    _websocketNotifier.sendMessage(AppConstants.wsEventMessage, {
      'session_id': sessionId,
      'content': content,
      'agent_id': 'user',
    });
  }

  void handleIncomingMessage(Map<String, dynamic> data) {
    try {
      final sessionId = data['session_id'] as String?;
      final agentId = data['agent_id'] as String? ?? 'agent';
      final content = data['content'] as String? ?? '';
      final messageType =
          data['type'] as String? ?? AppConstants.messageTypeAgent;

      final message = MessageModel.create(
        sessionId: sessionId ?? state.currentSessionId ?? '',
        agentId: agentId,
        content: content,
        type: messageType,
        role: messageType,
      );
      addMessage(message);
    } catch (e) {
      // Handle parse errors
    }
  }

  List<MessageModel> get messagesForSession {
    return state.messages;
  }

  List<MessageModel> get userMessages =>
      state.messages.where((m) => m.isUser).toList();

  List<MessageModel> get agentMessages =>
      state.messages.where((m) => m.isAgent).toList();

  Future<void> _persistMessages(List<MessageModel> messages) async {
    try {
      await _storageService.saveMessages(messages);
    } catch (e) {
      // Silently handle storage errors
    }
  }
}

// Selected chat room provider
final chatStateProvider = Provider<ChatState>((ref) {
  return ref.watch(chatProvider);
});

final messagesProvider = Provider<List<MessageModel>>((ref) {
  return ref.watch(chatProvider).messages;
});

final isTypingProvider = Provider<bool>((ref) {
  return ref.watch(chatProvider).isTyping;
});

final currentSessionIdProvider = Provider<String?>((ref) {
  return ref.watch(chatProvider).currentSessionId;
});
