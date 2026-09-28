import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/session_model.dart';
import '../models/agent_model.dart';
import '../models/message_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

// Storage service provider for Riverpod
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService.instance;
});

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _sessionsBox = 'sessions';
  static const String _agentsBox = 'agents';
  static const String _messagesBox = 'messages';
  static const String _settingsBox = 'settings';

  static Box<SessionModel>? _sessions;
  static Box<AgentModel>? _agents;
  static Box<MessageModel>? _messages;
  static Box? _settings;

  static StorageService get instance => _instance;

  Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SessionModelAdapter());
    Hive.registerAdapter(AgentModelAdapter());
    Hive.registerAdapter(MessageModelAdapter());

    _sessions = await Hive.openBox<SessionModel>(_sessionsBox);
    _agents = await Hive.openBox<AgentModel>(_agentsBox);
    _messages = await Hive.openBox<MessageModel>(_messagesBox);
    _settings = await Hive.openBox(_settingsBox);
  }

  Future<void> _ensureInitialized() async {
    if (_sessions == null) {
      await initialize();
    }
  }

  // Sessions
  Future<List<SessionModel>> getSessions() async {
    await _ensureInitialized();
    return (_sessions?.values.toList() ?? []).cast<SessionModel>();
  }

  Future<void> saveSessions(List<SessionModel> sessions) async {
    await _ensureInitialized();
    await _sessions?.clear();
    for (final session in sessions) {
      await _sessions?.put(session.id, session);
    }
  }

  Future<void> saveSession(SessionModel session) async {
    await _ensureInitialized();
    await _sessions?.put(session.id, session);
  }

  Future<void> deleteSession(String id) async {
    await _ensureInitialized();
    await _sessions?.delete(id);
  }

  // Agents
  Future<List<AgentModel>> getAgents() async {
    await _ensureInitialized();
    return (_agents?.values.toList() ?? []).cast<AgentModel>();
  }

  Future<void> saveAgents(List<AgentModel> agents) async {
    await _ensureInitialized();
    await _agents?.clear();
    for (final agent in agents) {
      await _agents?.put(agent.id, agent);
    }
  }

  Future<void> saveAgent(AgentModel agent) async {
    await _ensureInitialized();
    await _agents?.put(agent.id, agent);
  }

  Future<void> deleteAgent(String id) async {
    await _ensureInitialized();
    await _agents?.delete(id);
  }

  // Messages
  Future<List<MessageModel>> getMessages() async {
    await _ensureInitialized();
    return (_messages?.values.toList() ?? []).cast<MessageModel>();
  }

  Future<void> saveMessages(List<MessageModel> messages) async {
    await _ensureInitialized();
    await _messages?.clear();
    for (final message in messages) {
      await _messages?.put(message.id, message);
    }
  }

  Future<void> saveMessage(MessageModel message) async {
    await _ensureInitialized();
    await _messages?.put(message.id, message);
  }

  Future<void> clearMessages() async {
    await _ensureInitialized();
    await _messages?.clear();
  }

  // Settings
  Future<void> saveSetting(String key, dynamic value) async {
    await _ensureInitialized();
    await _settings?.put(key, jsonEncode(value));
  }

  Future<dynamic> getSetting(String key) async {
    await _ensureInitialized();
    final value = _settings?.get(key);
    if (value is String) {
      try {
        return jsonDecode(value);
      } catch (e) {
        return value;
      }
    }
    return value;
  }

  Future<void> deleteSetting(String key) async {
    await _ensureInitialized();
    await _settings?.delete(key);
  }
}

// Hive Adapters
class SessionModelAdapter extends TypeAdapter<SessionModel> {
  @override
  final int typeId = 0;

  @override
  SessionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return SessionModel(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      status: fields[3] as String,
      agentIds: (fields[4] as List).cast<String>(),
      messageIds: (fields[5] as List).cast<String>(),
      metadata: Map<String, dynamic>.from(fields[6] as Map),
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      createdBy: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SessionModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.agentIds)
      ..writeByte(5)
      ..write(obj.messageIds)
      ..writeByte(6)
      ..write(obj.metadata)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.createdBy);
  }
}

class AgentModelAdapter extends TypeAdapter<AgentModel> {
  @override
  final int typeId = 1;

  @override
  AgentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return AgentModel(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      type: fields[3] as String,
      avatar: fields[4] as String,
      systemPrompt: fields[5] as String,
      config: Map<String, dynamic>.from(fields[6] as Map),
      isActive: fields[7] as bool,
      order: fields[8] as int,
      capabilities: (fields[9] as List).cast<String>(),
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AgentModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.avatar)
      ..writeByte(5)
      ..write(obj.systemPrompt)
      ..writeByte(6)
      ..write(obj.config)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.order)
      ..writeByte(9)
      ..write(obj.capabilities)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt);
  }
}

class MessageModelAdapter extends TypeAdapter<MessageModel> {
  @override
  final int typeId = 2;

  @override
  MessageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return MessageModel(
      id: fields[0] as String,
      sessionId: fields[1] as String,
      agentId: fields[2] as String,
      content: fields[3] as String,
      type: fields[4] as String,
      metadata: Map<String, dynamic>.from(fields[5] as Map),
      toolCalls: (fields[6] as List).cast<String>(),
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime?,
      isEdited: fields[9] as bool,
      confidence: (fields[10] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, MessageModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.agentId)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.metadata)
      ..writeByte(6)
      ..write(obj.toolCalls)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.isEdited)
      ..writeByte(10)
      ..write(obj.confidence);
  }
}
