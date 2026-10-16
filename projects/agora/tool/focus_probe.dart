// Manual, opt-in probe. NOT part of CI and NOT part of `flutter test` -- it
// needs a real Chrome.
//
// Why this exists: `WebAgentAdapter.connect()` calls
// `Emulation.setFocusEmulationEnabled` and `send()` calls `Page.bringToFront`.
// Both are wrapped in try/catch so a site or Chrome build that rejects them
// degrades to "slower" instead of "broken". That is the right behaviour in the
// app and the wrong behaviour in a test -- a silent swallow means nobody would
// ever notice if Chrome stopped supporting either call. This probe makes the
// swallow observable.
//
//   dart run tool/focus_probe.dart
//
import 'dart:io';

import 'package:agora/core/chrome/chrome_launcher.dart';
import 'package:agora/core/cdp/cdp_client.dart';
import 'package:agora/core/council/tab_pool.dart';

Future<void> main(List<String> args) async {
  // `args` is unused; accepting it keeps the door open for a --serve mode
  // without a public CdpClient constructor to make it work today.
  assert(args.isEmpty || args.contains('--serve'), 'unknown arguments: $args');

  // A private port so the probe never collides with the user's Agora Chrome.
  const port = 9224;
  final profile = Directory.systemTemp
      .createTempSync('agora-focus-probe-')
      .path;
  final headless = (Platform.environment['DISPLAY'] ?? '').isEmpty;
  stdout.writeln('launching Chrome (headless=$headless, profile=$profile) ...');
  final launched = await ChromeLauncher().launch(
    preferredPort: port,
    profileDir: profile,
    headless: headless,
  );
  final client = launched.client;
  stdout.writeln(
    'browser: ${client.browserVersion}'
    '${launched.alreadyRunning ? ' (attached to an existing instance)' : ''}\n',
  );

  var failures = 0;
  Future<void> check(String label, Future<Object?> Function() call) async {
    try {
      final Object? res = await call();
      stdout.writeln('  OK   $label${res == null ? '' : ' -> $res'}');
    } on Object catch (e) {
      failures++;
      stdout.writeln('  FAIL $label -> ${e.runtimeType}: $e');
    }
  }

  // Two tabs: the second one is a genuine background tab, which is the only
  // situation the mitigation exists for.
  final Map<String, dynamic> a = await client.sendMap(
    'Target.createTarget',
    params: <String, dynamic>{'url': 'about:blank'},
  );
  final Map<String, dynamic> b = await client.sendMap(
    'Target.createTarget',
    params: <String, dynamic>{'url': 'about:blank'},
  );
  final targetA = '${a['targetId']}';
  final targetB = '${b['targetId']}';
  stdout.writeln('created targets $targetA (front) and $targetB (background)\n');

  final Map<String, dynamic> sB = await client.sendMap(
    'Target.attachToTarget',
    params: <String, dynamic>{'targetId': targetB, 'flatten': true},
  );
  final sessionB = '${sB['sessionId']}';
  stdout.writeln('background session $sessionB\n');

  await _send(client, 'Page.enable', sessionB);
  await _send(client, 'Runtime.enable', sessionB);

  stdout.writeln('Emulation / Page calls on a BACKGROUND tab:');
  await check('Emulation.setFocusEmulationEnabled{enabled:true}', () async {
    await _send(
      client,
      'Emulation.setFocusEmulationEnabled',
      sessionB,
      params: <String, dynamic>{'enabled': true},
    );
    return 'accepted';
  });

  await check('Page.bringToFront', () async {
    await _send(client, 'Page.bringToFront', sessionB);
    return 'accepted';
  });

  await check('Page.captureScreenshot', () async {
    final Map<String, dynamic> r = await client.sendMap(
      'Page.captureScreenshot',
      params: <String, dynamic>{'format': 'png'},
      sessionId: sessionB,
    );
    final data = '${r['data'] ?? ''}';
    return '${data.length} base64 chars';
  });

  // Toggling it back off must also be legal, so the call is a real API and not
  // a lucky no-op.
  await check('Emulation.setFocusEmulationEnabled{enabled:false}', () async {
    await _send(
      client,
      'Emulation.setFocusEmulationEnabled',
      sessionB,
      params: <String, dynamic>{'enabled': false},
    );
    return 'accepted';
  });

  stdout.writeln('\ntarget list after bringToFront (order is the tab strip order):');
  try {
    final Map<String, dynamic> targets = await client.sendMap(
      'Target.getTargets',
    );
    for (final t in (targets['targetInfos'] as List? ?? const [])) {
      final m = t as Map<String, dynamic>;
      stdout.writeln('  ${m['targetId']}  ${m['url']}');
    }
  } on Object catch (e) {
    stdout.writeln('  (Target.getTargets failed: $e)');
  }

  // Exercise TabPool itself, not just the raw calls above. The pool is the code
  // Agora actually ships, so a probe that only proves the CDP verbs would still
  // let a bug in TabPool.capture reach the vault unchecked.
  stdout.writeln('\nTabPool:');
  final pool = TabPool(client);
  await check('TabPool.open x2', () async {
    await pool.open('alpha', url: 'data:text/html,<h1>alpha</h1>');
    await pool.open('beta', url: 'data:text/html,<h1>beta</h1>');
    return '${pool.length} tabs open';
  });
  await check('TabPool.open is idempotent', () async {
    final again = await pool.open('alpha');
    if (again != pool.targetOf('alpha')) {
      throw StateError('reopen returned a different target: $again');
    }
    return 'alpha -> ${again.substring(0, 8)}';
  });
  await check('TabPool.capture returns a real PNG', () async {
    final png = await pool.capture('alpha');
    if (png == null || png.length < 8) {
      throw StateError('capture returned ${png?.length} bytes');
    }
    // PNG magic number: proves the bytes are an image, not an error page.
    const magic = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (var i = 0; i < magic.length; i++) {
      if (png[i] != magic[i]) {
        throw StateError('not a PNG at byte $i: ${png[i]}');
      }
    }
    return '${png.length} bytes, PNG magic verified';
  });
  await check(
    'TabPool.capture on an unknown kind is null, not a throw',
    () async {
      final png = await pool.capture('gamma');
      if (png != null) {
        throw StateError('expected null, got ${png.length} bytes');
      }
      return 'null';
    },
  );
  await check('TabPool.bringToFront', () async {
    await pool.bringToFront('beta');
    return 'accepted';
  });
  await check('TabPool.closeAll leaves nothing behind', () async {
    await pool.closeAll();
    if (pool.length != 0) throw StateError('${pool.length} tabs still tracked');
    return '${pool.length} tabs tracked';
  });

  for (final t in [targetA, targetB]) {
    await _send(
      client,
      'Target.closeTarget',
      null,
      params: <String, dynamic>{'targetId': t},
    );
  }

  await client.close();
  try {
    final d = Directory(profile);
    if (d.existsSync()) await d.delete(recursive: true);
  } on Object catch (_) {
    // A leftover temp profile is harmless.
  }

  stdout.writeln('\n${failures == 0 ? 'ALL OK' : '$failures FAILED'}');
  exit(failures == 0 ? 0 : 1);
}

Future<void> _send(
  CdpClient client,
  String method,
  String? sessionId, {
  Map<String, dynamic>? params,
}) => client.send(method, params: params, sessionId: sessionId);
