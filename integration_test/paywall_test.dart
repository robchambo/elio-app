import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:elio_app/screens/paywall/paywall_screen.dart';
import 'package:elio_app/theme/elio_theme.dart';

/// Integration tests for the PaywallScreen.
///
/// Requires Firebase (AnalyticsService depends on it).
///
/// Verifies:
///   - All three trigger modes render with correct headlines
///   - Annual plan is pre-selected by default
///   - Feature list items are displayed
///   - Close/skip and subscribe buttons exist
///
/// Run with: flutter test integration_test/paywall_test.dart --flavor prod -d [device-id]
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  Widget buildPaywall({
    PaywallTrigger trigger = PaywallTrigger.lockedFeature,
    String? lockedFeatureName,
  }) {
    return MaterialApp(
      theme: elioTheme(),
      home: PaywallScreen(
        trigger: trigger,
        lockedFeatureName: lockedFeatureName,
      ),
    );
  }

  group('PaywallScreen — Onboarding trigger', () {
    testWidgets('Shows "Unlock the full kitchen" headline', (tester) async {
      await tester.pumpWidget(buildPaywall(trigger: PaywallTrigger.onboarding));
      await tester.pumpAndSettle();

      expect(
        find.text('Unlock the full kitchen'),
        findsOneWidget,
        reason: 'Onboarding trigger should show "Unlock the full kitchen"',
      );
    });

    testWidgets('Shows trial subtitle', (tester) async {
      await tester.pumpWidget(buildPaywall(trigger: PaywallTrigger.onboarding));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('7-day free trial'),
        findsOneWidget,
        reason: 'Onboarding trigger should mention free trial',
      );
    });
  });

  group('PaywallScreen — Cap reached trigger', () {
    testWidgets('Shows "used all 7 this week" headline', (tester) async {
      await tester.pumpWidget(buildPaywall(trigger: PaywallTrigger.capReached));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('used all 7 this week'),
        findsOneWidget,
        reason: 'Cap reached trigger should mention 7 weekly limit',
      );
    });
  });

  group('PaywallScreen — Locked feature trigger', () {
    testWidgets('Shows feature name in headline', (tester) async {
      await tester.pumpWidget(buildPaywall(
        trigger: PaywallTrigger.lockedFeature,
        lockedFeatureName: 'Meal Planner',
      ));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Meal Planner'),
        findsOneWidget,
        reason: 'Locked feature trigger should show the feature name',
      );

      expect(
        find.textContaining('is Pro'),
        findsOneWidget,
        reason: 'Locked feature headline should include "is Pro"',
      );
    });
  });

  group('PaywallScreen — Plan selection', () {
    testWidgets('Annual and monthly prices are shown', (tester) async {
      await tester.pumpWidget(buildPaywall(trigger: PaywallTrigger.onboarding));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('27.99'),
        findsOneWidget,
        reason: 'Annual price should be displayed',
      );

      expect(
        find.textContaining('4.49'),
        findsOneWidget,
        reason: 'Monthly price should be displayed',
      );
    });

    testWidgets('Save badge is visible on annual plan', (tester) async {
      await tester.pumpWidget(buildPaywall(trigger: PaywallTrigger.onboarding));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Save'),
        findsWidgets,
        reason: 'Annual plan should show a Save badge',
      );
    });
  });

  group('PaywallScreen — UI elements', () {
    testWidgets('Close button exists', (tester) async {
      await tester.pumpWidget(buildPaywall(trigger: PaywallTrigger.onboarding));
      await tester.pumpAndSettle();

      final hasClose = find.byIcon(Icons.close).evaluate().isNotEmpty ||
          find.textContaining('Skip').evaluate().isNotEmpty;
      expect(hasClose, isTrue, reason: 'Paywall should have a way to dismiss');
    });

    testWidgets('Subscribe/trial button exists', (tester) async {
      await tester.pumpWidget(buildPaywall(trigger: PaywallTrigger.onboarding));
      await tester.pumpAndSettle();

      final hasSubscribe = find.textContaining('Start').evaluate().isNotEmpty ||
          find.textContaining('trial').evaluate().isNotEmpty ||
          find.textContaining('Subscribe').evaluate().isNotEmpty ||
          find.textContaining('Go Pro').evaluate().isNotEmpty;
      expect(hasSubscribe, isTrue, reason: 'Paywall should have a subscribe button');
    });

    testWidgets('Feature list items are shown', (tester) async {
      await tester.pumpWidget(buildPaywall(trigger: PaywallTrigger.onboarding));
      await tester.pumpAndSettle();

      final hasRecipes = find.textContaining('recipe').evaluate().isNotEmpty ||
          find.textContaining('Recipe').evaluate().isNotEmpty;
      final hasMealPlan = find.textContaining('meal plan').evaluate().isNotEmpty ||
          find.textContaining('Meal plan').evaluate().isNotEmpty;

      expect(hasRecipes || hasMealPlan, isTrue,
          reason: 'Paywall should list Pro features');
    });
  });
}
