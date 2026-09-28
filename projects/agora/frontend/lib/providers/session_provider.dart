import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session_model.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

// Session State
class SessionState {
  final List<SessionModel> sessions;
  final SessionModel? currentSession;
  final bool isLoading;
  final String? error;

  const SessionState({
    this.sessions = const [],
    this.currentSession,
    this.isLoading = false,
    this.error,
  });

  SessionState copyWith({
    List<SessionModel>? sessions,
    SessionModel? currentSession,
    bool? isLoading,
    String? error,
  }) {
    return SessionState(
      sessions: sessions ?? this.sessions,
      currentSession: currentSession ?? this.currentSession,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Session Provider
final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>(
  (ref) => SessionNotifier(ref.read(storageServiceProvider)),
);

class SessionNotifier extends StateNotifier<SessionState> {
  final StorageService _storageService;

  SessionNotifier(this._storageService) : super(const SessionState()) {
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    state = state.copyWith(isLoading: true);
    try {
      final sessions = await _storageService.getSessions();
      state = state.copyWith(sessions: sessions, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load sessions',
        isLoading: false,
      );
    }
  }

  Future<void> createSession(String title, {String? description}) async {
    final session = SessionModel.create(title: title, description: description);
    final sessions = [...state.sessions, session];
    await _storageService.saveSessions(sessions);
    state = state.copyWith(sessions: sessions, currentSession: session);
  }

  Future<void> updateSession(
    String id,
    String title, {
    String? description,
  }) async {
    final sessions = state.sessions.map((s) {
      if (s.id == id) {
        return s.copyWith(
          title: title,
          description: description ?? s.description,
        );
      }
      return s;
    }).toList();
    await _storageService.saveSessions(sessions);
    state = state.copyWith(sessions: sessions);
  }

  void deleteSession(String id) async {
    final sessions = state.sessions.where((s) => s.id != id).toList();
    await _storageService.saveSessions(sessions);
    state = state.copyWith(
      sessions: sessions,
      currentSession: state.currentSession?.id == id
          ? null
          : state.currentSession,
    );
  }

  void selectSession(String? id) {
    final session = id != null
        ? state.sessions.firstWhere(
            (s) => s.id == id,
            orElse: () => state.sessions.first,
          )
        : null;
    state = state.copyWith(currentSession: session);
  }

  void addAgentToSession(String sessionId, String agentId) {
    final sessions = state.sessions.map((s) {
      if (s.id == sessionId && !s.agentIds.contains(agentId)) {
        return s.copyWith(agentIds: [...s.agentIds, agentId]);
      }
      return s;
    }).toList();
    _storageService.saveSessions(sessions);
    state = state.copyWith(sessions: sessions);
  }

  void removeAgentFromSession(String sessionId, String agentId) {
    final sessions = state.sessions.map((s) {
      if (s.id == sessionId) {
        return s.copyWith(
          agentIds: s.agentIds.where((a) => a != agentId).toList(),
        );
      }
      return s;
    }).toList();
    _storageService.saveSessions(sessions);
    state = state.copyWith(sessions: sessions);
  }

  List<SessionModel> get activeSessions => state.sessions
      .where((s) => s.status == AppConstants.statusActive)
      .toList();

  List<SessionModel> get recentSessions =>
      state.sessions..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

// Selected session provider
final selectedSessionProvider = Provider<SessionModel?>((ref) {
  return ref.watch(sessionProvider).currentSession;
});

final sessionsListProvider = Provider<List<SessionModel>>((ref) {
  return ref.watch(sessionProvider).sessions;
});

final isSessionLoadingProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider).isLoading;
});
