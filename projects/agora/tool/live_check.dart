// Live real-site check: chatgpt.com + chat.deepseek.com + gemini.google.com
// driven through Agora's own logged-in Chrome profile.
//
// `sandbox_smoke.dart` proves the engine against a mock site; this is the
// counterpart that proves the engine against the actual websites, using the
// profile that holds the user's real logins (`~/.config/agora/chrome-profile`).
//
//   dart run tool/live_check.dart            # login check only (read-only)
//   dart run tool/live_check.dart council    # login check + one live council
//
// The council mode drives a real round: ChatGPT leads, DeepSeek and Gemini
// are invited. It writes to the real `~/.config/agora/agora.sqlite`, so a
// journal row is a genuine write, not a fixture.
//
// Exit codes: 0 = all checks green (council mode: dispatch rows present),
// 1 = a check failed, 2 = a site is signed out / blocked and needs the user
// to sign in to the visible Chrome window.
import 'dart:convert';
import 'dart:io';

import 'package:agora/core/adapters/agent_adapter.dart';
import 'package:agora/core/adapters/adapter_config.dart';
import 'package:agora/core/adapters/web_agent_adapter.dart';
import 'package:agora/core/chrome/chrome_launcher.dart';
import 'package:agora/core/council/adapter_loader.dart';
import 'package:agora/core/council/council_runner.dart';
import 'package:agora/core/council/login_checker.dart';
import 'package:agora/data/database.dart';
import 'package:agora/data/session_repository.dart';

const List<String> sites = <String>['chatgpt', 'deepseek', 'gemini'];

Future<void> main(List<String> args) async {
  final council = args.contains('council');
  final port =
      int.tryParse(
        args.where((a) => a.startsWith('--port=')).firstOrNull?.substring(7) ??
            '',
      ) ??
      9222;

  final loader = fileAdapterLoader('assets/adapters');
  // ---- 1. login state on the real profile --------------------------------
  final checker = LoginChecker(
    adapterLoader: loader,
    cdpPort: port,
    headless: (Platform.environment['DISPLAY'] ?? '').isEmpty,
  );
  final checks = await checker.checkAll(sites);
  var ready = 0;
  for (final c in checks) {
    final mark = switch (c.status) {
      LoginStatus.ready => 'READY ',
      LoginStatus.loggedOut => 'OUT  ',
      LoginStatus.captcha => 'CAPTCHA',
      LoginStatus.rateLimited => 'RATE  ',
      LoginStatus.needsRepair => 'REPAIR',
      LoginStatus.transportError => 'TRANSP',
      LoginStatus.unknown => '?     ',
    };
    stdout.writeln('[$mark] ${c.displayName.padRight(10)} ${c.url}');
    if (c.detail.isNotEmpty && c.status != LoginStatus.ready) {
      stdout.writeln('        ${c.detail}');
    }
    if (c.ready) ready++;
    if (c.status == LoginStatus.loggedOut ||
        c.status == LoginStatus.captcha ||
        c.status == LoginStatus.rateLimited) {
      stdout.writeln('        remedy: ${c.remedy}');
    }
  }
  stdout.writeln('login: $ready/${checks.length} sites ready');

  if (!council) {
    await checker.dispose();
    exit(ready == checks.length ? 0 : 2);
  }

  if (ready < checks.length) {
    await checker.dispose();
    stderr.writeln(
      'not running a council: sign in first (the Chrome window is open).',
    );
    exit(2);
  }
  await checker.dispose();

  // ---- 2. one live council, ChatGPT leading ------------------------------
  final configs = <String, AdapterConfig>{};
  for (final kind in sites) {
    configs[kind] = AdapterConfig.parse(
      await loader(kind),
      origin: 'assets/adapters/$kind.json',
    );
  }

  final db = AgoraDb();
  final repo = SessionRepository(db);
  final sessionId = await repo.createSession(
    title: 'Live real-site check',
    prompt:
        'In one short paragraph: what is the single most useful thing an '
        'AI assistant can do for a solo developer?',
    leaderKind: 'chatgpt',
    seats: <SeatSpec>[
      SeatSpec(
        kind: 'chatgpt',
        displayName: 'ChatGPT',
        colorValue: 0xFF10A37F,
        url: configs['chatgpt']!.homeUrl,
        isLeader: true,
      ),
      SeatSpec(
        kind: 'deepseek',
        displayName: 'DeepSeek',
        colorValue: 0xFF4D6BFE,
        url: configs['deepseek']!.homeUrl,
      ),
      SeatSpec(
        kind: 'gemini',
        displayName: 'Gemini',
        colorValue: 0xFF4285F4,
        url: configs['gemini']!.homeUrl,
      ),
    ],
  );
  stdout.writeln('session $sessionId');

  final runner = CouncilRunner(
    repo: repo,
    sessionId: sessionId,
    kindToAgentId: const <String, String>{},
    adapterLoader: loader,
    adapterOverrides: configs,
    cdpPort: port,
    headless: (Platform.environment['DISPLAY'] ?? '').isEmpty,
    // The real profile: this is the whole point of the check.
    profileDir: AgoraPaths.chromeProfile,
  );
  Object? failure;
  try {
    final outcome = await runner.run(
      seats: <SeatBinding>[
        SeatBinding(kind: 'chatgpt', displayName: 'ChatGPT', isLeader: true),
        SeatBinding(kind: 'deepseek', displayName: 'DeepSeek'),
        SeatBinding(kind: 'gemini', displayName: 'Gemini'),
      ],
      leaderKind: 'chatgpt',
      prompt:
          'In one short paragraph: what is the single most useful thing an '
          'AI assistant can do for a solo developer?',
      maxRounds: 1,
      timeBudget: const Duration(minutes: 4),
    );
    stdout.writeln('council stop=${outcome.stop} rounds=${outcome.rounds}');
    for (final n in runner.notes) {
      stdout.writeln('  $n');
    }
  } on Object catch (e) {
    failure = e;
    stderr.writeln('COUNCIL FAILED: $e');
  }

  // ---- 3. what did the run actually write? --------------------------------
  final journal = await repo.journalFor(sessionId);
  final dispatches = journal.where((e) => e.kind == 'dispatch').length;
  final captures = journal.where((e) => e.kind == 'capture').length;
  stdout.writeln(
    'journal: ${journal.length} rows '
    '($dispatches dispatch, $captures capture)',
  );
  stdout.writeln('messages in vault: ${await repo.messageCount(sessionId)}');
  await db.close();

  if (failure != null) {
    stderr.writeln('LIVE COUNCIL FAILED - see above.');
    exit(1);
  }
  if (dispatches == 0) {
    stderr.writeln('NO DISPATCHES - the leader never invited anyone.');
    exit(1);
  }
  stdout.writeln('LIVE CHECK OK - dispatches were journaled.');
}
