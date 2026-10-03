import 'package:flutter/material.dart';

import '../data/database.dart' as db;
import '../state/agora_controller.dart';
import 'theme.dart';

/// Left pane: the project list and full-text search over the verbatim vault.
class SessionSidebar extends StatefulWidget {
  const SessionSidebar({super.key, required this.c});
  final AgoraController c;

  @override
  State<SessionSidebar> createState() => _SessionSidebarState();
}

class _SessionSidebarState extends State<SessionSidebar> {
  final _search = TextEditingController();
  final _newPrompt = TextEditingController();
  final _newTitle = TextEditingController();
  bool _composing = false;

  @override
  void dispose() {
    _search.dispose();
    _newPrompt.dispose();
    _newTitle.dispose();
    super.dispose();
  }

  List<db.Session> get _visible => widget.c.sessions
      .where((s) => widget.c.showArchived || !s.archived)
      .toList();

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: AgoraTheme.surface1,
        border: Border(right: BorderSide(color: AgoraTheme.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(c),
          _searchBox(c),
          if (c.query.trim().isNotEmpty) _searchResults(c),
          Expanded(child: _list(c)),
          _footer(c),
        ],
      ),
    );
  }

  Widget _header(AgoraController c) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
    child: Row(
      children: [
        const Icon(Icons.forum_outlined, size: 18, color: AgoraTheme.accent),
        const SizedBox(width: 8),
        Text(
          'Agora',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'New session',
          icon: const Icon(Icons.add, size: 18),
          onPressed: () => setState(() => _composing = !_composing),
        ),
      ],
    ),
  );

  Widget _searchBox(AgoraController c) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: TextField(
      controller: _search,
      style: AgoraTheme.mono,
      decoration: InputDecoration(
        hintText: 'Search the vault…',
        prefixIcon: const Icon(Icons.search, size: 16),
        suffixIcon: c.query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 14),
                onPressed: () {
                  _search.clear();
                  c.clearSearch();
                },
              ),
      ),
      onChanged: c.search,
    ),
  );

  Widget _searchResults(AgoraController c) {
    final rows = c.results;
    return Container(
      constraints: const BoxConstraints(maxHeight: 190),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: AgoraTheme.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AgoraTheme.hairline),
      ),
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                c.searching ? 'Searching…' : 'No verbatim match.',
                style: AgoraTheme.caption,
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final m = rows[i];
                final snippet = m.rawText.length > 120
                    ? '${m.rawText.substring(0, 120)}…'
                    : m.rawText;
                return InkWell(
                  onTap: () => _jumpTo(m.id),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.nameOf(m.agentId)} · round ${m.round}',
                          style: AgoraTheme.caption.copyWith(
                            color: c.colorOf(m.agentId),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          snippet.replaceAll('\n', ' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _jumpTo(String messageId) {
    // The transcript keys off the same message id, so selecting it is enough.
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text('Match: $messageId')));
  }

  Widget _list(AgoraController c) {
    final rows = _visible;
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No sessions yet.\nOne session is one project.',
            textAlign: TextAlign.center,
            style: AgoraTheme.caption,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: rows.length + (_composing ? 1 : 0),
      itemBuilder: (_, i) {
        if (_composing && i == 0) return _composer();
        return _tile(c, rows[i - (_composing ? 1 : 0)]);
      },
    );
  }

  Widget _composer() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _newTitle,
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newPrompt,
              minLines: 3,
              maxLines: 6,
              style: AgoraTheme.mono,
              decoration: const InputDecoration(
                hintText: 'What should the council decide?',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _composing = false;
                    _newPrompt.clear();
                    _newTitle.clear();
                  }),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: () {
                    final p = _newPrompt.text.trim();
                    if (p.isEmpty) return;
                    widget.c.newSession(
                      prompt: p,
                      title: _newTitle.text.trim().isEmpty
                          ? p.split('\n').first
                          : _newTitle.text.trim(),
                    );
                    _newPrompt.clear();
                    _newTitle.clear();
                    setState(() => _composing = false);
                  },
                  child: const Text('Convene'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _tile(AgoraController c, db.Session s) {
    final active = s.id == c.selectedId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? AgoraTheme.surface2 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => c.select(s.id),
          onLongPress: () => _menu(c, s),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? AgoraTheme.accent : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.status} · round ${s.round}/${s.maxRounds}'
                        '${s.archived ? ' · archived' : ''}',
                        style: AgoraTheme.caption,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Session actions',
                  icon: const Icon(Icons.more_vert, size: 15),
                  color: AgoraTheme.surface2,
                  onSelected: (v) => _action(c, s, v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'archive', child: Text('Archive')),
                    PopupMenuItem(value: 'unarchive', child: Text('Unarchive')),
                    PopupMenuItem(value: 'export', child: Text('Export JSON')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _menu(AgoraController c, db.Session s) => _action(c, s, 'rename');

  void _action(AgoraController c, db.Session s, String v) {
    switch (v) {
      case 'rename':
        final t = TextEditingController(text: s.title);
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Rename session'),
            content: TextField(
              controller: t,
              autofocus: true,
              onSubmitted: (_) => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  c.rename(s.id, t.text.trim());
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      case 'archive':
        c.setArchived(s.id, true);
      case 'unarchive':
        c.setArchived(s.id, false);
      case 'export':
        final messenger = ScaffoldMessenger.maybeOf(context);
        c.export().then((doc) {
          final n = (doc['messages'] as List?)?.length ?? 0;
          messenger?.showSnackBar(
            SnackBar(content: Text('Export ready: $n verbatim messages.')),
          );
        });
      case 'delete':
        final messenger = ScaffoldMessenger.maybeOf(context);
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete session?'),
            content: const Text(
              'This removes the session, its transcript, packets, facts and '
              'journal. It cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AgoraTheme.danger,
                ),
                onPressed: () {
                  c.delete(s.id);
                  Navigator.pop(context);
                  messenger?.showSnackBar(
                    const SnackBar(content: Text('Session deleted.')),
                  );
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
    }
  }

  Widget _footer(AgoraController c) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
    child: Row(
      children: [
        Text('${_visible.length} sessions', style: AgoraTheme.caption),
        const Spacer(),
        Tooltip(
          message: c.showArchived
              ? 'Hiding nothing — archived included'
              : 'Archived sessions hidden',
          child: InkWell(
            onTap: c.toggleShowArchived,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                c.showArchived ? Icons.unarchive : Icons.archive_outlined,
                size: 15,
                color: AgoraTheme.dim,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
