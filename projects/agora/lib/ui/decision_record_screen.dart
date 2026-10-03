import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../state/agora_controller.dart';
import 'theme.dart';

/// Turns a chat into an artifact you can defend later: the question, who was in
/// the room, what each seat was for, the round log, and the full evidence chain
/// with every hash and integrity verdict. Nothing is summarised — the record
/// quotes the vault.
class DecisionRecordScreen extends StatefulWidget {
  const DecisionRecordScreen({super.key, required this.controller});
  final AgoraController controller;

  @override
  State<DecisionRecordScreen> createState() => _DecisionRecordScreenState();
}

class _DecisionRecordScreenState extends State<DecisionRecordScreen> {
  Future<Map<String, dynamic>>? _doc;
  bool _preview = true;

  @override
  void initState() {
    super.initState();
    _doc = widget.controller.export();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decision Record'),
        actions: [
          IconButton(
            tooltip: _preview ? 'Show Markdown' : 'Show rendered',
            icon: Icon(_preview ? Icons.visibility : Icons.code),
            onPressed: () => setState(() => _preview = !_preview),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy),
            onPressed: _copy,
          ),
          IconButton(
            tooltip: 'Save as Markdown…',
            icon: const Icon(Icons.save_alt),
            onPressed: _save,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _doc,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snap.data!;
          final md = _render(doc);
          if (!_preview) {
            return _scroll(SelectableText(md, style: AgoraTheme.mono));
          }
          return _scroll(
            MarkdownBody(
              data: md,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
            ),
          );
        },
      ),
    );
  }

  Widget _scroll(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: child,
      ),
    ),
  );

  String _render(Map<String, dynamic> doc) {
    final s = (doc['session'] as Map?)?.cast<String, dynamic>();
    if (s == null) return '# No session selected';
    final seats = (doc['seats'] as List?) ?? const [];
    final msgs = (doc['messages'] as List?) ?? const [];
    final facts = (doc['facts'] as List?) ?? const [];
    final c = widget.controller;

    final agents =
        (doc['messages'] as List?)
            ?.cast<Map>()
            .map((m) => (m['agent'] as String?) ?? '')
            .toSet() ??
        <String>{};
    final byKind = <String, String>{};
    for (final seat in seats.cast<Map>()) {
      byKind[(seat['kind'] as String?) ?? ''] =
          (seat['displayName'] as String?) ?? '';
    }

    final lastAgent = msgs.cast<Map>().lastWhere(
      (m) => m['role'] == 'agent',
      orElse: () => <String, dynamic>{},
    );

    final b = StringBuffer()
      ..writeln('# Decision Record — ${s['title']}')
      ..writeln()
      ..writeln('- **Session** `${s['id']}`')
      ..writeln('- **Exported** ${doc['exportedAt']}')
      ..writeln(
        '- **Status** ${s['status']} · round ${s['round']}/${s['maxRounds']}',
      )
      ..writeln('- **Verbatim messages** ${msgs.length}')
      ..writeln('- **Context strategy** ${s['contextStrategy']}')
      ..writeln()
      ..writeln('## The question')
      ..writeln()
      ..writeln('> ${s['prompt']}')
      ..writeln()
      ..writeln('## Who was in the room')
      ..writeln();

    for (final seat in seats.cast<Map>()) {
      b.writeln(
        '### ${seat['displayName']}${seat['isLeader'] == true ? ' — leader' : ''}',
      );
      b.writeln();
      b.writeln(
        'Seat status: `${seat['status']}`${seat['modelLabel'] == null ? '' : ' · model `${seat['modelLabel']}`'}',
      );
      b.writeln();
      final card = (seat['roleCard'] as String?)?.trim();
      b.writeln(
        card == null || card.isEmpty ? '_No role card._' : 'Role card: $card',
      );
      b.writeln();
    }

    if (facts.isNotEmpty) {
      b.writeln('## Facts the council settled on');
      b.writeln();
      for (final f in facts.cast<Map>()) {
        final pin = f['pinned'] == true ? '📌 ' : '';
        b.writeln('- $pin${f['fact']}  _(${f['origin']})_');
      }
      b.writeln();
    }

    if (lastAgent.isNotEmpty) {
      b
        ..writeln('## Verdict')
        ..writeln()
        ..writeln('```')
        ..writeln(lastAgent['rawText'])
        ..writeln('```')
        ..writeln()
        ..writeln(
          '_Round ${lastAgent['round']} · ${byKind[lastAgent['agent']] ?? lastAgent['agent']}._',
        )
        ..writeln();
    }

    b.writeln('## Round log');
    b.writeln();
    for (var r = 0; r <= (s['round'] as int? ?? 0); r++) {
      final inRound = msgs.cast<Map>().where((m) => m['round'] == r).toList();
      if (inRound.isEmpty) continue;
      b.writeln('### Round $r');
      b.writeln();
      for (final m in inRound) {
        final who = m['role'] == 'agent'
            ? (byKind[m['agent']] ?? '${m['agent']}')
            : '${m['role']}';
        final chars = (m['rawText'] as String? ?? '').length;
        b.writeln(
          '- **$who** · $chars chars · ${m['latencyMs'] ?? 0}ms'
          ' · hash `${m['contentHash']}` · integrity '
          '`${m['intact'] == true ? 'intact' : 'FAILED'}`',
        );
      }
      b.writeln();
    }

    b
      ..writeln('## Evidence chain')
      ..writeln()
      ..writeln('Every turn exactly as received. Agora does not paraphrase.')
      ..writeln();
    for (final m in msgs.cast<Map>()) {
      final who = m['role'] == 'agent'
          ? (byKind[m['agent']] ?? '${m['agent']}')
          : '${m['role']}';
      b
        ..writeln('### r${m['round']} · $who')
        ..writeln()
        ..writeln('- id `${m['id']}`')
        ..writeln(
          '- hash `${m['contentHash']}` — '
          '**${m['intact'] == true ? 'intact' : 'FAILED'}**',
        )
        ..writeln('- screenshot: `${m['screenshotPath'] ?? 'none'}`')
        ..writeln()
        ..writeln('```')
        ..writeln(m['rawText'])
        ..writeln('```')
        ..writeln();
    }

    b
      ..writeln('---')
      ..writeln()
      ..writeln(
        '_Agents present: ${agents.map((k) => byKind[k] ?? k).join(', ')}._',
      )
      ..writeln(
        '_Session view index: ${c.sessions.length} session(s) known to this app._',
      );
    return b.toString();
  }

  Future<String> _currentMd() async =>
      _render(await widget.controller.export());

  Future<void> _copy() async {
    final md = await _currentMd();
    await Clipboard.setData(ClipboardData(text: md));
    if (mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Decision Record copied.')));
    }
  }

  Future<void> _save() async {
    final md = await _currentMd();
    final loc = await getSaveLocation(
      suggestedName:
          'decision-record-${DateTime.now().millisecondsSinceEpoch}.md',
    );
    if (loc == null || !mounted) return;
    await File(loc.path).writeAsString(md);
    if (mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('Saved to ${loc.path}')));
    }
  }
}
