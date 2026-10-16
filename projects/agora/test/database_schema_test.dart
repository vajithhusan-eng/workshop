import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agora/data/database.dart';

void main() {
  late AgoraDb db;

  setUp(() => db = AgoraDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Set<String>> indexes() async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  Future<Set<String>> objectsOf(String type) async {
    final rows = await db
        .customSelect(
          'SELECT name FROM sqlite_master WHERE type = ?',
          variables: [Variable<String>(type)],
        )
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('a fresh install reports the current schema version', () async {
    expect(db.schemaVersion, 3);
  });

  test('a fresh install has every table', () async {
    final tables = await objectsOf('table');
    expect(
      tables,
      containsAll(<String>[
        'sessions',
        'channels',
        'agents',
        'session_agents',
        'messages',
        'packets',
        'agent_facts',
        'journal_events',
        'adapters',
        'usage_counters',
      ]),
    );
  });

  test('sessions carries the archived column from the start', () async {
    final cols = await db.customSelect('PRAGMA table_info(sessions)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('archived'));
  });

  test(
    'full-text search over the transcript exists on a fresh install',
    () async {
      // fts5 keeps shadow tables (messages_fts_data etc.) alongside the virtual
      // table, so match on the virtual table itself via sqlite_master.
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE sql LIKE '%VIRTUAL TABLE%'",
          )
          .get();
      expect(rows.map((r) => r.read<String>('name')), contains('messages_fts'));
      expect(await objectsOf('trigger'), contains('messages_ai'));
    },
  );

  // Regression: the index DDL used to live only in onUpgrade, so a brand new
  // database - the common case - silently had no indexes at all.
  test(
    'a fresh install has the hot-query indexes, not just upgrades',
    () async {
      expect(
        await indexes(),
        containsAll(<String>[
          'idx_messages_session_created',
          'idx_messages_session_round',
          'idx_messages_channel_created',
          'idx_journal_session_at',
          'idx_usage_counters_day',
        ]),
      );
    },
  );

  test('re-running the index DDL is a no-op', () async {
    // onCreate and onUpgrade can both fire the DDL; it must not throw.
    for (var i = 0; i < 2; i++) {
      for (final sql in AgoraDb.indexDdl) {
        await db.customStatement(sql);
      }
    }
    expect(await indexes(), contains('idx_messages_session_created'));
  });

  test('channels carries the R1 thread columns', () async {
    final cols = await db.customSelect('PRAGMA table_info(channels)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll(<String>[
        'id',
        'session_id',
        'kind',
        'display_name',
        'members',
        'created_at',
      ]),
    );
  });

  test('messages carries a nullable channel_id from the start', () async {
    final cols = await db.customSelect('PRAGMA table_info(messages)').get();
    final notNull = {
      for (final r in cols) r.read<String>('name'): r.read<int>('notnull'),
    };
    expect(notNull, contains('channel_id'));
    // Nullable: null is the session's default public thread, so every message
    // written before R1 keeps its meaning.
    expect(notNull['channel_id'], 0);
  });

  test('an existing v2 database upgrades to v3', () async {
    final dir = await Directory.systemTemp.createTemp('agora-v2-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/v2.sqlite');

    // Build a database shaped like v2: no `channels`, no `channel_id`.
    final seed = AgoraDb.forTesting(NativeDatabase(file));
    await seed.customStatement(
      'DROP INDEX IF EXISTS idx_messages_channel_created',
    );
    await seed.customStatement('DROP TABLE IF EXISTS channels');
    await seed.customStatement('ALTER TABLE messages DROP COLUMN channel_id');
    await seed.customStatement('PRAGMA user_version = 2');
    await seed.close();

    // Reopening must run onUpgrade(2 -> 3) and add both, without touching the
    // verbatim transcript.
    final upgraded = AgoraDb.forTesting(NativeDatabase(file));
    addTearDown(upgraded.close);

    expect(upgraded.schemaVersion, 3);
    final tables = await upgraded
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    expect(tables.map((r) => r.read<String>('name')), contains('channels'));
    final cols = await upgraded
        .customSelect('PRAGMA table_info(messages)')
        .get();
    expect(cols.map((r) => r.read<String>('name')), contains('channel_id'));
  });
}
