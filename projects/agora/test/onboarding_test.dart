import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agora/core/adapters/agent_adapter.dart';
import 'package:agora/core/council/login_checker.dart';
import 'package:agora/data/database.dart';
import 'package:agora/data/session_repository.dart';
import 'package:agora/state/agora_controller.dart';
import 'package:agora/ui/home_shell.dart';
import 'package:agora/ui/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginCheck', () {
    LoginCheck c(LoginStatus s) =>
        LoginCheck(kind: 'gemini', displayName: 'Gemini', status: s);

    test('ready only when the status is ready', () {
      expect(c(LoginStatus.ready).ready, isTrue);
      for (final s in LoginStatus.values.where((s) => s != LoginStatus.ready)) {
        expect(c(s).ready, isFalse, reason: '$s must not count as ready');
      }
    });

    test('every status has a distinct, non-empty remedy', () {
      final remedies = <String>{};
      for (final s in LoginStatus.values) {
        final r = c(s).remedy;
        expect(r.trim(), isNotEmpty, reason: '$s has no remedy text');
        remedies.add(r);
      }
      // Distinct enough that a screen of them is actually readable.
      expect(remedies.length, LoginStatus.values.length);
    });

    test('a signed-out site tells the user to sign in', () {
      expect(c(LoginStatus.loggedOut).remedy, contains('Sign in'));
    });

    test('a broken selector points at the Calibration Studio', () {
      expect(c(LoginStatus.needsRepair).remedy, contains('Calibration'));
    });
  });

  group('first-run gate', () {
    test('is not satisfied on a fresh profile', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await OnboardingScreen.alreadyOnboarded(), isFalse);
    });

    test('is satisfied once the wizard has been completed', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final p = await SharedPreferences.getInstance();
      await p.setBool(OnboardingScreen.prefsKey, true);
      expect(await OnboardingScreen.alreadyOnboarded(), isTrue);
    });

    testWidgets('shows the wizard on a fresh profile', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = AgoraDb.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final c = AgoraController(SessionRepository(db));
      addTearDown(c.dispose);
      c.start();

      await tester.pumpWidget(MaterialApp(home: HomeShellGate(c: c)));
      await tester.pumpAndSettle();

      // The wizard's first step, not the transcript.
      expect(find.text('Agora'), findsOneWidget);
      expect(find.text('Sign in to your AI sites'), findsNothing);
      // Step 0's action is Continue; only the last step says Start.
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('pressing Continue advances through the steps', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = AgoraDb.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final c = AgoraController(SessionRepository(db));
      addTearDown(c.dispose);
      c.start();

      await tester.pumpWidget(MaterialApp(home: HomeShellGate(c: c)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to your AI sites'), findsOneWidget);
      expect(find.text('Check my sign-ins'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('How Agora should behave'), findsOneWidget);
    });
  });
}
