/// The terminal's HUD vocabulary: verdict badges, conviction meters, stat tiles
/// and the ticker tape.
///
/// One rule governs everything in this file:
///
/// **Colour is never the only channel.** Under a deuteranopia simulation the
/// five verdict hues separate to a measured floor of 1.42:1 — SELL, HOLD and
/// AVOID sit in the same warm band and cannot be pushed apart without muting
/// BUY, the one colour that appears without a word in the candles. So the
/// design answer is structural rather than chromatic: every badge owns its
/// action word, and [VerdictBadge] has no constructor that renders a colour
/// without one.
library;

import 'package:flutter/material.dart';

import '../theme/terminal.dart';

/// What a symbol is judged to be, and how strongly.
///
/// Colour is decorative here; the word is the payload. The constructor takes
/// the action string, not a colour, so a caller cannot accidentally hand it a
/// hue that disagrees with its own enum.
class VerdictBadge extends StatelessWidget {
  const VerdictBadge({
    super.key,
    required this.action,
    this.conviction,
    this.compact = false,
  });

  /// One of `BUY`, `SELL`, `HOLD`, `AVOID`, `NO_DATA`. Anything else renders
  /// as `NO_DATA` rather than as a plausible-looking green.
  final String action;

  /// Optional 0..1 conviction, printed next to the word when present.
  final double? conviction;

  /// Dense mode for watchlist rows, where the badge sits in a 28px line.
  final bool compact;

  String get _word {
    switch (action.toUpperCase()) {
      case 'BUY':
        return 'BUY';
      case 'SELL':
        return 'SELL';
      case 'HOLD':
        return 'HOLD';
      case 'AVOID':
        return 'AVOID';
      default:
        return 'NO DATA';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = actionColor(action);
    final style = compact
        ? Terminal.label(size: 10, color: c, weight: FontWeight.w800)
        : Terminal.label(size: 12, color: c, weight: FontWeight.w900);

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 5, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        border: Border.all(color: c.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // The word. Always present, never replaced by the swatch.
          Text(_word, style: style),
          if (conviction != null) ...[
            SizedBox(width: compact ? 4 : 6),
            Text(
              '${(conviction! * 100).round()}%',
              style: Terminal.num(
                size: compact ? 10 : 12,
                color: Terminal.ink2,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A conviction bar with the number written out beside it.
///
/// The bar is redundant encoding of the figure, not a substitute for it —
/// and the figure itself is not a probability, which the label says so the
/// widget cannot be read as one.
class ConvictionMeter extends StatelessWidget {
  const ConvictionMeter({super.key, required this.conviction, this.action});

  final double conviction;
  final String? action;

  @override
  Widget build(BuildContext context) {
    final v = conviction.clamp(0.0, 1.0);
    final tone = action == null ? Terminal.ink2 : actionColor(action!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('CONVICTION', style: Terminal.label(size: 10)),
            Text(
              '${(v * 100).round()}%',
              style:
                  Terminal.num(size: 13, color: tone, weight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // Track + fill. The number above is the fact; this is the same fact
        // drawn, so a reader who only sees the bar is not being told anything
        // the figure does not already say.
        SizedBox(
          height: 6,
          width: double.infinity,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Terminal.hover,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Share of eligible weight pointing one way — not a probability.',
          style: Terminal.body(size: 10.5, color: Terminal.ink4),
        ),
      ],
    );
  }
}

/// A single readout in the HUD: a tiny label over a number.
class HudTile extends StatelessWidget {
  const HudTile({
    super.key,
    required this.label,
    required this.value,
    this.tone,
    this.hint,
  });

  final String label;
  final String value;
  final Color? tone;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final widget = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Terminal.raised,
        border: Border.all(color: Terminal.hairline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Terminal.label(size: 9.5)),
          const SizedBox(height: 3),
          Text(
            value,
            style: Terminal.num(size: 15, color: tone ?? Terminal.ink),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: Terminal.body(size: 9.5, color: Terminal.ink4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
    return hint == null ? widget : Tooltip(message: hint!, child: widget);
  }
}

/// A rule from the engine, rendered as one row of the analysis rail.
///
/// `direction` is the rule's vote: -1 down, +1 up, 0 neutral. It is drawn as
/// a signed word and a signed number, never as a coloured dot alone.
class RuleRow extends StatelessWidget {
  const RuleRow({
    super.key,
    required this.rule,
    required this.direction,
    required this.weight,
    required this.text,
  });

  final String rule;
  final int direction;
  final double weight;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = direction < 0
        ? Terminal.sell
        : direction > 0
            ? Terminal.buy
            : Terminal.ink4;
    final word = direction < 0
        ? 'DOWN'
        : direction > 0
            ? 'UP'
            : 'FLAT';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              word,
              style: Terminal.label(size: 9.5, color: tone),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              direction > 0 ? '+$weight' : '$weight',
              textAlign: TextAlign.right,
              style: Terminal.num(size: 11, color: Terminal.ink4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Terminal.body(size: 12, color: Terminal.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// The scrolling tape across the top of the terminal.
///
/// Static rather than animated: a tape that moves on its own timer is
/// indistinguishable from a live feed to a reader, and this one only shows
/// what was actually fetched and when. [asOf] is printed for the same reason.
class TickerTape extends StatelessWidget {
  const TickerTape({super.key, required this.items, this.asOf});

  final List<TickerItem> items;
  final String? asOf;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 34,
      color: Terminal.void0,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => items[i],
            ),
          ),
          if (asOf != null) ...[
            const SizedBox(width: 10),
            Text(
              asOf!,
              style: Terminal.label(size: 9, color: Terminal.ink4),
            ),
          ],
        ],
      ),
    );
  }
}

/// One entry on the tape: symbol, last close, verdict.
///
/// Deliberately **not** a price change. The scan payload carries a last close
/// and an action but no previous close, so a `±x.xx%` here would be invented —
/// and a tape whose deltas are fabricated is worse than one that shows none.
/// The verdict is what the scan actually knows, so that is what it shows, with
/// the action spelled out so the hue never has to carry it alone.
class TickerItem extends StatelessWidget {
  const TickerItem({
    super.key,
    required this.symbol,
    required this.last,
    required this.action,
    this.conviction,
    this.onTap,
  });

  final String symbol;
  final double last;
  final String action;
  final double? conviction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = actionColor(action);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(symbol, style: Terminal.label(size: 10, color: Terminal.ink)),
            const SizedBox(width: 6),
            Text(
              last.toStringAsFixed(2),
              style: Terminal.num(size: 11, color: Terminal.ink2),
            ),
            const SizedBox(width: 7),
            Text(
              action.isEmpty ? '—' : action,
              style: Terminal.label(
                size: 9.5,
                color: tone,
                weight: FontWeight.w800,
              ),
            ),
            if (conviction != null) ...[
              const SizedBox(width: 5),
              Text(
                '${(conviction! * 100).round()}%',
                style: Terminal.num(
                  size: 10,
                  color: Terminal.ink4,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
