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
    expect(db.schemaVersion, 2);
  });

  test('a fresh install has every table', () async {
    final tables = await objectsOf('table');
    expect(
      tables,
      containsAll(<String>[
        'sessions',
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
}
