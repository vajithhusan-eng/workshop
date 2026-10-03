import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../data/database.dart' as db;
import '../state/agora_controller.dart';
import 'theme.dart';

/// Centre pane: the verbatim record, round by round.
///
/// Nothing here rewrites text. The three view modes are lenses on the same
/// stored bytes, and the toggle sits on every message so the reader can always
/// get back to the truth.
class TranscriptView extends StatefulWidget {
  const TranscriptView({super.key, required this.c});
  final AgoraController c;

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView> {
  final _scroll = ScrollController();
  int _lastCount = -1;
  bool _stickToBottom = true;

  @override
  void initState() {
    super.initState();
    widget.c.addListener(_maybeFollow);
    _scroll.addListener(_trackStickiness);
  }

  @override
  void didUpdateWidget(TranscriptView old) {
    super.didUpdateWidget(old);
    if (old.c != widget.c) {
      old.c.removeListener(_maybeFollow);
      widget.c.addListener(_maybeFollow);
    }
  }

  @override
  void dispose() {
    widget.c.removeListener(_maybeFollow);
    _scroll.removeListener(_trackStickiness);
    _scroll.dispose();
    super.dispose();
  }

  void _trackStickiness() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    _stickToBottom = pos.pixels >= pos.maxScrollExtent - 80;
  }

  /// Follow the debate only while the reader is already at the bottom, so
  /// scrolling back to re-read an earlier round is never yanked away.
  void _maybeFollow() {
    final n = widget.c.transcript.length;
    if (n == _lastCount) return;
    _lastCount = n;
    if (!_scroll.hasClients || !_stickToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final session = c.current;
    if (session == null) {
      return const _Empty('Choose a session, or convene a new council.');
    }

    final rows = c.transcript;
    return Column(
      children: [
        _titleBar(session, rows.length),
        Expanded(
          child: rows.isEmpty
              ? const _Empty(
                  'Nothing said yet. The transcript fills in verbatim as the '
                  'council speaks.',
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final m = rows[i];
                    final prev = i == 0 ? null : rows[i - 1];
                    final newRound = prev == null || prev.round != m.round;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (newRound) _roundMarker(m.round),
                        _MessageCard(c: c, m: m),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _titleBar(db.Session s, int count) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AgoraTheme.hairline)),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count messages · round ${s.round}/${s.maxRounds} · '
                '${s.elapsedSeconds}s elapsed',
                style: AgoraTheme.caption,
              ),
            ],
          ),
        ),
        PopupMenuButton<ViewMode>(
          tooltip: 'Default view for all messages',
          icon: const Icon(Icons.tune, size: 16),
          color: AgoraTheme.surface2,
          initialValue: widget.c.viewFor('__default__'),
          onSelected: widget.c.setDefaultView,
          itemBuilder: (_) => [
            for (final v in ViewMode.values)
              PopupMenuItem(
                value: v,
                child: Tooltip(message: v.blurb, child: Text(v.label)),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _roundMarker(int round) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
    child: Row(
      children: [
        Text(
          'ROUND $round',
          style: AgoraTheme.caption.copyWith(
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider()),
      ],
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.c, required this.m});
  final AgoraController c;
  final db.Message m;

  bool get _isAgora => m.role == 'system' || m.role == 'orchestrator';
  bool get _isUser => m.role == 'user';

  @override
  Widget build(BuildContext context) {
    final colour = _isAgora
        ? AgoraTheme.agoraVoice
        : _isUser
        ? AgoraTheme.dim
        : c.colorOf(m.agentId);
    final mode = c.viewFor(m.id);
    final intact = c.repo.isIntact(m);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: _isAgora
              ? AgoraTheme.agoraVoice.withValues(alpha: 0.06)
              : AgoraTheme.surface1,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: colour, width: 3),
            top: BorderSide(
              color: _isAgora ? AgoraTheme.hairline : Colors.transparent,
            ),
            right: const BorderSide(color: AgoraTheme.hairline),
            bottom: BorderSide(
              color: _isAgora ? AgoraTheme.hairline : Colors.transparent,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, colour, mode, intact),
            const SizedBox(height: 8),
            _body(context, mode),
            if (m.rawHtml != null && mode != ViewMode.raw) ...[
              const SizedBox(height: 8),
              _rawHtmlDisclosure(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    Color colour,
    ViewMode mode,
    bool intact,
  ) => Row(
    children: [
      if (_isAgora)
        const Icon(Icons.auto_awesome, size: 12, color: AgoraTheme.agoraVoice)
      else
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
      const SizedBox(width: 7),
      Text(
        _isAgora ? 'AGORA' : c.nameOf(m.agentId),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colour,
          letterSpacing: 0.3,
        ),
      ),
      if (c.seatFor(m.agentId)?.isLeader ?? false) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
      ],
      const SizedBox(width: 8),
      Text(_stamp(), style: AgoraTheme.caption),
      if (m.latencyMs != null) ...[
        const SizedBox(width: 8),
        Text(
          '${(m.latencyMs! / 1000).toStringAsFixed(1)}s',
          style: AgoraTheme.caption,
        ),
      ],
      const Spacer(),
      Tooltip(
        message: intact
            ? 'Hash matches the stored text (${m.contentHash})'
            : 'INTEGRITY FAILURE — text does not match its hash',
        child: Icon(
          intact ? Icons.verified_outlined : Icons.gpp_bad_outlined,
          size: 14,
          color: intact ? AgoraTheme.dim : AgoraTheme.danger,
        ),
      ),
      const SizedBox(width: 4),
      _viewMenu(mode),
      IconButton(
        tooltip: 'Copy verbatim',
        icon: const Icon(Icons.copy, size: 14),
        visualDensity: VisualDensity.compact,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: m.rawText));
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(const SnackBar(content: Text('Copied verbatim.')));
        },
      ),
    ],
  );

  String _stamp() {
    final t = m.createdAt;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss · r${m.round}';
  }

  Widget _viewMenu(ViewMode mode) => PopupMenuButton<ViewMode>(
    tooltip: 'View as…',
    icon: const Icon(Icons.visibility_outlined, size: 14),
    color: AgoraTheme.surface2,
    initialValue: mode,
    onSelected: (v) {
      c.cycleView(m.id);
      c.setDefaultView(v);
    },
    itemBuilder: (_) => [
      for (final v in ViewMode.values)
        PopupMenuItem(value: v, child: Text(v.label)),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        mode.label,
        style: AgoraTheme.caption.copyWith(
          color: AgoraTheme.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _body(BuildContext context, ViewMode mode) {
    switch (mode) {
      case ViewMode.raw:
        return SelectableText(
          m.rawText,
          style: AgoraTheme.mono,
          maxLines: null,
        );
      case ViewMode.rendered:
        return MarkdownBody(
          data: m.rawText,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: const TextStyle(fontSize: 13.5, height: 1.55),
            code: AgoraTheme.mono,
            codeblockDecoration: BoxDecoration(
              color: AgoraTheme.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AgoraTheme.hairline),
            ),
            blockquoteDecoration: const BoxDecoration(
              color: AgoraTheme.surface2,
            ),
            blockquotePadding: const EdgeInsets.all(8),
          ),
        );
      case ViewMode.plain:
        return SelectableText(
          _stripMarkdown(m.rawText),
          style: AgoraTheme.mono,
        );
    }
  }

  Widget _rawHtmlDisclosure(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        'source HTML (${m.rawHtml!.length} bytes)',
        style: AgoraTheme.caption,
      ),
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 240),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AgoraTheme.surface0,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AgoraTheme.hairline),
          ),
          child: SingleChildScrollView(
            child: SelectableText(m.rawHtml!, style: AgoraTheme.mono),
          ),
        ),
      ],
    ),
  );

  /// Reading view: drop Markdown scaffolding without touching the words.
  /// Conservative on purpose — it removes markers, never content.
  static String _stripMarkdown(String s) => s
      .replaceAll(RegExp(r'```[a-zA-Z0-9]*'), '')
      .replaceAll('```', '')
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
      .replaceAll(RegExp(r'(?<!\*)\*([^*\n]+)\*(?!\*)'), r'$1')
      .replaceAll(RegExp(r'`([^`\n]+)`'), r'$1')
      .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ')
      .replaceAll(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), r'$1 ($2)');
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AgoraTheme.caption.copyWith(height: 1.6),
      ),
    ),
  );
}
