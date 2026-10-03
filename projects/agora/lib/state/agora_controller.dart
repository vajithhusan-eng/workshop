import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../data/database.dart' as db;
import '../data/session_repository.dart';

/// How a stored message is drawn. The bytes never change — only the lens.
enum ViewMode {
  raw('Raw', 'The exact stored bytes, in a monospace face.'),
  rendered('Rendered', 'The reply as Markdown, the way the site shows it.'),
  plain('Plain', 'Markdown markers removed, for reading straight through.');

  const ViewMode(this.label, this.blurb);
  final String label;
  final String blurb;
}

/// App-wide state. One controller, one live session — which is exactly the
/// locked decision: Agora runs a single council at a time.
class AgoraController extends ChangeNotifier {
  AgoraController(this.repo);

  final SessionRepository repo;

  // ---------------------------------------------------------------- listings
  List<db.Session> sessions = <db.Session>[];
  bool showArchived = false;

  String? selectedId;
  List<db.SessionAgent> seats = <db.SessionAgent>[];
  List<db.Agent> agents = <db.Agent>[];
  List<db.Message> transcript = <db.Message>[];

  db.Session? get current {
    if (selectedId == null) return null;
    for (final s in sessions) {
      if (s.id == selectedId) return s;
    }
    return null;
  }

  db.Agent? agentFor(String agentId) {
    for (final a in agents) {
      if (a.id == agentId) return a;
    }
    return null;
  }

  db.SessionAgent? seatFor(String agentId) {
    for (final s in seats) {
      if (s.agentId == agentId) return s;
    }
    return null;
  }

  db.SessionAgent? get leaderSeat {
    for (final s in seats) {
      if (s.isLeader) return s;
    }
    return null;
  }

  Color colorOf(String agentId) {
    final a = agentFor(agentId);
    return a == null ? const Color(0xFF8B98A8) : Color(a.colorValue);
  }

  String nameOf(String agentId) => agentFor(agentId)?.displayName ?? 'unknown';

  // ------------------------------------------------------------------ streams
  StreamSubscription<void>? _sessionsSub;
  StreamSubscription<void>? _seatsSub;
  StreamSubscription<void>? _messagesSub;
  StreamSubscription<void>? _agentsSub;

  void start() {
    _sessionsSub = repo.watchSessions(includeArchived: true).listen((rows) {
      sessions = rows;
      if (selectedId != null && !rows.any((s) => s.id == selectedId)) {
        select(null);
      }
      notifyListeners();
    });
    _agentsSub = repo.watchAgents().listen((rows) {
      agents = rows;
      notifyListeners();
    });
  }

  /// Switching sessions tears down the previous subscriptions first: a stale
  /// transcript from the last project is worse than a blank one.
  void select(String? id) {
    if (selectedId == id) return;
    selectedId = id;
    seats = <db.SessionAgent>[];
    transcript = <db.Message>[];
    _seatsSub?.cancel();
    _messagesSub?.cancel();
    _seatsSub = null;
    _messagesSub = null;
    if (id != null) {
      _seatsSub = repo.watchSeats(id).listen((rows) {
        seats = rows;
        notifyListeners();
      });
      _messagesSub = repo.watchMessages(id).listen((rows) {
        transcript = rows;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionsSub?.cancel();
    _seatsSub?.cancel();
    _messagesSub?.cancel();
    _agentsSub?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- view options
  final Map<String, ViewMode> _perMessage = <String, ViewMode>{};
  ViewMode _defaultView = ViewMode.rendered;

  ViewMode viewFor(String messageId) => _perMessage[messageId] ?? _defaultView;

  setDefaultView(ViewMode v) {
    _defaultView = v;
    notifyListeners();
  }

  void cycleView(String messageId) {
    final order = ViewMode.values;
    final next = order[(order.indexOf(viewFor(messageId)) + 1) % order.length];
    _perMessage[messageId] = next;
    notifyListeners();
  }

  void resetViews() {
    _perMessage.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------------ search
  String _query = '';
  String get query => _query;
  List<db.Message> results = <db.Message>[];
  bool searching = false;

  Future<void> search(String q) async {
    _query = q;
    if (q.trim().isEmpty || selectedId == null) {
      results = <db.Message>[];
      searching = false;
      notifyListeners();
      return;
    }
    searching = true;
    notifyListeners();
    results = await repo.search(selectedId!, q.trim());
    searching = false;
    notifyListeners();
  }

  void clearSearch() {
    _query = '';
    results = <db.Message>[];
    notifyListeners();
  }

  // --------------------------------------------------------------- mutations
  String? _lastError;
  String? get lastError => _lastError;

  Future<void> _guard(Future<void> Function() body) async {
    try {
      _lastError = null;
      await body();
    } on Object catch (e) {
      _lastError = '$e';
    }
    notifyListeners();
  }

  Future<void> newSession({required String prompt, required String title}) {
    return _guard(() async {
      final id = await repo.createSession(
        title: title,
        prompt: prompt,
        seats: const <SeatSpec>[
          SeatSpec(
            kind: 'chatgpt',
            displayName: 'ChatGPT',
            colorValue: 0xFF10A37F,
            url: 'https://chatgpt.com',
            adapterVersion: '1',
            isLeader: true,
          ),
          SeatSpec(
            kind: 'gemini',
            displayName: 'Gemini',
            colorValue: 0xFF4285F4,
            url: 'https://gemini.google.com',
            adapterVersion: '1',
          ),
          SeatSpec(
            kind: 'deepseek',
            displayName: 'DeepSeek',
            colorValue: 0xFF4D6BFE,
            url: 'https://chat.deepseek.com',
            adapterVersion: '1',
          ),
        ],
      );
      select(id);
    });
  }

  void rename(String id, String title) =>
      _guard(() => repo.renameSession(id, title));

  void setArchived(String id, bool value) =>
      _guard(() => repo.updateSession(id, archived: value));

  void delete(String id) => _guard(() async {
    if (selectedId == id) select(null);
    await repo.deleteSession(id);
  });

  void promoteLeader(String agentId) =>
      _guard(() => repo.setLeader(selectedId!, agentId));

  void kick(String agentId) =>
      _guard(() => repo.removeSeat(selectedId!, agentId));

  void setSeatStatus(String agentId, String status) =>
      _guard(() => repo.setSeatStatus(selectedId!, agentId, status));

  /// The user's own prompt, stored in the vault like any other turn.
  Future<void> recordUserTurn(String text) => _guard(() async {
    final s = current;
    if (s == null) return;
    await repo.record(
      sessionId: s.id,
      round: s.round,
      agentId: s.leaderId ?? 'user',
      role: 'user',
      direction: 'out',
      rawText: text,
    );
  });

  /// A Decision Record is just the export, rendered. The UI writes the file.
  Future<Map<String, dynamic>> export() async {
    if (selectedId == null) return <String, dynamic>{};
    return repo.exportSession(selectedId!);
  }

  void toggleShowArchived() {
    showArchived = !showArchived;
    notifyListeners();
  }
}
