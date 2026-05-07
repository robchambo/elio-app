import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/models/onboarding_state.dart';
import 'package:elio_app/screens/paywall/paywall_screen.dart';
import 'package:elio_app/widgets/elio/elio_page_title.dart';

// ─────────────────────────────────────────────
// Paywall first_recipe trigger — goal-keyed headline coverage.
//
// These tests render the screen shallowly (no RC packages) and assert
// which headline text appears. The paywall's `_showTrialState` getter
// is load-bearing (CLAUDE.md): empty packages → trial copy, so the
// "Start my 7-day free trial" CTA always shows. The hero headline
// varies purely on `onboarding.userGoal`.
// ─────────────────────────────────────────────

void main() {
  void useTallViewport(WidgetTester t) {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  Widget wrap({required OnboardingState onboarding}) => MaterialApp(
        home: PaywallScreen(
          trigger: PaywallTrigger.first_recipe,
          onboarding: onboarding,
        ),
      );

  group('first_recipe headline per goal', () {
    final cases = <(String?, String)>[
      ('pantryFirst', 'cook from your pantry. every night.'),
      ('wasteReduction', 'cut your food waste from week one.'),
      ('decisionFatigue', 'no more 6pm panic.'),
      ('household', 'one plan for the whole house.'),
      // takeawayEscape headline is region-aware — asserted separately below.
      (null, 'unlimited elio. start with 7 days free.'),
    ];

    for (final c in cases) {
      final goal = c.$1;
      final expected = c.$2;
      testWidgets('goal=${goal ?? "null"} → "$expected"', (t) async {
        useTallViewport(t);
        final state = OnboardingState(userGoal: goal);
        await t.pumpWidget(wrap(onboarding: state));
        // AnimatedBuilder etc — pump once for layout.
        await t.pump();
        expect(
          find.byWidgetPredicate(
            (w) => w is ElioPageTitle && w.text == expected,
            skipOffstage: false,
          ),
          findsOneWidget,
          reason: 'Headline for goal "$goal" should be "$expected"',
        );
      });
    }
  });

  group('takeawayEscape headline is region-aware', () {
    testWidgets('region=us → "skip the takeout."', (t) async {
      useTallViewport(t);
      await t.pumpWidget(wrap(
        onboarding: OnboardingState(userGoal: 'takeawayEscape', region: 'us'),
      ));
      await t.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is ElioPageTitle && w.text == 'skip the takeout.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('region=uk → "skip the takeaway."', (t) async {
      useTallViewport(t);
      await t.pumpWidget(wrap(
        onboarding: OnboardingState(userGoal: 'takeawayEscape', region: 'uk'),
      ));
      await t.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is ElioPageTitle && w.text == 'skip the takeaway.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('pantryFirst headline renders as single joined string', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(
      onboarding: OnboardingState(userGoal: 'pantryFirst'),
    ));
    await t.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is ElioPageTitle && w.text == 'cook from your pantry. every night.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('primary CTA uses "Start my" (first-person)', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(
      onboarding: OnboardingState(userGoal: 'pantryFirst'),
    ));
    await t.pump();
    // Packages are empty (no RC key in tests) → _showTrialState → true,
    // so trial CTA copy renders.
    expect(
      find.textContaining('Start my', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('recipeThumbnailUrl renders when provided', (t) async {
    useTallViewport(t);
    await t.pumpWidget(MaterialApp(
      home: PaywallScreen(
        trigger: PaywallTrigger.first_recipe,
        onboarding: OnboardingState(userGoal: 'pantryFirst'),
        // Use a file:// placeholder — Image.network errorBuilder returns
        // SizedBox.shrink on failure, so the *presence* of the key is the
        // assertion, not a successful load.
        recipeThumbnailUrl: 'https://example.test/thumb.jpg',
      ),
    ));
    await t.pump();
    expect(find.byKey(const Key('paywallRecipeThumbnail')), findsOneWidget);
  });

  testWidgets('feature cards include Recipe import + Scanning', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(onboarding: OnboardingState(userGoal: 'pantryFirst')));
    await t.pump();

    // New cards added Sprint 16.2 — these are real Pro features active in
    // the app and each surfaces a monetisation hook.
    expect(
      find.text('Recipe import', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Barcode & receipt scanning', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('footer shows Restore · Terms · Privacy links', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(onboarding: OnboardingState(userGoal: 'pantryFirst')));
    await t.pump();

    expect(find.byKey(const Key('paywallRestoreLink')), findsOneWidget);
    expect(find.byKey(const Key('paywallTermsLink')), findsOneWidget);
    expect(find.byKey(const Key('paywallPrivacyLink')), findsOneWidget);
  });

  testWidgets('tapping Terms shows a placeholder SnackBar', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(onboarding: OnboardingState(userGoal: 'pantryFirst')));
    await t.pump();

    final termsLink = find.byKey(const Key('paywallTermsLink'));
    await t.ensureVisible(termsLink);
    await t.pump();
    await t.tap(termsLink, warnIfMissed: false);
    await t.pump();

    expect(
      find.textContaining('Terms of Service — opens at'),
      findsOneWidget,
    );
  });

  testWidgets('recipeThumbnailUrl omitted when null', (t) async {
    useTallViewport(t);
    await t.pumpWidget(MaterialApp(
      home: PaywallScreen(
        trigger: PaywallTrigger.first_recipe,
        onboarding: OnboardingState(userGoal: 'pantryFirst'),
      ),
    ));
    await t.pump();
    expect(find.byKey(const Key('paywallRecipeThumbnail')), findsNothing);
  });
}
