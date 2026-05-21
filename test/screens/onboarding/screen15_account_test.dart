import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/screens/onboarding/screen15_account.dart';

import '../../fakes/fake_migration_service.dart';
import '../../fakes/fake_signin_adapter.dart';

const _stubDestinationKey = Key('stubDestinationHome');
Widget _stubDestination(BuildContext _) =>
    const Scaffold(key: _stubDestinationKey, body: Text('stub-home'));

void main() {
  void useTallViewport(WidgetTester t) {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  /// Sets the platform override. Caller MUST reset it at the end of the
  /// test body (the framework's invariant check runs before addTearDown).
  void usePlatform(TargetPlatform p) {
    debugDefaultTargetPlatformOverride = p;
  }

  void resetPlatform() {
    debugDefaultTargetPlatformOverride = null;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });


  Widget wrap({
    required OnboardingController controller,
    required FakeSignInAdapter adapter,
    required FakeMigrationService migration,
  }) =>
      MaterialApp(
        home: Screen15Account(
          controller: controller,
          signInAdapter: adapter,
          migration: migration,
          destinationBuilder: _stubDestination,
        ),
      );

  group('platform gating', () {
    testWidgets('iOS shows all three provider buttons', (t) async {
      useTallViewport(t);
      usePlatform(TargetPlatform.iOS);
      try {
        await t.pumpWidget(wrap(
          controller: OnboardingController(),
          adapter: FakeSignInAdapter(),
          migration: FakeMigrationService(),
        ));
        await t.pump();

        expect(find.byKey(const Key('screen15AppleButton')), findsOneWidget);
        expect(find.byKey(const Key('screen15GoogleButton')), findsOneWidget);
        expect(find.byKey(const Key('screen15EmailButton')), findsOneWidget);
      } finally {
        resetPlatform();
      }
    });

    testWidgets('Android hides Apple, keeps Google + Email', (t) async {
      useTallViewport(t);
      usePlatform(TargetPlatform.android);
      try {
        await t.pumpWidget(wrap(
          controller: OnboardingController(),
          adapter: FakeSignInAdapter(),
          migration: FakeMigrationService(),
        ));
        await t.pump();

        expect(find.byKey(const Key('screen15AppleButton')), findsNothing);
        expect(find.byKey(const Key('screen15GoogleButton')), findsOneWidget);
        expect(find.byKey(const Key('screen15EmailButton')), findsOneWidget);
      } finally {
        resetPlatform();
      }
    });
  });

  testWidgets('Skip sets onboardingComplete pref and pushes AppShell',
      (t) async {
    useTallViewport(t);
    usePlatform(TargetPlatform.android);
    try {
      final migration = FakeMigrationService();
      await t.pumpWidget(wrap(
        controller: OnboardingController(),
        adapter: FakeSignInAdapter(),
        migration: migration,
      ));
      await t.pump();

      await t.tap(find.byKey(const Key('screen15SkipButton')));
      await t.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboardingComplete'), true);
      expect(migration.calls, 0, reason: 'Skip path must NOT migrate');
      expect(find.byKey(_stubDestinationKey), findsOneWidget);
    } finally {
      resetPlatform();
    }
  });

  testWidgets(
      'Google sign-in success → migration + alias + onboardingComplete + AppShell',
      (t) async {
    useTallViewport(t);
    usePlatform(TargetPlatform.android);
    try {
      final controller = OnboardingController();
      controller.setUserGoal('pantryFirst');
      final adapter = FakeSignInAdapter(googleUid: 'uid-abc-123');
      final migration = FakeMigrationService();

      await t.pumpWidget(wrap(
        controller: controller,
        adapter: adapter,
        migration: migration,
      ));
      await t.pump();

      await t.tap(find.byKey(const Key('screen15GoogleButton')));
      await t.pumpAndSettle();

      expect(adapter.googleCalls, 1);
      expect(migration.calls, 1);
      expect(migration.capturedUid, 'uid-abc-123');
      expect(migration.capturedState?.userGoal, 'pantryFirst');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboardingComplete'), true);
      expect(find.byKey(_stubDestinationKey), findsOneWidget);
    } finally {
      resetPlatform();
    }
  });

  testWidgets(
      'Google sign-in failure → no migration, no nav, shows toast',
      (t) async {
    useTallViewport(t);
    usePlatform(TargetPlatform.android);
    try {
      final adapter = FakeSignInAdapter(googleUid: null);
      final migration = FakeMigrationService();

      await t.pumpWidget(wrap(
        controller: OnboardingController(),
        adapter: adapter,
        migration: migration,
      ));
      await t.pump();

      await t.tap(find.byKey(const Key('screen15GoogleButton')));
      await t.pump(); // dispatch tap
      await t.pump(const Duration(milliseconds: 200));

      expect(adapter.googleCalls, 1);
      expect(migration.calls, 0);
      expect(find.byKey(_stubDestinationKey), findsNothing);
      expect(
        find.textContaining("Couldn't sign in with google", skipOffstage: false),
        findsOneWidget,
      );
    } finally {
      resetPlatform();
    }
  });

  testWidgets(
      'iOS Apple button with null uid + comingSoonMessage → "coming soon" toast, no nav',
      (t) async {
    useTallViewport(t);
    usePlatform(TargetPlatform.iOS);
    try {
      // appleUid defaults to null → placeholder path, not failure.
      final adapter = FakeSignInAdapter();
      final migration = FakeMigrationService();

      await t.pumpWidget(wrap(
        controller: OnboardingController(),
        adapter: adapter,
        migration: migration,
      ));
      await t.pump();

      await t.tap(find.byKey(const Key('screen15AppleButton')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));

      expect(adapter.appleCalls, 1);
      expect(migration.calls, 0);
      expect(find.byKey(_stubDestinationKey), findsNothing);
      expect(
        find.textContaining('Sign in with Apple is coming soon',
            skipOffstage: false),
        findsOneWidget,
      );
    } finally {
      resetPlatform();
    }
  });

  testWidgets('tapping Terms link shows a placeholder SnackBar', (t) async {
    useTallViewport(t);
    usePlatform(TargetPlatform.android);
    try {
      await t.pumpWidget(wrap(
        controller: OnboardingController(),
        adapter: FakeSignInAdapter(),
        migration: FakeMigrationService(),
      ));
      await t.pump();

      final terms = find.byKey(const Key('screen15TermsLink'));
      expect(terms, findsOneWidget);
      await t.ensureVisible(terms);
      await t.pump();
      await t.tap(terms, warnIfMissed: false);
      await t.pump();

      expect(
        find.textContaining('Terms of Service — opens at',
            skipOffstage: false),
        findsOneWidget,
      );
    } finally {
      resetPlatform();
    }
  });

  testWidgets('iOS Apple button tap invokes adapter.signInWithApple',
      (t) async {
    useTallViewport(t);
    usePlatform(TargetPlatform.iOS);
    try {
      final adapter = FakeSignInAdapter(appleUid: 'uid-apple-1');
      final migration = FakeMigrationService();

      await t.pumpWidget(wrap(
        controller: OnboardingController(),
        adapter: adapter,
        migration: migration,
      ));
      await t.pump();

      await t.tap(find.byKey(const Key('screen15AppleButton')));
      await t.pumpAndSettle();

      expect(adapter.appleCalls, 1);
      expect(migration.capturedUid, 'uid-apple-1');
    } finally {
      resetPlatform();
    }
  });
}
