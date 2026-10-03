import 'dart:collection';

import '../cdp/cdp_client.dart';
import '../chrome/chrome_launcher.dart';
import '../council/tab_pool.dart';
import '../logging.dart';
import 'adapter_config.dart';
import 'page_script.dart';

/// What one selector found on the live page.
/// What kind of thing a selector points at.
///
/// This distinction is the difference between "your selector is stale" and
/// "there is nothing on the page to find yet". Scoring both as a miss makes a
/// working adapter look broken, which is worse than not probing at all.
enum SlotKind {
  /// A control that must be present on a loaded page.
  element,

  /// A page state. Login states are mutually exclusive by definition, so a miss
  /// here is normal: a signed-out selector cannot match a signed-in page.
  state,

  /// Only exists once the thread holds an exchange (assistant/user bubbles, the
  /// stop button). Undecidable on a fresh thread, so reported, never failed.
  conditional,
}

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
    this.kind = SlotKind.element,
    this.error,
  });

  final String slot;
  final SelectorSpec spec;
  final SlotKind kind;
  final List<SelectorHit> hits;

  /// Set when the kernel could not be asked at all, as opposed to answering
  /// "nothing here". A silent miss here would look exactly like a stale
  /// adapter, which is the opposite of what a diagnostic tool should do.
  final String? error;

  bool get isEmptySpec => spec.css.isEmpty && spec.text.isEmpty;

  /// Matched on at least one selector, which is what the real matcher needs.
  bool get matched => hits.any((SelectorHit h) => h.matched);

  /// True only when a miss is evidence of a broken selector. A conditional slot
  /// has nothing to match until the thread fills; a state slot is *supposed* to
  /// lose against a page sitting in a different state.
  bool get checkable => kind == SlotKind.element;

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

  /// A selector that is declared, checkable on this page, and did not match.
  /// State slots are excluded: they are mutually exclusive, so the ones that
  /// lose are supposed to lose.
  List<ProbeOutcome> get broken => outcomes
      .where((ProbeOutcome o) => !o.isEmptySpec && o.checkable && !o.matched)
      .toList();

  /// Slots that could not be judged because the page had nothing to show. They
  /// are reported so the user knows the check was skipped, not silently passed.
  List<ProbeOutcome> get unverifiable => outcomes
      .where(
        (ProbeOutcome o) =>
            !o.isEmptySpec && o.kind == SlotKind.conditional && !o.matched,
      )
      .toList();

  List<ProbeOutcome> get withInvalidCss =>
      outcomes.where((ProbeOutcome o) => o.hasInvalidSelector).toList();

  List<ProbeOutcome> get errored =>
      outcomes.where((ProbeOutcome o) => o.error != null).toList();

  int get matchedCount => outcomes.where((ProbeOutcome o) => o.matched).length;

  int get scoredCount =>
      outcomes.where((ProbeOutcome o) => !o.isEmptySpec && o.checkable).length;

  bool get allMatched => scoredCount > 0 && broken.isEmpty && errored.isEmpty;

  String get headline {
    if (error != null) return error!;
    if (errored.isNotEmpty) {
      return '${errored.length} slot(s) could not be probed';
    }
    if (!loaded) return 'page did not load';
    if (scoredCount == 0) return 'adapter declares no selectors to probe';
    if (unverifiable.isNotEmpty) {
      return '${broken.length} slot(s) broken, ${unverifiable.length} '
          'unverifiable on an empty thread';
    }
    if (allMatched) return 'all $scoredCount checkable slots matched';
    return '${broken.length} of $scoredCount checkable slots broken';
  }
}

/// How each probe slot should be scored.
///
/// Kept next to [probeSlotsOf] on purpose: a slot's kind and its selector are
/// one fact about the adapter, and splitting them across two tables is how they
/// drift apart.
const Map<String, SlotKind> slotKinds = <String, SlotKind>{
  'composer': SlotKind.element,
  'send': SlotKind.element,
  'assistant node': SlotKind.conditional,
  'user node': SlotKind.conditional,
  'container': SlotKind.element,
  'stop button': SlotKind.conditional,
  'signed in': SlotKind.state,
  'signed out': SlotKind.state,
  'captcha': SlotKind.state,
  'rate limited': SlotKind.state,
};

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
  /// Runtime.evaluate answers with `{"result": {"type":…, "value": …}}`; the
  /// kernel's own object is one level deeper. A page that threw instead carries
  /// `exceptionDetails`, which is far more useful than "no result".
  static Map<String, dynamic> _unwrap(Map<String, dynamic> envelope) {
    final Object? details = envelope['exceptionDetails'];
    if (details != null) {
      final String text = details is Map
          ? '${(details['exception'] is Map) ? (details['exception'] as Map)['description'] ?? details['exception'] : details['text'] ?? details}'
          : '$details';
      return <String, dynamic>{'ok': false, 'error': text.split('\n').first};
    }
    final Object? remote = envelope['result'];
    if (remote is Map && remote['value'] is Map) {
      return (remote['value'] as Map).cast<String, dynamic>();
    }
    return envelope;
  }

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
        final Map<String, dynamic> envelope = await _client.sendMap(
          'Runtime.evaluate',
          params: <String, dynamic>{
            'expression': PageScript.call('probeSlot', <String, dynamic>{
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
        // Runtime.evaluate answers with a RemoteObject envelope, so the kernel's
        // own return value lives at result.value. Reading `envelope` directly is
        // what made every slot report "no result" while the page was fine.
        final Map<String, dynamic> res = _unwrap(envelope);
        if (res['ok'] != true) {
          final String why =
              '${res['error'] ?? 'the page kernel returned no result'}';
          _log.w('probe failed on $kind/${e.key}', why);
          outcomes.add(
            ProbeOutcome(
              slot: e.key,
              spec: e.value,
              hits: <SelectorHit>[],
              error: why,
            ),
          );
          continue;
        }
        loaded = true;
        shadowRoots = (res['shadowRoots'] as num?)?.toInt() ?? shadowRoots;
        outcomes.add(
          ProbeOutcome(
            slot: e.key,
            spec: e.value,
            kind: slotKinds[e.key] ?? SlotKind.element,
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
