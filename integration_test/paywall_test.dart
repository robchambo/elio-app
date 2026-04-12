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
///   - All three trigger modes render with correct context headlines
///   - Trial hero copy is shown (dry mode = optimistic trial state)
///   - Feature list items are displayed
///   - Close/skip and subscribe buttons exist
///   - Fallback prices shown when RevenueCat is in dry mode
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
    String? triggerContext,
  }) {
    return MaterialApp(
      theme: elioTheme(),
      home: PaywallScreen(
        trigger: trigger,
        lockedFeatureName: lockedFeatureName,
        triggerContext: triggerContext,
      ),
    );
  }

  group('PaywallScreen — Onboarding trigger', () {
    testWidgets('Shows "Go Pro with Elio" context headline', (tester) async {
      await tester.pumpWidget(buildPaywall(trigger: PaywallTrigger.onboarding));
      await tester.pumpAndSettle();

      // Onboarding trigger has no resolved context, so falls through to default
      expect(
        find.text('Go Pro with Elio'),
        findsOneWidget,
        reason: 'Onboarding trigger should show "Go Pro with Elio" context headline',
      );
    });

    testWidgets('Shows trial hero copy', (tester) async {
      await tester.pumpWidget(buildPaywall(trigger: PaywallTrigger.onboarding));
      await tester.pumpAndSettle();

      // In dry mode (no RC key), _showTrialState is true, so hero shows trial copy
      expect(
        find.textContaining('Free Trial'),
        findsOneWidget,
        reason: 'Onboarding trigger should show trial hero (dry mode = optimistic)',
      );
    });

    testWidgets('Shows trial subtitle', (tester) async {
      await tester.pumpWidget(buildPaywall(trigger: PaywallTrigger.onboarding));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No charge for 7 days'),
        findsOneWidget,
        reason: 'Trial subtitle should mention no charge for 7 days',
      );
    });
  });

  group('PaywallScreen — Cap reached trigger', () {
    testWidgets('Shows "Unlock unlimited recipes" headline', (tester) async {
      await tester.pumpWidget(buildPaywall(
        trigger: PaywallTrigger.capReached,
        triggerContext: 'weekly_limit',
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Unlock unlimited recipes'),
        findsOneWidget,
        reason: 'Cap reached trigger should show "Unlock unlimited recipes"',
      );
    });
  });

  group('PaywallScreen — Locked feature trigger', () {
    testWidgets('Shows "Plan your whole week" for Meal Planner', (tester) async {
      await tester.pumpWidget(buildPaywall(
        trigger: PaywallTrigger.lockedFeature,
        lockedFeatureName: 'Meal Planner',
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Plan your whole week'),
        findsOneWidget,
        reason: 'Meal Planner locked feature should show "Plan your whole week"',
      );
    });

    testWidgets('Shows "Shop smarter with one list" for Shopping List', (tester) async {
      await tester.pumpWidget(buildPaywall(
        trigger: PaywallTrigger.lockedFeature,
        lockedFeatureName: 'Shopping List',
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Shop smarter with one list'),
        findsOneWidget,
        reason: 'Shopping List locked feature should show "Shop smarter with one list"',
      );
    });
  });

  group('PaywallScreen — Plan selection', () {
    testWidgets('Fallback prices shown in dry mode', (tester) async {
      await tester.pumpWidget(buildPaywall(trigger: PaywallTrigger.onboarding));
      await tester.pumpAndSettle();

      // In dry mode, _selectedPriceString falls back to hardcoded prices
      expect(
        find.textContaining('27.99'),
        findsOneWidget,
        reason: 'Annual fallback price should be displayed',
      );

      expect(
        find.textContaining('4.49'),
        findsOneWidget,
        reason: 'Monthly fallback price should be displayed',
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

      expect(
        find.byIcon(Icons.close),
        findsOneWidget,
        reason: 'Paywall should have a close button',
      );
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
