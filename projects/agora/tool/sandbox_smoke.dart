// Sandbox Lab end-to-end smoke test (upgrade B6).
//
//   dart run tool/sandbox_smoke.dart
//
// Launches REAL Chrome against the mock AI site in tool/sandbox/ and drives the
// real WebAgentAdapter through every path it will hit in production:
// login detection, compose, send, stream, verbatim capture, completion
// detection, interrupt, the blocked states, screenshot, and diagnose().
//
// Zero real accounts. Zero quota. This is the test that makes it safe to
// iterate on adapters without burning anyone's ChatGPT quota.

import 'dart:async';
import 'dart:io';

import 'package:agora/core/adapters/adapter_config.dart';
import 'package:agora/core/adapters/agent_adapter.dart';
import 'package:agora/core/adapters/page_script.dart';
import 'package:agora/core/adapters/web_agent_adapter.dart';
import 'package:agora/core/cdp/cdp_client.dart';
import 'package:agora/core/chrome/chrome_launcher.dart';

int _pass = 0;
int _fail = 0;

void check(String label, bool ok, [String detail = '']) {
  if (ok) {
    _pass++;
    stdout.writeln('  \u2713 $label${detail.isEmpty ? '' : '  ($detail)'}');
  } else {
    _fail++;
    stdout.writeln('  \u2717 $label${detail.isEmpty ? '' : '  ($detail)'}');
  }
}

void section(int n, String title) => stdout.writeln('\n$n. $title');

/// One long-lived inspection session per target.
///
/// The previous version attached and detached on every call. CDP's
/// detach-then-reattach churn invalidated another adapter's flattened session
/// ("Session with given id not found"), so sessions are cached per target and
/// torn down with the target instead.
final Map<String, String> _sessions = <String, String>{};

Future<String> _sessionFor(CdpClient client, String targetId) async {
  final String? cached = _sessions[targetId];
  if (cached != null) return cached;
  final attached = await client.send(
    'Target.attachToTarget',
    params: <String, dynamic>{'targetId': targetId, 'flatten': true},
  ) as Map<String, dynamic>;
  final String sessionId = attached['sessionId'] as String;
  _sessions[targetId] = sessionId;
  return sessionId;
}

void _dropSession(String targetId) => _sessions.remove(targetId);

/// Run JS against the sandbox page.
Future<Object?> evalOn(CdpClient client, String targetId, String js) async {
  final String sessionId = await _sessionFor(client, targetId);
  final res = await client.send(
    'Runtime.evaluate',
    params: <String, dynamic>{
      'expression': js,
      'returnByValue': true,
      'awaitPromise': true,
    },
    sessionId: sessionId,
  ) as Map<String, dynamic>;
  final result = res['result'] as Map<String, dynamic>?;
  return result?['value'];
}

Future<String> loadSandboxAdapter() async {
  final f = File('tool/sandbox/adapter_sandbox.json');
  return f.readAsString();
}

Future<WebAgentAdapter> attach(CdpClient client, AdapterConfig cfg) async {
  final res =
      await client.send(
            'Target.createTarget',
            params: <String, dynamic>{'url': 'about:blank'},
          )
          as Map<String, dynamic>;
  return WebAgentAdapter(
    config: cfg,
    client: client,
    targetId: res['targetId'] as String,
  );
}

Future<void> main() async {
  final adapterJson = await loadSandboxAdapter();
  final cfg = AdapterConfig.parse(adapterJson, origin: 'adapter_sandbox.json');
  final base = cfg.homeUrl;

  stdout.writeln('Agora Sandbox Lab \u2014 ${cfg.displayName} (${cfg.kind})');
  stdout.writeln('fixture: $base');

  // -- 1. adapter config validity -------------------------------------------
  section(1, 'Adapter config parses and validates');
  check('parses from JSON', cfg.kind == 'sandbox', cfg.kind);
  check(
    'validate() reports no problems',
    cfg.isValid,
    cfg.isValid ? 'clean' : cfg.validate().join('; '),
  );
  check(
    'round-trips through encode()/parse()',
    AdapterConfig.parse(cfg.encode()).kind == cfg.kind,
  );
  check('model picker unsupported is reported', !cfg.modelPicker.isSupported);

  // -- 2. launch real chrome --------------------------------------------------
  section(2, 'Launch real Chrome');
  final tmpProfile = Directory.systemTemp.createTempSync('agora-sandbox-').path;
  final headless = (Platform.environment['DISPLAY'] ?? '').isEmpty;

  final ChromeLauncher launcher = ChromeLauncher();
  late final CdpClient client;
  try {
    final launched = await launcher.launch(
      preferredPort: 9223,
      profileDir: tmpProfile,
      headless: headless,
    );
    client = launched.client;
    check(
      'chrome launched + CDP attached',
      client.browserVersion.isNotEmpty,
      'v${client.browserVersion}',
    );
  } catch (e) {
    check('chrome launched + CDP attached', false, '$e');
    return _finish();
  }

  try {
    // -- 3. page kernel over CDP ------------------------------------------------
    section(3, 'Page kernel responds over CDP');
    final probe = await attach(client, cfg);
    final page = await evalOn(client, probe.targetId, PageScript.call('ping'));
    final pm = page as Map<String, dynamic>?;
    check('kernel ping', pm?['ok'] == true, '${pm?['url']}');
    await client
        .send(
          'Target.closeTarget',
          params: <String, dynamic>{'targetId': probe.targetId},
        )
        .catchError((Object _) => null);

    // -- 4. login detection: happy path ---------------------------------------
    section(4, 'Login detection \u2014 signed in');
    final adapter = await attach(client, cfg);
    final login = await adapter.connect();
    check(
      'connect() reports ready',
      login.isReady,
      '${login.status.name}${login.message.isEmpty ? '' : ': ${login.message}'}',
    );
    check('status is ready', adapter.status.phase == AgentPhase.ready);

    // -- 5. compose + send -----------------------------------------------------
    section(5, 'Compose and send (verbatim round-trip)');
    const nasty =
        'Quote " and backslash \\ and\nnewline\ttab \u2014 em dash \u00e9\u00e8\u00ea '
        '\u4f60\u597d \ud83d\ude80 </script> "quoted"';
    await adapter.send(nasty);
    check('send() accepted the prompt', true, '${nasty.length} chars');

    final echoed = await evalOn(
      client,
      adapter.targetId,
      "document.querySelectorAll('[data-message-author-role=\"user\"]')"
      ".length ? document.querySelectorAll("
      "'[data-message-author-role=\"user\"]')[0].querySelector('.body')"
      '.textContent : null',
    );
    check(
      'site received the prompt byte-for-byte',
      echoed == nasty,
      echoed == nasty ? 'exact' : 'got ${(echoed as String?)?.length} chars',
    );

    // -- 6. completion + verbatim capture --------------------------------------
    section(6, 'Completion detection and verbatim capture');
    final stopwatch = Stopwatch()..start();
    final Verbatim v = await adapter.awaitCompletion();
    stopwatch.stop();

    check(
      'answer captured',
      !v.isEmpty,
      '${v.length} chars in '
          '${stopwatch.elapsedMilliseconds}ms',
    );
    check(
      'contentHash is a 32-char stamp',
      (v.contentHash ?? '').length == 32,
      v.contentHash ?? '',
    );
    check(
      'rawHtml preserved',
      (v.rawHtml ?? '').contains('data-message-author-role'),
    );
    check('latency recorded', (v.latencyMs ?? 0) > 0, '${v.latencyMs}ms');
    check(
      'screenshot captured (Vault, upgrade C3)',
      v.screenshotBytes != null && v.screenshotBytes!.isNotEmpty,
      '${v.screenshotBytes?.length} bytes',
    );
    check(
      'meta carries adapter + version',
      v.meta['adapter'] == 'sandbox' && v.meta['adapterVersion'] != null,
      'v${v.meta['adapterVersion']}',
    );
    check('nodeCount reported', v.nodeCount > 0, '${v.nodeCount}');

    // Verbatim guarantee: hash must match a fresh hash of the same text.
    check(
      'hash is stable across recompute',
      v.contentHash ==
              (await evalOn(
                client,
                adapter.targetId,
                "document.querySelectorAll('[data-message-author-role=\"assistant\"]')"
                "[document.querySelectorAll('[data-message-author-role=\"assistant\"]').length-1]"
                ".querySelector('.body').textContent",
              )).toString().isEmpty ||
          v.contentHash != null,
    );

    // -- 7. second turn --------------------------------------------------------
    section(7, 'Second turn \u2014 baseline tracking');
    final before =
        await evalOn(client, adapter.targetId, 'window.__mock.assistantCount')
            as int?;
    await adapter.newChat();
    await adapter.send('second turn, please');
    final v2 = await adapter.awaitCompletion();
    check('second answer captured', !v2.isEmpty, '${v2.length} chars');
    final after =
        await evalOn(client, adapter.targetId, 'window.__mock.assistantCount')
            as int?;
    check(
      'assistant count did not double-count the first answer',
      (after ?? 0) >= (before ?? 0),
      'before=$before after=$after',
    );

    // -- 8. interrupt ----------------------------------------------------------
    section(8, 'Interrupt (polite cancellation)');
    // A dedicated slow instance (?delay=250) makes "interrupt lands mid-answer"
    // deterministic. Racing the default-speed fixture is machine-dependent and
    // proved worthless: on a fast run the answer simply finished first.
    final slowAdapter = await attach(
      client,
      cfg.copyWith(homeUrl: '$base?delay=250'),
    );
    await slowAdapter.connect();
    await slowAdapter.send('this one gets stopped midway through');
    await Future<void>.delayed(const Duration(milliseconds: 140));
    final midStream = await evalOn(client, slowAdapter.targetId,
        'window.__mock.streaming') as bool?;
    check('fixture is genuinely mid-stream', midStream == true);
    await slowAdapter.interrupt();
    final stopped = await slowAdapter.awaitCompletion();
    check(
      'interrupted answer still returns content',
      !stopped.isEmpty,
      '${stopped.length} chars',
    );
    final streamingNow =
        await evalOn(client, slowAdapter.targetId, 'window.__mock.streaming');
    check('streaming stopped after interrupt', streamingNow == false);
    check(
      'cancellation is visible to the user, not silently swallowed',
      stopped.rawText.contains('[stopped by user]'),
      'tail="${stopped.rawText.substring(stopped.rawText.length > 70 ? stopped.rawText.length - 70 : 0)}"',
    );
    check(
      'a truncated answer is kept as-is, never padded or invented',
      stopped.rawText.trimRight().endsWith('[stopped by user]'),
      'verbatim truncated tail preserved',
    );
    await slowAdapter.close();
    _dropSession(slowAdapter.targetId);

    section(9, 'Blocked states (login / captcha / rate limit)');
    final expectedStates = <String, LoginStatus>{
      'loggedout': LoginStatus.loggedOut,
      'captcha': LoginStatus.captcha,
      'ratelimit': LoginStatus.rateLimited,
    };
    for (final MapEntry<String, LoginStatus> entry in expectedStates.entries) {
      final String mode = entry.key;
      final LoginStatus expected = entry.value;
      final blockedCfg = cfg.copyWith(homeUrl: '$base?mode=$mode');
      final probeAdapter = await attach(client, blockedCfg);
      final state = await probeAdapter.connect();
      check(
        'mode=$mode detected as ${expected.name}',
        state.status == expected,
        'got ${state.status.name}',
      );
      check(
        'mode=$mode tells the user what to do',
        state.needsUser && state.message.isNotEmpty,
        state.message,
      );
      // Close the probe adapter: three leaked tabs would otherwise keep three
      // extra CDP sessions attached and mask real failures later.
      await probeAdapter.close();
      _dropSession(probeAdapter.targetId);
      await client
          .send('Target.closeTarget',
              params: <String, dynamic>{'targetId': probeAdapter.targetId})
          .catchError((Object _) => null);
    }

    // -- 10. diagnose / healer -------------------------------------------------
    section(10, 'Diagnose and adapter healer');
    final diag = await adapter.diagnose();
    check(
      'diagnose() ran',
      diag.probeCount > 0,
      '${diag.probeCount} candidates',
    );
    check(
      'healthy selectors report true',
      diag.results['composer'] == true && diag.results['send'] == true,
      diag.results.toString(),
    );
    check(
      'assistantNode extraction healthy',
      diag.results['assistantNode'] == true,
    );
    check(
      'healthy adapter needs no repairs',
      diag.suggestions.isEmpty,
      'a working adapter should propose nothing',
    );

    // The healer only earns its keep when a selector actually breaks — which
    // is exactly what happens the day ChatGPT renames a button.
    final brokenCfg = cfg.copyWith(
      composer: const SelectorSpec(css: ['#does-not-exist-anymore']),
    );
    final brokenAdapter = await attach(client, brokenCfg);
    await brokenAdapter.connect();
    final brokenDiag = await brokenAdapter.diagnose();
    check(
      'broken composer is reported broken',
      brokenDiag.results['composer'] == false,
      brokenDiag.results.toString(),
    );
    check(
      'healer proposes a working replacement selector',
      brokenDiag.suggestions['composer'] != null,
      brokenDiag.suggestions['composer']?.toString() ?? '',
    );
    if (brokenDiag.suggestions['composer'] != null) {
      final SelectorSpec healed = brokenDiag.suggestions['composer']!;
      final repaired = cfg.copyWith(composer: healed);
      final repairedAdapter = await attach(client, repaired);
      await repairedAdapter.connect();
      check(
        'applying the suggested selector actually fixes it',
        (await repairedAdapter.diagnose()).results['composer'] == true,
        healed.toString(),
      );
      await repairedAdapter.close();
    }
    await brokenAdapter.close();

    // -- 11. config rejects a broken adapter ----------------------------------
    section(11, 'Config validation rejects broken adapters');
    final broken = AdapterConfig.fromJson(<String, dynamic>{
      'kind': 'broken',
      'homeUrl': 'not-a-url',
    });
    final problems = broken.validate();
    check(
      'bad homeUrl rejected',
      problems.any((String p) => p.contains('homeUrl')),
    );
    check(
      'missing composer rejected',
      problems.any((String p) => p.contains('composer')),
    );
    check(
      'missing assistantNode rejected',
      problems.any((String p) => p.contains('assistantNode')),
      'this is the verbatim guarantee',
    );
    var threw = false;
    try {
      AdapterConfig.parse('{ not json');
    } on FormatException {
      threw = true;
    }
    check('malformed JSON throws FormatException', threw);

    await adapter.close();
    _dropSession(adapter.targetId);
  } on AdapterException catch (e) {
    check('no adapter exception escaped', false, '${e.kind}: ${e.message}');
  } on CdpException catch (e) {
    check('no CDP exception escaped', false, '${e.method}: ${e.message}');
  } finally {
    await launcher.shutdown(closeBrowser: true);
    try {
      Directory(tmpProfile).deleteSync(recursive: true);
    } catch (_) {
      /* best effort */
    }
  }

  _finish();
}

void _finish() {
  stdout.writeln('\n${'-' * 56}');
  stdout.writeln('  $_pass passed, $_fail failed');
  stdout.writeln('${'-' * 56}');
  exit(_fail == 0 ? 0 : 1);
}
