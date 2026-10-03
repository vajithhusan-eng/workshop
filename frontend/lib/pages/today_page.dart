/// Today — the morning brief and what the watch loop noticed.
///
/// The 6am loop is pull, detect, retrieve, draft, guard. Everything except the
/// drafting is deterministic Python, deliberately: the twelve detection rules
/// must be reproducible and testable, because a rule that cries wolf gets
/// switched off, and a switched-off rule protects nobody.
///
/// So this screen shows the *findings* first, each with the rule that fired
/// and the principle behind it. A flag you cannot interrogate is an oracle,
/// and oracles are the thing this product exists to replace.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.api});
  final Api api;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final _circle = TextEditingController(text: 'IT, Pharma, Banking');
  final _invested = TextEditingController(text: '500000');
  final _events = TextEditingController(text: _sampleEvents);

  Map<String, dynamic>? _findings;
  Map<String, dynamic>? _brief;
  String? _error;
  bool _busy = false;

  static const _sampleEvents = '''[
  {"symbol":"RELIANCE","move_pct":-4.2,"sector_move_pct":-0.4,"holding":true},
  {"symbol":"TATAMOTORS","move_pct":4.8,"sector_move_pct":0.3,"holding":false}
]''';

  @override
  void dispose() {
    _circle.dispose();
    _invested.dispose();
    _events.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    List<dynamic> events;
    try {
      final decoded = jsonDecode(_events.text);
      if (decoded is! List) {
        throw const FormatException('expected a JSON array');
      }
      events = decoded;
    } catch (e) {
      setState(() => _error = 'Events must be a JSON array.\n\n$e');
      return;
    }

    final circle = _circle.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await widget.api.watchDetect(
      events: events.cast<Map<String, dynamic>>(),
      asOf: DateTime.now().toIso8601String().substring(0, 10),
      circle: circle,
      portfolioInvested: double.tryParse(_invested.text.trim()),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok) {
        _findings = r.value;
        _error = null;
      } else {
        _error = r.error;
        _findings = null;
      }
    });
  }

  Future<void> _briefNow() async {
    List<Map<String, dynamic>> events;
    try {
      events = (jsonDecode(_events.text) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      events = const <Map<String, dynamic>>[];
    }
    setState(() => _busy = true);
    final r = await widget.api.brief(events: events);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok) {
        _brief = r.value;
      } else {
        _error = r.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _input(),
          if (_error != null) ErrorBox(_error!),
          if (_findings != null) _findingsCard(_findings!),
          if (_brief != null) _briefCard(_brief!),
          _rulesCard(),
        ],
      );

  Widget _input() => SectionCard(
        title: 'What happened, and what did you promise yourself?',
        subtitle:
            'The circle is the box that matters. Declaring it is the only way any '
            'rule can hold you to it — we will not guess a boundary on your behalf.',
        children: [
          TextField(
            controller: _circle,
            decoration: const InputDecoration(
              labelText: 'My circle of competence',
              helperText: 'Comma-separated sectors or industries.',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          NumField(
            label: 'Portfolio invested (₹)',
            controller: _invested,
            fallback: 500000,
            decimals: 0,
            helper: 'Used by the concentration and cost rules.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _events,
            maxLines: 7,
            minLines: 3,
            style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              labelText: 'Events (symbol, move_pct, sector_move_pct, holding)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: RunButton(
                  onPressed: _run,
                  busy: _busy,
                  busyLabel: 'Checking…',
                  label: 'Run the 12 rules',
                  icon: Icons.radar,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _briefNow,
                  icon: const Icon(Icons.wb_sunny_outlined, size: 17),
                  label: const Text('Brief'),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _findingsCard(Map<String, dynamic> r) {
    final fired =
        (r['fired'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final errors = (r['errors'] as List?)?.cast<String>() ?? const [];

    return Column(
      children: [
        SectionCard(
          title: fired.isEmpty
              ? 'Nothing fired — 0 of ${r['rules_registered']} rules.'
              : '${fired.length} of ${r['rules_registered']} rules fired',
          subtitle: fired.isEmpty
              ? 'Not a pass. It means none of the twelve things we watch for happened.'
              : 'Each is a prompt to check your own reasoning, not an instruction.',
          children: [
            if (fired.isEmpty)
              const EmptyBox(
                'Quiet day. The rules look for specific things, and '
                'none of them happened.',
              )
            else
              for (final f in fired)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: VerdictBanner(
                    severity: f['severity'],
                    headline: '${f['rule']}'
                        '${f['symbol'] != null ? ' · ${f['symbol']}' : ''}',
                    detail: '${f['note']}',
                  ),
                ),
          ],
        ),
        if (errors.isNotEmpty)
          ErrorBox(
            '${errors.length} rule(s) failed to run:\n${errors.join('\n')}',
          ),
      ],
    );
  }

  Widget _briefCard(Map<String, dynamic> b) => SectionCard(
        title: 'Morning brief',
        subtitle: b['source']?.toString(),
        children: [
          SelectableText(
            '${b['brief'] ?? b['text'] ?? '(empty)'}',
            style: const TextStyle(height: 1.45),
          ),
          if (b['disclaimers'] is List)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final d in (b['disclaimers'] as List))
                    Text(
                      '· ${d.toString()}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                ],
              ),
            ),
        ],
      );

  Widget _rulesCard() => SectionCard(
        title: 'The twelve rules',
        subtitle:
            'All of them, with the reason each exists. A rule you cannot justify '
            'is a rule you should switch off.',
        children: [
          AsyncSection<Map<String, dynamic>>(
            future: widget.api.watchRules,
            loadingLabel: 'Loading rules',
            builder: (context, r) {
              final items =
                  (r['items'] as List?)?.cast<Map<String, dynamic>>() ??
                      const [];
              if (items.isEmpty) return const EmptyBox('No rules registered.');
              return Column(
                children: [
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${it['id']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${it['desc']}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${it['basis']}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.outline,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );
}
