import 'package:flutter/services.dart' show rootBundle;

import '../council/adapter_loader.dart';

/// The app's adapter source: the Flutter asset bundle.
///
/// This is the only place in the engine that knows the bundle exists. Keeping it
/// on the Flutter side of the seam is what lets `tool/` drive a real council
/// from a plain `dart run` with no Flutter on the path at all.
AdapterLoader bundleAdapterLoader() {
  return (String kind) => rootBundle.loadString('assets/adapters/$kind.json');
}
