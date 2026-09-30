import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../cdp/cdp_client.dart';
import '../logging.dart';
import '../util/hashing.dart';
import 'adapter_config.dart';
import 'agent_adapter.dart';
import 'page_script.dart';

/// Thrown when an adapter cannot do its job. Carries a human-readable
/// [hint] so the UI can tell the user what to DO, not just what broke.
class AdapterException implements Exception {
  AdapterException(this.kind, this.message, {this.hint = ''});

  final String kind;
  final String message;
  final String hint;

  @override
  String toString() => hint.isEmpty
      ? 'AdapterException($kind): $message'
      : 'AdapterException($kind): $message — $hint';
}

/// The real implementation: drives an AI website through one Chrome tab.
///
/// One adapter owns one tab for the whole session. It never creates tabs
/// itself; [openTarget] is handled by the browser pool so memory stays bounded
/// (one live session rule).
class WebAgentAdapter implements AgentAdapter {
  WebAgentAdapter({
    required this.config,
    required CdpClient client,
    required this.targetId,
    DateTime Function()? clock,
  }) : _client = client,
       _clock = clock ?? DateTime.now;

  final AdapterConfig config;
  final String targetId;
  final CdpClient _client;
  final DateTime Function() _clock;

  String? _sessionId;
  final StreamController<AgentStatus> _statuses =
      StreamController<AgentStatus>.broadcast();
  final StreamController<String> _tokens = StreamController<String>.broadcast();

  AgentStatus _status = const AgentStatus(AgentPhase.opening);
  bool _closed = false;
  bool _interrupted = false;
  DateTime? _sentAt;

  /// Baseline answer count, so we can detect "the new answer has arrived"
  /// instead of re-reading the previous one.
  int _answerBaseline = 0;

  @override
  String get kind => config.kind;

  @override
  String get displayName => config.displayName;

  @override
  String get targetId => _targetId;

  @override
  AgentStatus get status => _status;

  @override
  Stream<AgentStatus> get statuses => _statuses.stream;

  @override
  Stream<String> get tokens => _tokens.stream;

  final Logger _log = Logger('adapter');

  // ---------------------------------------------------------------- lifecycle

  @override
  Future<LoginState> connect() async {
    try {
      final Map<String, dynamic> res = await _client.sendMap(
        'Target.attachToTarget',
        params: <String, dynamic>{'targetId': targetId, 'flatten': true},
      );
      _sessionId = '${res['sessionId']}';
      _log.d('attached to $targetId session=$_sessionId');

      await _client.send('Page.enable', sessionId: _sessionId);
      await _client.send('Runtime.enable', sessionId: _sessionId);
      // Needed for screenshots in the Verbatim Vault.
      await _client.send('Page.getLayoutMetrics', sessionId: _sessionId);

      _emit(AgentPhase.opening);
      await _navigate(config.homeUrl);
      await _waitForComposer();

      final LoginState state = await checkLogin();
      if (!state.isReady) {
        _emit(AgentPhase.blocked, detail: state.message);
        return state;
      }
      _answerBaseline = await _answerCount();
      _emit(AgentPhase.ready);
      return state;
    } on CdpException catch (e) {
      _log.e('connect failed', e);
      _emit(AgentPhase.error, detail: e.message);
      return LoginState(
        status: LoginStatus.transportError,
        message: e.message,
        url: config.homeUrl,
      );
    }
  }

  @override
  Future<LoginState> checkLogin() async {
    final String url = await _currentUrl();

    // Blocked states win over everything: a CAPTCHA page also has no composer,
    // and telling the user "log in again" when a CAPTCHA is up wastes their time.
    if (config.login.captcha.isNotEmpty) {
      final Map<String, dynamic> r = await _eval('exists', <String, dynamic>{
        'spec': config.login.captcha.toJson(),
      });
      if (r['found'] == true) {
        return LoginState(
          status: LoginStatus.captcha,
          message:
              'Bot challenge is showing. Solve it in the Chrome window, '
              'then Agora continues automatically.',
          url: url,
        );
      }
    }

    if (config.login.rateLimited.isNotEmpty) {
      final Map<String, dynamic> r = await _eval('exists', <String, dynamic>{
        'spec': config.login.rateLimited.toJson(),
      });
      if (r['found'] == true) {
        return LoginState(
          status: LoginStatus.rateLimited,
          message: 'Quota or rate limit reached on ${config.displayName}.',
          url: url,
        );
      }
    }

    if (config.login.loggedOut.isNotEmpty) {
      final Map<String, dynamic> r = await _eval('exists', <String, dynamic>{
        'spec': config.login.loggedOut.toJson(),
      });
      if (r['found'] == true) {
        return LoginState(
          status: LoginStatus.loggedOut,
          message:
              'Not signed in to ${config.displayName}. Open the Agora '
              'Chrome window and log in once — cookies persist from then on.',
          url: url,
        );
      }
    }

    // Positive confirmation first (strongest signal).
    if (config.login.loggedIn.isNotEmpty) {
      final Map<String, dynamic> r = await _eval('exists', <String, dynamic>{
        'spec': config.login.loggedIn.toJson(),
      });
      if (r['found'] == true) return LoginState.ready;
    }

    // Fall back to "can we see the composer?".
    final bool composer = await _hasComposer();
    if (composer) return LoginState.ready;

    return LoginState(
      status: LoginStatus.needsRepair,
      message:
          '${config.displayName} loaded but Agora cannot find the message '
          'box. The site layout probably changed — open Calibration Studio to '
          're-pick the selector.',
      url: url,
    );
  }

  // ---------------------------------------------------------------- messaging

  @override
  Future<void> newChat() async {
    _log.i('starting a new chat');
    if (config.newChatUrl != null && config.newChatUrl!.isNotEmpty) {
      await _navigate(config.newChatUrl!);
    } else if (config.newChatButton.isNotEmpty) {
      final Map<String, dynamic> r = await _eval('click', <String, dynamic>{
        'spec': config.newChatButton.toJson(),
      });
      if (r['ok'] != true) {
        _log.w('new chat button not found; reloading home instead');
        await _navigate(config.homeUrl);
      }
    } else {
      await _navigate(config.homeUrl);
    }
    await _waitForComposer();
    _answerBaseline = await _answerCount();
  }

  @override
  Future<void> send(String prompt) async {
    if (prompt.trim().isEmpty) {
      throw AdapterException(kind, 'Refusing to send an empty prompt.');
    }
    _interrupted = false;
    await _waitForComposer();

    _emit(AgentPhase.composing);
    final Map<String, dynamic> written = await _eval('write', <String, dynamic>{
      'spec': config.composer.toJson(),
      'text': prompt,
    });
    if (written['ok'] != true) {
      throw AdapterException(
        kind,
        'Could not write into the ${config.displayName} message box.',
        hint: 'Run Calibration Studio and re-pick the composer selector.',
      );
    }

    // Give the framework a moment to enable the send button before clicking it.
    await Future<void>.delayed(const Duration(milliseconds: 120));

    _emit(AgentPhase.waiting);
    _sentAt = _clock();

    if (config.send.isNotEmpty) {
      final Map<String, dynamic> clicked = await _eval(
        'click',
        <String, dynamic>{'spec': config.send.toJson()},
      );
      if (clicked['ok'] == true) {
        _answerBaseline = await _answerCount();
        return;
      }
      _log.w('send button not clickable; falling back to Enter');
    }

    if (config.sendWithEnter) {
      await _eval('pressEnter', <String, dynamic>{
        'spec': config.composer.toJson(),
      });
      _answerBaseline = await _answerCount();
      return;
    }

    throw AdapterException(
      kind,
      'No way to submit the message on ${config.displayName}.',
      hint: 'Set a send button selector, or set "send_with_enter": true.',
    );
  }

  @override
  Future<Verbatim> awaitCompletion() async {
    final DateTime start = _sentAt ?? _clock();
    final int pollMs = config.completion.pollMs;
    final Duration stableWindow = Duration(
      milliseconds: config.completion.stableMs,
    );
    final DateTime deadline = start.add(
      Duration(milliseconds: config.completion.timeoutMs),
    );

    String previous = '';
    DateTime lastChange = _clock();
    bool sawNewAnswer = false;
    bool stopButtonSeen = false;
    Verbatim last = Verbatim(rawText: '');
    bool timedOut = false;

    while (true) {
      if (_interrupted) break;
      if (_clock().isAfter(deadline)) {
        timedOut = true;
        _log.w('awaitCompletion timed out for $kind; taking what we have');
        break;
      }

      final Verbatim? current = await peekLastMessage();

      if (current != null && current.nodeCount > _answerBaseline) {
        sawNewAnswer = true;
        last = current;

        if (current.rawText != previous) {
          if (!sawNewAnswer ||
              previous.isNotEmpty ||
              current.rawText.isNotEmpty) {
            previous = current.rawText;
            lastChange = _clock();
            if (_status.phase != AgentPhase.streaming) {
              _emit(AgentPhase.streaming);
            }
            _tokens.add(current.rawText);
          }
        } else if (sawNewAnswer) {
          final bool stable = _clock().difference(lastChange) >= stableWindow;
          final bool stopGone = !(await _stopButtonVisible());
          if (stable && stopGone) break;
        }
      }

      if (sawNewAnswer && config.completion.stopButton.isNotEmpty) {
        final bool visible = await _stopButtonVisible();
        if (visible) {
          stopButtonSeen = true;
        } else if (stopButtonSeen && previous.isNotEmpty) {
          // The site told us it finished.
          await Future<void>.delayed(const Duration(milliseconds: 250));
          break;
        }
      }

      await Future<void>.delayed(Duration(milliseconds: pollMs));
    }

    // Final read, so we never store a truncated answer.
    final Verbatim? finalPeek = await peekLastMessage();
    if (finalPeek != null && !finalPeek.isEmpty) last = finalPeek;

    if (last.isEmpty) {
      throw AdapterException(
        kind,
        'No answer came back from ${config.displayName}.',
        hint: timedOut
            ? 'The site took too long. Check for a CAPTCHA or quota limit.'
            : 'Check the Chrome tab — the site may have shown an error.',
      );
    }

    final Verbatim result = last.copyWith(
      latencyMs: _clock().difference(start).inMilliseconds,
    );

    _emit(AgentPhase.done, detail: '${result.length} chars');
    await _tokens.close();
    _tokens = StreamController<String>.broadcast();
    return result;
  }

  @override
  Future<Verbatim?> peekLastMessage() async {
    final Map<String, dynamic> r = await _eval('lastMessage', <String, dynamic>{
      'spec': config.extraction.assistantNode.toJson(),
    });
    if (r['found'] != true) return null;

    final String text = '${r['text'] ?? ''}';
    return Verbatim(
      rawText: text,
      rawHtml: r['html'] == null ? null : '${r['html']}',
      contentHash: contentHash(text),
      nodeCount: r['count'] is int ? r['count'] as int : 1,
      capturedAt: _clock(),
      meta: <String, dynamic>{
        'adapter': kind,
        'adapterVersion': config.version,
        'node': r['node'],
      },
    );
  }

  @override
  Future<void> interrupt() async {
    _interrupted = true;
    // Click the site's own stop button when we can — it is the polite way to
    // end generation and leaves the chat in a consistent state.
    if (config.completion.stopButton.isNotEmpty) {
      try {
        await _eval('click', <String, dynamic>{
          'spec': config.completion.stopButton.toJson(),
        });
      } catch (_) {
        // best effort
      }
    }
    _emit(AgentPhase.ready, detail: 'interrupted');
  }

  // ---------------------------------------------------------------- extras

  @override
  Future<bool> selectModel(String label) async {
    if (!config.modelPicker.isSupported) return false;
    try {
      await _eval('click', <String, dynamic>{
        'spec': config.modelPicker.trigger.toJson(),
      });
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final SelectorSpec? option = config.modelPicker.options[label];
      if (option == null) {
        _log.w('model "$label" is not in ${kind} config options');
        return false;
      }
      final Map<String, dynamic> r = await _eval('click', <String, dynamic>{
        'spec': option.toJson(),
      });
      return r['ok'] == true;
    } catch (e) {
      _log.e('selectModel failed', e);
      return false;
    }
  }

  /// Capture a PNG of the current page for the Verbatim Vault.
  Future<Uint8List?> screenshot() async {
    try {
      final Map<String, dynamic> r = await _client.sendMap(
        'Page.captureScreenshot',
        params: <String, dynamic>{
          'format': 'png',
          'captureBeyondViewport': false,
        },
        sessionId: _sessionId,
      );
      final String? b64 = r['data'] as String?;
      if (b64 == null) return null;
      return base64Decode(b64);
    } catch (e) {
      _log.w('screenshot failed', e);
      return null;
    }
  }

  @override
  Future<AgentDiagnostics> diagnose() async {
    final Map<String, bool> results = <String, bool>{};
    final Map<String, SelectorSpec> suggestions = <String, SelectorSpec>{};

    results['composer'] = await _hasComposer();

    // Probe the DOM once, then let the kernel propose selectors.
    final Map<String, dynamic> probe = await _eval(
      'probe',
      <String, dynamic>{},
    );
    final int probeCount = probe['count'] is int ? probe['count'] as int : 0;

    if (results['composer'] != true && probeCount > 0) {
      final SelectorSpec? guess = await _guessComposer(probe);
      if (guess != null) {
        suggestions['composer'] = guess;
      }
    }

    results['send'] = config.send.isEmpty
        ? config.sendWithEnter
        : (await _eval('exists', <String, dynamic>{
                'spec': config.send.toJson(),
              }))['found'] ==
              true;

    results['assistantNode'] =
        (await _eval('exists', <String, dynamic>{
          'spec': config.extraction.assistantNode.toJson(),
        }))['found'] ==
        true;

    return AgentDiagnostics(
      kind: kind,
      results: results,
      suggestions: suggestions,
      probeCount: probeCount,
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      if (!_tokens.isClosed) await _tokens.close();
      if (!_statuses.isClosed) await _statuses.close();
    } catch (_) {
      // ignore
    }
  }

  // ---------------------------------------------------------------- internals

  /// Heuristic: the message box is the largest visible textarea or
  /// contenteditable on the page. Used only as a repair suggestion.
  Future<SelectorSpec?> _guessComposer(Map<String, dynamic> probe) async {
    final List<dynamic> els =
        (probe['elements'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic e in els) {
      final Map<String, dynamic> m = (e as Map).cast<String, dynamic>();
      final String tag = '${m['tag'] ?? ''}';
      final int w = m['w'] is int ? m['w'] as int : 0;
      final int h = m['h'] is int ? m['h'] as int : 0;
      if (tag == 'textarea' || m['testid'] != null && m['testid'] != '') {
        // Ask the kernel for a verified selector for this exact element.
        final Map<String, dynamic> sug = await _eval(
          'suggest',
          <String, dynamic>{
            'spec': <String, dynamic>{
              'css': <String>['$tag'],
            },
          },
        );
        final List<dynamic> cands =
            (sug['candidates'] as List<dynamic>?) ?? const <dynamic>[];
        if (cands.isNotEmpty) {
          final String sel = '${(cands.first as Map)['selector']}';
          return SelectorSpec(css: <String>[sel]);
        }
      }
      if (w > 200 && h > 20) {
        // large editable-looking box
      }
    }
    return null;
  }

  Future<int> _answerCount() async {
    final Map<String, dynamic> r = await _eval('count', <String, dynamic>{
      'spec': config.extraction.assistantNode.toJson(),
    });
    return r['count'] is int ? r['count'] as int : 0;
  }

  Future<bool> _stopButtonVisible() async {
    if (config.completion.stopButton.isEmpty) return false;
    final Map<String, dynamic> r = await _eval('exists', <String, dynamic>{
      'spec': config.completion.stopButton.toJson(),
    });
    return r['found'] == true;
  }

  Future<bool> _hasComposer() async {
    final Map<String, dynamic> r = await _eval('exists', <String, dynamic>{
      'spec': config.composer.toJson(),
    });
    return r['found'] == true;
  }

  String _currentUrl() async {
    try {
      final Map<String, dynamic> r = await _eval('ping');
      return '${r['url'] ?? ''}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _navigate(String url) async {
    _log.d('navigating to $url');
    await _client.send(
      'Page.navigate',
      params: <String, dynamic>{'url': url},
      sessionId: _sessionId,
    );
  }

  /// Poll until the composer shows up or we give up. Sites are SPAs: the
  /// `load` event fires long before the chat UI renders.
  Future<void> _waitForComposer({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final DateTime deadline = _clock().add(timeout);
    while (_clock().isBefore(deadline)) {
      if (await _hasComposer()) return;
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    _log.w('composer never appeared on $kind within ${timeout.inSeconds}s');
  }

  /// Run one kernel op and return its plain map.
  Future<Map<String, dynamic>> _eval(
    String op, [
    Map<String, dynamic> args = const <String, dynamic>{},
  ]) async {
    final String js = PageScript.call(op, args);
    final Map<String, dynamic> res = await _client.sendMap(
      'Runtime.evaluate',
      params: <String, dynamic>{
        'expression': js,
        'returnByValue': true,
        'awaitPromise': true,
        'userGesture': true,
      },
      sessionId: _sessionId,
      timeout: const Duration(seconds: 20),
    );

    final Object? details = res['exceptionDetails'];
    if (details != null) {
      throw AdapterException(
        kind,
        'Page script error in "$op": ${_exceptionText(details)}',
      );
    }
    final Object? result = res['result'];
    if (result is Map) {
      final Object? value = (result as Map)['value'];
      if (value is Map) return value.cast<String, dynamic>();
      return <String, dynamic>{'value': value};
    }
    return <String, dynamic>{};
  }

  String _exceptionText(Object? details) {
    try {
      final Map<String, dynamic> m = (details as Map).cast<String, dynamic>();
      final Object? ex = m['exception'];
      if (ex is Map) {
        final Object? desc = (ex as Map)['description'];
        if (desc != null) return '$desc'.split('\n').first;
        return '${(ex as Map)['value']}';
      }
      return '${m['text']}';
    } catch (_) {
      return 'unknown page error';
    }
  }

  void _emit(AgentPhase phase, {String detail = ''}) {
    _status = AgentStatus(phase, detail: detail);
    if (!_statuses.isClosed) _statuses.add(_status);
    _log.d('${kind} -> ${phase.name}${detail.isEmpty ? '' : ' ($detail)'}');
  }
}
