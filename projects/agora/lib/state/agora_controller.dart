import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../data/database.dart' as db;
import '../core/council/council_runner.dart';
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

  // ------------------------------------------------------------- the council

  /// The live run, if any. Null whenever no council is in progress — one
  /// session at a time is a locked decision, and this field is where it is
  /// enforced rather than merely documented.
  CouncilRunner? _runner;
  CouncilRunner? get runner => _runner;

  bool get councilRunning => _runner?.isRunning ?? false;

  String? _councilError;
  String? get councilError => _councilError;

  String? _councilStop;
  String? get councilStop => _councilStop;

  List<String> _councilNotes = const <String>[];
  List<String> get councilNotes => _councilNotes;

  Timer? _noteTimer;

  /// Convenes the selected session around its opening prompt.
  ///
  /// Returns false and sets `councilError` when a precondition fails — no
  /// leader, no seats, no session. A precondition failure is never thrown at
  /// the caller, because the UI has to show it, not crash on it.
  Future<bool> startCouncil({String? prompt}) async {
    final sessionId = selectedId;
    if (sessionId == null) {
      _councilError = 'Select a session before convening a council.';
      notifyListeners();
      return false;
    }
    if (councilRunning) return false; // already convening; not an error

    _councilError = null;
    _councilStop = null;
    _councilNotes = const <String>[];

    final leader = leaderSeat;
    if (leader == null) {
      _councilError = 'Promote a leader before convening the council.';
      notifyListeners();
      return false;
    }
    // A leader seat whose agent row has gone missing is as unusable as no
    // leader at all, and is the more confusing failure of the two.
    final leaderKind = agentFor(leader.agentId)?.kind;
    if (leaderKind == null) {
      _councilError = 'That leader seat no longer points at a known agent.';
      notifyListeners();
      return false;
    }

    // Promotion of `leader` is lost inside the collection body, so capture the
    // id rather than re-reading the getter.
    final leaderId = leader.agentId;
    final bindings = <SeatBinding>[
      for (final seat in seats)
        if (agentFor(seat.agentId)?.kind case final kind?)
          SeatBinding(
            kind: kind,
            displayName: agentFor(seat.agentId)?.displayName ?? kind,
            roleCard: seat.roleCard,
            isLeader: seat.agentId == leaderId,
          ),
    ];
    if (bindings.isEmpty) {
      _councilError = 'A council needs at least one seat.';
      notifyListeners();
      return false;
    }

    final kindToAgentId = <String, String>{
      for (final seat in seats)
        if (agentFor(seat.agentId)?.kind case final k?) k: seat.agentId,
    };

    final session = await repo.session(sessionId);
    final runner = CouncilRunner(
      repo: repo,
      sessionId: sessionId,
      kindToAgentId: kindToAgentId,
    );
    _runner = runner;
    notifyListeners();

    // The runner reports progress as plain strings; poll them rather than
    // plumbing a second stream through the engine, which must stay storage- and
    // UI-free so it stays testable with fakes.
    var seen = 0;
    _noteTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (runner.notes.length == seen) return;
      seen = runner.notes.length;
      _councilNotes = runner.notes;
      notifyListeners();
    });

    try {
      final outcome = await runner.run(
        seats: bindings,
        leaderKind: leaderKind,
        prompt: (prompt ?? session?.prompt ?? '').trim(),
        maxRounds: session?.maxRounds ?? 12,
      );
      _councilStop = outcome.stop.name;
    } on CouncilBlocked catch (e) {
      _councilError = e.reason;
    } on Object catch (e) {
      _councilError = e.toString();
    } finally {
      _noteTimer?.cancel();
      _noteTimer = null;
      _councilNotes = runner.notes;
      _runner = null;
      notifyListeners();
    }
    return _councilError == null;
  }

  /// Hard-stops the debate. The orchestrator records the stop as a user
  /// interrupt so the session shows why it ended rather than just ending.
  void interruptCouncil() => _runner?.interrupt();
}
