/// Platform entry point for the chart.
///
/// Resolves to the real TradingView Lightweight Charts on web, and to a stub
/// everywhere else. The stub is not a formality: `dart:js_interop` and
/// `package:web` do not compile on the Dart VM, so without this split neither
/// this file nor anything importing it could be loaded by `flutter test`.
/// That would leave the chart page — and the synthetic-data banner, which is
/// the safety-critical part of it — with no test coverage whatsoever.
library;

export 'tradingview_stub.dart'
    if (dart.library.js_interop) 'tradingview_web.dart';
