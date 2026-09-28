import 'package:uuid/uuid.dart';

import '../utils/constants.dart';

class MessageModel {
  final String id;
  final String sessionId;
  final String agentId;
  final String role; // user, agent, system
  final String content;
  final String type;
  final Map<String, dynamic> metadata;
  final List<String> toolCalls;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;
  final double? confidence;
  final bool isFromBrowser;

  MessageModel({
    required this.id,
    required this.sessionId,
    required this.agentId,
    this.role = AppConstants.messageTypeUser,
    required this.content,
    this.type = AppConstants.messageTypeUser,
    this.metadata = const {},
    this.toolCalls = const [],
    DateTime? createdAt,
    this.updatedAt,
    this.isEdited = false,
    this.confidence,
    this.isFromBrowser = false,
  }) : id = id,
       createdAt = createdAt ?? DateTime.now();

  factory MessageModel.create({
    required String sessionId,
    required String agentId,
    required String content,
    String? role,
    String? type,
    Map<String, dynamic>? metadata,
    List<String>? toolCalls,
    double? confidence,
    bool? isFromBrowser,
  }) {
    return MessageModel(
      id: const Uuid().v4(),
      sessionId: sessionId,
      agentId: agentId,
      role: role ?? AppConstants.messageTypeUser,
      content: content,
      type: type ?? AppConstants.messageTypeUser,
      metadata: metadata ?? {},
      toolCalls: toolCalls ?? [],
      confidence: confidence,
      isFromBrowser: isFromBrowser ?? false,
    );
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? const Uuid().v4(),
      sessionId: json['session_id'] ?? '',
      agentId: json['agent_id'] ?? '',
      role: json['role'] ?? AppConstants.messageTypeUser,
      content: json['content'] ?? '',
      type: json['type'] ?? AppConstants.messageTypeUser,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      toolCalls: List<String>.from(json['tool_calls'] ?? []),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      isEdited: json['is_edited'] ?? false,
      confidence: (json['confidence'] as num?)?.toDouble(),
      isFromBrowser: json['is_from_browser'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'agent_id': agentId,
      'role': role,
      'content': content,
      'type': type,
      'metadata': metadata,
      'tool_calls': toolCalls,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_edited': isEdited,
      'confidence': confidence,
      'is_from_browser': isFromBrowser,
    };
  }

  MessageModel copyWith({
    String? content,
    String? role,
    String? type,
    Map<String, dynamic>? metadata,
    List<String>? toolCalls,
    DateTime? updatedAt,
    bool? isEdited,
    double? confidence,
    bool? isFromBrowser,
  }) {
    return MessageModel(
      id: id,
      sessionId: sessionId,
      agentId: agentId,
      role: role ?? this.role,
      content: content ?? this.content,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
      toolCalls: toolCalls ?? this.toolCalls,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isEdited: isEdited ?? this.isEdited,
      confidence: confidence,
      isFromBrowser: isFromBrowser ?? this.isFromBrowser,
    );
  }

  bool get isUser =>
      role == AppConstants.messageTypeUser ||
      type == AppConstants.messageTypeUser;
  bool get isAgent =>
      role == AppConstants.messageTypeAgent ||
      type == AppConstants.messageTypeAgent;
  bool get isSystem =>
      role == AppConstants.messageTypeSystem ||
      type == AppConstants.messageTypeSystem;
  bool get isTool => type == AppConstants.messageTypeTool;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MessageModel(id: $id, role: $role, agentId: $agentId)';
}
