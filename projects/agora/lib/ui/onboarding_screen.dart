import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/chrome/chrome_launcher.dart';
import '../core/chrome/chrome_mode.dart';
import '../core/adapters/agent_adapter.dart';
import '../core/adapters/bundle_loader.dart';
import '../core/council/login_checker.dart';
import 'theme.dart';

/// First-run setup. Three steps, and none of them are optional decoration:
///
///  1. What Agora is and where it keeps things.
///  2. Whether Agora's own Chrome profile is actually signed in to each AI.
///     This is the step that matters — Chrome 136+ refuses remote debugging on
///     the default profile, so Agora drives a dedicated one and the user has to
///     sign in to each site once, by hand, in that window.
///  3. The three plan-level defaults, as real settings.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final Future<void> Function() onDone;

  /// Shown only when no wizard has ever been completed.
  static const prefsKey = 'agora.onboarded';

  static const siteKinds = <String>['chatgpt', 'gemini', 'deepseek'];

  static const prefsKeys = <String, String>{
    'agora.dailyCapPerAgent': '60',
    'agora.chromeVisible': 'true',
    'agora.chromeMode': 'visible',
    'agora.relayRaw': 'true',
  };

  static Future<bool> alreadyOnboarded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(prefsKey) ?? false;
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pager = PageController();
  LoginChecker? _checker;

  int _step = 0;
  bool _checking = false;
  List<LoginCheck>? _checks;
  String? _checkError;

  bool _cap = true;
  bool _silentChrome = false;
  bool _rawRelay = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _cap = int.tryParse(p.getString('agora.dailyCapPerAgent') ?? '60') != 0;
      _silentChrome = ChromeMode.fromSetting(
        p.getString(ChromeMode.prefKey) ??
            (p.getBool(ChromeMode.legacyPrefKey) ?? true).toString(),
      ).isSilent;
      _rawRelay = p.getBool('agora.relayRaw') ?? true;
    });
  }

  @override
  void dispose() {
    _pager.dispose();
    // Never leak a Chrome the wizard opened just to look at it.
    _checker?.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pager.animateToPage(
      step,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  LoginChecker get _checkerOrCreate => _checker ??= LoginChecker(
    adapterLoader: bundleAdapterLoader(),
    headless: false,
  );

  Future<void> _runCheck() async {
    setState(() {
      _checking = true;
      _checkError = null;
    });
    try {
      final rows = await _checkerOrCreate.checkAll(OnboardingScreen.siteKinds);
      setState(() => _checks = rows);
    } on Object catch (e) {
      setState(() => _checkError = '$e');
    } finally {
      setState(() => _checking = false);
    }
  }

  Future<void> _openForSignIn() async {
    setState(() {
      _checking = true;
      _checkError = null;
    });
    try {
      await _checkerOrCreate.openSignInTabs(OnboardingScreen.siteKinds);
    } on Object catch (e) {
      setState(() => _checkError = '$e');
    } finally {
      setState(() => _checking = false);
    }
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('agora.dailyCapPerAgent', _cap ? '60' : '0');
    final mode = _silentChrome ? ChromeMode.silent : ChromeMode.visible;
    await p.setString(ChromeMode.prefKey, mode.wire);
    // Keep the legacy bool truthful for anything still reading it.
    await p.setBool(ChromeMode.legacyPrefKey, mode == ChromeMode.visible);
    await p.setBool('agora.relayRaw', _rawRelay);
  }

  Future<void> _finish() async {
    await _savePrefs();
    await _checker?.dispose();
    _checker = null;
    final p = await SharedPreferences.getInstance();
    await p.setBool(OnboardingScreen.prefsKey, true);
    await widget.onDone();
  }

  int get _readyCount =>
      (_checks ?? const <LoginCheck>[]).where((c) => c.ready).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView(
                controller: _pager,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  _welcome(context),
                  _signIn(context),
                  _preferences(context),
                ],
              ),
            ),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _card(Widget child) => Container(
    constraints: const BoxConstraints(maxWidth: 640),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AgoraTheme.surface1,
      border: Border.all(color: AgoraTheme.hairline),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );

  Widget _welcome(BuildContext context) {
    return _Centered(
      title: 'Agora',
      subtitle:
          'A council of the AI websites you already use, arguing it out in '
          'front of you — and keeping every word they said.',
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Everything stays on this machine. Agora keeps no account, sends '
              'no telemetry, and stores your transcripts in a local database '
              'you can export or delete at any time.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 18),
            const Text('On disk', style: AgoraTheme.caption),
            const SizedBox(height: 6),
            _path('Config', AgoraPaths.root),
            _path('Chrome profile', AgoraPaths.chromeProfile),
            _path('Transcript vault', AgoraPaths.vaultDir),
            _path('Logs', AgoraPaths.logsDir),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AgoraTheme.accent.withValues(alpha: 0.10),
                border: Border.all(
                  color: AgoraTheme.accent.withValues(alpha: 0.35),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Chrome 136 and newer refuse remote debugging on your everyday '
                'profile, so Agora drives its own copy. You will sign in to each '
                'AI site once, in that window. Your normal Chrome is untouched.',
                style: TextStyle(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _path(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 120, child: Text(label, style: AgoraTheme.caption)),
        Expanded(child: Text(value, style: AgoraTheme.mono)),
      ],
    ),
  );

  Widget _signIn(BuildContext context) {
    final rows = _checks;
    return _Centered(
      title: 'Sign in to your AI sites',
      subtitle:
          'Agora talks to the real websites in a real browser. Each one '
          'needs a sign-in in Agora\'s own Chrome window.',
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _checking ? null : _runCheck,
                  icon: _checking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(
                    rows == null ? 'Check my sign-ins' : 'Check again',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _checking ? null : _openForSignIn,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open Chrome to sign in'),
                ),
              ],
            ),
            if (_checkError != null) ...<Widget>[
              const SizedBox(height: 14),
              _note(Icons.error_outline, AgoraTheme.danger, _checkError!),
            ],
            if (rows != null && !_checking) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                '$_readyCount of ${rows.length} ready',
                style: AgoraTheme.caption,
              ),
              const SizedBox(height: 8),
              for (final r in rows) _checkRow(context, r),
            ],
            const SizedBox(height: 12),
            const Text(
              'A signed-out site is the normal first-run state, not an error. '
              'Sign in, then press Check again.',
              style: AgoraTheme.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkRow(BuildContext context, LoginCheck c) {
    final color = c.ready ? AgoraTheme.ok : AgoraTheme.danger;
    final icon = switch (c.status) {
      LoginStatus.ready => Icons.check_circle_outline,
      LoginStatus.captcha => Icons.gpp_maybe_outlined,
      LoginStatus.needsRepair => Icons.build_circle_outlined,
      _ => Icons.error_outline,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(c.displayName, style: AgoraTheme.mono),
                const SizedBox(height: 2),
                Text(c.remedy, style: AgoraTheme.caption),
                if (c.detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      c.detail,
                      style: AgoraTheme.caption.copyWith(color: color),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preferences(BuildContext context) {
    return _Centered(
      title: 'How Agora should behave',
      subtitle:
          'These are the three defaults the design left open. Change them '
          'now or any time in Settings.',
      child: _card(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _toggle(
              'Cap each AI at 60 messages a day',
              'A hard stop the budget guard enforces. Protects your quota and '
                  'your account.',
              value: _cap,
              onChanged: (v) => setState(() => _cap = v),
            ),
            const Divider(height: 28),
            _toggle(
              'Start Chrome off-screen (silent)',
              'Silent keeps the browser window hidden so a long council does '
                  'not fill your desktop. Agora brings it back the moment a '
                  'site needs you — a CAPTCHA or an expired sign-in.',
              value: _silentChrome,
              onChanged: (v) => setState(() => _silentChrome = v),
            ),
            const Divider(height: 28),
            _toggle(
              'Relay answers raw',
              'Each AI receives what the others actually wrote, not a summary. '
                  'This is the whole point.',
              value: _rawRelay,
              onChanged: (v) => setState(() => _rawRelay = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle(
    String title,
    String blurb, {
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title),
            const SizedBox(height: 2),
            Text(blurb, style: AgoraTheme.caption),
          ],
        ),
      ),
      Switch(value: value, onChanged: onChanged),
    ],
  );

  Widget _footer(BuildContext context) {
    final isLast = _step == 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AgoraTheme.hairline)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Row(
          children: <Widget>[
            for (var i = 0; i < 3; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _step ? AgoraTheme.accent : AgoraTheme.hairline,
                ),
              ),
            const Spacer(),
            if (_step > 0)
              TextButton(
                onPressed: () => _goTo(_step - 1),
                child: const Text('Back'),
              ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => isLast ? _finish() : _goTo(_step + 1),
              child: Text(isLast ? 'Start' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(subtitle, style: AgoraTheme.caption),
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

Widget _note(IconData icon, Color color, String text) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: <Widget>[
    Icon(icon, size: 18, color: color),
    const SizedBox(width: 8),
    Expanded(
      child: Text(text, style: AgoraTheme.caption.copyWith(color: color)),
    ),
  ],
);
