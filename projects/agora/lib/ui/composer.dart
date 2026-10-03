import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart' as db;
import '../state/agora_controller.dart';
import 'theme.dart';

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

  @override
  void initState() {
    super.initState();
    _text.addListener(_detectMention);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The `@partial` token under the caret, or null when the caret is not
  /// inside one.
  void _detectMention() {
    final sel = _text.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    final upto = _text.text.substring(0, sel.baseOffset);
    final at = upto.lastIndexOf('@');
    final match = at < 0
        ? null
        : RegExp(r'@([A-Za-z0-9_-]*)$').firstMatch(upto.substring(at));
    final next = match?.group(1);
    if (next != _mentionQuery) setState(() => _mentionQuery = next);
  }

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
    if (text.isEmpty || c.selectedId == null) return;
    await c.recordUserTurn(text);
    _text.clear();
    if (mounted) setState(() => _mentionQuery = null);
    final err = c.lastError;
    if (err != null && mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(err)));
    }
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
                            ? 'State the problem…  @chatgpt @gemini @deepseek'
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
