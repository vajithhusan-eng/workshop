import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves an adapter kind to the raw JSON that describes it.
///
/// Adapters are data, not code, and *where* that data lives differs by host:
/// the desktop app reads its asset bundle, while a command-line tool reads a
/// directory of JSON files. The council layer depends only on this signature so
/// it never has to import `flutter/services` — which would drag `dart:ui` in and
/// make `dart run` impossible for every tool that touches the engine.
typedef AdapterLoader = Future<String> Function(String kind);

/// Loads `$dir/$kind.json`.
///
/// Throws rather than returning null: a missing adapter is a broken install, and
/// the caller turns that into a message the user can act on.
AdapterLoader fileAdapterLoader(String dir) {
  return (String kind) async {
    final file = File(p.join(dir, '$kind.json'));
    if (!file.existsSync()) {
      throw FileSystemException('no adapter named "$kind"', file.path);
    }
    return file.readAsString();
  };
}
