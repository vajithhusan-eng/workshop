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
    required AdapterConfig config,
    required CdpClient client,
    required String targetId,
    DateTime Function()? clock,
  }) : _config = config,
       _targetId = targetId,
       _client = client,
       _clock = clock ?? DateTime.now;

  final AdapterConfig _config;
  final String _targetId;
  final CdpClient _client;
  final DateTime Function() _clock;

  String? _sessionId;
  final StreamController<AgentStatus> _statuses =
      StreamController<AgentStatus>.broadcast();

  /// Non-final on purpose: it is closed and replaced after every completed
  /// answer so late subscribers never see a finished answer replay.
  StreamController<String> _tokens = StreamController<String>.broadcast();

  AgentStatus _status = const AgentStatus(AgentPhase.opening);
  bool _closed = false;
  bool _interrupted = false;
  DateTime? _sentAt;

  /// Baseline answer count, so we can detect "the new answer has arrived"
  /// instead of re-reading the previous one.
  int _answerBaseline = 0;

  @override
  AdapterConfig get config => _config;

  @override
  String get kind => _config.kind;

  @override
  String get displayName => _config.displayName;

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

      // Chrome throttles timers in background tabs to roughly once per minute
      // and freezes them entirely once a page has been hidden for five minutes.
      // A council drives three or more tabs at once and polls each one while it
      // waits on the others, so without this the polling loop on every
      // non-foreground tab stalls until the full completion timeout -- and the
      // "still typing?" check that ends a send never fires. Focus emulation
      // tells the page it is visible and focused regardless of which tab the
      // user happens to be looking at.
      //
      // Best-effort by design: if Chrome or the site rejects the call we still
      // work, only slower, so a failure must never abort a council.
      try {
        await _client.send(
          'Emulation.setFocusEmulationEnabled',
          params: <String, dynamic>{'enabled': true},
          sessionId: _sessionId,
        );
        _log.d('focus emulation on');
      } on Object catch (e) {
        _log.w('focus emulation unavailable, polling may be slow', e);
      }

      _emit(AgentPhase.opening);
      await _navigate(config.homeUrl);

      // Short first wait only. A logged-out / CAPTCHA / rate-limit page has no
      // composer at all, so we must probe login state early instead of burning
      // the full composer timeout on a page that will never render one.
      await _waitForComposer(timeout: const Duration(seconds: 8));

      LoginState state = await checkLogin();
      if (!state.isReady) {
        // Try one more time with composer directly for modern UIs
        if (await _hasComposer()) {
          state = LoginState.ready;
        } else {
          _emit(AgentPhase.blocked, detail: state.message);
          return state;
        }
      }

      // Only now insist on a composer — we know we are signed in now.
      await _waitForComposer();
      _answerBaseline = await _answerCount();
      _emit(AgentPhase.ready);
      return state;
    } on CdpException catch (e) {
      final String why = e.message ?? 'CDP call failed';
      _log.e('connect failed', e);
      _emit(AgentPhase.error, detail: why);
      return LoginState(
        status: LoginStatus.transportError,
        message: why,
        url: _config.homeUrl,
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

    // Also treat "we can see a composer" as logged in for modern sites where
    // logged-in buttons may not appear immediately.
    if (await _hasComposer()) return LoginState.ready;

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
    if (config.newChatUrl.isNotEmpty) {
      await _navigate(config.newChatUrl);
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

    // Serialized dispatch means the agent we are about to type into should also
    // be the foreground tab, so the compositor keeps it at full frame rate.
    // Best-effort for the same reason as focus emulation above.
    try {
      await _client.send('Page.bringToFront', sessionId: _sessionId);
    } on Object catch (e) {
      _log.w('bringToFront failed', e);
    }

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

    // CRITICAL: the answer baseline MUST be captured *before* the send action.
    // Every real AI site appends an empty assistant node synchronously inside
    // its send click handler, so reading the count afterwards yields N+1 and
    // `nodeCount > _answerBaseline` is then false forever — awaitCompletion
    // spins to its full timeout on every single send. Measured on the Sandbox
    // Lab fixture: 45s instead of 1.4s.
    _answerBaseline = await _answerCount();
    _sentAt = _clock();

    if (config.send.isNotEmpty) {
      final Map<String, dynamic> clicked = await _eval(
        'click',
        <String, dynamic>{'spec': config.send.toJson()},
      );
      if (clicked['ok'] == true) {
        return;
      }
      _log.w('send button not clickable; falling back to Enter');
    }

    if (config.sendWithEnter) {
      await _eval('pressEnter', <String, dynamic>{
        'spec': config.composer.toJson(),
      });
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

    Verbatim result = last.copyWith(
      latencyMs: _clock().difference(start).inMilliseconds,
    );

    // Verbatim Vault (upgrade C3): the adapter asked for a screenshot, so we
    // take one. Failing to capture a screenshot must never lose the answer.
    if (config.extraction.screenshotOnStore) {
      try {
        result = result.copyWith(screenshotBytes: await screenshot());
      } catch (e) {
        _log.w('screenshot failed for $kind; keeping text-only Verbatim', e);
      }
    }

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

  /// Heuristic: propose a replacement composer selector.
  ///
  /// Only elements that genuinely accept typed text are eligible. A previous
  /// version ranked by "has a data-testid", which happily proposed a profile
  /// <button> as the message box — a "fix" that passed a naive exists-check
  /// while leaving the adapter completely unable to type.
  Future<SelectorSpec?> _guessComposer(Map<String, dynamic> probe) async {
    final List<dynamic> els =
        (probe['elements'] as List<dynamic>?) ?? const <dynamic>[];

    final List<Map<String, dynamic>> candidates = <Map<String, dynamic>>[];
    for (final dynamic e in els) {
      final Map<String, dynamic> m = (e as Map).cast<String, dynamic>();
      if (m['editable'] != true) continue;
      final int w = m['w'] is int ? m['w'] as int : 0;
      final int h = m['h'] is int ? m['h'] as int : 0;
      // A composer is a wide box, not a one-line search field.
      if (w < 160 || h < 24) continue;
      candidates.add(m);
    }
    if (candidates.isEmpty) return null;

    // Prefer the largest surface: that is the one a person would type into.
    candidates.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final int areaA = (a['w'] as int) * (a['h'] as int);
      final int areaB = (b['w'] as int) * (b['h'] as int);
      return areaB.compareTo(areaA);
    });

    final Map<String, dynamic> best = candidates.first;
    final Map<String, dynamic> sug = await _eval('suggest', <String, dynamic>{
      'spec': <String, dynamic>{
        'css': <String>['${best['tag']}'],
      },
    });
    final List<dynamic> cands =
        (sug['candidates'] as List<dynamic>?) ?? const <dynamic>[];
    if (cands.isEmpty) return null;

    // Prefer a candidate the kernel verified as exact.
    for (final dynamic c in cands) {
      if ((c as Map)['exact'] == true) {
        return SelectorSpec(css: <String>['${c['selector']}']);
      }
    }
    return SelectorSpec(css: <String>['${(cands.first as Map)['selector']}']);
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

  Future<String> _currentUrl() async {
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
      final Object? value = result['value'];
      if (value is Map) return value.cast<String, dynamic>();
      return <String, dynamic>{'value': value};
    }
    return <String, dynamic>{};
  }

  String _exceptionText(Object? details) {
    try {
      if (details is! Map) return '$details';
      final Map<String, dynamic> m = details.cast<String, dynamic>();
      final Object? ex = m['exception'];
      if (ex is Map) {
        final Object? desc = ex['description'];
        if (desc != null) return '$desc'.split('\n').first;
        return '${ex['value']}';
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
