import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/models/onboarding_state.dart';
import 'package:elio_app/screens/paywall/paywall_screen.dart';

// ─────────────────────────────────────────────
// Paywall first_recipe trigger — goal-keyed headline coverage.
//
// These tests render the screen shallowly (no RC packages) and assert
// which headline text appears. The paywall's `_showTrialState` getter
// is load-bearing (CLAUDE.md): empty packages → trial copy, so the
// "Start your 7-day free trial" CTA always shows. The hero headline
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
      ('pantryFirst', 'Keep cooking what you have.'),
      ('wasteReduction', 'Waste less, every week.'),
      ('decisionFatigue', 'No more 6pm panic.'),
      ('household', 'One plan for the whole house.'),
      ('takeawayEscape', 'Skip the takeaway.'),
      (null, 'Start your 7-day free trial.'),
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
          find.text(expected, skipOffstage: false),
          findsOneWidget,
          reason: 'Headline for goal "$goal" should be "$expected"',
        );
      });
    }
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
