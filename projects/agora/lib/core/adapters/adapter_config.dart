/// Data-driven adapter contract.
///
/// This file is deliberately **pure data with zero behaviour**. Every field
/// here is serialisable to JSON and back. That is the whole point: when
/// ChatGPT renames a button, the fix is an edit to `assets/adapters/chatgpt.json`
/// — not a code change, not an AppImage release.
///
/// See `PLAN.md` §4.3 ("AI websites change their UI constantly") and upgrade
/// B7 / the Adapter Healer.
library;

import 'dart:convert';

/// Two-tier selector.
///
/// Tier 1 — `css`: tried in order, first **visible** hit wins.
/// Tier 2 — `text`: lowercase substrings fuzzy-matched against a candidate
/// element's aria-label / title / placeholder / alt / name / id / data-testid
/// / innerText. This is what survives a CSS-class rename.
class SelectorSpec {
  final List<String> css;
  final List<String> text;

  const SelectorSpec({this.css = const [], this.text = const []});

  /// Accepts a bare String, a List, or a `{css, text}` Map so adapter JSON
  /// can stay terse: `"composer": "#composer"` just works.
  factory SelectorSpec.fromJson(Object? raw) {
    if (raw == null) return const SelectorSpec();
    if (raw is SelectorSpec) return raw;
    if (raw is String) {
      final s = raw.trim();
      return s.isEmpty ? const SelectorSpec() : SelectorSpec(css: [s]);
    }
    if (raw is List) {
      return SelectorSpec(css: raw.map((e) => e.toString()).toList());
    }
    if (raw is Map) {
      return SelectorSpec(
        css: _stringList(raw['css']),
        text: _stringList(raw['text']),
      );
    }
    throw FormatException('Unsupported selector: $raw (${raw.runtimeType})');
  }

  Map<String, dynamic> toJson() => {
    if (css.isNotEmpty) 'css': css,
    if (text.isNotEmpty) 'text': text,
  };

  bool get none => css.isEmpty && text.isEmpty;
  bool get isEmpty => none;
  bool get isNotEmpty => !none;
  int get candidateCount => css.length + text.length;

  SelectorSpec merge(SelectorSpec other) =>
      SelectorSpec(css: [...css, ...other.css], text: [...text, ...other.text]);

  @override
  String toString() => 'SelectorSpec(css: $css, text: $text)';

  @override
  bool operator ==(Object other) =>
      other is SelectorSpec &&
      other.css.length == css.length &&
      other.text.length == text.length &&
      _listEq(other.css, css) &&
      _listEq(other.text, text);

  @override
  int get hashCode => Object.hash(css.length, text.length, css.join('|'));
}

class LoginSpec {
  final SelectorSpec loggedIn;
  final SelectorSpec loggedOut;
  final SelectorSpec captcha;
  final SelectorSpec rateLimited;

  const LoginSpec({
    this.loggedIn = const SelectorSpec(),
    this.loggedOut = const SelectorSpec(),
    this.captcha = const SelectorSpec(),
    this.rateLimited = const SelectorSpec(),
  });

  factory LoginSpec.fromJson(Object? raw) {
    final m = _asMap(raw);
    return LoginSpec(
      loggedIn: SelectorSpec.fromJson(m['loggedIn']),
      loggedOut: SelectorSpec.fromJson(m['loggedOut']),
      captcha: SelectorSpec.fromJson(m['captcha']),
      rateLimited: SelectorSpec.fromJson(m['rateLimited']),
    );
  }

  Map<String, dynamic> toJson() => {
    'loggedIn': loggedIn.toJson(),
    'loggedOut': loggedOut.toJson(),
    'captcha': captcha.toJson(),
    'rateLimited': rateLimited.toJson(),
  };
}

/// How we know an answer has finished arriving.
class CompletionSpec {
  /// No DOM change for this long => the answer is done.
  final int stableMs;

  /// How often we re-read the last answer node while streaming.
  final int pollMs;

  /// Hard ceiling. Never hang, whatever the site does.
  final int timeoutMs;

  /// The site's own "Stop generating" button. Its disappearance is a strong
  /// completion signal and is checked before the stability timer.
  final SelectorSpec stopButton;

  /// Lowercase substrings that mean "the site stopped, it did not finish"
  /// (e.g. "stopped generating", "response cancelled").
  final List<String> cancelledText;

  const CompletionSpec({
    this.stableMs = 1500,
    this.pollMs = 400,
    this.timeoutMs = 180000,
    this.stopButton = const SelectorSpec(),
    this.cancelledText = const ['stop'],
  });

  factory CompletionSpec.fromJson(Object? raw) {
    final m = _asMap(raw);
    return CompletionSpec(
      stableMs: _intOr(m['stableMs'], 1500),
      pollMs: _intOr(m['pollMs'], 400),
      timeoutMs: _intOr(m['timeoutMs'], 180000),
      stopButton: SelectorSpec.fromJson(m['stopButton']),
      cancelledText: m['cancelledText'] == null
          ? const ['stop']
          : _stringList(m['cancelledText']),
    );
  }

  Map<String, dynamic> toJson() => {
    'stableMs': stableMs,
    'pollMs': pollMs,
    'timeoutMs': timeoutMs,
    'stopButton': stopButton.toJson(),
    'cancelledText': cancelledText,
  };
}

/// Where the answer lives in the DOM.
///
/// `assistantNode` is the single most important selector in the whole file:
/// it is what makes the Verbatim guarantee possible.
class ExtractionSpec {
  final SelectorSpec assistantNode;
  final SelectorSpec userNode;
  final SelectorSpec container;
  final SelectorSpec streamingHint;
  final bool screenshotOnStore;

  const ExtractionSpec({
    this.assistantNode = const SelectorSpec(),
    this.userNode = const SelectorSpec(),
    this.container = const SelectorSpec(),
    this.streamingHint = const SelectorSpec(),
    this.screenshotOnStore = false,
  });

  factory ExtractionSpec.fromJson(Object? raw) {
    final m = _asMap(raw);
    return ExtractionSpec(
      assistantNode: SelectorSpec.fromJson(m['assistantNode']),
      userNode: SelectorSpec.fromJson(m['userNode']),
      container: SelectorSpec.fromJson(m['container']),
      streamingHint: SelectorSpec.fromJson(m['streamingHint']),
      screenshotOnStore: m['screenshotOnStore'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'assistantNode': assistantNode.toJson(),
    'userNode': userNode.toJson(),
    'container': container.toJson(),
    'streamingHint': streamingHint.toJson(),
    'screenshotOnStore': screenshotOnStore,
  };
}

/// Automating each site's own model dropdown (upgrade D9).
class ModelPickerSpec {
  final SelectorSpec trigger;
  final SelectorSpec menu;
  final Map<String, SelectorSpec> options;

  const ModelPickerSpec({
    this.trigger = const SelectorSpec(),
    this.menu = const SelectorSpec(),
    this.options = const {},
  });

  factory ModelPickerSpec.fromJson(Object? raw) {
    final m = _asMap(raw);
    final rawOptions = m['options'];
    final options = <String, SelectorSpec>{};
    if (rawOptions is Map) {
      rawOptions.forEach((key, value) {
        options[key.toString()] = SelectorSpec.fromJson(value);
      });
    }
    return ModelPickerSpec(
      trigger: SelectorSpec.fromJson(m['trigger']),
      menu: SelectorSpec.fromJson(m['menu']),
      options: options,
    );
  }

  bool get isSupported => trigger.isNotEmpty && options.isNotEmpty;

  /// The label to show when we know the site changed but not what to call it.
  List<String> get labels => options.keys.toList()..sort();

  Map<String, dynamic> toJson() => {
    'trigger': trigger.toJson(),
    'menu': menu.toJson(),
    'options': {for (final e in options.entries) e.key: e.value.toJson()},
  };
}

/// The complete, hot-reloadable definition of one AI website.
///
/// Every field is non-nullable with a sensible default. That removes an entire
/// class of `String?` / `!` bugs at the call sites in `web_agent_adapter.dart`.
class AdapterConfig {
  final String kind;
  final String version;
  final String displayName;
  final String homeUrl;
  final String color;

  final SelectorSpec composer;
  final SelectorSpec send;
  final bool sendWithEnter;

  final String newChatUrl;
  final SelectorSpec newChatButton;

  final LoginSpec login;
  final CompletionSpec completion;
  final ExtractionSpec extraction;
  final ModelPickerSpec modelPicker;

  final List<String> knownModels;
  final String notes;

  AdapterConfig({
    required this.kind,
    required this.homeUrl,
    this.version = '1.0.0',
    this.displayName = '',
    this.color = '#888888',
    this.composer = const SelectorSpec(),
    this.send = const SelectorSpec(),
    this.sendWithEnter = true,
    this.newChatUrl = '',
    this.newChatButton = const SelectorSpec(),
    this.login = const LoginSpec(),
    this.completion = const CompletionSpec(),
    this.extraction = const ExtractionSpec(),
    this.modelPicker = const ModelPickerSpec(),
    this.knownModels = const [],
    this.notes = '',
  });

  factory AdapterConfig.fromJson(Map<String, dynamic> json) {
    return AdapterConfig(
      kind: _reqString(json, 'kind'),
      homeUrl: _expandHomeUrl(_reqString(json, 'homeUrl')),
      version: _optString(json, 'version', '1.0.0'),
      displayName: _optString(json, 'displayName', _reqString(json, 'kind')),
      color: _optString(json, 'color', '#888888'),
      composer: SelectorSpec.fromJson(json['composer']),
      send: SelectorSpec.fromJson(json['send']),
      sendWithEnter: json['sendWithEnter'] != false,
      newChatUrl: _optString(json, 'newChatUrl', ''),
      newChatButton: SelectorSpec.fromJson(json['newChatButton']),
      login: LoginSpec.fromJson(json['login']),
      completion: CompletionSpec.fromJson(json['completion']),
      extraction: ExtractionSpec.fromJson(json['extraction']),
      modelPicker: ModelPickerSpec.fromJson(json['modelPicker']),
      knownModels: _stringList(json['knownModels']),
      notes: _optString(json, 'notes', ''),
    );
  }

  /// Parse adapter JSON text. Throws [FormatException] with a human-readable
  /// message including the origin, because Calibration Studio round-trips
  /// user-edited JSON and a bare "FormatException" is useless.
  static AdapterConfig parse(String source, {String origin = 'adapter'}) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('$origin is not valid JSON: ${e.message}');
    }
    if (decoded is! Map) {
      throw FormatException('$origin must be a JSON object');
    }
    try {
      return AdapterConfig.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException catch (e) {
      throw FormatException('$origin: ${e.message}');
    }
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'version': version,
    'displayName': displayName,
    'homeUrl': homeUrl,
    'color': color,
    'composer': composer.toJson(),
    'send': send.toJson(),
    'sendWithEnter': sendWithEnter,
    'newChatUrl': newChatUrl,
    'newChatButton': newChatButton.toJson(),
    'login': login.toJson(),
    'completion': completion.toJson(),
    'extraction': extraction.toJson(),
    'modelPicker': modelPicker.toJson(),
    'knownModels': knownModels,
    'notes': notes,
  };

  /// Pretty JSON for writing back from the Calibration Studio.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  bool get isValid => validate().isEmpty;

  /// Human-readable problems, suitable for a UI list.
  List<String> validate() {
    final problems = <String>[];
    if (kind.trim().isEmpty) problems.add('kind is required');
    // file:// is legal: the Sandbox Lab (B6) drives a local fixture so the
    // whole orchestrator can be tested with no accounts and no quota.
    final bool urlOk =
        homeUrl.startsWith('http') ||
        homeUrl.startsWith('file://') ||
        homeUrl.startsWith('about:');
    if (!urlOk) {
      problems.add('homeUrl must be an absolute http(s) or file:// URL');
    }
    if (composer.none) {
      problems.add(
        'composer selector is required (Agora cannot type without it)',
      );
    }
    if (send.none && !sendWithEnter) {
      problems.add('send selector is required when sendWithEnter is false');
    }
    if (extraction.assistantNode.none) {
      problems.add(
        'extraction.assistantNode is required '
        '(this is what guarantees verbatim capture)',
      );
    }
    if (modelPicker.isSupported == false && modelPicker.trigger.isNotEmpty) {
      problems.add('modelPicker has a trigger but no options');
    }
    return problems;
  }

  AdapterConfig copyWith({
    String? version,
    String? displayName,
    String? homeUrl,
    SelectorSpec? composer,
    SelectorSpec? send,
    SelectorSpec? newChatButton,
    LoginSpec? login,
    CompletionSpec? completion,
    ExtractionSpec? extraction,
    String? notes,
  }) {
    return AdapterConfig(
      kind: kind,
      version: version ?? this.version,
      displayName: displayName ?? this.displayName,
      homeUrl: homeUrl ?? this.homeUrl,
      color: color,
      composer: composer ?? this.composer,
      send: send ?? this.send,
      sendWithEnter: sendWithEnter,
      newChatUrl: newChatUrl,
      newChatButton: newChatButton ?? this.newChatButton,
      login: login ?? this.login,
      completion: completion ?? this.completion,
      extraction: extraction ?? this.extraction,
      modelPicker: modelPicker,
      knownModels: knownModels,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() => 'AdapterConfig($kind v$version)';
}

// ---------------------------------------------------------------------------
// tolerant parsing helpers — adapter JSON is hand-edited, so never crash hard
// on a wrong type where a sane default exists.
// ---------------------------------------------------------------------------

Map<String, dynamic> _asMap(Object? raw) {
  if (raw == null) return const {};
  if (raw is Map) return Map<String, dynamic>.from(raw);
  throw FormatException('expected an object, got ${raw.runtimeType}');
}

String _reqString(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v == null || v.toString().trim().isEmpty) {
    throw FormatException('$key is required');
  }
  return v.toString();
}

/// Expand a relative `file://` home URL into an absolute one.
///
/// The Sandbox Lab fixture ships a *relative* URL
/// (`file://./tool/sandbox/mock_ai_site.html`) so that no machine's directory
/// layout is baked into the repository. Chrome needs an absolute `file://` URL,
/// so it is resolved here, at parse time, against the working directory — which
/// is the package root for every caller (the test suite and the `tool/`
/// harnesses). `http`/`https`/`about:` URLs and already-absolute `file:///…`
/// URLs pass through untouched.
///
/// [AdapterConfig.encode] emits the expanded URL. That is deliberate: encoded
/// output is written to the user's own config directory
/// (`~/.config/agora/adapters/`), never back into the repository.
String _expandHomeUrl(String raw) {
  const prefix = 'file://';
  if (!raw.startsWith(prefix)) return raw;
  final rest = raw.substring(prefix.length);
  // `file:///abs/path` (already absolute) and anything with an authority are
  // left alone; only a relative path needs resolving.
  if (!rest.startsWith('./') && !rest.startsWith('../')) return raw;
  return Uri.base.resolve(rest).toString();
}

String _optString(Map<String, dynamic> m, String key, String fallback) {
  final v = m[key];
  if (v == null) return fallback;
  final s = v.toString();
  return s.isEmpty ? fallback : s;
}

int _intOr(Object? raw, int fallback) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
  return fallback;
}

List<String> _stringList(Object? raw) {
  if (raw == null) return const [];
  if (raw is String) {
    return raw.trim().isEmpty ? const [] : [raw];
  }
  if (raw is List) {
    return raw
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }
  return const [];
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
