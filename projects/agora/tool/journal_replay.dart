// Replays a recorded council against the Sandbox Lab fixture.
//
// Why this exists: a real run talks to ChatGPT, Gemini and DeepSeek. Replaying
// it against those sites would cost money and could change under us mid-replay.
// The fixture is local, free and stable, so a `differs` verdict means Agora's own
// pipeline changed -- which is the half of the question that is ours to answer.
//
// Manual and opt-in: it launches a real Chrome. Never wired into CI.
//
// HOW TO RUN IT: plain `dart run` will NOT work here. The chain
// journal_replay -> session_repository -> database -> drift_flutter reaches
// flutter/widgets.dart, and `dart run` has no `dart:ui`, so the compile dies in
// velocity_tracker.dart before main() is reached. (tool/sandbox_smoke.dart runs
// fine under plain `dart run` because it never touches the storage layer.)
// Run it from a Flutter-aware entry point until lib/data drops drift_flutter in
// favour of a plain NativeDatabase over AgoraPaths.
//
//   dart run tool/journal_replay.dart <sessionId>

import 'dart:io';

import 'package:agora/core/adapters/adapter_config.dart';
import 'package:agora/core/adapters/agent_adapter.dart';
import 'package:agora/core/adapters/web_agent_adapter.dart';
import 'package:agora/core/chrome/chrome_launcher.dart';
import 'package:agora/core/council/journal_replay.dart';
import 'package:agora/core/council/tab_pool.dart';
import 'package:agora/data/database.dart';
import 'package:agora/data/session_repository.dart';

Future<void> main(List<String> argv) async {
  final args = argv.where((a) => !a.startsWith('--')).toList();
  if (args.isEmpty) {
    stderr.writeln('usage: journal_replay <sessionId>');
    exit(2);
  }
  final sessionId = args.first;

  final db = AgoraDb();
  final repo = SessionRepository(db);

  final session = await repo.session(sessionId);
  if (session == null) {
    stderr.writeln('no such session: $sessionId');
    await db.close();
    exit(2);
  }

  stdout.writeln('Agora Time Machine - ${session.title}');
  stdout.writeln(
    'session $sessionId, status ${session.status}, '
    'round ${session.round}/${session.maxRounds}',
  );

  // The stand-in site. Its kind differs from the real agents on purpose: if the
  // journal says it talked to `gemini` and we have no `gemini` adapter, that turn
  // is reported as skipped rather than silently answered by the wrong site.
  final adapterJson = await File(
    'tool/sandbox/adapter_sandbox.json',
  ).readAsString();
  final cfg = AdapterConfig.parse(adapterJson, origin: 'adapter_sandbox.json');
  final problems = cfg.validate();
  if (problems.isNotEmpty) {
    stderr.writeln('sandbox adapter does not validate:');
    for (final p in problems) {
      stderr.writeln('  - $p');
    }
    await db.close();
    exit(1);
  }

  final launch = await ChromeLauncher().launch(
    preferredPort: 9225,
    profileDir: '${Directory.systemTemp.path}/agora-replay-profile',
    headless: !Platform.environment.containsKey('DISPLAY'),
  );
  stdout.writeln(
    'chrome ${launch.client.browserVersion} on 127.0.0.1:${launch.port}',
  );
  stdout.writeln('stand-in site: ${cfg.displayName} (${cfg.kind})');

  final pool = TabPool(launch.client);
  WebAgentAdapter? adapter;
  try {
    final targetId = await pool.open(cfg.kind, url: cfg.homeUrl);
    adapter = WebAgentAdapter(
      config: cfg,
      client: launch.client,
      targetId: targetId,
    );
    final login = await adapter.connect();
    if (!login.isReady) {
      stderr.writeln('sandbox fixture is not ready: ${login.message}');
      exit(1);
    }
    await adapter.newChat();

    final report = await JournalReplay(
      repo: repo,
      adapters: <String, AgentAdapter>{cfg.kind: adapter},
    ).replay(sessionId);

    stdout.writeln('');
    stdout.writeln(report.headline);
    stdout.writeln('');
    for (final step in report.steps) {
      final mark = switch (step.status) {
        ReplayStatus.match => 'OK  ',
        ReplayStatus.differs => 'DIFF',
        ReplayStatus.noAdapter => 'SKIP',
        ReplayStatus.failed => 'FAIL',
      };
      stdout.writeln('[$mark] ${step.target}: ${step.verdict}');
      stdout.writeln(
        '        packet ${step.body.length} chars, '
        'reply ${step.replyChars} chars',
      );
    }

    stdout.writeln('');
    if (report.steps.isEmpty && report.dispatched == 0) {
      stdout.writeln(
        'Nothing to replay: this journal has no recorded turns yet.',
      );
    } else if (report.skipped == report.steps.length) {
      stdout.writeln(
        'Nothing was replayed: this journal has no turns addressed to '
        '"${cfg.kind}". Replay needs one adapter per agent kind, so a real '
        'session only replays once stand-ins exist for chatgpt, gemini and '
        'deepseek.',
      );
    }

    // Exit non-zero only on a genuine mismatch. Skips and failures are findings
    // about the data, not failures of this tool.
    exitCode = report.differs > 0 ? 1 : 0;
  } finally {
    await adapter?.close();
    await pool.closeAll();
    launch.client.close();
    await db.close();
  }
}
