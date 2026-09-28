import 'package:uuid/uuid.dart';

import '../utils/constants.dart';

class AgentModel {
  final String id;
  final String name;
  final String description;
  final String type;
  final String avatar;
  final String systemPrompt;
  final Map<String, dynamic> config;
  final bool isActive;
  final int order;
  final Map<String, dynamic> capabilities;
  final DateTime createdAt;
  final DateTime updatedAt;

  AgentModel({
    required this.id,
    required this.name,
    this.description = '',
    this.type = AppConstants.agentTypePlanner,
    this.avatar = '',
    this.systemPrompt = '',
    this.config = const {},
    this.isActive = true,
    this.order = 0,
    this.capabilities = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory AgentModel.create({
    required String name,
    String? type,
    String? description,
    String? systemPrompt,
    Map<String, dynamic>? config,
    List<String>? capabilities,
  }) {
    return AgentModel(
      id: const Uuid().v4(),
      name: name,
      description: description ?? '',
      type: type ?? AppConstants.agentTypePlanner,
      avatar: '',
      systemPrompt: systemPrompt ?? '',
      config: config ?? {},
      capabilities: capabilities ?? [],
    );
  }

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      id: json['id'] ?? const Uuid().v4(),
      name: json['name'] ?? 'Unnamed Agent',
      description: json['description'] ?? '',
      type: json['type'] ?? AppConstants.agentTypePlanner,
      avatar: json['avatar'] ?? '',
      systemPrompt: json['system_prompt'] ?? '',
      config: Map<String, dynamic>.from(json['config'] ?? {}),
      isActive: json['is_active'] ?? true,
      order: json['order'] ?? 0,
      capabilities: List<String>.from(json['capabilities'] ?? []),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'avatar': avatar,
      'system_prompt': systemPrompt,
      'config': config,
      'is_active': isActive,
      'order': order,
      'capabilities': capabilities,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AgentModel copyWith({
    String? name,
    String? description,
    String? type,
    String? avatar,
    String? systemPrompt,
    Map<String, dynamic>? config,
    bool? isActive,
    int? order,
    Map<String, dynamic>? capabilities,
    DateTime? updatedAt,
  }) {
    return AgentModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      avatar: avatar ?? this.avatar,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      config: config ?? this.config,
      isActive: isActive ?? this.isActive,
      order: order ?? this.order,
      capabilities: capabilities ?? this.capabilities,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AgentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AgentModel(id: $id, name: $name, type: $type)';
}
