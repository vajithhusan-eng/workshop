import 'package:flutter_test/flutter_test.dart';

import 'package:agora/core/chrome/chrome_mode.dart';

/// P11 — the silent-Chrome launch mode.
///
/// The visible/silent difference is the whole feature, and it is pure: the
/// preference reader and the Chrome flag builder are testable without ever
/// spawning a browser. That is deliberate — the one thing that must not regress
/// silently is a launch mode the user cannot see.
void main() {
  group('ChromeMode.fromSetting', () {
    test('missing or blank falls back to visible', () {
      expect(ChromeMode.fromSetting(null), ChromeMode.visible);
      expect(ChromeMode.fromSetting(''), ChromeMode.visible);
      expect(ChromeMode.fromSetting('   '), ChromeMode.visible);
    });

    test('recognises silent, case- and whitespace-insensitively', () {
      expect(ChromeMode.fromSetting('silent'), ChromeMode.silent);
      expect(ChromeMode.fromSetting('SILENT'), ChromeMode.silent);
      expect(ChromeMode.fromSetting('  Silent  '), ChromeMode.silent);
    });

    test('reads the legacy boolean string', () {
      expect(ChromeMode.fromSetting('false'), ChromeMode.silent);
      expect(ChromeMode.fromSetting('true'), ChromeMode.visible);
    });

    test('anything unrecognised is visible, never silent', () {
      // The safe direction: a window the user cannot find is worse than one
      // they can. A corrupted preference must not hide Chrome.
      expect(ChromeMode.fromSetting('nonsense'), ChromeMode.visible);
      expect(ChromeMode.fromSetting('0'), ChromeMode.visible);
      expect(ChromeMode.fromSetting('silentt'), ChromeMode.visible);
    });

    test('round-trips through its own wire string', () {
      for (final m in ChromeMode.values) {
        expect(ChromeMode.fromSetting(m.wire), m);
        expect(ChromeMode.fromSetting(m.setting), m);
      }
    });

    test('isSilent is true for silent and only silent', () {
      expect(ChromeMode.silent.isSilent, isTrue);
      expect(ChromeMode.visible.isSilent, isFalse);
    });
  });

  group('chromeWindowArgs', () {
    test('visible launches have no window override', () {
      expect(chromeWindowArgs(), isEmpty);
      expect(chromeWindowArgs(silent: false), isEmpty);
    });

    test('silent parks the window off-screen but keeps it real', () {
      final args = chromeWindowArgs(silent: true);
      expect(args, <String>['--window-position=-32000,-32000']);
      // It must NOT be headless: a headless Chrome has no window to reveal
      // when a site asks for a human.
      expect(args, isNot(contains('--headless=new')));
    });

    test('headless wins over silent — no window to position', () {
      final args = chromeWindowArgs(headless: true, silent: true);
      expect(args, <String>['--headless=new']);
      expect(args, isNot(contains('--window-position=-32000,-32000')));
    });

    test('headless alone is just headless', () {
      expect(chromeWindowArgs(headless: true), <String>['--headless=new']);
    });
  });

  test('the preference key is declared once and is the documented one', () {
    expect(ChromeMode.prefKey, 'agora.chromeMode');
    expect(ChromeMode.legacyPrefKey, 'agora.chromeVisible');
  });
}
