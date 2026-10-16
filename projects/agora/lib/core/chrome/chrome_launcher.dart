import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../logging.dart';
import '../cdp/cdp_client.dart';
import 'chrome_mode.dart';

/// Where Agora keeps its own data. Never the user's everyday Chrome profile:
/// Chrome 136+ refuses `--remote-debugging-port` on the default user-data-dir,
/// so Agora owns a dedicated profile that persists logins.
class AgoraPaths {
  AgoraPaths._();

  static String get _xdgConfig {
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty) return xdg;
    return p.join(_home, '.config');
  }

  static String get _home =>
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '/tmp';

  /// Root of all Agora state.
  static String get root => p.join(_xdgConfig, 'agora');

  /// Chrome's dedicated user-data-dir. Log in once per site; cookies persist.
  static String get chromeProfile => p.join(root, 'chrome-profile');

  static String get logsDir => p.join(root, 'logs');
  static String get chromeLog => p.join(logsDir, 'chrome.log');
  static String get agoraLog => p.join(logsDir, 'agora.log');

  /// Screenshots and other blobs referenced by the Verbatim Vault.
  static String get vaultDir => p.join(root, 'vault');

  /// Creates the directory tree. Safe to call repeatedly.
  static Future<void> ensureDirs() async {
    for (final d in [root, logsDir, vaultDir, chromeProfile]) {
      await Directory(d).create(recursive: true);
    }
  }
}

class ChromeLaunchResult {
  const ChromeLaunchResult({
    required this.client,
    required this.process,
    required this.port,
    required this.alreadyRunning,
    required this.binary,
  });

  final CdpClient client;

  /// The process Agora spawned, or `null` when attaching to an existing one.
  final Process? process;
  final int port;

  /// True when we attached to a Chrome Agora had already launched.
  final bool alreadyRunning;
  final String binary;
}

class ChromeLauncher {
  ChromeLauncher({Logger? log}) : _log = log ?? Logger('chrome');

  final Logger _log;

  /// Candidate Chrome binaries, most preferred first.
  static const _candidates = <String>[
    'google-chrome',
    'google-chrome-stable',
    'chromium',
    'chromium-browser',
    'chrome',
  ];

  CdpClient? _client;
  Process? _process;
  int? _port;

  bool get isRunning => _client != null && !_client!.isClosed;
  CdpClient? get client => _client;

  /// The CDP port this launcher is bound to, once running.
  int? get port => _port;

  /// Find a usable Chrome/Chromium binary, or explain why none is usable.
  static Future<String?> findBinary() async {
    for (final name in _candidates) {
      final r = await Process.run('which', [name]);
      if (r.exitCode == 0) {
        final path = (r.stdout as String).trim();
        if (path.isNotEmpty) return path;
      }
    }
    return null;
  }

  /// GET /json/version from a CDP port, returning the browser metadata.
  Future<Map<String, dynamic>?> probe(
    int port, {
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = timeout;
    try {
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:$port/json/version'))
          .timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      return (jsonDecode(body) as Map).cast<String, dynamic>();
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Find a free TCP port, preferring [preferred] when it is available.
  static Future<int> _findFreePort(int preferred) async {
    for (var port = preferred; port < preferred + 50; port++) {
      try {
        final socket = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        await socket.close();
        return port;
      } on SocketException {
        // Port already taken — advance to the next candidate.
        continue;
      }
    }
    throw StateError('no free port in $preferred..${preferred + 50}');
  }

  /// Launch (or attach to) Chrome with Agora's dedicated profile and connect.
  ///
  /// Flags are deliberately conservative: we drive the UI a human sees, so the
  /// window is visible and not sandboxed away.
  Future<ChromeLaunchResult> launch({
    int preferredPort = 9222,
    String? profileDir,
    List<String>? extraArgs,
    bool headless = false,
    bool silent = false,
  }) async {
    await AgoraPaths.ensureDirs();

    final binary = await findBinary();
    if (binary == null) {
      throw StateError(
        'No Chrome/Chromium binary found. Agora drives your system Chrome.\n'
        'Install it with:  sudo apt install google-chrome-stable',
      );
    }
    _log.i('binary: $binary');

    final profile = profileDir ?? AgoraPaths.chromeProfile;
    await Directory(profile).create(recursive: true);

    // 1) Attach to a Chrome Agora already started on the preferred port.
    final existing = await probe(preferredPort);
    if (existing != null) {
      _log.i('attaching to existing Chrome on :$preferredPort');
      final wsUrl = existing['webSocketDebuggerUrl'] as String?;
      if (wsUrl == null) {
        throw StateError('Chrome on :$preferredPort has no debugger URL');
      }
      final c = await CdpClient.connect(Uri.parse(wsUrl));
      _client = c;
      _port = preferredPort;
      return ChromeLaunchResult(
        client: c,
        process: null,
        port: preferredPort,
        alreadyRunning: true,
        binary: binary,
      );
    }

    // 2) Launch a fresh one.
    final port = await _findFreePort(preferredPort);
    _log.i('launching on :$port with profile $profile');

    final args = <String>[
      // The dedicated profile is the whole trick — see AgoraPaths.chromeProfile.
      '--user-data-dir=$profile',
      '--remote-debugging-port=$port',
      '--remote-allow-origins=*',
      // Keep the user logged in across restarts.
      '--no-first-run',
      '--no-default-browser-check',
      // Avoid Chrome's own automation banner.
      '--disable-features=Translate,MediaRouter,OptimizationHints',
      ...chromeWindowArgs(headless: headless, silent: silent),
      ...?extraArgs,
      'about:blank',
    ];

    final proc = await Process.start(binary, args);
    _process = proc;
    _port = port;

    // Surface Chrome's stderr — this is the first place profile problems show up.
    proc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      if (line.trim().isNotEmpty) _log.d('chrome: $line');
    });
    proc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      if (line.trim().isNotEmpty) _log.d('chrome: $line');
    });

    // Chrome exits immediately if another instance already owns the profile
    // and was started WITHOUT the debugging port. That is the single most
    // confusing failure mode, so detect and explain it.
    final exitCode = await proc.exitCode
        .then<int?>((c) => c)
        .catchError((_) => null)
        .timeout(const Duration(seconds: 4), onTimeout: () => null);
    if (exitCode != null) {
      _log.w('chrome exited immediately with code $exitCode');
      _process = null;
      throw StateError(
        'Chrome started but exited immediately (code $exitCode).\n\n'
        'This almost always means another Chrome window is already using\n'
        '$profile without a debugging port.\n\n'
        'Fix: close every Chrome window, then start Agora again.\n'
        'Alternatively point Agora at a different profile directory.',
      );
    }

    // 3) Wait for the debugging port to answer.
    final version = await _awaitPort(port);
    final wsUrl = version['webSocketDebuggerUrl'] as String?;
    if (wsUrl == null) {
      await _killProcess();
      throw StateError('Chrome is up but exposed no webSocketDebuggerUrl');
    }

    final c = await CdpClient.connect(Uri.parse(wsUrl));
    _client = c;
    return ChromeLaunchResult(
      client: c,
      process: proc,
      port: port,
      alreadyRunning: false,
      binary: binary,
    );
  }

  Future<Map<String, dynamic>> _awaitPort(
    int port, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var attempt = 0;
    while (DateTime.now().isBefore(deadline)) {
      attempt++;
      final v = await probe(port);
      if (v != null) {
        _log.i('CDP ready after $attempt probe(s) on :$port');
        return v;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await _killProcess();
    throw TimeoutException(
      'Chrome did not expose CDP on :$port within ${timeout.inSeconds}s',
      timeout,
    );
  }

  /// List the pages Chrome currently has open.
  Future<List<Map<String, dynamic>>> listTargets() async {
    final c = _client;
    if (c == null || c.isClosed) return const [];
    final res = await c.send('Target.getTargets', params: const {});
    final list = (res as Map)['targetInfos'] as List? ?? const [];
    return list
        .cast<Map>()
        .map((e) => e.cast<String, dynamic>())
        .where((e) => e['type'] == 'page')
        .toList();
  }

  Future<void> _killProcess() async {
    final proc = _process;
    _process = null;
    if (proc == null) return;
    try {
      proc.kill(ProcessSignal.sigterm);
      await proc.exitCode.timeout(const Duration(seconds: 5));
    } on Object catch (e) {
      _log.w('graceful shutdown failed, forcing', e);
      try {
        proc.kill(ProcessSignal.sigkill);
      } on Object catch (_) {
        /* already gone */
      }
    }
  }

  /// Close the CDP connection and, if we started Chrome, shut it down.
  Future<void> shutdown({bool closeBrowser = true}) async {
    final c = _client;
    _client = null;

    if (closeBrowser && c != null && !c.isClosed) {
      // Ask Chrome to close cleanly so the profile's lock files and session
      // state are flushed; an abrupt kill can corrupt the profile.
      try {
        await c.send('Browser.close', timeout: const Duration(seconds: 3));
      } on Object catch (e) {
        _log.d('Browser.close: $e');
      }
    }
    await c?.close();
    if (closeBrowser) await _killProcess();
    _port = null;
    _log.i('shutdown complete');
  }
}
