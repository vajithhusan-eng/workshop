import 'dart:convert';
import 'dart:typed_data';

import '../cdp/cdp_client.dart';

/// One Chrome tab per AI, created and destroyed over CDP.
///
/// This is the missing primitive: until now `Target.createTarget` had zero call
/// sites anywhere in `lib/`, which is why the tab pool in PLAN.md could not be
/// built. Agora owns exactly one tab per seat and closes every tab it opens —
/// it never leaves orphans behind and never touches a tab it did not create.
///
/// Dispatches are strictly serialized by the orchestrator, so this pool opens
/// tabs up front and then does nothing for the rest of the run. That is
/// deliberate: creating a tab is slow (a full page load), and doing it lazily
/// would mean a round-2 invite waits on a cold start.
class TabPool {
  TabPool(this._client);

  final CdpClient _client;

  /// agentKind -> CDP targetId, in the order the tabs were opened.
  final Map<String, String> _targets = <String, String>{};

  List<String> get openKinds => List<String>.unmodifiable(_targets.keys);

  int get length => _targets.length;

  String? targetOf(String kind) => _targets[kind];

  /// Opens a tab for one agent. `about:blank` first, because the adapter's
  /// `connect()` wants to run its login probe on a page that is already loaded
  /// rather than racing the site's own first paint.
  Future<String> open(String kind, {String url = 'about:blank'}) async {
    final existing = _targets[kind];
    if (existing != null) return existing;

    final res =
        await _client.send(
              'Target.createTarget',
              params: <String, dynamic>{'url': url},
            )
            as Map<String, dynamic>;
    final targetId = res['targetId'] as String;
    _targets[kind] = targetId;
    return targetId;
  }

  /// Focus emulation stops Chromium throttling timers in background tabs,
  /// which otherwise stalls an agent's "still typing" detection while another
  /// tab is in front. It must be set on the page session, so the adapter does
  /// it in `connect()`; the pool only has to ask for the tab to be foregrounded
  /// so that anything the compositor is holding on to gets flushed.
  Future<void> bringToFront(String kind) async {
    final targetId = _targets[kind];
    if (targetId == null) return;
    try {
      await _client.send(
        'Page.bringToFront',
        sessionId: await _sessionFor(targetId),
      );
    } on Object {
      // Focus is an optimisation, not a correctness requirement. A tab that
      // refuses to come forward must not abort the council.
    }
  }

  /// Pulls a tab back on screen after a silent launch parked it off-screen.
  ///
  /// Silent mode starts the window at `--window-position=-32000,-32000`, which
  /// keeps it real (it is not headless) but invisible. The moment a site needs a
  /// human — a captcha, a dead session — that window has to come back, or the
  /// run would sit forever waiting on a prompt nobody can see. So: ask the
  /// browser window manager for the window, move it to the top-left and make it
  /// normal, then bring the page to front.
  ///
  /// Best-effort like [bringToFront]: a window that refuses to move must not
  /// abort the council, and on a platform with no window manager there is
  /// simply nothing to do.
  Future<void> reveal(String kind) async {
    final targetId = _targets[kind];
    if (targetId == null) return;
    try {
      final window =
          await _client.send(
                'Browser.getWindowForTarget',
                params: <String, dynamic>{'targetId': targetId},
              )
              as Map<String, dynamic>;
      final windowId = window['windowId'];
      if (windowId != null) {
        await _client.send(
          'Browser.setWindowBounds',
          params: <String, dynamic>{
            'windowId': windowId,
            'bounds': <String, dynamic>{
              'windowState': 'normal',
              'left': 0,
              'top': 0,
            },
          },
        );
      }
      await _client.send(
        'Page.bringToFront',
        sessionId: await _sessionFor(targetId),
      );
    } on Object {
      // Reveal is a courtesy to the user, not a correctness requirement. If the
      // window will not come forward, the site's own request for a human is
      // still the thing the user needs to see; failing here changes nothing.
    }
  }

  final Map<String, String> _sessions = <String, String>{};

  /// The attached page session for an open kind, or null when that tab is not
  /// open. Public because the Calibration Studio probes a page with its own
  /// read-only queries and must reuse the pool's cached session — a second
  /// attach to the same target is exactly the churn that breaks adapters.
  Future<String?> sessionFor(String kind) async {
    final targetId = _targets[kind];
    if (targetId == null) return null;
    return _sessionFor(targetId);
  }

  /// Sessions are cached per target for the pool's own calls. The sandbox
  /// proved that attach/detach churn invalidates another adapter's flattened
  /// session ("Session with given id not found"), so we attach once and keep it
  /// until the target is gone.
  Future<String> _sessionFor(String targetId) async {
    final cached = _sessions[targetId];
    if (cached != null) return cached;
    final attached =
        await _client.send(
              'Target.attachToTarget',
              params: <String, dynamic>{'targetId': targetId, 'flatten': true},
            )
            as Map<String, dynamic>;
    final sessionId = attached['sessionId'] as String;
    _sessions[targetId] = sessionId;
    return sessionId;
  }

  Future<void> close(String kind) async {
    final targetId = _targets.remove(kind);
    if (targetId == null) return;
    _sessions.remove(targetId);
    try {
      await _client.send(
        'Target.closeTarget',
        params: <String, dynamic>{'targetId': targetId},
      );
    } on Object {
      // The tab may already be gone if Chrome crashed or the user closed it.
    }
  }

  /// PNG bytes of the tab as it currently looks, or null if the tab is gone or
  /// Chrome refuses. A snapshot is evidence, not a correctness requirement, so
  /// this never throws — the same reasoning as [bringToFront].
  Future<Uint8List?> capture(String kind) async {
    final targetId = _targets[kind];
    if (targetId == null) return null;
    try {
      final res =
          await _client.send(
                'Page.captureScreenshot',
                params: <String, dynamic>{'format': 'png'},
                sessionId: await _sessionFor(targetId),
              )
              as Map<String, dynamic>;
      return base64Decode(res['data'] as String);
    } on Object {
      return null;
    }
  }

  /// Best-effort cleanup of every tab this pool opened. Called from a `finally`
  /// so an aborted council still leaves no tabs behind.
  Future<void> closeAll() async {
    for (final kind in openKinds.toList()) {
      await close(kind);
    }
  }
}
