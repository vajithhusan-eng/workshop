/// The design system for a dark trading terminal.
///
/// One question governs every value here: **does this help a trader read a
/// number correctly, or does it make the number look better than it is?**
///
/// Two rules follow, and they are the reason this file exists rather than a
/// scattering of `Theme.of(context).colorScheme.primary`:
///
/// 1. **The only saturated colours in the app are the action words.** A verdict
///    needs a sub-second glance; a grid line does not. Everything else is
///    deliberately desaturated so that a red SELL is the loudest thing on
///    screen by a wide margin.
/// 2. **No hue is invented to soften a bad result.** An app whose entire
///    argument is about not laundering uncomfortable truths cannot launder them
///    in its own chrome.
library;

// `FontFeature` comes through `material.dart`; importing `dart:ui` as well is
// a redundant import the analyzer rightly flags.
import 'package:flutter/material.dart';

/// Terminal colours and metrics. Never instantiated — every member is static.
class Terminal {
  Terminal._();

  // ── Surfaces ──────────────────────────────────────────────────────────────
  //
  // Five, not three. A terminal has depth, and collapsing to flat dark grey is
  // what makes most "dark mode" UIs feel like a document with the lights off.

  /// Chart gutter and the floor behind everything.
  static const void0 = Color(0xFF07090B);

  /// The page behind panels.
  static const base = Color(0xFF0B0F12);

  /// Watchlist column, analysis rail — the big flat regions.
  static const panel = Color(0xFF11161A);

  /// HUD tiles and cards that sit on a panel.
  static const raised = Color(0xFF161D22);

  /// Hover and active row.
  static const hover = Color(0xFF1C242B);

  // ── Lines ─────────────────────────────────────────────────────────────────

  static const hairline = Color(0x14FFFFFF); // 8%
  static const divider = Color(0x1FFFFFFF); // 12%

  // ── Text ──────────────────────────────────────────────────────────────────

  static const ink = Color(0xFFE6EDF0);
  static const ink2 = Color(0xFF9FB0AD);

  /// Axis labels, captions, and the `NO_DATA` verdict.
  ///
  /// Was `#6B7B79`, which measured 4.10:1 on [panel] and 3.84:1 on [raised] —
  /// under the 4.5:1 WCAG AA floor for text. Brightened to `#7B8D8B`, which
  /// clears 4.5:1 on every surface including [hover].
  static const ink3 = Color(0xFF7B8D8B);

  /// Disabled / inert text.
  ///
  /// Was `#485552`, which measures 2.34:1 against [panel] — below WCAG's 3:1
  /// floor, so the comment claiming it "stays legible" was false. Brightened to
  /// `#657672`: 3.80:1 on [panel], 3.56:1 on [raised], 3.28:1 on [hover].
  /// Still clearly recessed behind [ink3] and now actually readable.
  ///
  /// The tests assert the ratio rather than trusting the eye, which is what
  /// let the original value through.
  static const ink4 = Color(0xFF657672);

  // ── Actions ───────────────────────────────────────────────────────────────
  //
  // Five, mapping one-to-one onto the backend's ACTIONS vocabulary. No sixth
  // colour and no gradient, so a verdict can never be rendered in a shade that
  // fails to match its own enum.

  static const buy = Color(0xFF26A65B);
  static const buyDim = Color(0xFF1B7F4B);
  static const sell = Color(0xFFE0526F);

  /// Dimmed variants, for chart fills and secondary rows where a full-strength
  /// verdict would shout. `sellDim` was `#BE185D` at 2.82:1 on [raised] — under
  /// the 3:1 floor — so it is now `#D61C69`, which clears 3:1 on every surface
  /// while staying visibly below [sell].
  static const sellDim = Color(0xFFD61C69);

  /// "Caution" — a warning, not a direction.
  ///
  /// Was `#D9A441`, close enough to [sell] under deuteranopia that SELL and
  /// HOLD read as a single colour at 1.09:1. Brightened to `#F8BC4C`:
  /// 1.45:1 against SELL, 4.28:1 against BUY, still 4.4:1 on the dimmest
  /// surface.
  static const hold = Color(0xFFF8BC4C);

  /// "Stay out". Deep burnt orange.
  ///
  /// Was `#E07A3F`, a near-sibling of [hold]: the two measured 0.20 apart in
  /// RGB and 1.04:1 under a deuteranopia simulation, so a reader with the
  /// commonest form of colour deficiency could not tell a HOLD from an AVOID
  /// at all. Now 0.39 RGB separation and 2.08:1, on 3.6:1 contrast everywhere.
  ///
  /// This does not make the palette fully separable under deuteranopia — see
  /// `terminal_test.dart` for which pairs are and which are not, and why 1.5:1
  /// is unreachable without muting BUY.
  static const avoid = Color(0xFFB66231);

  /// Aliases onto the ink ramp on purpose: "no answer" is an absence of
  /// information, so it wears an absence-of-emphasis colour rather than one of
  /// the five verdicts. Aliasing also means it cannot drift out of AA the way
  /// an independently-tuned literal did.
  static const nodata = ink3;

  static const good = buy;
  static const bad = sell;
  static const warn = hold;
  static const info = Color(0xFF4A9DB8);

  // ── Chart series ──────────────────────────────────────────────────────────
  //
  // Lives here, not in the chart module, so the chart, the HUD and the legend
  // cannot disagree about what "the RSI line" looks like.

  static const sma20 = Color(0xFFE0B341);
  static const sma50 = Color(0xFF9B7BE0);
  static const ema9 = Color(0xFF4A9DB8);
  static const ema21 = Color(0xFFCE6BA8);
  static const bb = Color(0x665E8C9B);
  static const rsi = Color(0xFFB08BD9);
  static const macdLine = Color(0xFF4A9DB8);
  static const macdSignal = Color(0xFFE0B341);
  static const volumeUp = Color(0x7326A65B);
  static const volumeDown = Color(0x73E0526F);
  static const crosshair = Color(0x669FB0AD);

  // ── Spacing ───────────────────────────────────────────────────────────────

  static const s1 = 2.0;
  static const s2 = 4.0;
  static const s3 = 8.0;
  static const s4 = 12.0;
  static const s5 = 16.0;
  static const s6 = 24.0;

  // ── Type ──────────────────────────────────────────────────────────────────

  /// Digits that do not reflow as they change.
  ///
  /// A price that shifts sideways as the last digit ticks makes a column of
  /// prices impossible to scan, which is the entire reason for showing them in
  /// a column.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const mono = 'Roboto Mono, monospace';

  static TextStyle num({
    double size = 13,
    Color color = ink,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        fontFeatures: tabular,
        fontFamily: mono,
        height: 1.1,
      );

  static TextStyle label({
    double size = 10,
    Color color = ink3,
    FontWeight weight = FontWeight.w600,
  }) =>
      TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: 0.8,
      );

  static TextStyle body({
    double size = 13,
    Color color = ink2,
  }) =>
      TextStyle(fontSize: size, color: color, height: 1.45);

  // ── Theme ─────────────────────────────────────────────────────────────────

  static ThemeData theme() {
    const scheme = ColorScheme.dark(
      surface: panel,
      primary: info,
      secondary: buy,
      error: sell,
      onSurface: ink,
    );
    return ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: base,
      canvasColor: base,
      dividerColor: hairline,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: info,
        selectionColor: Color(0x334A9DB8),
        selectionHandleColor: info,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: base,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: panel,
        indicatorColor: hover,
        height: 58,
        labelTextStyle: WidgetStatePropertyAll(
          label(size: 10, color: ink2),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected) ? ink : ink3,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: hairline,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: raised,
          borderRadius: BorderRadius.circular(s2),
          border: Border.all(color: divider),
        ),
        textStyle: body(size: 12, color: ink),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(ink4.withValues(alpha: 0.6)),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(s3),
      ),
    );
  }
}

/// The colour for a backend action string.
///
/// Total by construction: an unrecognised action reads as [Terminal.nodata],
/// never as a plausible-looking green. A typo in the enum must not become a
/// BUY on screen.
Color actionColor(String action) => switch (action.toUpperCase()) {
      'BUY' => Terminal.buy,
      'SELL' => Terminal.sell,
      'HOLD' => Terminal.hold,
      'AVOID' => Terminal.avoid,
      'NO_DATA' => Terminal.nodata,
      _ => Terminal.nodata,
    };

/// Green for up, red for down, neutral for zero.
///
/// A zero change is not an up day. Rendering it green is how a chart teaches
/// its reader that the colour means nothing.
Color signColor(double v) => v > 0
    ? Terminal.good
    : v < 0
        ? Terminal.bad
        : Terminal.ink2;
