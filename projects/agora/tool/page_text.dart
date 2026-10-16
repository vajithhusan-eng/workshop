// Dump what a real site currently renders (title + visible text) through the
// app profile, so adapter selectors can be written against ground truth.
//
//   dart run tool/page_text.dart https://chat.deepseek.com/
//
// Read-only: opens a tab, dumps text, closes. Never sends anything.
import 'dart:io';

import 'package:agora/core/chrome/chrome_launcher.dart';
import 'package:agora/core/council/tab_pool.dart';

Future<void> main(List<String> args) async {
  final url = args.firstWhere(
    (a) => a.startsWith('https://'),
    orElse: () => 'https://chatgpt.com/',
  );
  final port =
      int.tryParse(
        args.where((a) => a.startsWith('--port=')).firstOrNull?.substring(7) ??
            '',
      ) ??
      9227;

  final launch = await ChromeLauncher().launch(
    preferredPort: port,
    profileDir: AgoraPaths.chromeProfile,
    headless: (Platform.environment['DISPLAY'] ?? '').isEmpty,
  );
  final pool = TabPool(launch.client);
  try {
    // `sessionFor` takes the kind, not the target id — the returned id is dead.
    await pool.open('dump', url: url);
    final session = await pool.sessionFor('dump');
    if (session == null) {
      stderr.writeln('could not attach');
      exit(2);
    }
    await launch.client.send('Runtime.enable', sessionId: session);
    // Wait for the SPA to settle.
    await Future<void>.delayed(const Duration(seconds: 6));
    final res = await launch.client.sendMap(
      'Runtime.evaluate',
      params: <String, dynamic>{
        'expression': '''
(() => {
  const walk = (root, out) => {
    for (const el of root.querySelectorAll('*')) {
      const cs = getComputedStyle(el);
      if (cs.display === 'none' || cs.visibility === 'hidden') continue;
      const t = (el.childElementCount === 0 ? el.textContent : '');
      if (t && t.trim()) out.push(t.trim());
    }
  };
  const out = [];
  walk(document.body, out);
  return {
    url: location.href,
    title: document.title,
    text: [...new Set(out)].slice(0, 200),
  };
})()
''',
        'returnByValue': true,
      },
      sessionId: session,
      timeout: const Duration(seconds: 20),
    );
    final value = res['result']?['value'];
    if (value is Map<String, dynamic>) {
      stdout.writeln('URL   : ${value['url']}');
      stdout.writeln('TITLE : ${value['title']}');
      stdout.writeln('TEXT  :');
      for (final t in (value['text'] as List<Object?>? ?? const [])) {
        stdout.writeln('  - ${t.toString().replaceAll('\n', ' ')}');
      }
    } else {
      stderr.writeln('no value: $res');
    }
  } finally {
    await pool.closeAll();
    await launch.client.close();
  }
}
