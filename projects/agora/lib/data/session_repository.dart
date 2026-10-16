import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../core/chrome/chrome_launcher.dart';
import '../core/orchestration/speaker_selector.dart';
import '../core/util/hashing.dart';
import 'database.dart' as db;

/// Everything Agora persists goes through this class.
///
/// The engine (orchestrator, adapters) is deliberately storage-free so it can be
/// tested with fake adapters. This is the seam: the app wires an orchestrator to
/// a repository and every message lands here, verbatim, with a hash.
class SessionRepository {
  SessionRepository(this._db, {DateTime Function()? clock, String? vaultDir})
    : _clock = clock ?? DateTime.now,
      _vaultDir = vaultDir ?? AgoraPaths.vaultDir;

  final db.AgoraDb _db;
  final DateTime Function() _clock;

  /// Screenshots land here as `vault/<sessionId>/<messageId>.png`. Evidence
  /// storage must never be able to lose a message, so writes are best-effort.
  final String _vaultDir;

  static final Map<String, int> _idCounters = <String, int>{};

  /// Sortable, collision-resistant within a process.
  static String newId(String prefix) {
    final n = (_idCounters[prefix] = (_idCounters[prefix] ?? 0) + 1);
    final us = DateTime.now().microsecondsSinceEpoch;
    return '$prefix-${us.toRadixString(36)}-${n.toRadixString(36)}';
  }

  /// 'YYYY-MM-DD' in local time — the key the daily usage cap groups by.
  static String dayKey(DateTime at) {
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${at.year}-${p2(at.month)}-${p2(at.day)}';
  }

  // ---------------------------------------------------------------- sessions

  /// A session is a project: it owns its seats, transcript, packets, facts and
  /// journal. Created in one transaction so a half-built session never exists.
  Future<String> createSession({
    String title = 'Untitled session',
    required String prompt,
    String? leaderKind,
    int maxRounds = 12,
    int budgetSeconds = 1800,
    String contextStrategy = 'delta',
    String? templateId,
    List<SeatSpec> seats = const <SeatSpec>[],
  }) async {
    final id = newId('ses');
    final now = _clock();
    String? leaderId;
    await _db.transaction(() async {
      for (final s in seats) {
        final agentId = await ensureAgent(
          kind: s.kind,
          displayName: s.displayName,
          colorValue: s.colorValue,
          url: s.url,
          adapterVersion: s.adapterVersion,
        );
        await _db
            .into(_db.sessionAgents)
            .insert(
              db.SessionAgentsCompanion.insert(
                sessionId: id,
                agentId: agentId,
                roleCard: Value(s.roleCard),
                sortOrder: Value(seats.indexOf(s)),
                isLeader: Value(s.isLeader || s.kind == leaderKind),
                modelLabel: Value(s.modelLabel),
                addedAt: now,
              ),
            );
        if (s.isLeader || s.kind == leaderKind) leaderId = agentId;
      }
      await _db
          .into(_db.sessions)
          .insert(
            db.SessionsCompanion.insert(
              id: id,
              title: Value(title),
              prompt: prompt,
              leaderId: Value(leaderId),
              maxRounds: Value(maxRounds),
              budgetSeconds: Value(budgetSeconds),
              contextStrategy: Value(contextStrategy),
              templateId: Value(templateId),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    return id;
  }

  Stream<List<db.Session>> watchSessions({bool includeArchived = false}) {
    final q = _db.select(_db.sessions)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (!includeArchived) {
      q.where((t) => t.archived.equals(false));
    }
    return q.watch();
  }

  Future<List<db.Session>> sessions({bool includeArchived = false}) async {
    final q = _db.select(_db.sessions)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (!includeArchived) q.where((t) => t.archived.equals(false));
    return q.get();
  }

  Future<db.Session?> session(String id) => (_db.select(
    _db.sessions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> renameSession(String id, String title) =>
      updateSession(id, title: title);

  Future<void> updateSession(
    String id, {
    String? title,
    String? prompt,
    String? leaderId,
    int? round,
    int? maxRounds,
    int? budgetSeconds,
    int? elapsedSeconds,
    String? status,
    String? contextStrategy,
    bool? archived,
  }) async {
    await (_db.update(_db.sessions)..where((t) => t.id.equals(id))).write(
      db.SessionsCompanion(
        title: title == null ? const Value.absent() : Value(title),
        prompt: prompt == null ? const Value.absent() : Value(prompt),
        leaderId: leaderId == null ? const Value.absent() : Value(leaderId),
        round: round == null ? const Value.absent() : Value(round),
        maxRounds: maxRounds == null ? const Value.absent() : Value(maxRounds),
        budgetSeconds: budgetSeconds == null
            ? const Value.absent()
            : Value(budgetSeconds),
        elapsedSeconds: elapsedSeconds == null
            ? const Value.absent()
            : Value(elapsedSeconds),
        status: status == null ? const Value.absent() : Value(status),
        contextStrategy: contextStrategy == null
            ? const Value.absent()
            : Value(contextStrategy),
        archived: archived == null ? const Value.absent() : Value(archived),
        updatedAt: Value(_clock()),
      ),
    );
  }

  /// There are no ON DELETE CASCADEs in the schema, so children go first,
  /// explicitly, in one transaction. Hiding is not deleting — see `archived`.
  Future<void> deleteSession(String id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.messages,
      )..where((t) => t.sessionId.equals(id))).go();
      await (_db.delete(
        _db.packets,
      )..where((t) => t.sessionId.equals(id))).go();
      await (_db.delete(
        _db.agentFacts,
      )..where((t) => t.sessionId.equals(id))).go();
      await (_db.delete(
        _db.journalEvents,
      )..where((t) => t.sessionId.equals(id))).go();
      await (_db.delete(
        _db.sessionAgents,
      )..where((t) => t.sessionId.equals(id))).go();
      await (_db.delete(_db.sessions)..where((t) => t.id.equals(id))).go();
    });
  }

  // ------------------------------------------------------------------ agents

  /// Agents are keyed by kind so a session reuses the same ChatGPT row across
  /// projects rather than multiplying identical rows.
  Future<String> ensureAgent({
    required String kind,
    required String displayName,
    required int colorValue,
    required String url,
    String? adapterVersion,
  }) async {
    final existing = await (_db.select(
      _db.agents,
    )..where((t) => t.kind.equals(kind))).getSingleOrNull();
    if (existing != null) return existing.id;
    final id = newId('agt');
    await _db
        .into(_db.agents)
        .insert(
          db.AgentsCompanion.insert(
            id: id,
            kind: kind,
            displayName: displayName,
            colorValue: Value(colorValue),
            url: url,
            adapterVersion: Value(adapterVersion),
            createdAt: _clock(),
          ),
        );
    return id;
  }

  Stream<List<db.Agent>> watchAgents() => (_db.select(
    _db.agents,
  )..orderBy([(t) => OrderingTerm.asc(t.displayName)])).watch();

  Future<List<db.Agent>> allAgents() => (_db.select(
    _db.agents,
  )..orderBy([(t) => OrderingTerm.asc(t.displayName)])).get();

  /// One seat per session is leader. Clearing first, then setting, inside a
  /// transaction, makes the invariant hold even under concurrent UI clicks.
  Future<void> setLeader(String sessionId, String agentId) async {
    await _db.transaction(() async {
      await (_db.update(_db.sessionAgents)
            ..where((t) => t.sessionId.equals(sessionId)))
          .write(const db.SessionAgentsCompanion(isLeader: Value(false)));
      await (_db.update(_db.sessionAgents)..where(
            (t) => t.sessionId.equals(sessionId) & t.agentId.equals(agentId),
          ))
          .write(const db.SessionAgentsCompanion(isLeader: Value(true)));
      await (_db.update(_db.sessions)..where((t) => t.id.equals(sessionId)))
          .write(db.SessionsCompanion(leaderId: Value(agentId)));
    });
  }

  Stream<List<db.SessionAgent>> watchSeats(String sessionId) =>
      (_db.select(_db.sessionAgents)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<List<db.SessionAgent>> seats(String sessionId) =>
      (_db.select(_db.sessionAgents)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<void> addSeat(String sessionId, SeatSpec spec) async {
    final agentId = await ensureAgent(
      kind: spec.kind,
      displayName: spec.displayName,
      colorValue: spec.colorValue,
      url: spec.url,
      adapterVersion: spec.adapterVersion,
    );
    await _db
        .into(_db.sessionAgents)
        .insertOnConflictUpdate(
          db.SessionAgentsCompanion.insert(
            sessionId: sessionId,
            agentId: agentId,
            roleCard: Value(spec.roleCard),
            isLeader: Value(spec.isLeader),
            modelLabel: Value(spec.modelLabel),
            addedAt: _clock(),
          ),
        );
  }

  Future<void> removeSeat(String sessionId, String agentId) async {
    await (_db.delete(_db.sessionAgents)..where(
          (t) => t.sessionId.equals(sessionId) & t.agentId.equals(agentId),
        ))
        .go();
  }

  Future<void> setSeatStatus(
    String sessionId,
    String agentId,
    String status,
  ) async {
    await (_db.update(_db.sessionAgents)..where(
          (t) => t.sessionId.equals(sessionId) & t.agentId.equals(agentId),
        ))
        .write(db.SessionAgentsCompanion(status: Value(status)));
  }

  /// Persists a seat's role card — §18.3's "give this seat a job". A null or
  /// empty string clears it, which is why the value is written as-is rather
  /// than rejected.
  Future<void> setSeatRoleCard(
    String sessionId,
    String agentId,
    String? roleCard,
  ) async {
    await (_db.update(_db.sessionAgents)..where(
          (t) => t.sessionId.equals(sessionId) & t.agentId.equals(agentId),
        ))
        .write(db.SessionAgentsCompanion(roleCard: Value(roleCard)));
  }

  // ---------------------------------------------------------------- messages

  /// The verbatim writer. Stores exactly what the adapter captured plus a
  /// 128-bit content hash. Nothing here trims, summarises or reformats text —
  /// that is the whole point of the Verbatim Vault.
  ///
  /// [channelId] names the §18.1 thread this message belongs to; null is the
  /// session's public thread, which is what every pre-R1 caller wrote.
  Future<db.Message> record({
    required String sessionId,
    required int round,
    required String agentId,
    required String role,
    required String direction,
    required String rawText,
    String? rawHtml,
    Uint8List? screenshot,
    int? latencyMs,
    String? packetRef,
    Map<String, dynamic>? meta,
    String? channelId,
  }) async {
    final id = newId('msg');
    String? screenshotPath;
    if (screenshot != null && screenshot.isNotEmpty) {
      try {
        final dir = Directory(p.join(_vaultDir, sessionId));
        await dir.create(recursive: true);
        final file = File(p.join(dir.path, '$id.png'));
        await file.writeAsBytes(screenshot, flush: true);
        screenshotPath = file.path;
      } on Object catch (_) {
        // Losing the screenshot must never lose the message.
        screenshotPath = null;
      }
    }
    final row = db.MessagesCompanion.insert(
      id: id,
      sessionId: sessionId,
      round: Value(round),
      agentId: agentId,
      role: role,
      direction: direction,
      rawText: rawText,
      rawHtml: Value(rawHtml),
      screenshotPath: Value(screenshotPath),
      contentHash: contentHash(rawText),
      latencyMs: Value(latencyMs),
      packetRef: Value(packetRef),
      meta: Value(meta == null ? null : jsonEncode(meta)),
      channelId: Value(channelId),
      createdAt: _clock(),
    );
    await _db.into(_db.messages).insert(row);
    return (await (_db.select(
      _db.messages,
    )..where((t) => t.id.equals(id))).getSingle());
  }

  /// Re-checks the stored hash against the stored bytes. If this ever returns
  /// false, something rewrote the vault and Agora broke its own promise.
  bool isIntact(db.Message m) => contentHash(m.rawText) == m.contentHash;

  Stream<List<db.Message>> watchMessages(String sessionId) =>
      (_db.select(_db.messages)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<List<db.Message>> messages(String sessionId) =>
      (_db.select(_db.messages)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<List<db.Message>> roundMessages(String sessionId, int round) =>
      _db.messagesInRound(sessionId, round);

  Future<List<db.Message>> search(String sessionId, String query) =>
      _db.searchMessages(sessionId, query);

  Future<int> messageCount(String sessionId) async {
    final c = _db.messages.id.count();
    final row =
        await (_db.selectOnly(_db.messages)
              ..addColumns([c])
              ..where(_db.messages.sessionId.equals(sessionId)))
            .getSingle();
    return row.read(c) ?? 0;
  }

  // ---------------------------------------------------------------- channels

  /// The two `PLAN.md` §18.1 channel kinds.
  static const String channelKindPublic = 'public';
  static const String channelKindPrivate = 'private';

  /// Every session has exactly one public thread, materialised on first use.
  /// Its id is derived from the session, so it is also stable across restarts.
  Future<db.Channel> ensurePublicChannel(String sessionId) => _ensureChannel(
    id: 'ch:$sessionId:public',
    sessionId: sessionId,
    kind: channelKindPublic,
    displayName: 'Council',
    members: const <String>[],
  );

  /// A private thread between exactly two agents. The id is symmetric
  /// ([SpeakerSelector.dmChannelKey] sorts the pair), so the same two agents
  /// always resolve to the same thread no matter who spoke first.
  Future<db.Channel> ensureDmChannel(
    String sessionId,
    String aKind,
    String bKind, {
    String? aName,
    String? bName,
  }) {
    final members = <String>[aKind, bKind]..sort();
    return _ensureChannel(
      id: 'ch:$sessionId:${SpeakerSelector.dmChannelKey(aKind, bKind)}',
      sessionId: sessionId,
      kind: channelKindPrivate,
      displayName: '${aName ?? aKind} ⇄ ${bName ?? bKind}',
      members: members,
    );
  }

  Future<db.Channel> _ensureChannel({
    required String id,
    required String sessionId,
    required String kind,
    required String displayName,
    required List<String> members,
  }) async {
    final existing = await (_db.select(
      _db.channels,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing != null) return existing;
    await _db
        .into(_db.channels)
        .insert(
          db.ChannelsCompanion.insert(
            id: id,
            sessionId: sessionId,
            kind: kind,
            displayName: displayName,
            members: Value(jsonEncode(members)),
            createdAt: _clock(),
          ),
        );
    return (await (_db.select(
      _db.channels,
    )..where((t) => t.id.equals(id))).getSingle());
  }

  Stream<List<db.Channel>> watchChannels(String sessionId) =>
      (_db.select(_db.channels)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<List<db.Channel>> channels(String sessionId) =>
      (_db.select(_db.channels)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<db.Channel?> channel(String id) => (_db.select(
    _db.channels,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Messages in one thread, oldest first. A null [channelId] reads the public
  /// thread — every message written before R1's channels.
  Stream<List<db.Message>> watchChannelMessages(String? channelId) =>
      (_db.select(_db.messages)
            ..where(
              (t) => channelId == null
                  ? t.channelId.isNull()
                  : t.channelId.equals(channelId),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<List<db.Message>> channelMessages(String? channelId) =>
      (_db.select(_db.messages)
            ..where(
              (t) => channelId == null
                  ? t.channelId.isNull()
                  : t.channelId.equals(channelId),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// How many messages a thread holds. A null [channelId] counts the public
  /// thread (the null-`channel_id` rows). Drives §18.3's unread badges — the
  /// reader's cursor is a message count, not a timestamp, because drift stores
  /// `createdAt` at whole-second granularity and two turns can share a second.
  Future<int> channelMessageCount(String? channelId) async {
    final c = _db.messages.id.count();
    final q = _db.selectOnly(_db.messages)..addColumns([c]);
    q.where(
      channelId == null
          ? _db.messages.channelId.isNull()
          : _db.messages.channelId.equals(channelId),
    );
    final row = await q.getSingle();
    return row.read(c) ?? 0;
  }

  // ----------------------------------------------------------------- packets

  Future<String> recordPacket({
    required String sessionId,
    required int round,
    required String targetAgentId,
    required String strategy,
    required String body,
  }) async {
    final id = newId('pkt');
    await _db
        .into(_db.packets)
        .insert(
          db.PacketsCompanion.insert(
            id: id,
            sessionId: sessionId,
            round: Value(round),
            targetAgentId: targetAgentId,
            strategy: strategy,
            byteSize: Value(body.length),
            bodyHash: contentHash(body),
            body: body,
            createdAt: _clock(),
          ),
        );
    return id;
  }

  Future<db.Packet?> packet(String id) => (_db.select(
    _db.packets,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  // --------------------------------------------------- fractal memory (E)

  Future<String> addFact({
    required String sessionId,
    required String fact,
    String? sourceMessageId,
    String origin = 'archivist',
    bool pinned = false,
  }) async {
    final id = newId('fct');
    await _db
        .into(_db.agentFacts)
        .insert(
          db.AgentFactsCompanion.insert(
            id: id,
            sessionId: sessionId,
            fact: fact,
            sourceMessageId: Value(sourceMessageId),
            origin: Value(origin),
            pinned: Value(pinned),
            createdAt: _clock(),
          ),
        );
    return id;
  }

  Future<List<db.AgentFact>> facts(String sessionId) =>
      (_db.select(_db.agentFacts)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Stream<List<db.AgentFact>> watchFacts(String sessionId) =>
      (_db.select(_db.agentFacts)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<void> pinFact(String id, bool pinned) async {
    await (_db.update(_db.agentFacts)..where((t) => t.id.equals(id))).write(
      db.AgentFactsCompanion(pinned: Value(pinned)),
    );
  }

  // ----------------------------------------------------------------- journal

  /// Time Machine (B5): every action the engine takes is recorded, so a run can
  /// be replayed against the Sandbox Lab without touching a real AI site.
  Future<void> journal(
    String sessionId,
    String kind, {
    String? agentId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    await _db
        .into(_db.journalEvents)
        .insert(
          db.JournalEventsCompanion.insert(
            id: newId('jrn'),
            sessionId: sessionId,
            kind: kind,
            agentId: Value(agentId),
            payload: Value(jsonEncode(payload)),
            at: _clock(),
          ),
        );
  }

  Future<List<db.JournalEvent>> journalFor(String sessionId) =>
      (_db.select(_db.journalEvents)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.at)]))
          .get();

  // ------------------------------------------------------------------- usage

  /// Insert-or-increment: the daily cap in BudgetGuard must survive restarts,
  /// otherwise a crash loop quietly blows past the limit.
  Future<void> countMessage(String agentKind, int bytes) async {
    final key = dayKey(_clock());
    final into = _db.into(_db.usageCounters);
    await into.insert(
      db.UsageCountersCompanion.insert(
        agentKind: agentKind,
        day: key,
        // Seed the row at zero; the UPDATE below does the counting, so the
        // first message of a new day is not double-counted.
        messageCount: const Value(0),
        byteCount: const Value(0),
        updatedAt: _clock(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    // Drift has no "increment", so express it as a raw upsert.
    await _db.customStatement(
      'UPDATE usage_counters SET message_count = message_count + 1, '
      'byte_count = byte_count + ?, updated_at = ? '
      'WHERE agent_kind = ? AND day = ?',
      [bytes, _clock().millisecondsSinceEpoch, agentKind, key],
    );
  }

  Future<int> sentToday(String agentKind) async {
    final c = _db.usageCounters.messageCount.sum();
    final row =
        await (_db.selectOnly(_db.usageCounters)
              ..addColumns([c])
              ..where(_db.usageCounters.agentKind.equals(agentKind)))
            .getSingleOrNull();
    if (row == null) return 0;
    return (row.read(c) ?? 0);
  }

  Future<List<db.UsageCounter>> usage() =>
      (_db.select(_db.usageCounters)..orderBy([
            (t) => OrderingTerm.desc(t.day),
            (t) => OrderingTerm.asc(t.agentKind),
          ]))
          .get();

  // ---------------------------------------------------------------- adapters

  Future<void> saveAdapter({
    required String provider,
    required String version,
    required String config,
    String source = 'user',
    bool verified = false,
  }) async {
    await _db
        .into(_db.adapters)
        .insertOnConflictUpdate(
          db.AdaptersCompanion.insert(
            id: '$provider@$version',
            provider: provider,
            version: version,
            config: config,
            source: Value(source),
            verified: Value(verified),
            installedAt: _clock(),
          ),
        );
  }

  Future<List<db.Adapter>> adapters() => _db.select(_db.adapters).get();

  Future<void> deleteAdapter(String provider) async {
    await (_db.delete(
      _db.adapters,
    )..where((t) => t.provider.equals(provider))).go();
  }

  // ------------------------------------------------------------------ export

  /// A session leaves as one self-describing JSON document. The Decision Record
  /// export (A5) is rendered from the same data by the UI.
  Future<Map<String, dynamic>> exportSession(String id) async {
    final s = await session(id);
    if (s == null) {
      throw ArgumentError('no such session: $id');
    }
    final seatRows = await seats(id);
    final msgs = await messages(id);
    final agentById = <String, db.Agent>{
      for (final a in await allAgents()) a.id: a,
    };
    return <String, dynamic>{
      'format': 'agora.session',
      'version': 1,
      'exportedAt': _clock().toIso8601String(),
      'session': <String, dynamic>{
        'id': s.id,
        'title': s.title,
        'prompt': s.prompt,
        'round': s.round,
        'maxRounds': s.maxRounds,
        'status': s.status,
        'contextStrategy': s.contextStrategy,
        'archived': s.archived,
        'createdAt': s.createdAt.toIso8601String(),
        'updatedAt': s.updatedAt.toIso8601String(),
      },
      'seats': <Map<String, dynamic>>[
        for (final r in seatRows)
          <String, dynamic>{
            'kind': agentById[r.agentId]?.kind,
            'displayName': agentById[r.agentId]?.displayName,
            'roleCard': r.roleCard,
            'isLeader': r.isLeader,
            'status': r.status,
            'modelLabel': r.modelLabel,
          },
      ],
      'messages': <Map<String, dynamic>>[
        for (final m in msgs)
          <String, dynamic>{
            'id': m.id,
            'round': m.round,
            'agent': agentById[m.agentId]?.kind,
            'role': m.role,
            'direction': m.direction,
            'rawText': m.rawText,
            'rawHtml': m.rawHtml,
            'screenshotPath': m.screenshotPath,
            'contentHash': m.contentHash,
            'latencyMs': m.latencyMs,
            'packetRef': m.packetRef,
            'createdAt': m.createdAt.toIso8601String(),
            'intact': isIntact(m),
          },
      ],
      'facts': <Map<String, dynamic>>[
        for (final f in await facts(id))
          <String, dynamic>{
            'fact': f.fact,
            'origin': f.origin,
            'pinned': f.pinned,
          },
      ],
      'journal': <Map<String, dynamic>>[
        for (final j in await journalFor(id))
          <String, dynamic>{
            'kind': j.kind,
            'at': j.at.toIso8601String(),
            'payload': j.payload,
          },
      ],
    };
  }
}

/// A seat as the UI describes it before it becomes two rows.
class SeatSpec {
  const SeatSpec({
    required this.kind,
    required this.displayName,
    required this.colorValue,
    required this.url,
    this.adapterVersion,
    this.roleCard,
    this.isLeader = false,
    this.modelLabel,
  });

  final String kind;
  final String displayName;
  final int colorValue;
  final String url;
  final String? adapterVersion;
  final String? roleCard;
  final bool isLeader;
  final String? modelLabel;
}
