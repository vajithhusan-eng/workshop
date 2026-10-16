/// The adviser's voice.
///
/// **THE HYBRID AI RULE, applied:** every number in this file was computed by
/// Python before it got here. The narration only *arranges* those numbers into
/// sentences — it does not derive, estimate, round in its favour, or invent a
/// figure. If the engine says HOLD, the prose says HOLD.
///
/// There is no LLM in this path today. The backend's `/api/ask` is a scaffold
/// waiting on a key, so presenting this composition as a model's opinion would
/// be a lie about where the words came from. [narrationProvenance] says so out
/// loud and the HUD prints it. When a model is wired in, it narrates *over*
/// these same Python outputs and the provenance string changes with it.
library;

import 'package:flutter/material.dart' show Color;

import '../theme/terminal.dart';

/// How the words in a narration were produced. Printed beside the text so a
/// reader never has to guess whether a sentence came from a model.
const String narrationProvenance =
    'Composed from the engine\'s own rule outputs — no language model in the '
    'loop. Every number below was computed by Python from the same bars the '
    'chart is drawn from.';

/// An adviser-style reading of one verdict payload.
class Narration {
  const Narration({
    required this.action,
    required this.headline,
    required this.body,
    required this.counter,
    required this.caveat,
  });

  /// The engine's action, carried through so the tone can never disagree with
  /// the badge beside it.
  final String action;

  /// One line: what the engine concluded.
  final String headline;

  /// Why, in prose, grouped by which way the rules voted.
  final String body;

  /// What would have to be true for this to be wrong.
  final String counter;

  /// The engine's own limits, carried through verbatim.
  final String caveat;
}

/// Compose a [Narration] from a `/api/analysis/symbol` `verdict`.
///
/// Pure and total: any payload shape — including a malformed one — produces
/// prose rather than an exception, because a narrator that throws takes the
/// panel down with it.
Narration narrate(Map<String, dynamic> verdict) {
  final action = (verdict['action'] ?? '').toString().toUpperCase();
  final regime = (verdict['regime'] ?? 'UNKNOWN').toString();
  final conviction = _asDouble(verdict['conviction']) ?? 0;
  final agreement = _asDouble(verdict['agreement']) ?? 0;
  final barsUsed = _asInt(verdict['bars_used']) ?? 0;
  final synthetic = (verdict['data_quality'] ?? '').toString() == 'synthetic';
  final vetoes = _strings(verdict['vetoes']);
  final notes = _strings(verdict['notes']);

  final reasons = _reasons(verdict['reasons']);
  final forIt = reasons.where((r) => r.direction > 0).toList();
  final against = reasons.where((r) => r.direction < 0).toList();
  final flat = reasons.where((r) => r.direction == 0).toList();

  if (action.isEmpty) {
    return const Narration(
      action: '',
      headline: 'No verdict returned.',
      body: 'The engine produced no action for this symbol, so there is '
          'nothing to explain. Treat the panel as empty rather than as a hold.',
      counter: 'A missing verdict is a missing answer, not a neutral one.',
      caveat: '',
    );
  }

  if (synthetic) {
    return Narration(
      action: action,
      headline: '$action — but the prices behind it are invented.',
      body: 'No real feed was reachable for this symbol, so the bars are a '
          'deterministic random walk. A signal computed on invented prices '
          'describes nothing, which is why the engine reports the data quality '
          'before it reports the action. Read the chart for the interface, not '
          'for the market.',
      counter: 'The only thing that changes this is a real feed. Nothing in '
          'the numbers below can be repaired by looking harder at it.',
      caveat: notes.join(' '),
    );
  }

  final headline = switch (action) {
    'BUY' => 'The engine leans in: $action at ${(conviction * 100).round()}% '
        'conviction, in a $regime regime.',
    'SELL' => 'The engine leans out: $action at ${(conviction * 100).round()}% '
        'conviction, in a $regime regime.',
    'AVOID' => 'The engine says stay out: $action, in a $regime regime.',
    'NO_DATA' => 'The engine refuses to answer: NO_DATA.',
    _ => 'The engine is flat: $action at ${(conviction * 100).round()}% '
        'conviction, in a $regime regime.',
  };

  final b = StringBuffer();

  if (vetoes.isNotEmpty) {
    b.writeln('A veto overrode the arithmetic: ${vetoes.join('; ')}. ');
    b.writeln();
  }

  if (against.isNotEmpty) {
    b.writeln('${_count(against.length)} of the rules point down. ');
    b.writeln(against.take(3).map((r) => r.text).join(' '));
    b.writeln();
  }
  if (forIt.isNotEmpty) {
    b.writeln('${_count(forIt.length)} point up. ');
    b.writeln(forIt.take(3).map((r) => r.text).join(' '));
    b.writeln();
  }
  if (flat.isNotEmpty) {
    b.writeln('${_count(flat.length)} are neutral and contributed nothing: '
        '${flat.map((r) => r.rule.replaceAll('_', ' ')).join(', ')}.');
    b.writeln();
  }

  b.writeln(
    'Rules agreed ${(agreement * 100).round()}% of the time across '
    '$barsUsed bars — agreement is how consistently the rules pointed the '
    'same way, not how right they are.',
  );

  final counter = _counter(verdict, action, regime, reasons);

  return Narration(
    action: action,
    headline: headline,
    body: b.toString().trim(),
    counter: counter,
    caveat: notes.isEmpty
        ? 'A classification of the state of the last bar — not a timed '
            'instruction and not a price target.'
        : notes.join(' '),
  );
}

/// What would have to change for this verdict to be wrong.
///
/// Built from the rules that are currently *neutral*, because those are the
/// ones with room to move — quoting a rule that already votes against the
/// verdict as "what would change it" would be backwards.
String _counter(
  Map<String, dynamic> verdict,
  String action,
  String regime,
  List<_Reason> reasons,
) {
  final neutral = reasons.where((r) => r.direction == 0).toList();
  final parts = <String>[];

  if (neutral.isNotEmpty) {
    parts.add(
      'The undecided rules are what would move it: '
      '${neutral.take(3).map((r) => r.text).join(' ')}',
    );
  }

  final direction = verdict['fingerprint'];
  if (direction is Map) {
    final flips = direction.entries
        .where((e) => e.value is int && (e.value as int) != 0)
        .map((e) => e.key.toString().replaceAll('_', ' '))
        .toList();
    if (flips.isNotEmpty) {
      parts.add(
        'A change in any of these would re-grade it: ${flips.join(', ')}.',
      );
    }
  }

  parts.add(
    'Nothing here has a horizon attached. Without one, "$action $regime" is a '
    'description of the last bar and not of the next one.',
  );

  return parts.join('\n\n');
}

class _Reason {
  const _Reason(this.rule, this.direction, this.text);
  final String rule;
  final int direction;
  final String text;
}

List<_Reason> _reasons(dynamic raw) {
  if (raw is! List) return const [];
  final out = <_Reason>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final text = e['text'];
    if (text is! String || text.isEmpty) continue;
    out.add(_Reason(
      (e['rule'] ?? '').toString(),
      _asInt(e['direction']) ?? 0,
      text,
    ));
  }
  return out;
}

String _count(int n) {
  const words = [
    'None',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve'
  ];
  return n < words.length ? words[n] : '$n';
}

double? _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

List<String> _strings(dynamic v) => v is List
    ? v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
    : const [];

/// The colour a narration headline is drawn in.
///
/// Reads the action off the narration rather than off the sentence, so it can
/// never parse a word out of prose and get it wrong — the prose and the badge
/// beside it are the same colour by construction.
Color narrationTone(Narration n) => actionColor(n.action);
