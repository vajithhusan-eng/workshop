// Validates every bundled adapter config without launching Chrome.
// Usage: dart run tool/registry_check.dart
import 'dart:io';

import 'package:agora/core/adapters/adapter_config.dart';

const required = ['composer', 'send', 'extraction'];

Future<void> main() async {
  final dir = Directory('assets/adapters');
  if (!dir.existsSync()) {
    stderr.writeln('no assets/adapters directory');
    exit(2);
  }
  var pass = 0, fail = 0;
  for (final e
      in dir.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path))) {
    if (!e.path.endsWith('.json')) continue;
    final name = e.path.split('/').last;
    try {
      final c = AdapterConfig.parse(e.readAsStringSync(), origin: name);
      final errs = c.validate();
      if (errs.isEmpty) {
        print(
          'PASS $name  kind=${c.kind}  v=${c.version}  '
          'composer=${c.composer.candidateCount}  models=${c.modelPicker.labels.length}',
        );
        pass++;
      } else {
        fail++;
        for (final x in errs) {
          print('FAIL $name  $x');
        }
      }
    } on FormatException catch (err) {
      fail++;
      print('FAIL $name  ${err.message}');
    }
  }
  print('\n$pass passed, $fail failed');
  exit(fail == 0 ? 0 : 1);
}
