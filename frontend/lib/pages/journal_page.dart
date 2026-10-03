/// The Journal — the only part of this app the user actually owns.
///
/// A thesis without an expiry is a feeling with a ticker attached, so every
/// entry carries a written reason and gets graded later. The reason is
/// required and cannot be edited: the entire value lies in having written it
/// down *before* you knew the outcome, and an editable "why" is a hindsight
/// machine that always says you were right.
library;

import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key, required this.api});
  final Api api;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final _sym = TextEditingController(text: 'RELIANCE');
  final _why = TextEditingController();
  final _inval = TextEditingController();
  final _price = TextEditingController(text: '1384');
  final _qty = TextEditingController(text: '10');

  String _tag = 'value';
  String _side = 'buy';
  bool _busy = false;
  String? _error;
  String? _ok;

  @override
  void dispose() {
    for (final c in [_sym, _why, _inval, _price, _qty]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _log() async {
    if (_why.text.trim().isEmpty) {
      setState(() => _error = 'The reason is the whole point. Write it.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    final r = await widget.api.addJournalEntry(
      symbol: _sym.text.trim().toUpperCase(),
      why: _why.text.trim(),
      side: _side,
      tag: _tag,
      price: double.tryParse(_price.text.trim()) ?? 0,
      qty: double.tryParse(_qty.text.trim()) ?? 0,
      invalidation: _inval.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok) {
        _ok =
            'Logged. The reason is frozen now — you cannot edit it later, which '
            'is the only reason it stays worth anything.';
        _why.clear();
        _inval.clear();
      } else {
        _error = r.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      _form(),
      if (_error != null) ErrorBox(_error!),
      if (_ok != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: VerdictBanner(severity: 'LOW', headline: _ok!),
        ),
      _stats(),
      _entries(),
    ],
  );

  Widget _form() => SectionCard(
    title: 'Log it before you know how it ends',
    subtitle: 'Write the reason now. Grade it in 12 months.',
    children: [
      TextField(
        controller: _sym,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Symbol',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _side,
              decoration: const InputDecoration(
                labelText: 'Side',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                'buy',
                'sell',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _side = v ?? 'buy'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _tag,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tag',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                'value',
                'quality',
                'FOMO',
                'breakout',
                'revenge-trade',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _tag = v ?? 'value'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: NumField(
              label: 'Qty',
              controller: _qty,
              fallback: 10,
              decimals: 0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: NumField(
              label: 'Price ₹',
              controller: _price,
              fallback: 1384,
              decimals: 2,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _why,
        maxLines: 3,
        minLines: 2,
        decoration: const InputDecoration(
          labelText: 'Why (required, frozen)',
          helperText: 'The claim, in one sentence, in your own words.',
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _inval,
        decoration: const InputDecoration(
          labelText: 'What would prove me wrong?',
          helperText:
              'Optional, but a thesis with no invalidation has no exit.',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: RunButton(
          onPressed: _log,
          busy: _busy,
          busyLabel: 'Logging…',
          label: 'Log it',
          icon: Icons.edit_note,
        ),
      ),
    ],
  );

  Widget _stats() => SectionCard(
    title: 'Your own record',
    subtitle: 'The only track record that is definitely yours.',
    children: [
      AsyncSection<Map<String, dynamic>>(
        future: widget.api.journalStats,
        builder: (context, s) {
          final n = (s['n_entries'] as num?)?.toInt() ?? 0;
          if (n == 0) {
            return const EmptyBox(
              'No entries yet. Nothing lives here until '
              'you write a reason down.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in s.entries)
                if (e.value is num)
                  Kv(
                    '${e.key}',
                    fmt(e.value),
                    severity: '${e.key}'.toLowerCase().contains('loss')
                        ? 'HIGH'
                        : null,
                  )
                else
                  Kv('${e.key}', '${e.value}'),
            ],
          );
        },
      ),
    ],
  );

  Widget _entries() => SectionCard(
    title: 'Everything you have written',
    children: [
      AsyncSection<List<dynamic>>(
        future: widget.api.journalEntries,
        builder: (context, items) {
          if (items.isEmpty) return const EmptyBox('Nothing logged yet.');
          return Column(
            children: [
              for (final raw in items)
                Builder(
                  builder: (context) {
                    final e = Map<String, dynamic>.from(raw as Map);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${e['symbol']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${e['tag']}',
                                  style: const TextStyle(fontSize: 10.5),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${e['side']} · ${e['qty']} @ ${e['price']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${e['why']}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                          if ('${e['invalidation'] ?? ''}'.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Invalidation: ${e['invalidation']}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                          const Divider(height: 18),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    ],
  );
}
