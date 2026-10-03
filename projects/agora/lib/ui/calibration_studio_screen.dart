import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/adapters/adapter_config.dart';
import '../state/agora_controller.dart';
import 'theme.dart';

/// Adapters are data, not code. This screen is where a site redesign gets
/// answered without shipping a new Agora: edit a JSON selector set, re-validate,
/// and the next run uses it.
class CalibrationStudioScreen extends StatefulWidget {
  const CalibrationStudioScreen({super.key, required this.controller});
  final AgoraController controller;

  @override
  State<CalibrationStudioScreen> createState() => _CalibrationStudioState();
}

class _CalibrationStudioState extends State<CalibrationStudioScreen> {
  static const _kinds = <String>['chatgpt', 'gemini', 'deepseek'];
  String _kind = 'chatgpt';
  Map<String, dynamic>? _json;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load(_kind);
  }

  Future<void> _load(String kind) async {
    setState(() {
      _loading = true;
      _error = null;
      _kind = kind;
    });
    try {
      final raw = await rootBundle.loadString('assets/adapters/$kind.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('adapter file must be a JSON object');
      }
      setState(() {
        _json = decoded;
        _loading = false;
      });
    } on Object catch (e) {
      setState(() {
        _error = '$e';
        _json = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calibration Studio'),
        actions: [
          if (_json != null)
            IconButton(
              tooltip: 'Reset to shipped file',
              icon: const Icon(Icons.restart_alt),
              onPressed: () => _load(_kind),
            ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 170,
            child: Container(
              color: AgoraTheme.surface1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final k in _kinds)
                    ListTile(
                      dense: true,
                      selected: k == _kind,
                      title: Text(k, style: const TextStyle(fontSize: 13)),
                      onTap: () => _load(k),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not read the adapter:\n$_error',
                        style: const TextStyle(color: AgoraTheme.danger),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _validation(cfg),
                      const SizedBox(height: 14),
                      _inventory(cfg),
                      const SizedBox(height: 14),
                      _source(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  AdapterConfig? _config() {
    final j = _json;
    if (j == null) return null;
    try {
      return AdapterConfig.fromJson(j);
    } on Object {
      return null;
    }
  }

  Widget _validation(AdapterConfig? cfg) {
    if (cfg == null) {
      return const _Note(
        'This file does not parse as an adapter config, so it cannot be run.',
        bad: true,
      );
    }
    final problems = cfg.validate();
    if (problems.isEmpty) {
      return const _Note('Valid. Agora can drive this site as configured.');
    }
    return Card(
      color: AgoraTheme.danger.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Will not run until these are fixed',
              style: TextStyle(
                color: AgoraTheme.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (final p in problems)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('• $p', style: AgoraTheme.mono),
              ),
          ],
        ),
      ),
    );
  }

  Widget _inventory(AdapterConfig? cfg) {
    final c = cfg;
    if (c == null) return const SizedBox.shrink();
    final groups = <String, SelectorSpec>{
      'composer': c.composer,
      'send': c.send,
      'assistant node': c.extraction.assistantNode,
      'user node': c.extraction.userNode,
      'container': c.extraction.container,
      'streaming hint': c.extraction.streamingHint,
      'stop button': c.completion.stopButton,
      'logged in': c.login.loggedIn,
      'logged out': c.login.loggedOut,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${c.kind} v${c.version} — ${c.displayName}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 10),
            for (final e in groups.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(e.key, style: AgoraTheme.caption),
                    ),
                    Expanded(
                      child: Text(_describe(e.value), style: AgoraTheme.mono),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            const _Note(
              'Selector order is a fallback chain, most-specific first. Text '
              'selectors survive a CSS class rename; CSS selectors survive a '
              'copy change. Agora needs both to keep working.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _source() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('assets/adapters/$_kind.json', style: AgoraTheme.mono),
              const Spacer(),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy, size: 15),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _pretty));
                  ScaffoldMessenger.maybeOf(
                    context,
                  )?.showSnackBar(const SnackBar(content: Text('Copied.')));
                },
              ),
            ],
          ),
          const Divider(height: 16),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 420),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AgoraTheme.surface0,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AgoraTheme.hairline),
            ),
            child: SingleChildScrollView(
              child: SelectableText(_pretty, style: AgoraTheme.mono),
            ),
          ),
          const SizedBox(height: 10),
          const _Note(
            'Live probing against a real tab is the next step: open the '
            'site, then have Agora report which selector actually matched.',
          ),
        ],
      ),
    ),
  );

  /// A single candidate is worth printing in full; a fallback chain is not.
  static String _describe(SelectorSpec spec) {
    if (spec.none) return '—';
    final only = <String>[...spec.css, ...spec.text];
    if (only.length == 1) return only.first;
    return '${spec.candidateCount} candidates '
        '(${spec.css.length} css, ${spec.text.length} text)';
  }

  String get _pretty => const JsonEncoder.withIndent('  ').convert(_json ?? {});
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.bad = false});
  final String text;
  final bool bad;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: bad
          ? AgoraTheme.danger.withValues(alpha: 0.08)
          : AgoraTheme.surface2,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: bad ? AgoraTheme.danger : AgoraTheme.hairline),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        height: 1.5,
        color: bad ? AgoraTheme.danger : AgoraTheme.dim,
      ),
    ),
  );
}
