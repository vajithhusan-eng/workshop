import 'dart:typed_data';

import 'adapter_config.dart';

/// Whether we can actually talk to an agent right now.
enum LoginStatus {
  /// We have not checked yet.
  unknown,

  /// Logged in and the composer is present.
  ready,

  /// Cookies expired or the site wants a sign-in.
  loggedOut,

  /// A bot challenge (CAPTCHA / Cloudflare) is blocking us.
  captcha,

  /// Quota exhausted or the site is throttling.
  rateLimited,

  /// The site loaded but our selectors no longer match — needs Calibration.
  needsRepair,

  /// The tab died, was closed, or crashed.
  transportError,
}

/// Result of a login probe, with enough context for the UI to tell the user
/// exactly what went wrong.
class LoginState {
  const LoginState({required this.status, this.message = '', this.url = ''});

  final LoginStatus status;
  final String message;
  final String url;

  bool get isReady => status == LoginStatus.ready;
  bool get needsUser =>
      status == LoginStatus.loggedOut ||
      status == LoginStatus.captcha ||
      status == LoginStatus.rateLimited;

  static const LoginState ready = LoginState(status: LoginStatus.ready);

  @override
  String toString() =>
      'LoginState(${status.name}${message.isEmpty ? '' : ': $message'})';
}

/// An agent's reply, captured byte-for-byte.
///
/// This class is the contract behind "Agora never changes what an AI said".
/// [rawText] and [rawHtml] are exactly what the website rendered; any
/// markdown conversion, truncation or summarisation happens in a *view* layer
/// and never touches these fields. [contentHash] lets the UI prove integrity
/// later (Verbatim Vault, upgrade C3).
class Verbatim {
  const Verbatim({
    required this.rawText,
    this.rawHtml,
    this.contentHash,
    this.latencyMs,
    this.screenshotBytes,
    this.nodeCount = 1,
    this.capturedAt,
    this.meta = const <String, dynamic>{},
  });

  /// The agent's words, exactly as rendered by the site.
  final String rawText;

  /// The outer HTML of the answer node, for rendering with original styling.
  final String? rawHtml;

  /// sha256 prefix of [rawText]. Stored so tampering is detectable.
  final String? contentHash;

  /// How long the agent took from send to completion.
  final int? latencyMs;

  /// Optional PNG of the message (Verbatim Vault screenshot mode).
  final Uint8List? screenshotBytes;

  /// How many answer nodes existed. 1 = single answer, useful sanity check.
  final int nodeCount;

  final DateTime? capturedAt;

  /// Free-form diagnostics (node descriptor, adapter version, timeouts hit).
  final Map<String, dynamic> meta;

  bool get isEmpty => rawText.trim().isEmpty;

  /// Characters, as the user would count them.
  int get length => rawText.length;

  Verbatim copyWith({int? latencyMs, Uint8List? screenshotBytes}) => Verbatim(
    rawText: rawText,
    rawHtml: rawHtml,
    contentHash: contentHash,
    latencyMs: latencyMs ?? this.latencyMs,
    screenshotBytes: screenshotBytes ?? this.screenshotBytes,
    nodeCount: nodeCount,
    capturedAt: capturedAt,
    meta: meta,
  );

  @override
  String toString() =>
      'Verbatim(${rawText.length} chars, hash: ${contentHash ?? 'none'})';
}

/// Progress events emitted while an agent works, so the UI can show live
/// state without polling.
enum AgentPhase {
  /// Navigating to the chat page.
  opening,

  /// Waiting for the composer to appear.
  ready,

  /// Writing the prompt into the site.
  composing,

  /// Prompt submitted; waiting for the first tokens.
  waiting,

  /// Tokens are arriving.
  streaming,

  /// Answer complete.
  done,

  /// Blocked and needs the user.
  blocked,

  /// Something broke.
  error,
}

/// A single immutable status update.
class AgentStatus {
  const AgentStatus(this.phase, {this.detail = '', this.progress = 0});

  final AgentPhase phase;
  final String detail;

  /// 0..1 when known, otherwise 0. Used for indeterminate spinners.
  final double progress;

  @override
  String toString() =>
      'AgentStatus(${phase.name}${detail.isEmpty ? '' : ': $detail'})';
}

/// Drives one AI website.
///
/// Implementations must uphold two rules:
///  1. [send] must never mutate the prompt text.
///  2. [lastMessage] must return the site's own rendering, verbatim.
abstract class AgentAdapter {
  /// Protocol identity, e.g. 'chatgpt'. Must match `AdapterConfig.kind`.
  String get kind;

  String get displayName;

  AdapterConfig get config;

  /// Chrome DevTools target id backing this adapter.
  String get targetId;

  /// Latest status, for the council panel.
  AgentStatus get status;

  /// Live status updates.
  Stream<AgentStatus> get statuses;

  /// Partial answer text as it streams in. Completes when the answer does.
  Stream<String> get tokens;

  /// Navigate to the site and confirm we can talk to it.
  Future<LoginState> connect();

  /// Is the user signed in? Cheap enough to poll.
  Future<LoginState> checkLogin();

  /// Start a fresh conversation (Fractal Memory relies on this).
  Future<void> newChat();

  /// Type [prompt] and submit it. Does NOT wait for the reply.
  Future<void> send(String prompt);

  /// Wait for the current answer to finish. Returns the verbatim text.
  ///
  /// Must terminate on: stability window, stop-button disappearance, timeout,
  /// or [interrupt].
  Future<Verbatim> awaitCompletion();

  /// Capture the most recent assistant message without waiting.
  Future<Verbatim?> peekLastMessage();

  /// Switch model via the site's own picker. No-op when unsupported.
  Future<bool> selectModel(String label);

  /// Abandon whatever is in flight and make the adapter reusable.
  Future<void> interrupt();

  /// Release the tab.
  Future<void> close();

  /// Diagnostics for Calibration Studio / the Adapter Healer.
  Future<AgentDiagnostics> diagnose();
}

/// Result of an adapter health check.
class AgentDiagnostics {
  const AgentDiagnostics({
    required this.kind,
    required this.results,
    this.suggestions = const <String, SelectorSpec>{},
    this.probeCount = 0,
  });

  final String kind;

  /// Per-capability outcome, keyed by capability name.
  final Map<String, bool> results;

  /// Concrete repairs the Healer proposes, ready to apply to the config.
  final Map<String, SelectorSpec> suggestions;

  /// How many candidate elements the probe found.
  final int probeCount;

  bool get allHealthy => results.values.every((bool ok) => ok);

  /// Capabilities that are broken, for the UI to highlight.
  List<String> get broken => results.entries
      .where((MapEntry<String, bool> e) => !e.value)
      .map((MapEntry<String, bool> e) => e.key)
      .toList();

  @override
  String toString() =>
      'AgentDiagnostics($kind ${results.length} checks, broken: $broken)';
}
