import 'package:flutter/material.dart';

import '../data/database.dart' as db;
import '../state/agora_controller.dart';
import 'convergence_graph.dart';
import 'decision_record_screen.dart';
import 'theme.dart';

/// Right pane: who is in the room, what they are for, and what the council can
/// do next. Roles are editable because the leader's role card is the single
/// highest-leverage thing a human contributes to a debate.
class CouncilPanel extends StatelessWidget {
  const CouncilPanel({super.key, required this.c});
  final AgoraController c;

  @override
  Widget build(BuildContext context) {
    final session = c.current;
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: AgoraTheme.surface1,
        border: Border(left: BorderSide(color: AgoraTheme.hairline)),
      ),
      child: session == null
          ? const Center(
              child: Text('No council convened.', style: AgoraTheme.caption),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(session),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    children: [
                      for (final seat in c.seats) _seatCard(context, seat),
                      const SizedBox(height: 6),
                      _addSeat(context),
                      if (c.runner?.latestConvergence != null)
                        ConvergenceCard(report: c.runner!.latestConvergence!),
                    ],
                  ),
                ),
                _actions(context, session),
              ],
            ),
    );
  }

  Widget _header(db.Session s) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AgoraTheme.hairline)),
    ),
    child: Row(
      children: [
        const Icon(Icons.groups_outlined, size: 17, color: AgoraTheme.accent),
        const SizedBox(width: 8),
        const Text(
          'Council',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        _statusPill(s.status),
      ],
    ),
  );

  Widget _statusPill(String status) {
    final live = status == 'running' || status == 'debating';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: live
            ? AgoraTheme.ok.withValues(alpha: 0.15)
            : AgoraTheme.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: live ? AgoraTheme.ok : AgoraTheme.hairline),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.5,
          color: live ? AgoraTheme.ok : AgoraTheme.dim,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _seatCard(BuildContext context, db.SessionAgent seat) {
    final agent = c.agentFor(seat.agentId);
    if (agent == null) return const SizedBox.shrink();
    final muted = seat.status != 'enabled';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Color(agent.colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      agent.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: muted ? AgoraTheme.dim : null,
                      ),
                    ),
                  ),
                  if (seat.isLeader)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AgoraTheme.accent),
                      ),
                      child: const Text(
                        'LEADER',
                        style: TextStyle(
                          fontSize: 9,
                          color: AgoraTheme.accent,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Seat actions',
                    icon: const Icon(Icons.more_horiz, size: 15),
                    color: AgoraTheme.surface2,
                    onSelected: (v) => _seatAction(context, seat, v),
                    itemBuilder: (_) => [
                      if (!seat.isLeader)
                        const PopupMenuItem(
                          value: 'promote',
                          child: Text('Make leader'),
                        ),
                      PopupMenuItem(
                        value: seat.status == 'enabled' ? 'mute' : 'unmute',
                        child: Text(
                          seat.status == 'enabled'
                              ? 'Mute seat'
                              : 'Unmute seat',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'card',
                        child: Text('Edit role card'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'kick',
                        child: Text('Remove from council'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _roleCard(context, seat),
              if (seat.modelLabel != null) ...[
                const SizedBox(height: 6),
                Text(seat.modelLabel!, style: AgoraTheme.caption),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard(BuildContext context, db.SessionAgent seat) {
    final text = seat.roleCard?.trim();
    if (text == null || text.isEmpty) {
      return InkWell(
        onTap: () => _editRoleCard(context, seat),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AgoraTheme.hairline,
              style: BorderStyle.solid,
            ),
          ),
          child: Text(
            'No role card — tap to give this seat a job.',
            style: AgoraTheme.caption.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => _editRoleCard(context, seat),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AgoraTheme.surface0,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AgoraTheme.hairline),
        ),
        child: Text(text, style: AgoraTheme.mono),
      ),
    );
  }

  void _editRoleCard(BuildContext context, db.SessionAgent seat) {
    final t = TextEditingController(text: seat.roleCard ?? '');
    final messenger = ScaffoldMessenger.maybeOf(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Role card'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: t,
            autofocus: true,
            maxLines: 6,
            style: AgoraTheme.mono,
            decoration: const InputDecoration(
              hintText:
                  'What is this seat for, and what must it refuse to do?\n'
                  'e.g. "Thermal engineer. Challenge energy-density claims. '
                  'Never discuss cost."',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = t.text.trim();
              c.setSeatRoleCard(seat.agentId, v.isEmpty ? null : v);
              messenger?.showSnackBar(
                SnackBar(
                  content: Text(
                    v.isEmpty ? 'Role card cleared.' : 'Role card saved.',
                  ),
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _seatAction(BuildContext context, db.SessionAgent seat, String v) {
    switch (v) {
      case 'promote':
        c.promoteLeader(seat.agentId);
      case 'mute':
        c.setSeatStatus(seat.agentId, 'muted');
      case 'unmute':
        c.setSeatStatus(seat.agentId, 'enabled');
      case 'card':
        _editRoleCard(context, seat);
      case 'kick':
        if (seat.isLeader) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Promote another leader before removing this one.'),
            ),
          );
        } else {
          c.kick(seat.agentId);
        }
    }
  }

  Widget _addSeat(BuildContext context) => OutlinedButton.icon(
    onPressed: () {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Seat roster comes from assets/adapters/*.json.'),
        ),
      );
    },
    icon: const Icon(Icons.person_add_alt, size: 15),
    label: const Text('Add a seat'),
    style: OutlinedButton.styleFrom(
      foregroundColor: AgoraTheme.dim,
      side: const BorderSide(color: AgoraTheme.hairline),
    ),
  );

  Widget _actions(BuildContext context, db.Session s) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AgoraTheme.hairline)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.councilRunning)
          Row(
            children: [
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AgoraTheme.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.councilNotes.isEmpty ? 'Convening…' : c.councilNotes.last,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AgoraTheme.caption,
                ),
              ),
              TextButton.icon(
                onPressed: c.interruptCouncil,
                icon: const Icon(Icons.stop, size: 14),
                label: const Text('Stop'),
                style: TextButton.styleFrom(foregroundColor: AgoraTheme.danger),
              ),
            ],
          )
        else
          FilledButton.icon(
            onPressed: s.prompt.trim().isEmpty ? null : c.startCouncil,
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Start the council'),
            style: FilledButton.styleFrom(
              backgroundColor: AgoraTheme.accent,
              foregroundColor: const Color(0xFF0B0E13),
            ),
          ),
        if (c.councilError != null) ...[
          const SizedBox(height: 8),
          _councilError(c.councilError!),
        ],
        if (!c.councilRunning && c.councilStop != null) ...[
          const SizedBox(height: 8),
          Text('Last run stopped: ${c.councilStop}', style: AgoraTheme.caption),
        ],
        if (c.lastSnapshot != null) ...[
          const SizedBox(height: 8),
          Text(
            'Last snapshot: ${c.lastSnapshot}',
            style: AgoraTheme.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openDecisionRecord(context),
                icon: const Icon(Icons.description_outlined, size: 15),
                label: const Text('Decision Record'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AgoraTheme.dim,
                  side: const BorderSide(color: AgoraTheme.hairline),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Snapshot every live tab into the vault (Ctrl+S)',
              icon: const Icon(Icons.camera_alt_outlined, size: 16),
              color: AgoraTheme.dim,
              // Disabled rather than a no-op: the tabs belong to a run, so there
              // is genuinely nothing to capture between councils.
              onPressed: c.councilRunning ? () => c.snapshot() : null,
            ),
            IconButton(
              tooltip: 'Reveal Chrome (R1 §18.2)',
              icon: const Icon(Icons.open_in_new, size: 16),
              color: AgoraTheme.dim,
              // Silent mode parks the windows off-screen. Like snapshot, this
              // needs a live run — there is no window to reveal otherwise.
              onPressed: c.councilRunning ? () => c.revealChrome() : null,
            ),
          ],
        ),
      ],
    ),
  );

  void _openDecisionRecord(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DecisionRecordScreen(controller: c),
      ),
    );
  }

  /// Blocked runs are the common case on a first launch — a site the user has
  /// never logged into — so the remedy has to be on screen, not in a stack
  /// trace. `CouncilBlocked` already carries a sentence written for a human.
  Widget _councilError(String message) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: AgoraTheme.danger.withValues(alpha: 0.10),
      border: Border.all(color: AgoraTheme.danger.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 14, color: AgoraTheme.danger),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 11.5, color: AgoraTheme.danger),
          ),
        ),
      ],
    ),
  );
}
