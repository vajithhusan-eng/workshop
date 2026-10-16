import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart' as db;
import '../state/agora_controller.dart';
import 'theme.dart';

/// A composer slash command.
///
/// Only commands with a real backing action appear here. `PLAN.md` §18.3 names
/// `/adversarial`, `/fork`, `/template`, `/roles` and `/inject`, but the engine
/// for each (a one-shot adversarial round, session fork, a template store, a
/// message injector) does not exist yet — offering them would be a menu of
/// buttons that do nothing. They stay out until they have an engine behind them.
class SlashCommand {
  const SlashCommand(this.name, this.help);

  final String name;
  final String help;
}

const List<SlashCommand> kSlashCommands = <SlashCommand>[
  SlashCommand('stop', 'Stop the running council'),
  SlashCommand('snapshot', 'Screenshot every live tab into the vault'),
  SlashCommand('export', 'Export this session as a decision record'),
  SlashCommand('archived', 'Toggle archived sessions in the sidebar'),
  SlashCommand('help', 'List the commands'),
];

/// The `/partial` token under the caret, without the slash, or null.
///
/// A slash only opens a command at the very start of the text or right after
/// whitespace, so a URL like `https://…` is never mistaken for a command, and
/// the token must be bare letters — typing a space closes the menu.
String? slashQueryAt(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;
  final upto = text.substring(0, caret);
  final slash = upto.lastIndexOf('/');
  if (slash < 0) return null;
  if (slash > 0 && !RegExp(r'\s').hasMatch(upto[slash - 1])) return null;
  final token = upto.substring(slash + 1);
  return RegExp(r'^[A-Za-z]*$').hasMatch(token) ? token : null;
}

/// Commands whose name starts with [query], case-insensitive.
List<SlashCommand> slashMatches(String query) {
  final q = query.toLowerCase();
  return kSlashCommands
      .where((c) => c.name.startsWith(q))
      .toList(growable: false);
}

/// The command a whole-composer text names, or null.
///
/// `'/stop'` and `'/stop now'` both resolve to `stop`; an unknown name resolves
/// to null so it is stored as an ordinary message instead of silently eaten.
SlashCommand? commandFor(String text) {
  if (!text.startsWith('/')) return null;
  final name = text.substring(1).split(RegExp(r'\s')).first;
  for (final c in kSlashCommands) {
    if (c.name == name) return c;
  }
  return null;
}

/// Bottom pane: state the problem, address the council, send.
///
/// `@` routing is an addressing aid for the human. It never dispatches — per
/// the locked decisions, only a strict machine-readable `invite` block from the
/// leader may cause an agent to be sent anything. The chips below show who the
/// human is talking to, not what the engine will do.
class Composer extends StatefulWidget {
  const Composer({super.key, required this.c});
  final AgoraController c;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  String? _mentionQuery;
  String? _slashQuery;

  @override
  void initState() {
    super.initState();
    _text.addListener(_detectSuggestions);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The `@partial` and `/partial` tokens under the caret, if either is open.
  void _detectSuggestions() {
    final sel = _text.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      if (_mentionQuery != null || _slashQuery != null) {
        setState(() {
          _mentionQuery = null;
          _slashQuery = null;
        });
      }
      return;
    }
    final upto = _text.text.substring(0, sel.baseOffset);
    final at = upto.lastIndexOf('@');
    final match = at < 0
        ? null
        : RegExp(r'@([A-Za-z0-9_-]*)$').firstMatch(upto.substring(at));
    final nextMention = match?.group(1);
    final nextSlash = slashQueryAt(_text.text, sel.baseOffset);
    if (nextMention != _mentionQuery || nextSlash != _slashQuery) {
      setState(() {
        _mentionQuery = nextMention;
        _slashQuery = nextSlash;
      });
    }
  }

  List<SlashCommand> get _slashMatches =>
      _slashQuery == null ? const <SlashCommand>[] : slashMatches(_slashQuery!);

  List<db.Agent> get _candidates {
    final q = _mentionQuery;
    if (q == null) return const <db.Agent>[];
    final seated = widget.c.seats.map((s) => s.agentId).toSet();
    final pool = widget.c.agents.where((a) => !seated.contains(a.id)).toList();
    if (q.isEmpty) return pool.take(4).toList();
    return pool
        .where(
          (a) =>
              a.kind.toLowerCase().contains(q.toLowerCase()) ||
              a.displayName.toLowerCase().contains(q.toLowerCase()),
        )
        .take(4)
        .toList();
  }

  /// Mentions already present in the draft, resolved to seated agents.
  List<db.SessionAgent> get _mentions {
    final text = _text.text;
    final out = <db.SessionAgent>[];
    for (final seat in widget.c.seats) {
      final agent = widget.c.agentFor(seat.agentId);
      if (agent == null) continue;
      for (final needle in <String>[
        '@${agent.kind}',
        '@${agent.displayName}',
      ]) {
        final re = RegExp('${RegExp.escape(needle)}\\b', caseSensitive: false);
        if (re.hasMatch(text)) {
          out.add(seat);
          break;
        }
      }
    }
    return out;
  }

  void _insert(db.Agent a) {
    final sel = _text.selection;
    if (!sel.isValid) return;
    final upto = _text.text.substring(0, sel.baseOffset);
    final at = upto.lastIndexOf('@');
    if (at < 0) return;
    final next = _text.text.replaceRange(at, sel.baseOffset, '@${a.kind} ');
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + a.kind.length + 2),
    );
    _focus.requestFocus();
  }

  Future<void> _send() async {
    final c = widget.c;
    final text = _text.text.trim();
    if (text.isEmpty) return;

    // A command is only a command when the whole draft names one. Anything else
    // is an ordinary message, so a stray '/' is never silently eaten.
    final cmd = commandFor(text);
    if (cmd != null) {
      _text.clear();
      if (mounted) {
        setState(() {
          _mentionQuery = null;
          _slashQuery = null;
        });
      }
      await _runSlash(cmd);
      return;
    }

    if (c.selectedId == null) return;
    await c.recordUserTurn(text);
    _text.clear();
    if (mounted) {
      setState(() {
        _mentionQuery = null;
        _slashQuery = null;
      });
    }
    final err = c.lastError;
    if (err != null) _snack(err);
  }

  /// Runs a slash command. Every branch calls a real controller method — there
  /// is no command here whose engine does not exist.
  Future<void> _runSlash(SlashCommand cmd) async {
    final c = widget.c;
    switch (cmd.name) {
      case 'help':
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Commands'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final sc in kSlashCommands)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '/${sc.name}  —  ${sc.help}',
                      style: AgoraTheme.mono,
                    ),
                  ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      case 'stop':
        if (!c.councilRunning) {
          _snack('No council is running.');
          return;
        }
        c.interruptCouncil();
        _snack('Stopping the council at the next round boundary…');
      case 'snapshot':
        if (!c.councilRunning) {
          _snack('No live tabs to capture.');
          return;
        }
        final ok = await c.snapshot();
        _snack(
          ok
              ? 'Snapshot saved to the vault.'
              : (c.councilError ?? 'Snapshot failed.'),
        );
      case 'export':
        if (c.selectedId == null) {
          _snack('Select a session first.');
          return;
        }
        final doc = await c.export();
        final n = (doc['messages'] as List?)?.length ?? 0;
        _snack('Exported $n messages.');
      case 'archived':
        c.toggleShowArchived();
        _snack(
          c.showArchived
              ? 'Showing archived sessions.'
              : 'Hiding archived sessions.',
        );
      default:
        _snack('Unknown command /${cmd.name}.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Completes the `/partial` under the caret to `/name `, closing the menu.
  void _insertSlash(SlashCommand cmd) {
    final sel = _text.selection;
    if (!sel.isValid) return;
    final upto = _text.text.substring(0, sel.baseOffset);
    final slash = upto.lastIndexOf('/');
    if (slash < 0) return;
    final next = _text.text.replaceRange(
      slash,
      sel.baseOffset,
      '/${cmd.name} ',
    );
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: slash + cmd.name.length + 2),
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.c.selectedId != null;

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AgoraTheme.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_slashMatches.isNotEmpty) _slashSuggestions(),
          if (_candidates.isNotEmpty) _suggestions(),
          if (_mentions.isNotEmpty) _mentionChips(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Shortcuts(
                  shortcuts: const <ShortcutActivator, Intent>{
                    SingleActivator(LogicalKeyboardKey.enter, control: true):
                        SendIntent(),
                    SingleActivator(LogicalKeyboardKey.enter, meta: true):
                        SendIntent(),
                  },
                  child: Actions(
                    actions: <Type, Action<Intent>>{
                      SendIntent: CallbackAction<SendIntent>(
                        onInvoke: (_) {
                          _send();
                          return null;
                        },
                      ),
                    },
                    child: TextField(
                      controller: _text,
                      focusNode: _focus,
                      enabled: enabled,
                      minLines: 2,
                      maxLines: 8,
                      style: AgoraTheme.mono,
                      decoration: InputDecoration(
                        hintText: enabled
                            ? 'State the problem…  @chatgpt @gemini  ·  / for commands'
                            : 'Select a session first',
                        hintStyle: AgoraTheme.caption,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Hold-to-talk (upgrade D2) — not implemented',
                    onPressed: null,
                    icon: const Icon(Icons.mic_none, size: 18),
                  ),
                  const SizedBox(height: 2),
                  Tooltip(
                    message: 'Send  (Ctrl/⌘ + Enter)',
                    child: IconButton.filled(
                      onPressed: enabled ? _send : null,
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AgoraTheme.accent,
                        foregroundColor: const Color(0xFF0B0E13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slashSuggestions() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(
      spacing: 6,
      runSpacing: 4,
      children: <Widget>[
        for (final cmd in _slashMatches)
          Tooltip(
            message: cmd.help,
            child: ActionChip(
              avatar: const Icon(Icons.terminal, size: 13),
              label: Text('/${cmd.name}', style: AgoraTheme.mono),
              onPressed: () => _insertSlash(cmd),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    ),
  );

  Widget _suggestions() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(
      spacing: 6,
      runSpacing: 4,
      children: <Widget>[
        for (final a in _candidates)
          ActionChip(
            avatar: CircleAvatar(
              radius: 5,
              backgroundColor: Color(a.colorValue),
            ),
            label: Text('@${a.kind}'),
            onPressed: () => _insert(a),
            visualDensity: VisualDensity.compact,
          ),
      ],
    ),
  );

  Widget _mentionChips() {
    final c = widget.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Text('addressing', style: AgoraTheme.caption),
          const SizedBox(width: 8),
          for (final seat in _mentions)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.colorOf(seat.agentId).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.colorOf(seat.agentId)),
                ),
                child: Text(
                  c.nameOf(seat.agentId),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: c.colorOf(seat.agentId),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          const Spacer(),
          Text('never dispatches on its own', style: AgoraTheme.caption),
        ],
      ),
    );
  }
}

class SendIntent extends Intent {
  const SendIntent();
}
