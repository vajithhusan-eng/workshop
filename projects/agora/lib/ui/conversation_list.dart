import 'package:flutter/material.dart';

import 'theme.dart';

/// A WhatsApp-style conversation chip for the §18.3 chat list: a stack of its
/// members' colours, a presence dot, the title and an unread count.
///
/// Pure presentation — the caller supplies every byte, so this renders (and
/// tests) without a database or a controller. Every value it draws has a real
/// source: the member kinds come from `channels.members`, the presence dot from
/// the live seat status, and the count from Agora's own read marks.
class ConversationChip extends StatelessWidget {
  const ConversationChip({
    super.key,
    required this.label,
    required this.selected,
    required this.icon,
    required this.memberKinds,
    required this.colorOf,
    this.status,
    this.unread = 0,
    required this.onTap,
  });

  /// Title: 'Council' for the public thread, 'A ⇄ B' for a dm.
  final String label;

  final bool selected;

  /// Fallback glyph when there are no [memberKinds] (an unseated public thread).
  final IconData icon;

  /// Adapter kinds in the conversation, in display order.
  final List<String> memberKinds;

  /// Maps an adapter kind to the colour Agora already uses for that agent.
  final Color Function(String kind) colorOf;

  /// Live seat presence: 'enabled' | 'running' | 'muted' | 'login_required'…
  final String? status;

  /// Messages that arrived since the reader last opened this conversation.
  final int unread;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      avatar: _avatar(),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (unread > 0) ...[const SizedBox(width: 6), _UnreadBadge(unread)],
        ],
      ),
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _avatar() {
    final kinds = stackKinds(memberKinds);
    if (kinds.isEmpty) return Icon(icon, size: 14);
    return SizedBox(
      width: 24,
      height: 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < kinds.length; i++)
            Positioned(
              left: i * 7.0,
              child: Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorOf(kinds[i]),
                  shape: BoxShape.circle,
                  border: Border.all(color: AgoraTheme.surface1, width: 1),
                ),
                child: Text(
                  initialOf(kinds[i]),
                  style: const TextStyle(fontSize: 8, color: Colors.white),
                ),
              ),
            ),
          // The presence dot sits under the stack: a small status pip.
          Positioned(
            left: 0,
            top: 13,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: presenceColor(status),
                shape: BoxShape.circle,
                border: Border.all(color: AgoraTheme.surface1, width: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: AgoraTheme.accent,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      unreadLabel(count),
      style: const TextStyle(
        fontSize: 10,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Up to [max] distinct member kinds, in the order given, dropping blanks.
List<String> stackKinds(List<String> kinds, {int max = 3}) {
  final out = <String>[];
  for (final k in kinds) {
    if (k.isEmpty || out.contains(k)) continue;
    out.add(k);
    if (out.length >= max) break;
  }
  return out;
}

/// The first character of a kind, upper-cased. '?' when there is nothing drawn.
String initialOf(String kind) {
  final t = kind.trim();
  return t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
}

/// How an unread count is written on the badge.
String unreadLabel(int count) => count > 99 ? '99+' : '$count';

/// The presence dot colour for a seat status.
///
/// 'running' is a live turn; 'enabled' is ready; the error-ish states are red;
/// anything else (muted, idle, unknown) reads as away, in the dim tone.
Color presenceColor(String? status) => switch (status) {
  'running' => AgoraTheme.accent,
  'enabled' => AgoraTheme.ok,
  'login_required' || 'error' || 'failed' || 'blocked' => AgoraTheme.danger,
  _ => AgoraTheme.dim,
};
