import 'dart:convert';
import 'dart:io';

import 'package:agora/core/adapters/adapter_config.dart';
import 'package:agora/core/adapters/selector_prober.dart';
import 'package:flutter_test/flutter_test.dart';

SelectorHit hit({
  String selector = '#composer',
  String kind = 'css',
  int total = 0,
  int visible = 0,
  String sample = '',
  bool invalid = false,
}) => SelectorHit(
  selector: selector,
  kind: kind,
  total: total,
  visible: visible,
  sample: sample,
  invalid: invalid,
);

void main() {
  group('SelectorHit', () {
    test('parses the kernel payload', () {
      final h = SelectorHit.fromMap(<String, dynamic>{
        'selector': 'div[data-testid="send"]',
        'kind': 'css',
        'total': 3,
        'visible': 1,
        'sample': 'Send message',
        'invalid': false,
      });
      expect(h.selector, 'div[data-testid="send"]');
      expect(h.total, 3);
      expect(h.visible, 1);
      expect(h.matched, isTrue);
      expect(h.verdict, '1 visible');
    });

    test('survives a payload with missing numbers', () {
      final h = SelectorHit.fromMap(<String, dynamic>{'selector': 'x'});
      expect(h.total, 0);
      expect(h.visible, 0);
      expect(h.matched, isFalse);
      expect(h.invalid, isFalse);
    });

    test('verdicts separate invalid, hidden and absent', () {
      expect(hit(invalid: true).verdict, 'invalid CSS');
      expect(hit(invalid: true).matched, isFalse);
      expect(hit(total: 2, visible: 0).verdict, 'found but hidden');
      expect(hit(total: 2, visible: 0).foundButHidden, isTrue);
      expect(hit().verdict, 'no match');
    });
  });

  group('ProbeOutcome', () {
    test('matched means at least one selector was visible', () {
      final o = ProbeOutcome(
        slot: 'composer',
        spec: const SelectorSpec(css: <String>['#a', '#b']),
        hits: <SelectorHit>[
          hit(selector: '#a'),
          hit(selector: '#b', visible: 1),
        ],
      );
      expect(o.matched, isTrue);
      expect(o.winningSelector, '#b');
      expect(o.bestVisible, 1);
    });

    test('a hidden-only match is not a match', () {
      final o = ProbeOutcome(
        slot: 'send',
        spec: const SelectorSpec(css: <String>['#send']),
        hits: <SelectorHit>[hit(total: 4, visible: 0)],
      );
      expect(o.matched, isFalse);
      expect(o.matchedOnlyHidden, isTrue);
      expect(o.winningSelector, isNull);
    });

    test('an empty spec is not counted as broken', () {
      const o = ProbeOutcome(
        slot: 'captcha',
        spec: SelectorSpec(),
        hits: <SelectorHit>[],
      );
      expect(o.isEmptySpec, isTrue);
      expect(o.matched, isFalse);
    });

    test('flags invalid CSS separately from no match', () {
      final o = ProbeOutcome(
        slot: 'composer',
        spec: const SelectorSpec(css: <String>['#[']),
        hits: <SelectorHit>[hit(invalid: true)],
      );
      expect(o.hasInvalidSelector, isTrue);
      expect(o.matched, isFalse);
    });
  });

  group('SiteProbe', () {
    SiteProbe probe(
      List<ProbeOutcome> outcomes, {
      String? error,
      bool loaded = true,
    }) => SiteProbe(
      kind: 'gemini',
      displayName: 'Gemini',
      url: 'https://gemini.google.com',
      loaded: loaded,
      shadowRoots: 2,
      outcomes: outcomes,
      error: error,
    );

    ProbeOutcome ok(String slot) => ProbeOutcome(
      slot: slot,
      spec: const SelectorSpec(css: <String>['#x']),
      hits: <SelectorHit>[hit(visible: 1)],
    );
    ProbeOutcome dead(String slot) => ProbeOutcome(
      slot: slot,
      spec: const SelectorSpec(css: <String>['#x']),
      hits: <SelectorHit>[hit()],
    );

    test('counts only slots the adapter actually declares', () {
      final p = probe(<ProbeOutcome>[
        ok('composer'),
        dead('send'),
        const ProbeOutcome(
          slot: 'captcha',
          spec: SelectorSpec(),
          hits: <SelectorHit>[],
        ),
      ]);
      expect(p.scoredCount, 2);
      expect(p.matchedCount, 1);
      expect(p.allMatched, isFalse);
      expect(p.broken.map((ProbeOutcome o) => o.slot), <String>['send']);
      expect(p.headline, '1 of 2 checkable slots broken');
    });

    test('all green when every declared slot matched', () {
      final p = probe(<ProbeOutcome>[ok('composer'), ok('send')]);
      expect(p.allMatched, isTrue);
      expect(p.headline, 'all 2 checkable slots matched');
      expect(p.broken, isEmpty);
    });

    test('a login state that loses is not a broken selector', () {
      // signed in matched, so signed out cannot. Scoring that as rot would tell
      // the user their adapter is stale when it is behaving perfectly.
      final p = probe(<ProbeOutcome>[
        ok('composer'),
        ok('signed in'),
        const ProbeOutcome(
          slot: 'signed out',
          spec: SelectorSpec(text: <String>['sign in']),
          kind: SlotKind.state,
          hits: <SelectorHit>[],
        ),
      ]);
      expect(p.broken, isEmpty);
      expect(p.unverifiable, isEmpty);
      expect(p.allMatched, isTrue);
    });

    test('a node that cannot exist yet is unverifiable, not broken', () {
      final p = probe(<ProbeOutcome>[
        ok('composer'),
        const ProbeOutcome(
          slot: 'assistant node',
          spec: SelectorSpec(css: <String>['[data-role="assistant"]']),
          kind: SlotKind.conditional,
          hits: <SelectorHit>[],
        ),
        const ProbeOutcome(
          slot: 'user node',
          spec: SelectorSpec(css: <String>['[data-role="user"]']),
          kind: SlotKind.conditional,
          hits: <SelectorHit>[],
        ),
      ]);
      expect(p.broken, isEmpty);
      expect(p.allMatched, isTrue);
      expect(p.unverifiable.map((ProbeOutcome o) => o.slot), <String>[
        'assistant node',
        'user node',
      ]);
      expect(p.headline, '0 slot(s) broken, 2 unverifiable on an empty thread');
    });

    test('slotKinds covers every slot the prober reports', () {
      // A slot with no declared kind would silently default to element and so
      // be able to fail a healthy adapter.
      final Map<String, dynamic> raw =
          jsonDecode(File('assets/adapters/gemini.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final String slot in probeSlotsOf(
        AdapterConfig.fromJson(raw),
      ).keys) {
        expect(
          slotKinds.containsKey(slot),
          isTrue,
          reason: 'no kind for $slot',
        );
      }
    });

    test('a transport failure explains itself instead of looking like rot', () {
      final p = probe(const <ProbeOutcome>[], error: 'connection refused');
      expect(p.headline, 'connection refused');
      expect(p.broken, isEmpty);
    });

    test('an unloaded page is called out before any selector verdict', () {
      final p = probe(<ProbeOutcome>[dead('composer')], loaded: false);
      expect(p.headline, 'page did not load');
    });
  });

  group('probeSlotsOf', () {
    AdapterConfig load() {
      final raw = jsonDecode(
        File('assets/adapters/gemini.json').readAsStringSync(),
      );
      return AdapterConfig.fromJson(raw as Map<String, dynamic>);
    }

    test('walks the slots in the order a site actually breaks', () {
      final slots = probeSlotsOf(load()).keys.toList();
      expect(slots, <String>[
        'composer',
        'send',
        'assistant node',
        'user node',
        'container',
        'stop button',
        'signed in',
        'signed out',
      ]);
    });

    test('pulls the real specs out of the shipped adapter', () {
      final slots = probeSlotsOf(load());
      expect(slots['composer'], isNotEmpty);
      expect(slots['composer']!.css, isNotEmpty);
    });
  });

  group('shipped adapters', () {
    for (final kind in <String>['chatgpt', 'gemini', 'deepseek']) {
      test('$kind declares probeable selectors', () {
        final raw = jsonDecode(
          File('assets/adapters/$kind.json').readAsStringSync(),
        );
        final cfg = AdapterConfig.fromJson(raw as Map<String, dynamic>);
        expect(cfg.validate(), isEmpty, reason: '$kind must validate');

        final slots = probeSlotsOf(cfg);
        final scored = slots.entries
            .where(
              (MapEntry<String, SelectorSpec> e) =>
                  e.value.css.isNotEmpty || e.value.text.isNotEmpty,
            )
            .toList();
        expect(scored, isNotEmpty, reason: '$kind probes nothing');
        // A composer and a send button are the two things without which no
        // council can run at all.
        expect(slots['composer']!.css, isNotEmpty);
        expect(slots['send']!.css + slots['send']!.text, isNotEmpty);
      });
    }
  });
}
