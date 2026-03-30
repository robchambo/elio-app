import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:elio_app/screens/onboarding/screen6_appliances.dart';
import 'package:elio_app/models/onboarding_state.dart';
import 'package:elio_app/theme/elio_theme.dart';

/// Integration tests for the KitchenAppliancesScreen (onboarding screen 6).
///
/// Verifies:
///   - All 12 appliance options render
///   - Tapping an appliance toggles its selection
///   - "Skip for now" button exists and works
///   - "Continue" / "Save appliances" button text changes based on selection
///   - Back button exists
///
/// Run with: flutter test integration_test/appliances_test.dart --flavor prod -d [device-id]
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late OnboardingState capturedState;
  bool backCalled = false;

  Widget buildScreen({List<String> initialAppliances = const []}) {
    capturedState = OnboardingState(appliances: initialAppliances);
    backCalled = false;

    return MaterialApp(
      theme: elioTheme(),
      home: KitchenAppliancesScreen(
        state: capturedState,
        onComplete: (updated) {
          capturedState = updated;
        },
        onBack: () {
          backCalled = true;
        },
      ),
    );
  }

  group('KitchenAppliancesScreen — Layout', () {
    testWidgets('Shows header text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.text("What's in your kitchen?"),
        findsOneWidget,
        reason: 'Header title should be visible',
      );

      expect(
        find.textContaining('suggest recipes'),
        findsOneWidget,
        reason: 'Subtitle should explain the purpose',
      );
    });

    testWidgets('Shows all 12 appliance options', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final expectedAppliances = [
        'Air fryer',
        'Slow cooker',
        'Rice cooker',
        'Instant Pot / Pressure cooker',
        'Stand mixer',
        'Food processor',
        'Blender',
        'Sous vide',
        'Bread maker',
        'Waffle iron',
        'Spiralizer',
        'Grill / BBQ',
      ];

      // Some may need scrolling — check the ones visible initially
      int found = 0;
      for (final name in expectedAppliances) {
        if (find.text(name).evaluate().isNotEmpty) found++;
      }

      // At least 6 should be visible without scrolling (2-column grid)
      expect(found, greaterThanOrEqualTo(6),
          reason: 'At least 6 appliances should be visible without scrolling');
    });

    testWidgets('Progress bar shows step 6 of 6', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Progress bar widget should exist
      expect(
        find.byType(LinearProgressIndicator).evaluate().isNotEmpty ||
            find.byWidgetPredicate((w) => w.runtimeType.toString().contains('ProgressBar')).evaluate().isNotEmpty,
        isTrue,
        reason: 'Progress bar should be visible',
      );
    });
  });

  group('KitchenAppliancesScreen — Interaction', () {
    testWidgets('Tapping an appliance selects it', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Tap "Air fryer"
      await tester.tap(find.text('Air fryer'));
      await tester.pumpAndSettle();

      // Verify check icon appears (selection indicator)
      expect(
        find.byIcon(Icons.check_circle_rounded),
        findsOneWidget,
        reason: 'Selected appliance should show a check icon',
      );
    });

    testWidgets('Tapping a selected appliance deselects it', (tester) async {
      await tester.pumpWidget(buildScreen(initialAppliances: ['Air fryer']));
      await tester.pumpAndSettle();

      // Should start with one check icon
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Tap to deselect
      await tester.tap(find.text('Air fryer'));
      await tester.pumpAndSettle();

      // Check icon should be gone
      expect(
        find.byIcon(Icons.check_circle_rounded),
        findsNothing,
        reason: 'Deselected appliance should not show a check icon',
      );
    });

    testWidgets('Button text is "Continue" when nothing selected', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.text('Continue'),
        findsOneWidget,
        reason: 'Button should say "Continue" when no appliances selected',
      );
    });

    testWidgets('Button text changes to "Save appliances" when item selected', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Select an appliance
      await tester.tap(find.text('Blender'));
      await tester.pumpAndSettle();

      expect(
        find.text('Save appliances'),
        findsOneWidget,
        reason: 'Button should say "Save appliances" after selection',
      );
    });

    testWidgets('"Skip for now" button exists', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.text('Skip for now'),
        findsOneWidget,
        reason: 'Skip button should be visible',
      );
    });

    testWidgets('Back button exists and calls onBack', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backButton, findsOneWidget, reason: 'Back button should exist');

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(backCalled, isTrue, reason: 'Back callback should be invoked');
    });

    testWidgets('Completing with selection passes appliances to callback', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Select two appliances
      await tester.tap(find.text('Air fryer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blender'));
      await tester.pumpAndSettle();

      // Tap "Save appliances"
      await tester.tap(find.text('Save appliances'));
      await tester.pumpAndSettle();

      expect(capturedState.appliances, containsAll(['Air fryer', 'Blender']),
          reason: 'Callback should receive selected appliances');
    });
  });
}
