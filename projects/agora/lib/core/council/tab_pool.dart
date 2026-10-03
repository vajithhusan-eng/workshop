import 'dart:convert';
import 'dart:typed_data';

import 'package:agora/core/cdp/cdp_client.dart';

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

  final Map<String, String> _sessions = <String, String>{};

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
