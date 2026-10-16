import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agora/ui/conversation_list.dart';
import 'package:agora/ui/theme.dart';

/// §18.3 chat-list chrome. The chip is pure presentation, so every value it
/// draws can be pinned here without a database, a controller or a live council.
void main() {
  group('stackKinds', () {
    test('drops blanks and duplicates, keeping order', () {
      expect(stackKinds(<String>[]), isEmpty);
      expect(stackKinds(<String>['', 'gemini']), <String>['gemini']);
      expect(stackKinds(<String>['a', 'a', 'b']), <String>['a', 'b']);
    });

    test('caps the stack', () {
      expect(stackKinds(<String>['a', 'b', 'c', 'd'], max: 3), <String>[
        'a',
        'b',
        'c',
      ]);
      expect(stackKinds(<String>['a', 'b'], max: 1), <String>['a']);
    });
  });

  group('initialOf', () {
    test('upper-cases the first character of a kind', () {
      expect(initialOf('gemini'), 'G');
      expect(initialOf('DeepSeek'), 'D');
    });

    test('is ? when there is nothing to draw', () {
      expect(initialOf(''), '?');
      expect(initialOf('   '), '?');
    });
  });

  group('unreadLabel', () {
    test('shows the count, capping at 99+', () {
      expect(unreadLabel(0), '0');
      expect(unreadLabel(5), '5');
      expect(unreadLabel(99), '99');
      expect(unreadLabel(100), '99+');
      expect(unreadLabel(1234), '99+');
    });
  });

  group('presenceColor', () {
    test('a live turn is not the same colour as ready', () {
      expect(presenceColor('running'), isNot(presenceColor('enabled')));
    });

    test('the trouble states are the danger colour', () {
      for (final s in <String>[
        'error',
        'failed',
        'blocked',
        'login_required',
      ]) {
        expect(presenceColor(s), AgoraTheme.danger);
      }
    });

    test('ready is ok; unknown and muted read as away', () {
      expect(presenceColor('enabled'), AgoraTheme.ok);
      expect(presenceColor(null), AgoraTheme.dim);
      expect(presenceColor('muted'), AgoraTheme.dim);
      expect(presenceColor('idle'), AgoraTheme.dim);
    });
  });

  group('ConversationChip', () {
    Future<void> pump(
      WidgetTester tester, {
      required List<String> memberKinds,
      int unread = 0,
      VoidCallback? onTap,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationChip(
            label: 'Council',
            selected: false,
            icon: Icons.groups,
            memberKinds: memberKinds,
            colorOf: (_) => AgoraTheme.accent,
            status: 'enabled',
            unread: unread,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );

    testWidgets('draws the title and the unread badge', (tester) async {
      await pump(
        tester,
        memberKinds: <String>['gemini', 'deepseek'],
        unread: 3,
      );
      expect(find.text('Council'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('hides the badge when nothing is unread', (tester) async {
      await pump(tester, memberKinds: <String>['gemini']);
      expect(find.text('Council'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('falls back to the icon when no members are drawn', (
      tester,
    ) async {
      await pump(tester, memberKinds: <String>[]);
      expect(find.byIcon(Icons.groups), findsOneWidget);
    });

    testWidgets('tapping reports the choice', (tester) async {
      var tapped = 0;
      await pump(
        tester,
        memberKinds: <String>['gemini'],
        onTap: () => tapped++,
      );
      await tester.tap(find.byType(ConversationChip));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });
  });
}
