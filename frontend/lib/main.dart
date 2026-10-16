/// OMNIVEST — a TradingView-style AI trading terminal.
///
/// This file used to boot a five-tab learning shell (Brief / Chart / Journal /
/// Autopsy / 87.7%) on a light `colorSchemeSeed: Colors.teal` theme, with the
/// terminal nowhere in the tree and none of the dark palette applied. It was
/// replaced outright rather than extended: the brief calls for a terminal —
/// live charts, an analysis HUD, a verdict — and explicitly not a learning
/// app, so the tabs went with the light theme.
///
/// `Terminal.theme()` is the single source of truth for colour. Nothing here
/// sets a colour directly, because a hex literal in a widget is a hex literal
/// that has already drifted from the palette and its contrast tests.
library;

import 'package:flutter/material.dart';

import 'pages/terminal_page.dart';
import 'theme/terminal.dart';

void main() => runApp(const OmniApp());

class OmniApp extends StatelessWidget {
  const OmniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMNIVEST',
      debugShowCheckedModeBanner: false,
      // Dark only, deliberately: this is a trading terminal and the palette is
      // contrast-tested against exactly these surfaces. Letting the OS flip it
      // to light would render tested-on-dark tokens on an untested background.
      theme: Terminal.theme(),
      home: const TerminalPage(),
    );
  }
}
