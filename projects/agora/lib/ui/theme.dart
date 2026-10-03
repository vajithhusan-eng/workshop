import 'package:flutter/material.dart';

/// Agora reads as a room, not a chat app: dark, quiet, and deliberately plain
/// so the agents' own words are the only thing with colour in it.
class AgoraTheme {
  const AgoraTheme._();

  static const Color accent = Color(0xFF7C9CFF);
  static const Color surface0 = Color(0xFF0E1116);
  static const Color surface1 = Color(0xFF161B22);
  static const Color surface2 = Color(0xFF1C232C);
  static const Color hairline = Color(0xFF2A323D);
  static const Color dim = Color(0xFF8B98A8);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color ok = Color(0xFF5BD98A);

  /// Agora's own voice — annotations, system notices, stop reasons. Deliberately
  /// not an agent colour, so a reader never mistakes them for an AI speaking.
  static const Color agoraVoice = Color(0xFFB98CFF);

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: Color(0xFF0B0E13),
      secondary: agoraVoice,
      surface: surface0,
      onSurface: Color(0xFFE6EDF3),
      error: danger,
      outline: hairline,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface0,
      fontFamily: 'Inter',
      visualDensity: VisualDensity.compact,
    );

    return base.copyWith(
      dividerTheme: const DividerThemeData(
        color: hairline,
        thickness: 1,
        space: 1,
      ),
      cardTheme: const CardThemeData(
        color: surface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: hairline),
        ),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 500),
        decoration: BoxDecoration(
          color: surface2,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: const Color(0xFFE6EDF3),
        displayColor: const Color(0xFFE6EDF3),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: surface1,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: accent),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surface2,
        contentTextStyle: TextStyle(color: Color(0xFFE6EDF3)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['DejaVu Sans Mono', 'Courier New'],
    fontSize: 12.5,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11.5,
    color: dim,
    letterSpacing: 0.2,
  );
}
