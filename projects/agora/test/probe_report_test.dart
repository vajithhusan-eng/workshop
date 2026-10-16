import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agora/core/adapters/adapter_config.dart';
import 'package:agora/core/adapters/selector_prober.dart';
import 'package:agora/ui/probe_report.dart';
import 'package:agora/ui/theme.dart';

void main() {
  const okCss = SelectorSpec(css: ['#composer'], text: ['message mockai']);

  ProbeOutcome slot(
    String name, {
    SelectorSpec spec = okCss,
    SlotKind kind = SlotKind.element,
    List<SelectorHit> hits = const <SelectorHit>[],
    String? error,
  }) => ProbeOutcome(
    slot: name,
    spec: spec,
    kind: kind,
    hits: hits,
    error: error,
  );

  Future<void> render(WidgetTester t, SiteProbe probe) => t.pumpWidget(
    MaterialApp(
      theme: AgoraTheme.build(),
      home: Scaffold(body: SingleChildScrollView(child: ProbeReport(probe))),
    ),
  );

  const goodHit = SelectorHit(
    selector: '#composer',
    kind: 'css',
    total: 1,
    visible: 1,
    sample: 'message mockai',
    invalid: false,
  );

  testWidgets('a healthy probe reads as matched, not just valid', (t) async {
    await render(
      t,
      SiteProbe(
        kind: 'sandbox',
        displayName: 'Mock AI',
        url: 'file:///mock.html',
        loaded: true,
        shadowRoots: 0,
        outcomes: [
          slot('composer', hits: [goodHit]),
          slot(
            'stop button',
            kind: SlotKind.conditional,
            hits: const <SelectorHit>[],
          ),
        ],
      ),
    );

    expect(
      find.text('0 slot(s) broken, 1 unverifiable on an empty thread'),
      findsOneWidget,
    );
    expect(find.text('matched on #composer'), findsOneWidget);
    expect(find.textContaining('1 matched'), findsOneWidget);
    // The empty thread must not read as breakage.
    expect(find.textContaining('the site changed'), findsNothing);
    expect(
      find.textContaining('send a message, then probe again'),
      findsOneWidget,
    );
  });

  testWidgets('a stale selector names the site change, not a parse error', (
    t,
  ) async {
    await render(
      t,
      SiteProbe(
        kind: 'sandbox',
        displayName: 'Mock AI',
        url: 'file:///mock.html',
        loaded: true,
        shadowRoots: 0,
        outcomes: [
          slot('composer', hits: [goodHit]),
          slot(
            'container',
            spec: const SelectorSpec(css: ['#renamed-last-quarter']),
            hits: const [
              SelectorHit(
                selector: '#renamed-last-quarter',
                kind: 'css',
                total: 0,
                visible: 0,
                sample: '',
                invalid: false,
              ),
            ],
          ),
        ],
      ),
    );

    expect(find.text('1 of 2 checkable slots broken'), findsOneWidget);
    expect(
      find.text('no candidate resolved — the site changed'),
      findsOneWidget,
    );
    expect(
      find.textContaining('css no match: #renamed-last-quarter'),
      findsOneWidget,
    );
  });

  testWidgets('every tier is printed so a dead fallback tier is visible', (
    t,
  ) async {
    await render(
      t,
      SiteProbe(
        kind: 'sandbox',
        displayName: 'Mock AI',
        url: 'file:///mock.html',
        loaded: true,
        shadowRoots: 0,
        outcomes: [
          slot(
            'composer',
            hits: const [
              SelectorHit(
                selector: '#composer-that-was-renamed',
                kind: 'css',
                total: 0,
                visible: 0,
                sample: '',
                invalid: false,
              ),
              goodHit,
              SelectorHit(
                selector: 'message mockai',
                kind: 'text',
                total: 1,
                visible: 1,
                sample: 'message mockai',
                invalid: false,
              ),
            ],
          ),
        ],
      ),
    );

    // The CSS tier missed and the text tier won. Hiding the miss would make a
    // half-rotten adapter look healthy.
    expect(find.textContaining('css no match'), findsOneWidget);
    expect(find.textContaining('text 1 visible'), findsOneWidget);
    expect(find.text('matched on #composer'), findsOneWidget);
  });

  testWidgets('a transport error is shown instead of a verdict', (t) async {
    await render(
      t,
      const SiteProbe(
        kind: 'sandbox',
        displayName: 'Mock AI',
        url: 'file:///mock.html',
        loaded: false,
        shadowRoots: 0,
        outcomes: <ProbeOutcome>[],
        error: 'chrome did not start',
      ),
    );

    expect(find.text('chrome did not start'), findsWidgets);
    expect(find.text('page did not load'), findsNothing);
  });

  testWidgets('invalid CSS is called out separately from no-match', (t) async {
    await render(
      t,
      SiteProbe(
        kind: 'sandbox',
        displayName: 'Mock AI',
        url: 'file:///mock.html',
        loaded: true,
        shadowRoots: 0,
        outcomes: [
          slot(
            'composer',
            spec: const SelectorSpec(css: ['#(((']),
            hits: const [
              SelectorHit(
                selector: '#(((',
                kind: 'css',
                total: 0,
                visible: 0,
                sample: '',
                invalid: true,
              ),
            ],
          ),
        ],
      ),
    );

    expect(find.textContaining('invalid CSS — #((('), findsOneWidget);
    expect(find.textContaining('the site changed'), findsNothing);
  });

  testWidgets('a slot the adapter never declares is not counted as rot', (
    t,
  ) async {
    await render(
      t,
      SiteProbe(
        kind: 'sandbox',
        displayName: 'Mock AI',
        url: 'file:///mock.html',
        loaded: true,
        shadowRoots: 0,
        outcomes: [
          slot('composer', hits: [goodHit]),
          slot('send', spec: const SelectorSpec()),
        ],
      ),
    );

    expect(find.textContaining('not declared'), findsOneWidget);
    expect(find.textContaining('slot(s) broken'), findsNothing);
  });
}
