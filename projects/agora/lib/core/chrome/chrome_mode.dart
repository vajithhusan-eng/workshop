/// How Agora launches Chrome — Amendment R1, §18.5 item P11.
///
/// `visible` is the historical behaviour: the window is on screen, because a
/// real AI site can throw a captcha or expire a login and the user has to see
/// it. `silent` starts the window parked off-screen so a long council run does
/// not turn the desktop into a wall of tabs. The window still exists, so
/// `TabPool.reveal` can pull it back the moment a site needs a human.
///
/// Deliberately **not** `--headless=new`: a headless Chrome has no window, so
/// there would be nothing to reveal when a site demands a human.
enum ChromeMode {
  visible('visible'),
  silent('silent');

  const ChromeMode(this.wire);

  /// The preference this mode is stored under, shared by every reader so the
  /// key is declared exactly once.
  static const String prefKey = 'agora.chromeMode';

  /// The bool this mode replaced. Still read so an install that only ever wrote
  /// the old key keeps behaving the way it did.
  static const String legacyPrefKey = 'agora.chromeVisible';

  /// The persisted value, under the `agora.chromeMode` preference.
  final String wire;

  /// Alias the settings layer can store and read without knowing the enum.
  String get setting => wire;

  bool get isSilent => this == ChromeMode.silent;

  /// Reads the preference defensively.
  ///
  /// Missing or unrecognised values fall back to [visible] — the safe choice,
  /// because a window the user cannot find is worse than one they can. The
  /// legacy `agora.chromeVisible` boolean is understood too, so an install that
  /// only ever wrote that key keeps behaving the way it did.
  static ChromeMode fromSetting(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'silent' || 'false' => ChromeMode.silent,
      _ => ChromeMode.visible,
    };
  }
}

/// The Chrome command-line window flags for a launch mode.
///
/// Pure on purpose: the visible/silent difference is the part worth testing,
/// and it can be tested without spawning a browser. `headless` wins when both
/// are set, because a headless browser has no window to position.
List<String> chromeWindowArgs({bool headless = false, bool silent = false}) {
  return <String>[
    if (headless) '--headless=new',
    if (!headless && silent) '--window-position=-32000,-32000',
  ];
}
