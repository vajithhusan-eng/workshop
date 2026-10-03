import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agora/data/database.dart';
import 'package:agora/data/session_repository.dart';
import 'package:agora/state/agora_controller.dart';

/// `startCouncil` must refuse to start a browser when a precondition fails.
///
/// These are the paths a first-launch user actually hits — no leader promoted
/// yet, an empty council, a session with no problem to solve. Each one has to
/// come back as a sentence on screen, not an exception in the widget tree.
void main() {
  late AgoraDb db;
  late SessionRepository repo;
  late AgoraController c;
  late Directory vault;

  setUp(() async {
    db = AgoraDb.forTesting(NativeDatabase.memory());
    vault = await Directory.systemTemp.createTemp('agora-startup-test');
    repo = SessionRepository(db, vaultDir: vault.path);
    c = AgoraController(repo)..start();
  });

  tearDown(() async {
    c.dispose();
    await db.close();
    if (vault.existsSync()) await vault.delete(recursive: true);
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  test('no session selected is a refusal, not a crash', () async {
    expect(await c.startCouncil(), isFalse);
    expect(c.councilError, contains('session'));
  });

  test('a session with no promoted leader explains what to do', () async {
    await c.newSession(prompt: 'pick a leader', title: 't');
    await settle();
    // Undo the seeded leader so the "no leader" path is actually exercised.
    final seats = await repo.seats(c.selectedId!);
    await repo.setLeader(c.selectedId!, seats.first.agentId);
    for (final s in seats.skip(1)) {
      await repo.removeSeat(c.selectedId!, s.agentId);
    }
    await repo.updateSession(c.selectedId!, leaderId: '');
    c.select(c.selectedId);
    await settle();

    final outcome = await c.startCouncil();
    expect(outcome, isFalse);
    expect(c.councilError, isNotNull);
    // Critically: no Chrome was launched and no run is in flight.
    expect(c.councilRunning, isFalse);
    expect(c.runner, isNull);
  });

  test('a leader with seats is accepted and reports progress notes', () async {
    await c.newSession(prompt: 'compare three approaches', title: 't');
    await settle();
    c.select(c.selectedId);
    await settle();

    expect(c.seats, hasLength(3));
    expect(c.leaderSeat, isNotNull);
    expect(c.current!.prompt, 'compare three approaches');
  });

  test('interrupting when nothing runs is harmless', () {
    expect(c.interruptCouncil, returnsNormally);
  });

  test('an empty prompt is not something the UI can offer', () async {
    await c.newSession(prompt: '', title: 't');
    await settle();
    expect(c.current!.prompt.trim(), isEmpty);
  });

  test(
    'snapshot with no live council says why instead of failing silently',
    () async {
      await c.newSession(prompt: 'p', title: 't');
      await settle();
      expect(await c.snapshot(), isFalse);
      expect(c.councilError, contains('No live tabs'));
      expect(c.lastSnapshot, isNull);
    },
  );
}
