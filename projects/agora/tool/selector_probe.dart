// Manual, opt-in. Not part of `flutter test` and never wired into CI.
//
// The adapter JSON can validate perfectly and still be wrong about the live
// page, because a selector being syntactically valid says nothing about whether
// the site still has that node. This drives the real prober against the
// sandbox's mock AI site so the probe path itself is proven against real Chrome
// without needing a logged-in account to a real AI site.
//
//   dart run tool/selector_probe.dart
//
// Add --config <path> to probe any adapter JSON. The default is the sandbox
// fixture, whose selectors are known-good, so a red result here is a bug in the
// prober rather than a stale adapter.
import 'dart:convert';
import 'dart:io';

import 'package:agora/core/adapters/adapter_config.dart';
import 'package:agora/core/adapters/selector_prober.dart';

Future<void> main(List<String> args) async {
  final String path =
      _argValue(args, '--config') ?? 'tool/sandbox/adapter_sandbox.json';
  final File f = File(path);
  if (!f.existsSync()) {
    stderr.writeln('no such adapter: $path');
    exit(2);
  }

  final Object? raw = jsonDecode(f.readAsStringSync());
  if (raw is! Map<String, dynamic>) {
    stderr.writeln('adapter is not a JSON object: $path');
    exit(2);
  }
  final AdapterConfig cfg = AdapterConfig.fromJson(raw);

  final List<String> problems = cfg.validate();
  if (problems.isNotEmpty) {
    stderr.writeln(
      'adapter does not validate, so a probe would be meaningless:',
    );
    for (final String p in problems) {
      stderr.writeln('  - $p');
    }
    exit(2);
  }

  // 9224: 9222 is the app, 9223 is the sandbox smoke driver.
  final SelectorProber prober = SelectorProber(
    cdpPort: int.parse(_argValue(args, '--port') ?? '9224'),
    headless: !Platform.environment.containsKey('DISPLAY'),
  );

  int failures = 0;
  try {
    stdout.writeln(
      'probing ${cfg.displayName} (${cfg.kind}) at ${cfg.homeUrl}',
    );
    final SiteProbe report = await prober.probe(cfg);
    stdout.writeln('  url          : ${report.url}');
    stdout.writeln('  loaded       : ${report.loaded}');
    stdout.writeln('  shadow roots : ${report.shadowRoots}');
    stdout.writeln('  verdict      : ${report.headline}');
    stdout.writeln('');

    for (final ProbeOutcome o in report.outcomes) {
      final String mark = o.matched
          ? 'OK  '
          : (o.isEmptySpec ? 'SKIP' : (o.checkable ? 'MISS' : '----'));
      stdout.writeln('  [$mark] ${o.slot}');
      for (final SelectorHit h in o.hits) {
        stdout.writeln(
          '         ${h.kind.padRight(4)} ${h.verdict.padRight(16)} '
          '${h.selector}',
        );
        if (h.sample.isNotEmpty) {
          stdout.writeln('               -> "${h.sample}"');
        }
      }
      if (o.error != null) {
        stdout.writeln('         ERROR: ${o.error}');
      }
      // Only a checkable miss is a failure. A conditional slot on an empty
      // thread and a losing login state are both correct outcomes, and counting
      // them would make this tool report a red result on a healthy adapter.
      if (!o.matched && !o.isEmptySpec && o.checkable) failures++;
    }

    if (report.unverifiable.isNotEmpty) {
      stdout.writeln('');
      stdout.writeln(
        '  note: ${report.unverifiable.length} slot(s) could not be judged — '
        '${report.unverifiable.map((ProbeOutcome o) => o.slot).join(', ')} '
        'only appear once the thread holds a message. Send one, then probe '
        'again to check them.',
      );
    }

    stdout.writeln('');
    if (report.error != null) {
      stdout.writeln('FAILED: ${report.error}');
    } else if (report.outcomes.isEmpty) {
      stdout.writeln(
        'FAILED: the probe reached the page but scored no slots, so it '
        'is not actually asking the kernel anything',
      );
    } else if (failures > 0) {
      final String which = report.broken
          .map((ProbeOutcome o) => o.slot)
          .join(', ');
      stdout.writeln(
        'FAILED: $failures checkable slot(s) did not match: $which',
      );
    } else {
      stdout.writeln(
        'ALL OK: ${report.matchedCount} slot(s) matched on a real page'
        '${report.unverifiable.isEmpty ? '' : ', ${report.unverifiable.length} not judgeable yet'}',
      );
    }
  } finally {
    await prober.dispose();
  }

  exit(failures == 0 ? 0 : 1);
}

String? _argValue(List<String> args, String name) {
  final int i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}
