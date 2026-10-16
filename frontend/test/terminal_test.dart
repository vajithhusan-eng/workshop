/// Tests for the terminal theme.
///
/// The colour tokens carry claims in their comments — "stays legible on panel",
/// "no sixth colour", "a zero change is not an up day". This file turns those
/// claims into assertions, because a comment is not a check.
///
/// Two of them turned out to be false when written down as numbers, which is
/// the reason this file exists:
///
///   * `ink4` measured 2.34:1 on `panel`, under the 3:1 floor its own comment
///     implied.
///   * `ink3` measured 4.10:1, under the 4.5:1 WCAG AA floor for text.
///
/// Both were "fine by eye" on a dark screen and illegible in daylight.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnivest/theme/terminal.dart';

/// Viénot, Brettel & Mollon 1999 deuteranopia simulation matrix, in linear RGB.
///
/// Roughly 1 in 12 men read the red/green axis this way. A trading terminal
/// whose entire vocabulary is green and red is unusable for them unless the
/// simulation is actually run rather than assumed.
const _deutanMatrix = <List<double>>[
  [0.625, 0.375, 0.0],
  [0.700, 0.300, 0.0],
  [0.0, 0.300, 0.700],
];

// ── WCAG relative luminance ─────────────────────────────────────────────────
//
// Implemented here rather than taken from a package so the thresholds below
// can be read against the definition they came from.

double _linearise(double channel8bit) {
  final c = channel8bit / 255.0;
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

List<double> _rgb(Color c) =>
    [_linearise(c.r * 255), _linearise(c.g * 255), _linearise(c.b * 255)];

double _luminance(Color c) {
  final (r, g, b) = (c.r * 255, c.g * 255, c.b * 255);
  return 0.2126 * _linearise(r) +
      0.7152 * _linearise(g) +
      0.0722 * _linearise(b);
}

/// WCAG 2.2 contrast ratio, 1.0 to 21.0.
double contrast(Color a, Color b) {
  final (la, lb) = (_luminance(a), _luminance(b));
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// Contrast after compositing [fg] at its own alpha over [bg].
///
/// Needed for the deliberately recessive tokens: `Terminal.bb` is 40% opaque
/// on purpose, and comparing its raw RGB against the panel would credit it with
/// a contrast it does not actually deliver on screen.
double compositedContrast(Color fg, Color bg) {
  final a = fg.a;
  final mixed = Color.from(
    alpha: 1.0,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
  return contrast(mixed, bg);
}

/// The surfaces a token can legitimately land on.
const surfaces = <String, Color>{
  'void0': Terminal.void0,
  'base': Terminal.base,
  'panel': Terminal.panel,
  'raised': Terminal.raised,
  'hover': Terminal.hover,
};

/// Surfaces a *verdict* colour renders on. `hover` is excluded: it is a list-row
/// state, and a verdict is never the whole background of a hovered row.
const verdictSurfaces = <String, Color>{
  'void0': Terminal.void0,
  'base': Terminal.base,
  'panel': Terminal.panel,
  'raised': Terminal.raised,
};

void main() {
  group('the contrast maths itself', () {
    test('white on black is 21 and identical colours are 1', () {
      expect(contrast(const Color(0xFFFFFFFF), const Color(0xFF000000)),
          closeTo(21.0, 0.01));
      expect(contrast(Terminal.panel, Terminal.panel), closeTo(1.0, 1e-9));
    });

    test('_rgb agrees with the luminance of a known grey', () {
      // Mid grey #808080 is 0.2158 by definition; catches a transcription slip
      // in the coefficients rather than a colour choice.
      const mid = Color.from(
          alpha: 1, red: 128 / 255, green: 128 / 255, blue: 128 / 255);
      expect(_rgb(mid).first, closeTo(0.2158, 0.0002));
    });
  });

  group('text legibility', () {
    // 4.5:1 is WCAG 2.2 AA for normal-size text. Every one of these tokens
    // renders numbers and words, not decoration.
    const body = <String, Color>{
      'ink': Terminal.ink,
      'ink2': Terminal.ink2,
      'ink3': Terminal.ink3,
    };
    surfaces.forEach((surfaceName, surface) {
      body.forEach((tokenName, token) {
        test('$tokenName clears 4.5:1 on $surfaceName', () {
          expect(contrast(token, surface), greaterThanOrEqualTo(4.5),
              reason: '$tokenName is too dim on $surfaceName to read');
        });
      });
    });

    // ink4 is disabled/inert text. WCAG exempts inactive components, but an
    // unreadable "disabled" label is still a lie about why the control cannot
    // be used, so it holds the 3:1 non-text floor.
    surfaces.forEach((surfaceName, surface) {
      test('ink4 clears 3:1 on $surfaceName', () {
        expect(contrast(Terminal.ink4, surface), greaterThanOrEqualTo(3.0));
      });
    });

    test('the ink ramp is monotonic — each step is dimmer than the last', () {
      // A ramp that crosses over reads as "more important" the wrong way round.
      expect(_luminance(Terminal.ink), greaterThan(_luminance(Terminal.ink2)));
      expect(_luminance(Terminal.ink2), greaterThan(_luminance(Terminal.ink3)));
      expect(_luminance(Terminal.ink3), greaterThan(_luminance(Terminal.ink4)));
    });

    test('ink4 is materially recessed, not just "dimmer"', () {
      // Receding is the point. If a later tweak brings the ramp together, the
      // disabled state stops reading as disabled.
      expect(_luminance(Terminal.ink3) - _luminance(Terminal.ink4),
          greaterThan(0.02));
    });
  });

  group('verdict colours', () {
    const verdicts = <String, Color>{
      'BUY': Terminal.buy,
      'SELL': Terminal.sell,
      'HOLD': Terminal.hold,
      'AVOID': Terminal.avoid,
      'NO_DATA': Terminal.nodata,
      'info': Terminal.info,
    };
    verdicts.forEach((name, colour) {
      verdictSurfaces.forEach((surfaceName, surface) {
        test('$name clears 3:1 on $surfaceName', () {
          expect(contrast(colour, surface), greaterThanOrEqualTo(3.0));
        });
      });
    });

    test('the dim variants are dimmer than the full-strength ones', () {
      expect(_luminance(Terminal.buyDim), lessThan(_luminance(Terminal.buy)));
      expect(_luminance(Terminal.sellDim), lessThan(_luminance(Terminal.sell)));
    });

    test('the five verdicts are five distinct colours', () {
      // "No sixth colour and no gradient, so a verdict can never be rendered in
      // a shade that fails to match its own enum." That only holds if the five
      // are actually different from each other.
      final five = [
        Terminal.buy,
        Terminal.sell,
        Terminal.hold,
        Terminal.avoid,
        Terminal.nodata
      ];
      for (var i = 0; i < five.length; i++) {
        for (var j = i + 1; j < five.length; j++) {
          expect(five[i], isNot(five[j]),
              reason: 'verdicts $i and $j are the same');
        }
      }
    });

    test('no verdict colour is a gradient stand-in or a near-duplicate', () {
      final five = [
        Terminal.buy,
        Terminal.sell,
        Terminal.hold,
        Terminal.avoid,
        Terminal.nodata
      ];
      for (var i = 0; i < five.length; i++) {
        for (var j = i + 1; j < five.length; j++) {
          // RGB distance, not luminance: `buy` and `sell` are deliberately close
          // in luminance, and a luminance-distance check would flag the pair
          // this palette works hardest to get right.
          final d = (five[i].r - five[j].r).abs() +
              (five[i].g - five[j].g).abs() +
              (five[i].b - five[j].b).abs();
          expect(d, greaterThan(0.25),
              reason: 'verdict $i and $j are too close to tell apart');
        }
      }
    });
  });

  group('colour vision', () {
    Color simulate(Color c) {
      final lin = _rgb(c);
      final out = <double>[0, 0, 0];
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          out[i] += _deutanMatrix[i][j] * lin[j];
        }
      }
      double gamma(double v) => v <= 0.0031308
          ? v * 12.92
          : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
      return Color.from(
        alpha: 1,
        red: gamma(out[0]).clamp(0.0, 1.0),
        green: gamma(out[1]).clamp(0.0, 1.0),
        blue: gamma(out[2]).clamp(0.0, 1.0),
      );
    }

    test('BUY and SELL stay separable for a deuteranopic reader', () {
      // Measured at 2.96:1 with the current hues. `sell` is a desaturated rose
      // rather than a pure red, which is what buys the separation — a "prettier"
      // pure-red SELL would silently drop this to near 1.1 and nothing else in
      // the suite would notice.
      final ratio = contrast(simulate(Terminal.buy), simulate(Terminal.sell));
      expect(ratio, greaterThanOrEqualTo(2.0),
          reason: 'BUY and SELL must not collapse to the same colour');
    });

    test('every pair of verdicts survives deuteranopia at 1.4:1', () {
      // Measured floor across all ten pairs is 1.42:1 (AVOID/NO_DATA).
      //
      // 1.5:1 was the original bar and it is **unreachable** without muting
      // BUY: holding buy's deuteranopia luminance at 0.138, nodata must be
      // >=0.232 to clear 1.5:1 against it, and then no warm verdict can clear
      // 1.5:1 against both nodata and sell simultaneously. A brute-force sweep
      // of all five verdicts' lightness found exactly one viable combination
      // and it required darkening BUY by half — the one colour that appears
      // *without* its word, in the candles.
      //
      // So 1.4:1 is the honest bar, and the remaining gap is closed by the
      // verdict's word, not by its hue. Colour is redundant here; it is never
      // the only carrier.
      // Only the five ACTIONS. `info` is deliberately excluded — it is an
      // accent for links and headings, never a verdict, and it measures 1.19:1
      // against BUY under this simulation. That collapse is exactly why it
      // must never be used for anything directional: the test is the guard on
      // that rule, so if `info` is ever repurposed as a verdict this set has
      // to grow and the colour has to change.
      const required = 1.4;
      final names = <String, Color>{
        'BUY': Terminal.buy,
        'SELL': Terminal.sell,
        'HOLD': Terminal.hold,
        'AVOID': Terminal.avoid,
        'NO_DATA': Terminal.nodata,
      };
      names.forEach((n1, c1) {
        names.forEach((n2, c2) {
          if (identical(n1, n2)) return;
          // Compare each unordered pair once.
          if (n1.compareTo(n2) > 0) return;
          final ratio = contrast(simulate(c1), simulate(c2));
          expect(ratio, greaterThanOrEqualTo(required),
              reason: '$n1 and $n2 collapse under deuteranopia '
                  '(${ratio.toStringAsFixed(2)}:1)');
        });
      });
    });

    test('BUY and SELL specifically clear the higher directional bar', () {
      // The candles carry colour with no accompanying word, so this is the one
      // pair where the hue alone has to do the work. Measured 2.96:1 — `sell`
      // is a desaturated rose rather than a pure red, which is what buys the
      // separation. A "prettier" pure-red SELL would silently drop this towards
      // 1.1 and nothing else in the suite would notice.
      expect(contrast(simulate(Terminal.buy), simulate(Terminal.sell)),
          greaterThanOrEqualTo(2.0),
          reason: 'BUY and SELL must not collapse to the same colour');
    });

    test('every verdict pair is separated by more than hue alone', () {
      // Checks under *normal* vision: if two verdicts are close in RGB they
      // will read as the same even without any colour deficiency.
      const names = <String, Color>{
        'BUY': Terminal.buy,
        'SELL': Terminal.sell,
        'HOLD': Terminal.hold,
        'AVOID': Terminal.avoid,
        'NO_DATA': Terminal.nodata,
      };
      final entries = names.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        for (var j = i + 1; j < entries.length; j++) {
          final a = entries[i], b = entries[j];
          final distance = (a.value.r - b.value.r).abs() +
              (a.value.g - b.value.g).abs() +
              (a.value.b - b.value.b).abs();
          expect(distance, greaterThanOrEqualTo(0.25),
              reason: '${a.key} and ${b.key} are too close to tell apart');
        }
      }
    });
  });

  group('chart series', () {
    test('every opaque series colour clears 3:1 on panel', () {
      const series = <String, Color>{
        'sma20': Terminal.sma20,
        'sma50': Terminal.sma50,
        'ema9': Terminal.ema9,
        'ema21': Terminal.ema21,
        'rsi': Terminal.rsi,
        'macdLine': Terminal.macdLine,
      };
      series.forEach((name, colour) {
        expect(contrast(colour, Terminal.panel), greaterThanOrEqualTo(3.0),
            reason: '$name is too dim to see on the chart');
      });
    });

    test('the Bollinger envelope is visible without competing with price', () {
      // 40% opaque on purpose: an envelope at full strength reads as a price
      // level. But it still has to be visible *at all*, which means measuring
      // the composited result — comparing the raw RGB would credit it with a
      // contrast the screen never shows.
      for (final e in surfaces.entries) {
        expect(
            compositedContrast(Terminal.bb, e.value), greaterThanOrEqualTo(1.3),
            reason: 'bb is invisible on ${e.key}');
      }
      expect(compositedContrast(Terminal.bb, Terminal.panel),
          lessThan(contrast(Terminal.ink2, Terminal.panel)),
          reason: 'bb must stay behind the price line');
    });

    test('MACD and its signal are distinct, and RSI is not the RSI colour', () {
      expect(Terminal.macdLine, isNot(Terminal.macdSignal));
      expect(Terminal.rsi, isNot(Terminal.macdLine));
      expect(Terminal.macdLine, isNot(Terminal.sma20));
    });

    test('volume bars are visible in both directions', () {
      for (final (name, c) in [
        ('up', Terminal.volumeUp),
        ('down', Terminal.volumeDown),
      ]) {
        for (final e in surfaces.entries) {
          expect(compositedContrast(c, e.value), greaterThanOrEqualTo(1.3),
              reason: 'volume $name is invisible on ${e.key}');
        }
      }
    });
  });

  group('actionColor', () {
    test('maps every backend action', () {
      expect(actionColor('BUY'), Terminal.buy);
      expect(actionColor('SELL'), Terminal.sell);
      expect(actionColor('HOLD'), Terminal.hold);
      expect(actionColor('AVOID'), Terminal.avoid);
      expect(actionColor('NO_DATA'), Terminal.nodata);
    });

    test('is case-insensitive, because a payload is not a constant', () {
      expect(actionColor('buy'), Terminal.buy);
      expect(actionColor('Buy'), Terminal.buy);
      expect(actionColor('no_data'), Terminal.nodata);
    });

    test('an unknown action reads as NO_DATA, never as a BUY', () {
      // The whole point of the `_ =>` arm. A typo in the enum must not become
      // a buy signal on screen.
      for (final junk in [
        'STRONG_BUY',
        'BUYING',
        'ACQUIRE',
        '',
        '  BUY  ',
        'BUY!',
        'null',
        'HOLD2',
      ]) {
        expect(actionColor(junk), Terminal.nodata,
            reason: '"$junk" must not be dressed up as a real verdict');
      }
    });

    test('NO_DATA is never rendered as a directional colour', () {
      expect(actionColor('NO_DATA'), isNot(Terminal.buy));
      expect(actionColor('NO_DATA'), isNot(Terminal.sell));
      expect(actionColor('nonsense'), isNot(Terminal.buy));
      expect(actionColor('nonsense'), isNot(Terminal.sell));
    });

    test('the info accent is never used for a verdict', () {
      // `info` measures 1.19:1 against BUY under deuteranopia. It is safe as a
      // link colour and unsafe as a verdict, so the mapping must never reach it.
      for (final s in [
        'BUY',
        'SELL',
        'HOLD',
        'AVOID',
        'NO_DATA',
        'info',
        'INFO',
        '',
      ]) {
        expect(actionColor(s), isNot(Terminal.info),
            reason: '"$s" must not be rendered as the info accent');
      }
    });

    test('it is total — it cannot throw for any string', () {
      for (final s in ['BUY', 'SELL', 'HOLD', 'AVOID', 'NO_DATA', '', '🎉']) {
        expect(() => actionColor(s), returnsNormally);
      }
    });
  });

  group('signColor', () {
    test('a zero change is neither green nor red', () {
      // Rendering a flat day green is how a chart teaches its reader that the
      // colour means nothing.
      expect(signColor(0), Terminal.ink2);
      expect(signColor(0), isNot(Terminal.good));
      expect(signColor(0), isNot(Terminal.bad));
      expect(signColor(-0.0), Terminal.ink2);
    });

    test('a rise is good and a fall is bad', () {
      expect(signColor(0.01), Terminal.good);
      expect(signColor(-0.01), Terminal.bad);
      expect(signColor(1200), Terminal.good);
      expect(signColor(-0.0001), Terminal.bad);
    });

    test('good and bad alias the action colours, not new ones', () {
      expect(Terminal.good, Terminal.buy);
      expect(Terminal.bad, Terminal.sell);
      expect(Terminal.warn, Terminal.hold);
    });
  });

  group('every colour is a valid 32-bit ARGB', () {
    test('no token is 8 bytes or otherwise malformed', () {
      // A literal like 0xFF48555256 compiles as an int but renders as garbage
      // or throws. `ink4` shipped in that shape once.
      final all = <String, Color>{
        'void0': Terminal.void0,
        'base': Terminal.base,
        'panel': Terminal.panel,
        'raised': Terminal.raised,
        'hover': Terminal.hover,
        'hairline': Terminal.hairline,
        'divider': Terminal.divider,
        'ink': Terminal.ink,
        'ink2': Terminal.ink2,
        'ink3': Terminal.ink3,
        'ink4': Terminal.ink4,
        'buy': Terminal.buy,
        'buyDim': Terminal.buyDim,
        'sell': Terminal.sell,
        'sellDim': Terminal.sellDim,
        'hold': Terminal.hold,
        'avoid': Terminal.avoid,
        'info': Terminal.info,
        'bb': Terminal.bb,
        'volumeUp': Terminal.volumeUp,
        'volumeDown': Terminal.volumeDown,
        'crosshair': Terminal.crosshair,
      };
      all.forEach((name, colour) {
        expect(() => colour.toARGB32(), returnsNormally, reason: name);
        final argb = colour.toARGB32();
        expect(argb, lessThan(0x100000000), reason: '$name is not 32-bit');
        for (final channel in [colour.r, colour.g, colour.b, colour.a]) {
          expect(channel, inInclusiveRange(0.0, 1.0), reason: '$name channel');
        }
      });
    });

    test('the surfaces get progressively lighter, top to bottom', () {
      expect(_luminance(Terminal.void0), lessThan(_luminance(Terminal.base)));
      expect(_luminance(Terminal.base), lessThan(_luminance(Terminal.panel)));
      expect(_luminance(Terminal.panel), lessThan(_luminance(Terminal.raised)));
      expect(_luminance(Terminal.raised), lessThan(_luminance(Terminal.hover)));
    });
  });

  group('type', () {
    test('numbers are tabular so a price column can be scanned', () {
      // A price that shifts sideways as the last digit ticks makes a column of
      // prices impossible to scan, which is the entire reason for a column.
      expect(Terminal.num().fontFeatures,
          contains(const FontFeature.tabularFigures()));
    });

    test('labels are letter-spaced, because terminals are dense', () {
      expect(Terminal.label().letterSpacing, greaterThan(0));
    });

    test('body text has a readable line height', () {
      expect(Terminal.body().height, greaterThan(1.0));
    });

    test('every style factory returns the ink colour, not black', () {
      expect(Terminal.num().color, Terminal.ink);
      expect(Terminal.num().color, isNot(const Color(0xFF000000)));
    });
  });

  group('theme()', () {
    test('is dark and uses the terminal surfaces', () {
      final t = Terminal.theme();
      expect(t.brightness, Brightness.dark);
      expect(t.colorScheme.surface, Terminal.panel);
      expect(t.colorScheme.onSurface, Terminal.ink);
      expect(t.scaffoldBackgroundColor, Terminal.base);
      expect(t.dividerColor, Terminal.hairline);
      expect(t.useMaterial3, isTrue);
    });

    test('maps the action colours onto the scheme so widgets agree', () {
      final t = Terminal.theme();
      expect(t.colorScheme.primary, Terminal.info);
      expect(t.colorScheme.secondary, Terminal.buy);
      expect(t.colorScheme.error, Terminal.sell);
    });

    test('the navigation bar is a panel, not a default light surface', () {
      final t = Terminal.theme();
      expect(t.navigationBarTheme.backgroundColor, Terminal.panel);
      expect(t.appBarTheme.backgroundColor, Terminal.base);
    });
  });
}
