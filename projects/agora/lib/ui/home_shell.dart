import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/agora_controller.dart';
import 'calibration_studio_screen.dart';
import 'composer.dart';
import 'council_panel.dart';
import 'decision_record_screen.dart';
import 'session_sidebar.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'transcript_view.dart';

/// The room: projects on the left, the verbatim record in the middle, the
/// council on the right. One live session at a time, per the locked decisions.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.c});
  final AgoraController c;

  /// Esc is the interrupt. It only does anything while a council is live;
  /// otherwise there is genuinely nothing to stop, so say so rather than
  /// pretending otherwise.
  static void _stopCouncil(AgoraController c, BuildContext context) {
    if (!c.councilRunning) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Nothing is running — Esc is the interrupt.'),
        ),
      );
      return;
    }
    c.interruptCouncil();
  }

  @override
  Widget build(BuildContext context) {
    void openPalette() => showDialog<void>(
      context: context,
      builder: (_) => CommandPalette(c: c),
    );
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            openPalette,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): openPalette,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _stopCouncil(c, context),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            c.snapshot(),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
            c.snapshot(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: <Widget>[
              _Rail(controller: c),
              SessionSidebar(c: c),
              Expanded(
                child: Column(
                  children: <Widget>[
                    Expanded(child: TranscriptView(c: c)),
                    Composer(c: c),
                  ],
                ),
              ),
              CouncilPanel(c: c),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.controller});
  final AgoraController controller;

  void _go(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      color: AgoraTheme.surface0,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          const Icon(Icons.hub_outlined, size: 20, color: AgoraTheme.accent),
          const SizedBox(height: 18),
          _icon(context, Icons.forum_outlined, 'Sessions'),
          _icon(
            context,
            Icons.tune,
            'Calibration Studio',
            () => _go(context, CalibrationStudioScreen(controller: controller)),
          ),
          _icon(
            context,
            Icons.description_outlined,
            'Decision Record',
            () => _go(context, DecisionRecordScreen(controller: controller)),
          ),
          const Spacer(),
          _icon(
            context,
            Icons.settings_outlined,
            'Settings',
            () => _go(context, SettingsScreen(controller: controller)),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _icon(
    BuildContext context,
    IconData i,
    String tip, [
    VoidCallback? onTap,
  ]) => Tooltip(
    message: tip,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Icon(i, size: 18, color: AgoraTheme.dim),
      ),
    ),
  );
}

/// Ctrl/⌘+K. Deliberately small: only what a council chair reaches for.
class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, required this.c});
  final AgoraController c;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final all = <String, VoidCallback>{
      'Toggle archived sessions': widget.c.toggleShowArchived,
      'Reset all view overrides': widget.c.resetViews,
      'Clear vault search': widget.c.clearSearch,
      'Open Calibration Studio': () =>
          _go(ctx, CalibrationStudioScreen(controller: widget.c)),
      'Open Decision Record': () =>
          _go(ctx, DecisionRecordScreen(controller: widget.c)),
      'Open Settings': () => _go(ctx, SettingsScreen(controller: widget.c)),
    };
    final keys = all.keys
        .where((k) => k.toLowerCase().contains(_q.text.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Command palette', style: TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 440,
        height: 300,
        child: Column(
          children: <Widget>[
            TextField(
              controller: _q,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Type a command…'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: <Widget>[
                  for (final k in keys)
                    ListTile(
                      dense: true,
                      title: Text(k, style: const TextStyle(fontSize: 13)),
                      onTap: () {
                        Navigator.pop(ctx);
                        all[k]!();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext ctx, Widget screen) {
    Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}
