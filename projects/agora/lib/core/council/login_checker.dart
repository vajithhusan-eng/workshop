import 'package:agora/core/adapters/adapter_config.dart';
import 'package:agora/core/adapters/agent_adapter.dart';
import 'package:agora/core/adapters/web_agent_adapter.dart';
import 'package:agora/core/chrome/chrome_launcher.dart';
import 'package:agora/core/logging.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'tab_pool.dart';

/// One site's sign-in state, with enough detail for a first-run wizard to tell
/// the user exactly what to do about it.
class LoginCheck {
  const LoginCheck({
    required this.kind,
    required this.displayName,
    required this.status,
    this.url = '',
    this.detail = '',
  });

  final String kind;
  final String displayName;
  final LoginStatus status;
  final String url;
  final String detail;

  bool get ready => status == LoginStatus.ready;

  /// The one sentence a first-run wizard should show for this row.
  String get remedy => switch (status) {
    LoginStatus.ready => 'Signed in.',
    LoginStatus.unknown => 'Not checked yet.',
    LoginStatus.loggedOut => 'Sign in to this site in the Agora Chrome window.',
    LoginStatus.captcha =>
      'A bot challenge is blocking the page — solve it in the window.',
    LoginStatus.rateLimited =>
      'The site is throttling this profile. Wait, or sign in again.',
    LoginStatus.needsRepair =>
      'The stored selectors no longer match this site. Recalibrate in the Calibration Studio.',
    LoginStatus.transportError =>
      'Could not reach the page. Check that Chrome started and the site loaded.',
  };
}

/// Checks whether Agora's own Chrome profile is signed in to each AI site.
///
/// Tabs are deliberately **kept open** after a check: when a site is signed out
/// the remedy is for the user to sign in to the window that is already on the
/// screen, not for Agora to close it and open another. `dispose()` cleans up.
class LoginChecker {
  LoginChecker({this.cdpPort = 9222, this.headless = false});

  final int cdpPort;
  final bool headless;

  ChromeLaunchResult? _launch;
  TabPool? _pool;
  bool _disposed = false;

  static final Logger _log = Logger('login_checker');

  /// Opens a tab per site at its home URL without probing. Used by the
  /// "open Chrome to sign in" affordance, where the point is the window, not
  /// the answer.
  Future<void> openSignInTabs(List<String> kinds) async {
    final pool = await _ensurePool();
    for (final kind in kinds) {
      final cfg = await _loadConfig(kind);
      if (cfg == null) continue;
      if (pool.targetOf(kind) != null) continue;
      try {
        await pool.open(kind, url: cfg.homeUrl);
      } on Object catch (e) {
        _log.w('could not open a tab for $kind', e);
      }
    }
  }

  /// Probes every site in one Chrome session and returns one row per site.
  ///
  /// A single failure — Chrome refusing to launch, say — is reported as a
  /// transport error on every site rather than thrown, because the wizard needs
  /// a complete list to render and "Chrome did not start" is not something the
  /// user can fix by signing in.
  Future<List<LoginCheck>> checkAll(List<String> kinds) async {
    TabPool? pool;
    try {
      pool = await _ensurePool();
    } on Object catch (e) {
      _log.e('Chrome did not start', e);
      return <LoginCheck>[
        for (final kind in kinds)
          LoginCheck(
            kind: kind,
            displayName: kind,
            status: LoginStatus.transportError,
            detail: 'Chrome did not start: $e',
          ),
      ];
    }

    final out = <LoginCheck>[];
    for (final kind in kinds) {
      out.add(await _checkOne(kind, pool));
    }
    return out;
  }

  Future<LoginCheck> _checkOne(String kind, TabPool pool) async {
    final cfg = await _loadConfig(kind);
    if (cfg == null) {
      return LoginCheck(
        kind: kind,
        displayName: kind,
        status: LoginStatus.needsRepair,
        detail: 'no adapter file at assets/adapters/$kind.json',
      );
    }
    final problems = cfg.validate();
    if (problems.isNotEmpty) {
      return LoginCheck(
        kind: kind,
        displayName: cfg.displayName,
        url: cfg.homeUrl,
        status: LoginStatus.needsRepair,
        detail: problems.join('; '),
      );
    }

    WebAgentAdapter? adapter;
    try {
      final targetId = await pool.open(kind, url: cfg.homeUrl);
      adapter = WebAgentAdapter(
        config: cfg,
        client: _launch!.client,
        targetId: targetId,
      );
      final state = await adapter.connect();
      return LoginCheck(
        kind: kind,
        displayName: cfg.displayName,
        url: state.url.isEmpty ? cfg.homeUrl : state.url,
        status: state.status,
        detail: state.message,
      );
    } on Object catch (e) {
      _log.w('probe failed for $kind', e);
      return LoginCheck(
        kind: kind,
        displayName: cfg.displayName,
        url: cfg.homeUrl,
        status: LoginStatus.transportError,
        detail: '$e',
      );
    } finally {
      // Detach but keep the tab: closing it would close the window the user
      // may need in order to sign in.
      try {
        await adapter?.close();
      } on Object catch (e) {
        _log.w('could not detach $kind', e);
      }
    }
  }

  Future<AdapterConfig?> _loadConfig(String kind) async {
    try {
      final raw = await rootBundle.loadString('assets/adapters/$kind.json');
      return AdapterConfig.parse(raw, origin: 'assets/adapters/$kind.json');
    } on Object catch (e) {
      _log.w('adapter $kind is missing or unreadable', e);
      return null;
    }
  }

  Future<TabPool> _ensurePool() async {
    if (_disposed) {
      throw StateError('LoginChecker was disposed');
    }
    final existing = _pool;
    if (existing != null) return existing;
    await AgoraPaths.ensureDirs();
    final launch = await ChromeLauncher().launch(
      preferredPort: cdpPort,
      profileDir: AgoraPaths.chromeProfile,
      headless: headless,
    );
    _launch = launch;
    _pool = TabPool(launch.client);
    return _pool!;
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _pool?.closeAll();
    } on Object catch (e) {
      _log.w('could not close tabs', e);
    }
    try {
      await _launch?.client.close();
    } on Object catch (e) {
      _log.w('could not close the CDP client', e);
    }
    _pool = null;
    _launch = null;
  }
}
