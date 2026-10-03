import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// The Verbatim Vault hash lives in ../core/util/hashing.dart — defined in one
// place so the stamp written on save is the stamp re-checked on read.

/// One session = one chat = one project.
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get title =>
      text().withDefault(const Constant('Untitled session'))();

  /// The user's opening problem statement.
  TextColumn get prompt => text()();
  TextColumn get leaderId => text().nullable()();

  /// Current round number (1-based while running).
  IntColumn get round => integer().withDefault(const Constant(0))();

  /// Hard stops. These are what make "until solved" safe.
  IntColumn get maxRounds => integer().withDefault(const Constant(12))();
  IntColumn get budgetSeconds => integer().withDefault(const Constant(1800))();
  IntColumn get elapsedSeconds => integer().withDefault(const Constant(0))();

  /// 'idle' | 'running' | 'paused' | 'solved' | 'blocked' | 'failed'
  TextColumn get status => text().withDefault(const Constant('idle'))();

  /// 'delta' | 'window' | 'full' | 'scratchpad' (see ContextStrategist).
  TextColumn get contextStrategy =>
      text().withDefault(const Constant('delta'))();

  /// Template this session was created from, if any.
  TextColumn get templateId => text().nullable()();

  /// Archived sessions stay on disk and stay searchable, but drop out of the
  /// default sidebar. Hiding is not deleting.
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The catalogue of AI agents Agora can drive (one row per provider kind).
class Agents extends Table {
  TextColumn get id => text()();

  /// 'chatgpt' | 'gemini' | 'deepseek' | 'claude' | ...
  TextColumn get kind => text()();
  TextColumn get displayName => text()();

  /// Packed ARGB, e.g. 0xFF10A37F — drives the colour coding in the council.
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF78909C))();

  /// Entry point Agora navigates to.
  TextColumn get url => text()();

  /// Selector/version of the adapter this agent is pinned to.
  TextColumn get adapterVersion => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Join table: which agents participate in which session, and in what role.
class SessionAgents extends Table {
  TextColumn get sessionId => text()();
  TextColumn get agentId => text()();

  /// Role Card text (e.g. "You are a battery electrochemist. Be sceptical of
  /// optimistic cycle-life claims."). This is what stops five generalists
  /// from politely agreeing with each other.
  TextColumn get roleCard => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isLeader => boolean().withDefault(const Constant(false))();

  /// 'enabled' | 'disabled' | 'login_required' | 'error'
  TextColumn get status => text().withDefault(const Constant('enabled'))();

  /// Model label chosen on the site's own model picker, if any.
  TextColumn get modelLabel => text().nullable()();

  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sessionId, agentId};
}

/// A verbatim transcript entry. Nothing here is ever summarised or rewritten.
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  IntColumn get round => integer().withDefault(const Constant(0))();

  /// Agent id, or 'user' / 'system' / 'orchestrator'.
  TextColumn get agentId => text()();

  /// 'user' | 'agent' | 'system' | 'orchestrator'
  TextColumn get role => text()();

  /// 'in' | 'out' — whose words are these.
  TextColumn get direction => text()();

  /// The exact characters the agent produced. Source of truth.
  TextColumn get rawText => text()();

  /// The exact DOM the agent rendered, for the Raw view.
  TextColumn get rawHtml => text().nullable()();

  /// Path into AgoraPaths.vaultDir; null when screenshots are disabled.
  TextColumn get screenshotPath => text().nullable()();

  /// sha256 of [rawText]. Recomputable, so alteration is detectable.
  TextColumn get contentHash => text()();

  IntColumn get latencyMs => integer().nullable()();

  /// The context packet this reply answers, for audit.
  TextColumn get packetRef => text().nullable()();

  /// Orchestrator annotations (protocol warnings, dissent, scores) as JSON.
  TextColumn get meta => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The compiled context packet Agora sent to an agent (PromptCompiler output).
class Packets extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  IntColumn get round => integer().withDefault(const Constant(0))();
  TextColumn get targetAgentId => text()();

  /// 'delta' | 'window' | 'full' | 'scratchpad'
  TextColumn get strategy => text()();
  IntColumn get byteSize => integer().withDefault(const Constant(0))();
  TextColumn get bodyHash => text()();
  TextColumn get body => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fractal Memory: durable, project-scoped facts distilled from past rounds.
///
/// Web chat context windows are small and fixed. Instead of fighting them,
/// Agora rehydrates each round from these facts.
class AgentFacts extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();

  /// The fact, one per row, phrased so it can be re-injected verbatim.
  TextColumn get fact => text()();

  /// Which message produced it.
  TextColumn get sourceMessageId => text().nullable()();

  /// 'archivist' | 'pinned' | 'agent'
  TextColumn get origin => text().withDefault(const Constant('archivist'))();

  /// Pinned facts are never compacted away.
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Append-only action journal: the Time Machine / replay log.
class JournalEvents extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();

  /// 'launch' | 'navigate' | 'send' | 'extract' | 'round' | 'stop' | ...
  TextColumn get kind => text()();
  TextColumn get agentId => text().nullable()();

  TextColumn get payload => text().withDefault(const Constant('{}'))();
  DateTimeColumn get at => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Versioned, hot-reloadable site adapters. JSON here, not code, so a site
/// redesign is a data update and not an app release.
class Adapters extends Table {
  TextColumn get id => text()();
  TextColumn get provider => text()();
  TextColumn get version => text()();

  /// The selector document as JSON.
  TextColumn get config => text()();

  /// 'bundled' | 'user' | 'remote'
  TextColumn get source => text().withDefault(const Constant('bundled'))();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();

  DateTimeColumn get installedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-agent, per-day message counters — the quota guardrail that keeps Agora
/// inside human-pacing limits on free tiers.
class UsageCounters extends Table {
  TextColumn get agentKind => text()();

  /// Local calendar day, 'YYYY-MM-DD'.
  TextColumn get day => text()();

  IntColumn get messageCount => integer().withDefault(const Constant(0))();
  IntColumn get byteCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {agentKind, day};
}

@DriftDatabase(
  tables: [
    Sessions,
    Agents,
    SessionAgents,
    Messages,
    Packets,
    AgentFacts,
    JournalEvents,
    Adapters,
    UsageCounters,
  ],
)
class AgoraDb extends _$AgoraDb {
  AgoraDb() : super(_open());

  /// Test / sandbox constructor.
  AgoraDb.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Full-text search over the verbatim transcript.
      await customStatement(
        "CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5("
        "raw_text, content='messages', content_rowid='rowid')",
      );
      await customStatement(
        "CREATE TRIGGER messages_ai AFTER INSERT ON messages BEGIN "
        "INSERT INTO messages_fts(rowid, raw_text) VALUES (new.rowid, new.raw_text); "
        "END",
      );
    },
    onUpgrade: (m, from, to) async {
      // v1 -> v2: the sidebar gained `archived`. Additive only, so no verbatim
      // text is rewritten and no data is at risk.
      if (from < 2) {
        await m.addColumn(sessions, sessions.archived);
      }
      // Indexes for the queries the UI runs on every keystroke and every paint.
      // Safe to re-issue: SQLite treats an identical index as a no-op.
      await m.createIndex('idx_messages_session_created', messages, columns: [
        messages.sessionId,
        messages.createdAt,
      ]);
      await m.createIndex(
        'idx_messages_session_round',
        messages,
        columns: [messages.sessionId, messages.round],
      );
      await m.createIndex('idx_journal_session_at', journalEvents, columns: [
        journalEvents.sessionId,
        journalEvents.at,
      ]);
      await m.createIndex(
        'idx_usage_counters_day',
        usageCounters,
        columns: [usageCounters.day],
      );
    },
    beforeOpen: (details) async {
      // Foreign keys are off by default in SQLite.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Opens the database inside the platform's app-support directory so the
  /// transcript survives upgrades and is not buried in a temp dir.
  static QueryExecutor _open() {
    return driftDatabase(
      name: 'agora',
      native: DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }

  // ---- queries the engine needs ----

  /// Full-text search across a session's transcript.
  Future<List<Message>> searchMessages(String sessionId, String query) {
    final needle = query.replaceAll("'", "''");
    return (select(messages)..where(
          (m) => m.sessionId.equals(sessionId) & m.rawText.like('%$needle%'),
        ))
        .get();
  }

  Future<List<SessionAgent>> participantsOf(String sessionId) => (select(
    sessionAgents,
  )..where((s) => s.sessionId.equals(sessionId))).get();

  /// Round-over-round corpus used by the convergence scorer.
  Future<List<Message>> messagesInRound(String sessionId, int round) => (select(
    messages,
  )..where((m) => m.sessionId.equals(sessionId) & m.round.equals(round))).get();
}
