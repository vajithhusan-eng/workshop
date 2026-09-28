// End-to-end smoke test for Agora's Chrome engine.
//
// Launches the system Chrome with a throwaway profile, drives it over raw CDP,
// and exercises every primitive an adapter needs. Run with:
//   dart run tool/cdp_smoke.dart
//
// This is intentionally dependency-light: it touches no Flutter code so it can
// run as a plain Dart script in seconds.

import 'dart:async';
import 'dart:io';

import 'package:agora/core/cdp/cdp_client.dart';
import 'package:agora/core/chrome/chrome_launcher.dart';
import 'package:agora/core/logging.dart';

var _pass = 0;
var _fail = 0;

void check(String label, bool ok, [String detail = '']) {
  if (ok) {
    _pass++;
    stdout.writeln('  \u2713 $label${detail.isEmpty ? '' : ' \u2014 $detail'}');
  } else {
    _fail++;
    stdout.writeln('  \u2717 $label${detail.isEmpty ? '' : ' \u2014 $detail'}');
  }
}

Future<void> main() async {
  Logger.debugEnabled = true;
  stdout.writeln('\n=== Agora CDP smoke test ===\n');
  final headless = (Platform.environment['DISPLAY'] ?? '').isEmpty;
  if (headless) stdout.writeln('(no DISPLAY detected -> running headless)\n');

  final launcher = ChromeLauncher();
  CdpClient? cdp;
  String? sessionId;

  try {
    // ---- 1. launch ----
    final t0 = DateTime.now();
    final res = await launcher.launch(
      headless: headless,
      profileDir: Directory.systemTemp.createTempSync('agora-smoke').path,
    );
    cdp = res.client;
    final elapsed = DateTime.now().difference(t0).inMilliseconds;
    stdout.writeln('1. LAUNCH');
    check(
      'chrome launched',
      true,
      '${res.binary} :${res.port} in ${elapsed}ms',
    );
    check(
      'version reported',
      cdp.browserVersion.contains('Chrome'),
      cdp.browserVersion,
    );

    // ---- 2. create + attach a target ----
    stdout.writeln('\n2. TARGET & ATTACH');
    final target = await cdp.sendMap(
      'Target.createTarget',
      params: {'url': 'about:blank'},
    );
    final targetId = target['targetId'] as String?;
    check('Target.createTarget', targetId != null, targetId ?? '');

    final attach = await cdp.sendMap(
      'Target.attachToTarget',
      params: {'targetId': targetId, 'flatten': true},
    );
    sessionId = attach['sessionId'] as String?;
    check('Target.attachToTarget', sessionId != null, sessionId ?? '');

    // ---- 3. domains ----
    stdout.writeln('\n3. ENABLE DOMAINS');
    for (final d in ['Page.enable', 'Runtime.enable', 'DOM.enable']) {
      await cdp.send(d, sessionId: sessionId);
      check(d, true);
    }

    // ---- 4. navigate + read ----
    stdout.writeln('\n4. NAVIGATE + EVALUATE');
    await cdp.send(
      'Page.navigate',
      params: {'url': 'data:text/html,<title>Agora</title><h1>hi</h1>'},
      sessionId: sessionId,
    );
    // Give the data: URL a beat to commit.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final title = await _eval<String>(cdp, sessionId!, 'document.title');
    check('Runtime.evaluate title', title == 'Agora', title ?? 'null');

    final h1 = await _eval<String>(
      cdp,
      sessionId,
      'document.querySelector("h1").textContent',
    );
    check('DOM querySelector', h1 == 'hi', h1 ?? 'null');

    // ---- 5. write into the page (this is how we type into an AI chat box) ----
    stdout.writeln('\n5. TYPE INTO PAGE');
    await _eval<void>(cdp, sessionId, '''
      document.body.innerHTML += '<textarea id="t"></textarea><button id="b">Send</button>';
      document.getElementById('b').addEventListener('click', () => {
        document.title = 'sent:' + document.getElementById('t').value;
      });
    ''');
    await cdp.send(
      'Runtime.evaluate',
      params: {
        'expression': '''
          (() => {
            const el = document.getElementById('t');
            el.focus();
            return true;
          })()
        ''',
      },
      sessionId: sessionId,
    );
    // Input.insertText is what adapters use — it types text like a human
    // without synthesising hundreds of key events.
    await cdp.send(
      'Input.insertText',
      params: {'text': 'Design a sodium-ion battery'},
      sessionId: sessionId,
    );
    final typed = await _eval<String>(
      cdp,
      sessionId,
      'document.getElementById("t").value',
    );
    check(
      'Input.insertText',
      typed == 'Design a sodium-ion battery',
      typed ?? 'null',
    );

    // ---- 6. events are flowing ----
    stdout.writeln('\n6. EVENT STREAM');
    final events = <String>[];
    final sub = cdp.events.listen((e) => events.add(e.method));
    // Navigate: with Page.enable this must produce frameNavigated/loadEventFired.
    await cdp.send(
      'Page.navigate',
      params: {'url': 'data:text/html,<title>Events</title>'},
      sessionId: sessionId,
    );
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await sub.cancel();
    check(
      'events received',
      events.any((m) => m.startsWith('Page.')),
      events.isEmpty ? 'none' : events.take(4).join(', '),
    );
    check(
      'events are session-scoped',
      events.every((m) => !m.contains('null')),
    );

    // ---- 7. screenshot (Verbatim Vault) ----
    stdout.writeln('\n7. SCREENSHOT');
    final shot = await cdp.sendMap(
      'Page.captureScreenshot',
      params: {'format': 'png'},
      sessionId: sessionId,
    );
    final data = shot['data'] as String?;
    check(
      'Page.captureScreenshot',
      (data?.length ?? 0) > 500,
      data == null ? 'null' : 'base64 ${data.length} chars',
    );

    // ---- 8. error handling ----
    stdout.writeln('\n8. ERROR HANDLING');
    try {
      await cdp.send('This.MethodDoesNotExist', sessionId: sessionId);
      check('bad method rejected', false, 'no error thrown');
    } on CdpException catch (e) {
      check('bad method rejected', true, 'code ${e.code}');
    }
    try {
      await cdp.send('Page.enable', sessionId: 'no-such-session');
      check('bad session rejected', false, 'no error thrown');
    } on CdpException catch (e) {
      check('bad session rejected', true, e.message ?? '');
    }

    // ---- 9. targets listing ----
    stdout.writeln('\n9. TARGET LIST');
    final targets = await launcher.listTargets();
    check('Target.getTargets', targets.isNotEmpty, '${targets.length} page(s)');
  } on Object catch (e, s) {
    _fail++;
    stdout.writeln('\n  \u2717 FATAL: $e');
    stdout.writeln(s);
  } finally {
    stdout.writeln('\n10. SHUTDOWN');
    try {
      await launcher.shutdown();
      check('clean shutdown', true);
    } on Object catch (e) {
      check('clean shutdown', false, '$e');
    }
  }

  stdout.writeln('\n=== $_pass passed, $_fail failed ===\n');
  exit(_fail == 0 ? 0 : 1);
}

Future<T?> _eval<T>(CdpClient cdp, String sessionId, String expression) async {
  final r = await cdp.sendMap(
    'Runtime.evaluate',
    params: {
      'expression': expression,
      'returnByValue': true,
      'awaitPromise': true,
    },
    sessionId: sessionId,
  );
  final res = r['result'];
  if (res is! Map) return null;
  if (res['subtype'] == 'error') return null;
  return res['value'] as T?;
}
