import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Story App';
  static const String appVersion = '1.0.0';
  static const String apiBaseUrl = 'http://localhost:8000/api/v1';
  static const String wsBaseUrl = 'ws://localhost:8000/ws';
  static const int connectTimeoutSeconds = 30;
  static const int retryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Colors
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color accentColor = Color(0xFFFF6B6B);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);

  // Agent Colors
  static const List<Color> agentColors = [
    Color(0xFF6C63FF),
    Color(0xFF03DAC6),
    Color(0xFFFF6B6B),
    Color(0xFFFFC107),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFFFF9800),
  ];

  // Storage Keys
  static const String storageKeySessions = 'sessions';
  static const String storageKeyAgents = 'agents';
  static const String storageKeySettings = 'settings';
  static const String storageKeyAuthToken = 'auth_token';

  // Session Status
  static const String statusActive = 'active';
  static const String statusArchived = 'archived';
  static const String statusCompleted = 'completed';
  static const String statusPending = 'pending';

  // Agent Types
  static const String agentTypePlanner = 'planner';
  static const String agentTypeWriter = 'writer';
  static const String agentTypeEditor = 'editor';
  static const String agentTypeReviewer = 'reviewer';
  static const String agentTypeIllustrator = 'illustrator';

  // Message Types
  static const String messageTypeUser = 'user';
  static const String messageTypeAgent = 'agent';
  static const String messageTypeSystem = 'system';
  static const String messageTypeTool = 'tool';

  // WebSocket Events
  static const String wsEventConnect = 'connect';
  static const String wsEventDisconnect = 'disconnect';
  static const String wsEventMessage = 'message';
  static const String wsEventAgentUpdate = 'agent_update';
  static const String wsEventSessionUpdate = 'session_update';
  static const String wsEventTyping = 'typing';
  static const String wsEventError = 'error';
}

class RouteNames {
  static const String home = '/';
  static const String chat = '/chat';
  static const String sessionDetail = '/session/:id';
  static const String settings = '/settings';
  static const String agentConfig = '/agents';
}
