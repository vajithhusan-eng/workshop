import 'dart:collection';

import '../cdp/cdp_client.dart';
import '../chrome/chrome_launcher.dart';
import '../council/tab_pool.dart';
import '../logging.dart';
import 'adapter_config.dart';
import 'page_script.dart';

/// What one selector found on the live page.
class SelectorHit {
  const SelectorHit({
    required this.selector,
    required this.kind,
    required this.total,
    required this.visible,
    required this.sample,
    required this.invalid,
  });

  factory SelectorHit.fromMap(Map<String, dynamic> m) => SelectorHit(
    selector: '${m['selector']}',
    kind: '${m['kind']}',
    total: (m['total'] as num?)?.toInt() ?? 0,
    visible: (m['visible'] as num?)?.toInt() ?? 0,
    sample: '${m['sample'] ?? ''}',
    invalid: m['invalid'] == true,
  );

  final String selector;

  /// 'css' or 'text' — which tier of the two-tier matcher found this.
  final String kind;

  /// Elements matching in the DOM, ignoring visibility.
  final int total;

  /// How many of those a human could actually see and click.
  final int visible;

  /// A short label from the first match, so a wrong-node match is obvious.
  final String sample;

  /// True when the browser rejected this as a CSS selector. A syntax error is a
  /// different bug from "the site changed", and it deserves a different message.
  final bool invalid;

  bool get matched => visible > 0;
  bool get foundButHidden => total > 0 && visible == 0;

  String get verdict {
    if (invalid) return 'invalid CSS';
    if (visible > 0) return '$visible visible';
    if (total > 0) return 'found but hidden';
    return 'no match';
  }
}

/// One slot of the adapter (composer, send, assistantNode, …) and how it fared.
class ProbeOutcome {
  const ProbeOutcome({
    required this.slot,
    required this.spec,
    required this.hits,
  });

  final String slot;
  final SelectorSpec spec;
  final List<SelectorHit> hits;

  bool get isEmptySpec => spec.css.isEmpty && spec.text.isEmpty;

  /// Matched on at least one selector, which is what the real matcher needs.
  bool get matched => hits.any((SelectorHit h) => h.matched);

  bool get hasInvalidSelector => hits.any((SelectorHit h) => h.invalid);

  /// Matched, but only on something the page hid — the classic stale-adapter
  /// symptom where the node is still in the DOM but behind a redesign.
  bool get matchedOnlyHidden =>
      !matched && hits.any((SelectorHit h) => h.foundButHidden);

  int get bestVisible =>
      hits.fold(0, (int m, SelectorHit h) => h.visible > m ? h.visible : m);

  /// The first selector the matcher would actually use, for the "fix it here"
  /// hint in the Calibration Studio.
  String? get winningSelector {
    for (final SelectorHit h in hits) {
      if (h.matched) return h.selector;
    }
    return null;
  }

  static const ProbeOutcome absent = ProbeOutcome(
    slot: '',
    spec: SelectorSpec(),
    hits: <SelectorHit>[],
  );
}

/// Everything one site told us.
class SiteProbe {
  const SiteProbe({
    required this.kind,
    required this.displayName,
    required this.url,
    required this.loaded,
    required this.shadowRoots,
    required this.outcomes,
    this.error,
  });

  final String kind;
  final String displayName;
  final String url;

  /// False when the page never answered at all, which is a login/transport
  /// problem rather than a selector problem.
  final bool loaded;

  /// Number of shadow roots the page publishes. High counts explain why a plain
  /// `querySelector` finds nothing on a modern AI site.
  final int shadowRoots;

  final List<ProbeOutcome> outcomes;
  final String? error;

  List<ProbeOutcome> get broken =>
      outcomes.where((ProbeOutcome o) => !o.isEmptySpec && !o.matched).toList();

  List<ProbeOutcome> get withInvalidCss =>
      outcomes.where((ProbeOutcome o) => o.hasInvalidSelector).toList();

  int get matchedCount => outcomes.where((ProbeOutcome o) => o.matched).length;

  int get scoredCount =>
      outcomes.where((ProbeOutcome o) => !o.isEmptySpec).length;

  bool get allMatched => scoredCount > 0 && matchedCount == scoredCount;

  String get headline {
    if (error != null) return error!;
    if (!loaded) return 'page did not load';
    if (scoredCount == 0) return 'adapter declares no selectors to probe';
    if (allMatched) return 'all $scoredCount slots matched';
    return '$matchedCount of $scoredCount slots matched';
  }
}

/// The ordered set of adapter slots worth probing.
///
/// Order is meaningful: it runs composer → send → assistant → user → container →
/// stop button → login, so the Calibration Studio reads top-down in the order a
/// site actually breaks (the composer breaks first, the transcript last).
LinkedHashMap<String, SelectorSpec> probeSlotsOf(AdapterConfig c) {
  return LinkedHashMap<String, SelectorSpec>.from(<String, SelectorSpec>{
    'composer': c.composer,
    'send': c.send,
    'assistant node': c.extraction.assistantNode,
    'user node': c.extraction.userNode,
    'container': c.extraction.container,
    'stop button': c.completion.stopButton,
    'signed in': c.login.loggedIn,
    'signed out': c.login.loggedOut,
  });
}

/// Opens a real page and asks the kernel what each adapter selector finds there.
///
/// This exists because a selector that is merely *present* in the JSON tells you
/// nothing about whether the site still has it. Probing is read-only and
/// disposable: it opens its own tab, never touches a live council, and closes
/// what it opened.
class SelectorProber {
  SelectorProber({this.cdpPort = 9222, this.headless = false});

  final int cdpPort;
  final bool headless;

  static final Logger _log = Logger('selector_prober');

  ChromeLaunchResult? _launch;
  TabPool? _pool;

  /// Probe one site. Never throws: every failure comes back inside [SiteProbe]
  /// so the Calibration Studio can render a reason next to a green checkmark.
  Future<SiteProbe> probe(
    AdapterConfig cfg, {
    Duration settle = const Duration(seconds: 3),
  }) async {
    final String kind = cfg.kind;
    final String name = cfg.displayName;
    try {
      final TabPool pool = await _ensurePool();
      await pool.open(kind, url: cfg.homeUrl);
      final String? session = await pool.sessionFor(kind);
      if (session == null) {
        return _failed(kind, name, cfg.homeUrl, 'could not attach to the tab');
      }

      // The site needs its own JS to run before a probe means anything.
      await Future<void>.delayed(settle);
      await _client.send('Runtime.enable', sessionId: session);
      await _client.send('Page.enable', sessionId: session);

      final List<ProbeOutcome> outcomes = <ProbeOutcome>[];
      int shadowRoots = 0;
      bool loaded = false;

      for (final MapEntry<String, SelectorSpec> e in probeSlotsOf(
        cfg,
      ).entries) {
        if (e.value.css.isEmpty && e.value.text.isEmpty) continue;
        final Map<String, dynamic> res = await _client.sendMap(
          'Runtime.evaluate',
          params: <String, dynamic>{
            'expression': PageScript.call('probe', <String, dynamic>{
              'slot': e.key,
              'spec': <String, dynamic>{
                'css': e.value.css,
                'text': e.value.text,
              },
            }),
            'returnByValue': true,
            'awaitPromise': true,
          },
          sessionId: session,
          timeout: const Duration(seconds: 20),
        );
        if (res['ok'] != true) {
          _log.w('probe failed on $kind/${e.key}', '${res['error']}');
          outcomes.add(
            ProbeOutcome(slot: e.key, spec: e.value, hits: <SelectorHit>[]),
          );
          continue;
        }
        loaded = true;
        shadowRoots = (res['shadowRoots'] as num?)?.toInt() ?? shadowRoots;
        outcomes.add(
          ProbeOutcome(
            slot: e.key,
            spec: e.value,
            hits: <SelectorHit>[
              for (final Object? h
                  in (res['hits'] as List<Object?>? ?? const <Object?>[]))
                if (h is Map<String, dynamic>) SelectorHit.fromMap(h),
            ],
          ),
        );
      }

      return SiteProbe(
        kind: kind,
        displayName: name,
        url: cfg.homeUrl,
        loaded: loaded,
        shadowRoots: shadowRoots,
        outcomes: outcomes,
      );
    } on Object catch (e) {
      _log.w('probe of $kind failed', e);
      return _failed(kind, name, cfg.homeUrl, '$e');
    }
  }

  SiteProbe _failed(String kind, String name, String url, String why) =>
      SiteProbe(
        kind: kind,
        displayName: name,
        url: url,
        loaded: false,
        shadowRoots: 0,
        outcomes: const <ProbeOutcome>[],
        error: why,
      );

  CdpClient get _client {
    final ChromeLaunchResult? l = _launch;
    if (l == null) throw StateError('Chrome has not been launched yet');
    return l.client;
  }

  Future<TabPool> _ensurePool() async {
    final TabPool? existing = _pool;
    if (existing != null) return existing;
    await AgoraPaths.ensureDirs();
    final ChromeLaunchResult launch = await ChromeLauncher().launch(
      preferredPort: cdpPort,
      profileDir: AgoraPaths.chromeProfile,
      headless: headless,
    );
    _launch = launch;
    final TabPool pool = TabPool(launch.client);
    _pool = pool;
    _log.i(
      'probe browser up on ${launch.port} (${launch.client.browserVersion})',
    );
    return pool;
  }

  /// Closes the probe's tabs and the browser it started. A user who pressed
  /// "Probe live page" three times must not be left with three Chromes.
  Future<void> dispose() async {
    try {
      await _pool?.closeAll();
    } on Object catch (e) {
      _log.w('closing probe tabs failed', e);
    }
    try {
      await _launch?.client.close();
    } on Object catch (e) {
      _log.w('closing probe client failed', e);
    }
    _pool = null;
    _launch = null;
  }
}
