import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/screens/onboarding/screen03_household.dart';
import 'package:elio_app/widgets/elio/elio_big_button.dart';
import 'package:elio_app/widgets/elio/elio_household_stepper.dart';
import 'package:elio_app/widgets/elio/elio_onboarding_option_card.dart';
import 'package:elio_app/widgets/elio/elio_onboarding_progress_bar.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  void useTallViewport(WidgetTester t) {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  testWidgets('renders all 5 household type cards', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen03Household(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    expect(find.byType(ElioOnboardingOptionCard), findsNWidgets(5));
    expect(find.text('Just me'), findsOneWidget);
    expect(find.text('Just the two of us'), findsOneWidget);
    expect(find.text('Family with kids'), findsOneWidget);
    expect(find.text('Flatmates or housemates'), findsOneWidget);
    expect(find.text('Something else'), findsOneWidget);
  });

  testWidgets('Continue disabled until a type is picked', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen03Household(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    final btn = t.widget<ElioBigButton>(find.byType(ElioBigButton));
    expect(btn.onTap, isNull);
  });

  testWidgets('stepper hidden until a type is selected', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen03Household(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    expect(find.byType(ElioHouseholdStepper), findsNothing);
  });

  testWidgets('tapping couple sets type and pre-fills count=2', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen03Household(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text('Just the two of us'));
    await t.pump();
    expect(c.state.householdType, 'couple');
    expect(c.state.householdCount, 2);
    expect(find.byType(ElioHouseholdStepper), findsOneWidget);
  });

  testWidgets('tapping each type pre-fills spec default count', (t) async {
    useTallViewport(t);
    final defaults = {
      'Just me': ('solo', 1),
      'Just the two of us': ('couple', 2),
      'Family with kids': ('family', 4),
      'Flatmates or housemates': ('flat', 3),
      'Something else': ('other', 2),
    };
    for (final entry in defaults.entries) {
      final c = OnboardingController();
      await t.pumpWidget(wrap(Screen03Household(
        controller: c,
        onContinue: () {},
        onBack: () {},
      )));
      await t.tap(find.text(entry.key));
      await t.pump();
      expect(c.state.householdType, entry.value.$1,
          reason: 'Tapping "${entry.key}" should set type ${entry.value.$1}');
      expect(c.state.householdCount, entry.value.$2,
          reason: 'Tapping "${entry.key}" should pre-fill count ${entry.value.$2}');
    }
  });

  testWidgets('changing stepper sets countManuallyEdited=true', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen03Household(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text('Family with kids'));
    await t.pump();
    expect(c.countManuallyEdited, isFalse);
    // Bump to 5.
    await t.tap(find.byIcon(Icons.add));
    await t.pump();
    expect(c.state.householdCount, 5);
    expect(c.countManuallyEdited, isTrue);
  });

  testWidgets(
      'changing type after manual edit preserves user count',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen03Household(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text('Family with kids'));
    await t.pump();
    expect(c.state.householdCount, 4);
    await t.tap(find.byIcon(Icons.add));
    await t.pump();
    expect(c.state.householdCount, 5);
    // Switch type to Flatmates — should NOT reset to 3.
    await t.tap(find.text('Flatmates or housemates'));
    await t.pump();
    expect(c.state.householdType, 'flat');
    expect(c.state.householdCount, 5);
  });

  testWidgets('Continue enabled once type picked, fires callback', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    var continued = false;
    await t.pumpWidget(wrap(Screen03Household(
      controller: c,
      onContinue: () => continued = true,
      onBack: () {},
    )));
    await t.tap(find.text('Just me'));
    await t.pump();
    final btn = t.widget<ElioBigButton>(find.byType(ElioBigButton));
    expect(btn.onTap, isNotNull);
    await t.tap(find.byType(ElioBigButton));
    await t.pump();
    expect(continued, isTrue);
  });

  testWidgets('back button fires onBack', (t) async {
    useTallViewport(t);
    var backed = false;
    await t.pumpWidget(wrap(Screen03Household(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () => backed = true,
    )));
    await t.tap(find.byType(BackButton));
    await t.pump();
    expect(backed, isTrue);
  });

  testWidgets('subhead defaults when userGoal is not household', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen03Household(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    expect(find.text("we'll size recipes and plan around your household."),
        findsOneWidget);
    expect(find.text("we'll make sure everyone's covered."), findsNothing);
  });

  testWidgets('subhead softens when userGoal == household', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    c.setUserGoal('household');
    await t.pumpWidget(wrap(Screen03Household(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    expect(find.text("we'll make sure everyone's covered."), findsOneWidget);
    expect(find.text("we'll size recipes and plan around your household."),
        findsNothing);
  });

  testWidgets('progress bar shows 3/15', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen03Household(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    final bar = t.widget<ElioOnboardingProgressBar>(
        find.byType(ElioOnboardingProgressBar));
    expect(bar.value, closeTo(3 / 15, 0.0001));
  });
}
