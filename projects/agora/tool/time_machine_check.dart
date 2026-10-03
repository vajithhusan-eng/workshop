// End-to-end Time Machine check against the real vault.
//
// `sandbox_smoke.dart` proves the engine can drive a site. This proves the
// other half: that a real council run writes journalled turns, and that a
// *fresh* stand-in reproduces them. Everything runs against the real
// `~/.config/agora/agora.sqlite` — the point is to exercise the same write
// path the app uses, not a fake database.
//
// Two sandbox seats are used, `sandbox` and `sandbox2`, both pointing at the
// same mock site in separate tabs. One seat alone would never emit a dispatch,
// so the replay would have nothing to reproduce.
//
//   dart run tool/time_machine_check.dart
//
// Exit code 1 means the replay did not reproduce a recorded turn.
import 'dart:convert';
import 'dart:io';

import 'package:agora/core/adapters/agent_adapter.dart';
import 'package:agora/core/adapters/adapter_config.dart';
import 'package:agora/core/adapters/web_agent_adapter.dart';
import 'package:agora/core/chrome/chrome_launcher.dart';
import 'package:agora/core/council/adapter_loader.dart';
import 'package:agora/core/council/council_runner.dart';
import 'package:agora/core/council/journal_replay.dart';
import 'package:agora/core/council/tab_pool.dart';
import 'package:agora/data/database.dart';
import 'package:agora/data/session_repository.dart';

const int port = 9226;

Future<AdapterConfig> _cfg(String kind) async {
  final raw = File('tool/sandbox/adapter_sandbox.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  json['kind'] = kind;
  json['displayName'] = 'Mock AI ($kind)';
  return AdapterConfig.parse(
    jsonEncode(json),
    origin: 'tool/sandbox/$kind.json',
  );
}

Future<void> main() async {
  final headless = (Platform.environment['DISPLAY'] ?? '').isEmpty;
  final leader = await _cfg('sandbox');
  final delegate = await _cfg('sandbox2');
  for (final c in [leader, delegate]) {
    if (!c.isValid) {
      stderr.writeln(
        'adapter ${c.kind} is invalid: ${c.validate().join('; ')}',
      );
      exit(2);
    }
  }

  final db = AgoraDb();
  final repo = SessionRepository(db);
  final sessionId = await repo.createSession(
    title: 'Time Machine self-check',
    prompt: 'Propose one way to store a debate transcript on a laptop.',
    leaderKind: leader.kind,
    seats: [
      SeatSpec(
        kind: leader.kind,
        displayName: leader.displayName,
        colorValue: 0xFF10A37F,
        url: leader.homeUrl,
        isLeader: true,
      ),
      SeatSpec(
        kind: delegate.kind,
        displayName: delegate.displayName,
        colorValue: 0xFF4285F4,
        url: delegate.homeUrl,
      ),
    ],
  );
  stdout.writeln('session $sessionId');
  stdout.writeln('vault   ~/.config/agora/agora.sqlite\n');

  // ---- 1. run a real council, writing to the real vault ---------------------
  final runner = CouncilRunner(
    repo: repo,
    sessionId: sessionId,
    kindToAgentId: <String, String>{},
    adapterLoader: fileAdapterLoader('tool/sandbox'),
    adapterOverrides: <String, AdapterConfig>{
      leader.kind: leader,
      delegate.kind: delegate,
    },
    cdpPort: port,
    headless: headless,
    // A throwaway profile: the app's real one may already be held open by a
    // running Agora, and Chrome hands off to that instance instead of starting.
    profileDir: Directory.systemTemp.createTempSync('agora-tm-').path,
  );
  Object? failure;
  try {
    final outcome = await runner.run(
      seats: [
        SeatBinding(
          kind: leader.kind,
          displayName: leader.displayName,
          isLeader: true,
        ),
        SeatBinding(kind: delegate.kind, displayName: delegate.displayName),
      ],
      leaderKind: leader.kind,
      prompt: 'Propose one way to store a debate transcript on a laptop.',
      maxRounds: 2,
      timeBudget: const Duration(minutes: 3),
    );
    stdout.writeln('council stop=${outcome.stop} rounds=${outcome.rounds}');
    for (final n in runner.notes) {
      stdout.writeln('  $n');
    }
  } on Object catch (e) {
    failure = e;
    stderr.writeln('COUNCIL FAILED: $e');
  }

  // ---- 2. what did the journal actually capture? ----------------------------
  final journal = await repo.journalFor(sessionId);
  final dispatches = journal.where((e) => e.kind == 'dispatch').length;
  final captures = journal.where((e) => e.kind == 'capture').length;
  stdout.writeln(
    '\njournal: ${journal.length} rows '
    '($dispatches dispatch, $captures capture)',
  );
  stdout.writeln('messages in vault: ${await repo.messageCount(sessionId)}');
  if (failure != null || dispatches == 0) {
    stderr.writeln('\nNO TURNS TO REPLAY - the run produced no dispatch rows.');
    await db.close();
    exit(1);
  }

  // ---- 3. replay against a fresh stand-in ----------------------------------
  final launcher = ChromeLauncher();
  final launched = await launcher.launch(
    preferredPort: port,
    profileDir: Directory.systemTemp.createTempSync('agora-tm-').path,
    headless: headless,
  );
  final pool = TabPool(launched.client);
  WebAgentAdapter? standIn;
  try {
    final cfg = await _cfg('replay');
    final adapter = WebAgentAdapter(
      config: cfg,
      client: launched.client,
      targetId: await pool.open('replay', url: cfg.homeUrl),
    );
    await adapter.connect();
    await adapter.newChat();
    standIn = adapter;

    final report = await JournalReplay(
      repo: repo,
      adapters: <String, AgentAdapter>{cfg.kind: adapter},
    ).replay(sessionId);

    stdout.writeln('\n${report.headline}');
    for (final s in report.steps) {
      final mark = switch (s.status) {
        ReplayStatus.match => 'OK  ',
        ReplayStatus.differs => 'DIFF',
        ReplayStatus.noAdapter => 'SKIP',
        ReplayStatus.failed => 'FAIL',
      };
      stdout.writeln('  [$mark] ${s.target}: ${s.verdict}');
    }
    stdout.writeln(
      '\nmatched=${report.matched} differs=${report.differs} '
      'skipped=${report.skipped} failed=${report.failed}',
    );
    await db.close();
    exit(report.failed > 0 || report.differs > 0 ? 1 : 0);
  } finally {
    await standIn?.close();
    await pool.closeAll();
    await launched.client.close();
  }
}
