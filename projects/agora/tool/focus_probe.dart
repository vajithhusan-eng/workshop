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
  print('launching Chrome (headless=$headless, profile=$profile) ...');
  final launched = await ChromeLauncher().launch(
    preferredPort: port,
    profileDir: profile,
    headless: headless,
  );
  final client = launched.client;
  print(
    'browser: ${client.browserVersion}'
    '${launched.alreadyRunning ? ' (attached to an existing instance)' : ''}\n',
  );

  var failures = 0;
  Future<void> check(String label, Future<Object?> Function() call) async {
    try {
      final Object? res = await call();
      print('  OK   $label${res == null ? '' : ' -> $res'}');
    } on Object catch (e) {
      failures++;
      print('  FAIL $label -> ${e.runtimeType}: $e');
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
  print('created targets $targetA (front) and $targetB (background)\n');

  final Map<String, dynamic> sB = await client.sendMap(
    'Target.attachToTarget',
    params: <String, dynamic>{'targetId': targetB, 'flatten': true},
  );
  final sessionB = '${sB['sessionId']}';
  print('background session $sessionB\n');

  await _send(client, 'Page.enable', sessionB);
  await _send(client, 'Runtime.enable', sessionB);

  print('Emulation / Page calls on a BACKGROUND tab:');
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

  print('\ntarget list after bringToFront (order is the tab strip order):');
  try {
    final Map<String, dynamic> targets = await client.sendMap(
      'Target.getTargets',
    );
    for (final t in (targets['targetInfos'] as List? ?? const [])) {
      final m = t as Map<String, dynamic>;
      print('  ${m['targetId']}  ${m['url']}');
    }
  } on Object catch (e) {
    print('  (Target.getTargets failed: $e)');
  }

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

  print('\n${failures == 0 ? 'ALL OK' : '$failures FAILED'}');
  exit(failures == 0 ? 0 : 1);
}

Future<void> _send(
  CdpClient client,
  String method,
  String? sessionId, {
  Map<String, dynamic>? params,
}) => client.send(method, params: params, sessionId: sessionId);
