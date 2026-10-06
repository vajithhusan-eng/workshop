/// Non-web fallback for the chart.
///
/// Renders an explanation rather than throwing. A chart widget that takes the
/// whole screen down is worse than one that admits it cannot draw — and on the
/// VM test runner this is not a rare edge case, it is the *only* path, so the
/// safety banner and the empty state are exercised through here.
library;

import 'package:flutter/widgets.dart';

import 'candle.dart';
import 'overlays.dart';

export 'candle.dart';
export 'overlays.dart';

/// Always false off the web: there is no DOM to mount into.
bool get chartsAvailable => false;

/// No chart to update. The `overlays` parameter exists so this stub has the same
/// signature as the web build — a conditional import whose two branches disagree
/// on their API compiles fine and then fails to link.
void chartSetData(
  String id,
  List<Candle> data, [
  List<Overlay> overlays = const [],
]) {}

/// A live candlestick chart with a volume pane — or, here, an honest notice.
class CandlestickChart extends StatelessWidget {
  const CandlestickChart({
    super.key,
    required this.candles,
    this.overlays = const [],
    this.showVolume = true,
    this.height = 380,
  });

  final List<Candle> candles;
  final List<Overlay> overlays;
  final bool showVolume;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          candles.isEmpty
              ? 'No bars to chart.'
              : 'The chart needs the web build. Charts render through a '
                  'TradingView canvas, which only exists in a browser.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF9FB0AD), fontSize: 13),
        ),
      ),
    );
  }
}
