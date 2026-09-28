import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session_model.dart';
import '../models/agent_model.dart';
import '../models/message_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class ChatRoom {
  final SessionModel session;
  final List<AgentModel> agents;
  final List<MessageModel> messages;
  final bool isConnected;
  final bool isTyping;
  final String? typingAgentId;
  final Map<String, dynamic> state;

  ChatRoom({
    required this.session,
    required this.agents,
    required this.messages,
    this.isConnected = false,
    this.isTyping = false,
    this.typingAgentId,
    this.state = const {},
  });

  ChatRoom copyWith({
    SessionModel? session,
    List<AgentModel>? agents,
    List<MessageModel>? messages,
    bool? isConnected,
    bool? isTyping,
    String? typingAgentId,
    Map<String, dynamic>? state,
  }) {
    return ChatRoom(
      session: session ?? this.session,
      agents: agents ?? this.agents,
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      isTyping: isTyping ?? this.isTyping,
      typingAgentId: typingAgentId ?? this.typingAgentId,
      state: state ?? this.state,
    );
  }

  List<MessageModel> get sortedMessages {
    return List<MessageModel>.from(messages)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<MessageModel> get userMessages =>
      messages.where((m) => m.isUser).toList();

  List<MessageModel> get agentMessages =>
      messages.where((m) => m.isAgent).toList();

  MessageModel? get lastMessage => messages.isEmpty ? null : messages.last;

  int get messageCount => messages.length;

  double get averageAgentConfidence {
    if (agentMessages.isEmpty) return 0.0;
    final total = agentMessages
        .where((m) => m.confidence != null)
        .fold<double>(0, (sum, m) => sum + (m.confidence ?? 0));
    return total / agentMessages.length;
  }

  Map<String, dynamic> toJson() {
    return {
      'session': session.toJson(),
      'agents': agents.map((a) => a.toJson()).toList(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'is_connected': isConnected,
      'is_typing': isTyping,
      'typing_agent_id': typingAgentId,
      'state': state,
    };
  }

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      session: SessionModel.fromJson(json['session'] ?? {}),
      agents:
          (json['agents'] as List?)
              ?.map((a) => AgentModel.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      messages:
          (json['messages'] as List?)
              ?.map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      isConnected: json['is_connected'] ?? false,
      isTyping: json['is_typing'] ?? false,
      typingAgentId: json['typing_agent_id'],
      state: Map<String, dynamic>.from(json['state'] ?? {}),
    );
  }

  static ChatRoom empty(SessionModel session) {
    return ChatRoom(
      session: session,
      agents: [],
      messages: [],
      isConnected: false,
      isTyping: false,
    );
  }
}
