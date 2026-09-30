import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/logging.dart';
import 'adapter_config.dart';

/// Where a single adapter config came from. Used by the Calibration Studio to
/// show "this is your local override, the bundled copy is still v3".
enum AdapterOrigin { bundled, user, sandbox, memory }

/// One loaded adapter plus the provenance the UI needs.
class RegisteredAdapter {
  RegisteredAdapter({
    required this.config,
    required this.origin,
    required this.source,
  });

  final AdapterConfig config;
  final AdapterOrigin origin;

  /// File path, asset name, or "<memory>" — shown in the Calibration Studio.
  final String source;

  String get kind => config.kind;

  /// User configs win over bundled ones, so they can pin a broken version.
  int get precedence => _precedenceOf(origin);

  @override
  String toString() =>
      'RegisteredAdapter(${config.kind} v${config.version}, '
      '$origin, $source)';
}

int _precedenceOf(AdapterOrigin o) => switch (o) {
  AdapterOrigin.user => 300,
  AdapterOrigin.sandbox => 250,
  AdapterOrigin.bundled => 200,
  AdapterOrigin.memory => 100,
};

/// A file that failed to load. Never fatal — a broken user override must not
/// take down the whole app, it just has to be visible and fixable.
class AdapterLoadError {
  AdapterLoadError({required this.source, required this.message, this.kind});

  final String source;
  final String message;
  final String? kind;

  @override
  String toString() => '$source: $message';
}

/// Where bundled adapter JSON is looked up inside an asset bundle.
const String kBundledAdapterDir = 'assets/adapters/';

/// Loads, overlays and hot-reloads adapter configs.
///
/// The whole point: a chatgpt.com redesign is fixed by dropping a new JSON
/// file into `~/.config/agora/adapters/`. No app release, no recompile.
class AdapterRegistry extends ChangeNotifier {
  AdapterRegistry({
    this.userDir,
    AssetBundle? bundle,
    this.bundledDir = kBundledAdapterDir,
  }) : _bundle = bundle;

  /// `~/.config/agora/adapters` — user overrides, hot-reloaded on change.
  final String? userDir;

  /// Asset bundle holding the shipped defaults. Null in pure-Dart tests.
  final AssetBundle? _bundle;

  final String bundledDir;

  final Map<String, RegisteredAdapter> _byKind = <String, RegisteredAdapter>{};
  final List<AdapterLoadError> _errors = <AdapterLoadError>[];
  StreamSubscription<FileSystemEvent>? _watch;
  Timer? _debounce;
  bool _loaded = false;
  bool _reloading = false;

  bool get isLoaded => _loaded;
  bool get isEmpty => _byKind.isEmpty;

  List<RegisteredAdapter> get all {
    final list = _byKind.values.toList()
      ..sort((a, b) => a.config.displayName.compareTo(b.config.displayName));
    return List<RegisteredAdapter>.unmodifiable(list);
  }

  List<String> get kinds => _byKind.keys.toList()..sort();

  List<AdapterLoadError> get errors =>
      List<AdapterLoadError>.unmodifiable(_errors);

  bool has(String kind) => _byKind.containsKey(kind);

  RegisteredAdapter? byKind(String kind) => _byKind[kind];

  AdapterConfig? configOf(String kind) => _byKind[kind]?.config;

  // ------------------------------------------------------------------ load

  /// First load: bundled assets, then the user directory (which overlays).
  Future<void> load({bool watch = true}) async {
    _errors.clear();
    _byKind.clear();

    await _loadBundled();
    await _loadUserDir();

    _loaded = true;
    notifyListeners();
    log.i(
      'adapter registry: ${_byKind.length} adapters, '
      '${_errors.length} errors',
    );

    if (watch && userDir != null) {
      _startWatching();
    }
  }

  Future<void> _loadBundled() async {
    final bundle = _bundle;
    if (bundle == null) return;

    List<String> keys;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      keys =
          manifest
              .listAssets()
              .where((k) => k.startsWith(bundledDir) && k.endsWith('.json'))
              .toList()
            ..sort();
    } catch (e) {
      _errors.add(
        AdapterLoadError(
          source: 'asset://$bundledDir',
          message: 'cannot read asset manifest: $e',
        ),
      );
      return;
    }

    for (final key in keys) {
      String raw;
      try {
        raw = await bundle.loadString(key);
      } catch (e) {
        _errors.add(
          AdapterLoadError(source: 'asset://$key', message: 'cannot read: $e'),
        );
        continue;
      }
      _ingest(_Source('asset:$key', raw), AdapterOrigin.bundled);
    }
  }

  Future<void> _loadUserDir() async {
    final dir = userDir;
    if (dir == null) return;

    final handle = Directory(dir);
    if (!await handle.exists()) {
      // Create it so the user has an obvious place to drop selector fixes.
      try {
        await handle.create(recursive: true);
      } on FileSystemException catch (e) {
        _errors.add(
          AdapterLoadError(
            source: dir,
            message: 'cannot create user adapter dir: ${e.message}',
          ),
        );
      }
      return;
    }

    List<FileSystemEntity> files;
    try {
      files = await handle.list(followLinks: false).toList();
    } on FileSystemException catch (e) {
      _errors.add(
        AdapterLoadError(
          source: dir,
          message: 'cannot list user adapter dir: ${e.message}',
        ),
      );
      return;
    }

    files.sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      if (f is! File) continue;
      if (!f.path.toLowerCase().endsWith('.json')) continue;
      final raw = await _readOrNull(f.path);
      if (raw == null) continue;
      _ingest(_Source(f.path, raw), AdapterOrigin.user);
    }
  }

  // --------------------------------------------------------------- watching

  void _startWatching() {
    _watch?.cancel();
    _watch = null;
    try {
      final dir = Directory(userDir!);
      _watch = dir.watch().listen(
        (event) {
          // Editors write in bursts (tmp file + rename); debounce so we parse once.
          _debounce?.cancel();
          _debounce = Timer(
            const Duration(milliseconds: 250),
            () => unawaited(reload()),
          );
        },
        onError: (Object e) {
          log.w('adapter watcher error: $e');
        },
      );
    } on FileSystemException catch (e) {
      log.w('adapter watch failed on $userDir: ${e.message}');
    }
  }

  /// Re-read everything. Cheap: a handful of small JSON files.
  Future<void> reload() async {
    if (_reloading) return;
    _reloading = true;
    try {
      final before = _signature;
      await load(watch: _watch != null);
      if (_signature != before) {
        log.i('adapter registry hot-reloaded');
      }
    } finally {
      _reloading = false;
    }
  }

  String get _signature => _byKind.entries
      .map(
        (e) =>
            '${e.key}@${e.value.config.version}@${e.value.config.encode().hashCode}',
      )
      .join('|');

  // ------------------------------------------------------------- registering

  /// Install or update an adapter in memory (Calibration Studio "apply fix").
  /// Also persisted to the user dir when one exists, so it survives restart.
  Future<bool> upsert(AdapterConfig config, {String? source}) async {
    final persisting = source == null;
    final entry = RegisteredAdapter(
      config: config,
      origin: persisting ? AdapterOrigin.memory : AdapterOrigin.user,
      source: source ?? '<memory>',
    );

    final existing = _byKind[config.kind];
    if (existing != null && existing.precedence > entry.precedence) {
      _errors.add(
        AdapterLoadError(
          source: entry.source,
          kind: config.kind,
          message:
              'refused: a ${existing.origin} config already owns this kind',
        ),
      );
      notifyListeners();
      return false;
    }
    _byKind[config.kind] = entry;
    notifyListeners();

    if (!persisting || userDir == null) return true;

    final file = File(
      '${userDir!}${Platform.pathSeparator}${config.kind}.json',
    );
    try {
      await file.writeAsString(config.encode());
      _errors.removeWhere((e) => e.source == file.path);
      return true;
    } on FileSystemException catch (e) {
      _errors.add(
        AdapterLoadError(
          source: file.path,
          kind: config.kind,
          message: 'could not persist: ${e.message}',
        ),
      );
      notifyListeners();
      return false;
    }
  }

  /// Delete a user override, falling back to the bundled config.
  Future<void> remove(String kind) async {
    final dir = userDir;
    if (dir != null) {
      final f = File('$dir${Platform.pathSeparator}$kind.json');
      if (await f.exists()) {
        try {
          await f.delete();
        } on FileSystemException catch (e) {
          _errors.add(
            AdapterLoadError(
              source: f.path,
              kind: kind,
              message: 'could not delete: ${e.message}',
            ),
          );
          notifyListeners();
          return;
        }
      }
    }
    await reload();
  }

  // ------------------------------------------------------------------ ingest

  void _ingest(_Source entry, AdapterOrigin origin) {
    try {
      final config = AdapterConfig.parse(entry.raw, origin: entry.name);
      if (!config.isValid) {
        _errors.add(
          AdapterLoadError(
            source: entry.name,
            kind: config.kind,
            message: 'invalid: ${config.validate().join('; ')}',
          ),
        );
        return;
      }
      final existing = _byKind[config.kind];
      if (existing != null && existing.precedence > _precedenceOf(origin)) {
        log.d(
          'adapter ${config.kind}: keeping ${existing.source} over '
          '${entry.name} (${existing.origin} wins)',
        );
        return;
      }
      _byKind[config.kind] = RegisteredAdapter(
        config: config,
        origin: origin,
        source: entry.name,
      );
      _errors.removeWhere((e) => e.source == entry.name);
    } on FormatException catch (e) {
      _errors.add(AdapterLoadError(source: entry.name, message: e.message));
      log.w('adapter file rejected: ${entry.name}: ${e.message}');
    } catch (e) {
      _errors.add(
        AdapterLoadError(source: entry.name, message: 'unexpected: $e'),
      );
    }
  }

  Future<String?> _readOrNull(String path) async {
    try {
      return await File(path).readAsString();
    } on FileSystemException catch (e) {
      _errors.add(AdapterLoadError(source: path, message: e.message));
      return null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_watch?.cancel());
    _watch = null;
    super.dispose();
  }
}

class _Source {
  const _Source(this.name, this.raw);
  final String name;
  final String raw;
}
