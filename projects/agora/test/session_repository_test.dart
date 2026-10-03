import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agora/data/database.dart';
import 'package:agora/data/session_repository.dart';

void main() {
  late AgoraDb db;
  late SessionRepository repo;
  late Directory vault;

  setUp(() async {
    db = AgoraDb.forTesting(NativeDatabase.memory());
    vault = await Directory.systemTemp.createTemp('agora-vault-test');
    repo = SessionRepository(db, vaultDir: vault.path);
  });

  tearDown(() async {
    await db.close();
    if (vault.existsSync()) {
      await vault.delete(recursive: true);
    }
  });

  SeatSpec seat(String kind, {bool leader = false, String? role}) => SeatSpec(
    kind: kind,
    displayName: kind,
    colorValue: 0xFF000000,
    url: 'https://example.test/$kind',
    roleCard: role,
    isLeader: leader,
  );

  group('sessions', () {
    test('creates a session with seats, one leader, and both agents', () async {
      final id = await repo.createSession(
        title: 'Battery design',
        prompt: 'compare LFP vs NMC',
        leaderKind: 'chatgpt',
        seats: [
          seat('chatgpt', role: 'architect'),
          seat('gemini'),
        ],
      );

      final s = await repo.session(id);
      expect(s, isNotNull);
      expect(s!.title, 'Battery design');
      expect(s.leaderId, isNotNull);
      expect(s.archived, isFalse);

      final seats = await repo.seats(id);
      expect(seats.length, 2);
      expect(seats.where((s) => s.isLeader).length, 1);

      final agents = await repo.allAgents();
      expect(agents.length, 2);
      final kinds = agents.map((a) => a.kind).toSet();
      expect(kinds, {'chatgpt', 'gemini'});
    });

    test('role cards survive the round trip', () async {
      final id = await repo.createSession(
        prompt: 'p',
        seats: [seat('gemini', role: 'Devil\'s Advocate')],
      );
      final seats = await repo.seats(id);
      expect(seats.single.roleCard, "Devil's Advocate");
    });

    test('rename, update and archive persist', () async {
      final id = await repo.createSession(prompt: 'p', seats: [seat('gemini')]);
      await repo.renameSession(id, 'Renamed');
      await repo.updateSession(id, round: 4, status: 'running');
      await repo.updateSession(id, archived: true);

      final s = (await repo.session(id))!;
      expect(s.title, 'Renamed');
      expect(s.round, 4);
      expect(s.status, 'running');
      expect(s.archived, isTrue);

      // Archived sessions leave the default listing but are still readable.
      expect((await repo.sessions()).any((x) => x.id == id), isFalse);
      expect(
        (await repo.sessions(includeArchived: true)).any((x) => x.id == id),
        isTrue,
      );
    });

    test('delete removes every child row, not just the session', () async {
      final id = await repo.createSession(
        prompt: 'p',
        seats: [seat('chatgpt', leader: true), seat('gemini')],
      );
      final agents = await repo.allAgents();
      final chatgpt = agents.firstWhere((a) => a.kind == 'chatgpt');
      final msg = await repo.record(
        sessionId: id,
        round: 1,
        agentId: chatgpt.id,
        role: 'agent',
        direction: 'in',
        rawText: 'hello',
      );
      await repo.recordPacket(
        sessionId: id,
        round: 1,
        targetAgentId: chatgpt.id,
        strategy: 'delta',
        body: 'packet body',
      );
      await repo.addFact(sessionId: id, fact: 'a fact');
      await repo.journal(id, 'sent', payload: {'x': 1});
      await repo.countMessage('chatgpt', 10);

      await repo.deleteSession(id);

      expect(await repo.session(id), isNull);
      expect(await repo.seats(id), isEmpty);
      expect(await repo.messages(id), isEmpty);
      expect(await repo.facts(id), isEmpty);
      expect(await repo.journalFor(id), isEmpty);
      expect(await repo.messageCount(id), 0);
      // Agents are shared across sessions, so they survive on purpose.
      expect(await repo.allAgents(), hasLength(2));
      expect(msg.id, isNotEmpty);
    });
  });

  group('leader', () {
    test('setLeader leaves exactly one leader', () async {
      final id = await repo.createSession(
        prompt: 'p',
        seats: [seat('chatgpt', leader: true), seat('gemini')],
      );
      final agents = await repo.allAgents();
      final gemini = agents.firstWhere((a) => a.kind == 'gemini');

      await repo.setLeader(id, gemini.id);

      final seats = await repo.seats(id);
      expect(seats.where((s) => s.isLeader).length, 1);
      expect(seats.firstWhere((s) => s.agentId == gemini.id).isLeader, isTrue);
      expect((await repo.session(id))!.leaderId, gemini.id);
    });
  });

  group('verbatim vault', () {
    test('stores text byte-for-byte and hashes it', () async {
      final id = await repo.createSession(prompt: 'p', seats: [seat('gemini')]);
      final gemini = (await repo.allAgents()).single;
      const nasty = 'He said "hi"\n\ttabbed \\ and 你好 🚀 </script> — ok';

      final m = await repo.record(
        sessionId: id,
        round: 2,
        agentId: gemini.id,
        role: 'agent',
        direction: 'in',
        rawText: nasty,
        rawHtml: '<p>$nasty</p>',
        latencyMs: 821,
        packetRef: 'pkt-1',
        meta: {'adapter': 'gemini'},
      );

      expect(m.rawText, nasty);
      expect(m.rawHtml, '<p>$nasty</p>');
      expect(m.contentHash, hasLength(32));
      expect(m.latencyMs, 821);
      expect(repo.isIntact(m), isTrue);
      expect(m.round, 2);
    });

    test('detects tampering with stored text', () async {
      final id = await repo.createSession(prompt: 'p', seats: [seat('gemini')]);
      final gemini = (await repo.allAgents()).single;
      final m = await repo.record(
        sessionId: id,
        round: 1,
        agentId: gemini.id,
        role: 'agent',
        direction: 'in',
        rawText: 'original',
      );

      // Simulate someone rewriting history behind our back.
      await db
          .update(db.messages)
          .write(MessagesCompanion(rawText: const Value('quietly edited')));
      final tampered = (await repo.messages(id)).single;
      expect(tampered.rawText, 'quietly edited');
      expect(repo.isIntact(tampered), isFalse);
      // The hash did not move: that mismatch against the text is the evidence.
      expect(tampered.contentHash, m.contentHash);
    });

    test('writes the screenshot to the vault', () async {
      final id = await repo.createSession(prompt: 'p', seats: [seat('gemini')]);
      final gemini = (await repo.allAgents()).single;
      final png = Uint8List.fromList(List<int>.generate(64, (i) => i));

      final m = await repo.record(
        sessionId: id,
        round: 1,
        agentId: gemini.id,
        role: 'agent',
        direction: 'in',
        rawText: 'see attached',
        screenshot: png,
      );

      expect(m.screenshotPath, isNotNull);
      expect(File(m.screenshotPath!).existsSync(), isTrue);
      expect(File(m.screenshotPath!).readAsBytesSync(), png);
      expect(m.screenshotPath, contains(id));
    });

    test('keeps the message when the screenshot cannot be written', () async {
      // Point the vault at a path that cannot be created (a file, not a dir).
      final blocker = File('${vault.path}/blocked');
      await blocker.writeAsString('not a directory');
      final badRepo = SessionRepository(db, vaultDir: blocker.path);
      final id = await badRepo.createSession(
        prompt: 'p',
        seats: [seat('gemini')],
      );
      final gemini = (await badRepo.allAgents()).single;

      final m = await badRepo.record(
        sessionId: id,
        round: 1,
        agentId: gemini.id,
        role: 'agent',
        direction: 'in',
        rawText: 'evidence fails, text survives',
        screenshot: Uint8List.fromList([1, 2, 3]),
      );

      expect(m.rawText, 'evidence fails, text survives');
      expect(m.screenshotPath, isNull);
    });

    test('search and round filtering', () async {
      final id = await repo.createSession(prompt: 'p', seats: [seat('gemini')]);
      final gemini = (await repo.allAgents()).single;
      for (var r = 1; r <= 3; r++) {
        await repo.record(
          sessionId: id,
          round: r,
          agentId: gemini.id,
          role: 'agent',
          direction: 'in',
          rawText: 'round $r talking about cathodes',
        );
      }
      expect(await repo.messageCount(id), 3);
      expect(await repo.roundMessages(id, 2), hasLength(1));
      expect(await repo.search(id, 'cathodes'), hasLength(3));
      expect(await repo.search(id, 'nothing-here'), isEmpty);
    });
  });

  group('packets, facts, journal', () {
    test('packet round-trips with its hash', () async {
      final id = await repo.createSession(prompt: 'p', seats: [seat('gemini')]);
      final gemini = (await repo.allAgents()).single;
      final pid = await repo.recordPacket(
        sessionId: id,
        round: 1,
        targetAgentId: gemini.id,
        strategy: 'delta',
        body: 'body of packet',
      );
      final p = (await repo.packet(pid))!;
      expect(p.body, 'body of packet');
      expect(p.strategy, 'delta');
      expect(p.byteSize, 'body of packet'.length);
      expect(p.bodyHash, hasLength(32));
    });

    test('facts accumulate and pin', () async {
      final id = await repo.createSession(prompt: 'p', seats: [seat('gemini')]);
      final a = await repo.addFact(sessionId: id, fact: 'LFP is cheaper');
      await repo.addFact(sessionId: id, fact: 'NMC has higher energy density');
      expect(await repo.facts(id), hasLength(2));

      await repo.pinFact(a, true);
      final pinned = (await repo.facts(id)).where((f) => f.pinned).toList();
      expect(pinned, hasLength(1));
      expect(pinned.single.fact, 'LFP is cheaper');
    });

    test('journal keeps insertion order', () async {
      final id = await repo.createSession(prompt: 'p', seats: [seat('gemini')]);
      await repo.journal(id, 'navigate', payload: {'url': 'x'});
      await repo.journal(id, 'type', payload: {'chars': 5});
      await repo.journal(id, 'send');
      final j = await repo.journalFor(id);
      expect(j.map((e) => e.kind).toList(), ['navigate', 'type', 'send']);
      expect(j.first.payload, contains('url'));
    });
  });

  group('usage counters', () {
    test('counts once per message, not twice on the first of a day', () async {
      await repo.countMessage('chatgpt', 100);
      expect(await repo.sentToday('chatgpt'), 1);

      await repo.countMessage('chatgpt', 50);
      await repo.countMessage('chatgpt', 50);
      expect(await repo.sentToday('chatgpt'), 3);
    });

    test('keeps agents separate', () async {
      await repo.countMessage('chatgpt', 10);
      await repo.countMessage('gemini', 10);
      expect(await repo.sentToday('chatgpt'), 1);
      expect(await repo.sentToday('gemini'), 1);
      expect((await repo.usage()).length, 2);
    });

    test('dayKey formats as YYYY-MM-DD', () {
      expect(SessionRepository.dayKey(DateTime(2026, 10, 3)), '2026-10-03');
      expect(SessionRepository.dayKey(DateTime(2026, 1, 9)), '2026-01-09');
    });
  });

  group('export', () {
    test('produces a self-describing document with integrity flags', () async {
      final id = await repo.createSession(
        prompt: 'the original request',
        leaderKind: 'chatgpt',
        seats: [seat('chatgpt', leader: true), seat('gemini')],
      );
      final gemini = (await repo.allAgents()).firstWhere(
        (a) => a.kind == 'gemini',
      );
      await repo.record(
        sessionId: id,
        round: 1,
        agentId: gemini.id,
        role: 'agent',
        direction: 'in',
        rawText: 'the answer',
      );

      final doc = await repo.exportSession(id);
      expect(doc['format'], 'agora.session');
      expect(doc['version'], 1);
      final s = doc['session'] as Map<String, dynamic>;
      expect(s['prompt'], 'the original request');
      final seats = doc['seats'] as List;
      expect(seats.length, 2);
      final msgs = doc['messages'] as List;
      expect(msgs.length, 1);
      expect((msgs.single as Map)['intact'], isTrue);
      expect((msgs.single as Map)['rawText'], 'the answer');
    });

    test('throws for a session that does not exist', () {
      expect(() => repo.exportSession('nope'), throwsArgumentError);
    });
  });

  test('watchMessages emits the recorded message', () async {
    final id = await repo.createSession(prompt: 'p', seats: [seat('gemini')]);
    final gemini = (await repo.allAgents()).single;
    final first = await repo.watchMessages(id).first;
    expect(first, isEmpty);

    await repo.record(
      sessionId: id,
      round: 1,
      agentId: gemini.id,
      role: 'agent',
      direction: 'in',
      rawText: 'live',
    );
    final rows = await repo.watchMessages(id).first;
    expect(rows.single.rawText, 'live');
  });
}
