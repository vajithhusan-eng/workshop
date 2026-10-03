import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agora/core/adapters/agent_adapter.dart';
import 'package:agora/core/adapters/adapter_config.dart';
import 'package:agora/core/council/journal_replay.dart';
import 'package:agora/data/database.dart';
import 'package:agora/data/session_repository.dart';

/// A stand-in AI site. It exists so a replay never talks to a real service:
/// if Agora's pipeline changed, the fixture answers differently and that is the
/// signal we want, without spending money or depending on a third party.
class _FakeAgent implements AgentAdapter {
  _FakeAgent(this.answerFor, {this.failOnSend = false});

  final String Function(String prompt) answerFor;
  final bool failOnSend;

  final List<String> sent = <String>[];

  @override
  String get kind => 'fake';

  @override
  String get displayName => 'Fake';

  @override
  AdapterConfig? get config => null;

  @override
  String get targetId => 'fake-target';

  @override
  AgentStatus get status => AgentStatus.ready;

  @override
  AgentDiagnostics get diagnostics =>
      const AgentDiagnostics(allHealthy: true, checks: <String>[]);

  @override
  Future<LoginState> connect() async =>
      const LoginState(status: LoginStatus.ready);

  @override
  Future<LoginState> checkLogin() async => connect();

  @override
  Future<void> newChat() async {}

  @override
  Future<void> send(String text) async {
    if (failOnSend) {
      throw StateError('the stand-in site is down');
    }
    sent.add(text);
  }

  @override
  Future<Verbatim> awaitCompletion() async =>
      Verbatim(rawText: answerFor(sent.isEmpty ? '' : sent.last));

  @override
  Future<Verbatim?> peekLastMessage() async => null;

  @override
  bool selectModel(String label) => true;

  @override
  Future<void> interrupt() async {}

  @override
  Future<void> close() async {}
}

void main() {
  late AgoraDb db;
  late SessionRepository repo;

  setUp(() {
    db = AgoraDb.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db, vaultDir: Directory.systemTemp.path);
  });

  tearDown(() => db.close());

  Future<String> newSession() =>
      repo.createSession(prompt: 'p', seats: const <SeatSpec>[]);

  test('an unchanged site reproduces a turn exactly', () async {
    final id = await newSession();
    await repo.journal(
      id,
      'dispatch',
      agentId: 'a',
      payload: {'round': 1, 'target': 'fake', 'body': 'PACKET ONE'},
    );
    await repo.journal(
      id,
      'capture',
      agentId: 'a',
      payload: {'round': 1, 'kind': 'fake', 'hash': 'deadbeef'},
    );

    final agent = _FakeAgent((_) => 'ANSWER ONE');
    final report = await JournalReplay(
      repo: repo,
      adapters: {'fake': agent},
    ).replay(id);

    expect(agent.sent, ['PACKET ONE']);
    expect(report.matched, 1);
    expect(report.differs, 0);
    expect(report.dispatched, 1);
    expect(report.captured, 1);
    expect(report.steps.single.verdict, 'reproduced exactly');
    expect(report.steps.single.replyChars, 'ANSWER ONE'.length);
  });

  test('a changed answer is reported, never silently accepted', () async {
    final id = await newSession();
    await repo.journal(
      id,
      'dispatch',
      agentId: 'a',
      payload: {'round': 1, 'target': 'fake', 'body': 'P'},
    );
    await repo.journal(
      id,
      'capture',
      agentId: 'a',
      payload: {'round': 1, 'kind': 'fake', 'hash': 'expected-but-wrong'},
    );

    final report = await JournalReplay(
      repo: repo,
      adapters: {'fake': _FakeAgent((_) => 'SOMETHING ELSE')},
    ).replay(id);

    expect(report.differs, 1);
    expect(report.steps.single.status, ReplayStatus.differs);
    expect(report.steps.single.verdict, 'answered differently');
    expect(report.headline, contains('different'));
  });

  test('two rounds pair FIFO per agent, not positionally', () async {
    final id = await newSession();
    // Deliberately interleave two kinds so a positional pairing would cross.
    await repo.journal(
      id,
      'dispatch',
      agentId: 'a',
      payload: {'round': 1, 'target': 'fake', 'body': 'P1'},
    );
    await repo.journal(
      id,
      'dispatch',
      agentId: 'a',
      payload: {'round': 2, 'target': 'fake', 'body': 'P2'},
    );
    await repo.journal(
      id,
      'capture',
      agentId: 'a',
      payload: {'round': 1, 'kind': 'fake', 'hash': 'h1'},
    );
    await repo.journal(
      id,
      'capture',
      agentId: 'a',
      payload: {'round': 2, 'kind': 'fake', 'hash': 'h2'},
    );

    // The site answers round 1's packet on the *second* await, which only works
    // if the replay queued replies FIFO instead of pairing by position.
    var n = 0;
    final agent = _FakeAgent((prompt) {
      n++;
      return prompt == 'P1' ? 'REPLY-TO-P2' : 'REPLY-TO-P1';
    });

    final report = await JournalReplay(
      repo: repo,
      adapters: {'fake': agent},
    ).replay(id);

    expect(agent.sent, ['P1', 'P2']);
    expect(report.steps, hasLength(2));
    expect(report.steps[0].body, 'P1');
    expect(report.steps[1].body, 'P2');
    // Both were compared against a hash that matches neither answer.
    expect(report.differs, 2);
  });

  test(
    'a turn aimed at a site with no stand-in is skipped, not failed',
    () async {
      final id = await newSession();
      await repo.journal(
        id,
        'dispatch',
        agentId: 'a',
        payload: {'round': 1, 'target': 'gemini', 'body': 'P'},
      );
      await repo.journal(
        id,
        'capture',
        agentId: 'a',
        payload: {'round': 1, 'kind': 'gemini', 'hash': 'h'},
      );

      final report = await JournalReplay(
        repo: repo,
        adapters: {'fake': _FakeAgent((_) => 'x')},
      ).replay(id);

      expect(report.skipped, 1);
      expect(report.failed, 0);
      expect(report.steps.single.status, ReplayStatus.noAdapter);
      expect(report.steps.single.verdict, 'no adapter for this site');
    },
  );

  test('a broken stand-in is one failed step, not an aborted replay', () async {
    final id = await newSession();
    for (var i = 0; i < 2; i++) {
      await repo.journal(
        id,
        'dispatch',
        agentId: 'a',
        payload: {'round': i, 'target': 'fake', 'body': 'P$i'},
      );
    }

    final report = await JournalReplay(
      repo: repo,
      adapters: {'fake': _FakeAgent((_) => 'x', failOnSend: true)},
    ).replay(id);

    expect(report.failed, 2);
    expect(report.steps, hasLength(2));
    expect(report.steps.first.detail, contains('stand-in site is down'));
  });

  test('an empty journal says so plainly', () async {
    final id = await newSession();
    final report = await JournalReplay(repo: repo, adapters: {}).replay(id);
    expect(report.steps, isEmpty);
    expect(report.headline, contains('no recorded turns'));
  });

  test(
    'turns with no recorded replies are named as pre-Time-Machine',
    () async {
      final id = await newSession();
      await repo.journal(
        id,
        'dispatch',
        agentId: 'a',
        payload: {'round': 1, 'target': 'fake', 'body': 'P'},
      );

      final report = await JournalReplay(repo: repo, adapters: {}).replay(id);
      expect(report.missingCaptures, isTrue);
      expect(report.headline, contains('before the Time Machine'));
    },
  );

  test('rows that are neither dispatch nor capture are ignored', () async {
    final id = await newSession();
    await repo.journal(id, 'phase', payload: {'phase': 'debate'});
    await repo.journal(id, 'safety_warning', payload: {'detail': 'p'});
    await repo.journal(
      id,
      'dispatch',
      agentId: 'a',
      payload: {'round': 1, 'target': 'fake', 'body': 'P'},
    );

    final report = await JournalReplay(
      repo: repo,
      adapters: {'fake': _FakeAgent((_) => 'x')},
    ).replay(id);

    expect(report.steps, hasLength(1));
    expect(report.dispatched, 1);
  });

  test('a malformed payload does not abort its neighbours', () async {
    final id = await newSession();
    await repo.journal(id, 'dispatch', agentId: 'a', payload: {});
    // Write a row whose payload is not JSON at all, bypassing the journal API.
    await db
        .into(db.journalEvents)
        .insert(
          db.JournalEventsCompanion.insert(
            id: 'jrn-broken',
            sessionId: id,
            kind: 'dispatch',
            payload: const Value('this is not json'),
            at: DateTime.now(),
          ),
        );
    await repo.journal(
      id,
      'dispatch',
      agentId: 'a',
      payload: {'round': 2, 'target': 'fake', 'body': 'GOOD'},
    );

    final agent = _FakeAgent((_) => 'x');
    final report = await JournalReplay(
      repo: repo,
      adapters: {'fake': agent},
    ).replay(id);

    expect(agent.sent, ['GOOD']);
    expect(report.steps.last.body, 'GOOD');
  });

  test('counts are reported even when nothing replays', () async {
    final id = await newSession();
    await repo.journal(
      id,
      'dispatch',
      agentId: 'a',
      payload: {'round': 1, 'target': 'gemini', 'body': 'P'},
    );
    await repo.journal(
      id,
      'capture',
      agentId: 'a',
      payload: {'round': 1, 'kind': 'gemini', 'hash': 'h'},
    );

    final report = await JournalReplay(repo: repo, adapters: {}).replay(id);
    expect(report.dispatched, 1);
    expect(report.captured, 1);
    expect(report.skipped, 1);
  });
}
