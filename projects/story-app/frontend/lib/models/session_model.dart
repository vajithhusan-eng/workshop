import 'package:uuid/uuid.dart';

import '../utils/constants.dart';

class SessionModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final List<String> agentIds;
  final List<String> messageIds;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  SessionModel({
    required this.id,
    required this.title,
    this.description = '',
    this.status = AppConstants.statusPending,
    required this.agentIds,
    required this.messageIds,
    this.metadata = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy,
  }) : id = id,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory SessionModel.create({
    required String title,
    List<String>? agentIds,
    String? description,
    String? createdBy,
  }) {
    return SessionModel(
      id: const Uuid().v4(),
      title: title,
      description: description ?? '',
      agentIds: agentIds ?? [],
      messageIds: [],
      createdBy: createdBy,
    );
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] ?? const Uuid().v4(),
      title: json['title'] ?? 'Untitled Session',
      description: json['description'] ?? '',
      status: json['status'] ?? AppConstants.statusPending,
      agentIds: List<String>.from(json['agent_ids'] ?? []),
      messageIds: List<String>.from(json['message_ids'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      createdBy: json['created_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'agent_ids': agentIds,
      'message_ids': messageIds,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  SessionModel copyWith({
    String? title,
    String? description,
    String? status,
    List<String>? agentIds,
    List<String>? messageIds,
    Map<String, dynamic>? metadata,
    DateTime? updatedAt,
  }) {
    return SessionModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      agentIds: agentIds ?? this.agentIds,
      messageIds: messageIds ?? this.messageIds,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      createdBy: createdBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SessionModel(id: $id, title: $title, status: $status)';
}
