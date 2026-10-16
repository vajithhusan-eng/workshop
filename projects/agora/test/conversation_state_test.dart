import 'dart:io';

import 'package:agora/core/orchestration/speaker_selector.dart';
import 'package:agora/data/database.dart';
import 'package:agora/data/session_repository.dart';
import 'package:agora/state/agora_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// §18.1 / §18.3: the conversation state the centre pane reads.
///
/// The runner's `_channelIdFor` composition needs a live council to exercise,
/// but everything below it — a session materialising its public channel, the
/// user's turn landing in the public thread, a dm staying out of that thread
/// until it is selected — is pure repository + controller logic and must be
/// pinned here rather than assumed.
void main() {
  late AgoraDb db;
  late SessionRepository repo;
  late AgoraController c;
  late Directory vault;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = AgoraDb.forTesting(NativeDatabase.memory());
    vault = Directory.systemTemp.createTempSync('agora-conversation');
    repo = SessionRepository(db, vaultDir: vault.path);
    c = AgoraController(repo)..start();
  });

  tearDown(() async {
    c.dispose();
    await db.close();
    if (vault.existsSync()) await vault.delete(recursive: true);
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  Future<String> fresh() async {
    await c.newSession(prompt: 'compare three approaches', title: 't');
    await settle();
    return c.selectedId!;
  }

  List<String> texts() => c.channelMessages.map((m) => m.rawText).toList();

  test('selecting a session materialises the public channel row', () async {
    await fresh();
    // The public thread is the default view: null channelId, no dm selected.
    expect(c.selectedChannelId, isNull);
    expect(c.channels.where((ch) => ch.kind == 'public'), hasLength(1));
  });

  test('the user turn lands in the public thread', () async {
    await fresh();
    await c.recordUserTurn('the opening problem');
    await settle();

    expect(texts(), contains('the opening problem'));
    // Public messages are the null-channel rows — the §18.1 mapping.
    expect(c.channelMessages.every((m) => m.channelId == null), isTrue);
  });

  test('a dm is a separate thread the public view never shows', () async {
    final sessionId = await fresh();
    await c.recordUserTurn('public problem');

    final seats = await repo.seats(sessionId);
    final dm = await repo.ensureDmChannel(
      sessionId,
      'gemini',
      'deepseek',
      aName: 'Gemini',
      bName: 'DeepSeek',
    );
    await repo.record(
      sessionId: sessionId,
      round: 1,
      agentId: seats[1].agentId,
      role: 'agent',
      direction: 'in',
      rawText: 'psst, privately',
      channelId: dm.id,
    );
    await settle();

    // The public view is unchanged: the dm is not in the public thread…
    expect(texts(), contains('public problem'));
    expect(texts(), isNot(contains('psst, privately')));
    // …but the conversation list learned about the new thread.
    expect(c.channels.any((ch) => ch.id == dm.id), isTrue);

    c.selectChannel(dm.id);
    await settle();
    expect(c.selectedChannelId, dm.id);
    expect(texts(), contains('psst, privately'));
    expect(texts(), isNot(contains('public problem')));

    c.selectChannel(null);
    await settle();
    expect(texts(), contains('public problem'));
    expect(texts(), isNot(contains('psst, privately')));
  });

  test('a dm channel key round-trips through SpeakerSelector', () async {
    final sessionId = await fresh();
    final key = SpeakerSelector.dmChannelKey('gemini', 'deepseek');
    final dm = await repo.ensureDmChannel(sessionId, 'deepseek', 'gemini');

    expect(dm.id, 'ch:$sessionId:$key');
    expect(dm.displayName, 'deepseek ⇄ gemini'); // no names passed
    expect(dm.members, contains('deepseek'));
    expect(dm.members, contains('gemini'));
  });

  test('unread badges follow the reader, thread by thread', () async {
    final sessionId = await fresh();
    await c.recordUserTurn('public problem');
    await settle();

    final seats = await repo.seats(sessionId);
    final dm = await repo.ensureDmChannel(sessionId, 'gemini', 'deepseek');
    await settle();

    await repo.record(
      sessionId: sessionId,
      round: 1,
      agentId: seats[1].agentId,
      role: 'agent',
      direction: 'in',
      rawText: 'psst',
      channelId: dm.id,
    );
    await settle();

    // The dm holds a message the reader has not opened: it is unread.
    expect(c.unreadFor(dm.id), 1);
    // The public thread is what is on screen, so it is not.
    expect(c.unreadFor(null), 0);

    // Opening the dm clears it, and the public thread becomes the unread one.
    c.selectChannel(dm.id);
    await settle();
    expect(c.unreadFor(dm.id), 0);

    await repo.record(
      sessionId: sessionId,
      round: 1,
      agentId: seats[0].agentId,
      role: 'agent',
      direction: 'in',
      rawText: 'public again',
    );
    await settle();
    expect(c.unreadFor(null), 1);
    expect(c.unreadFor(dm.id), 0);
  });
}
