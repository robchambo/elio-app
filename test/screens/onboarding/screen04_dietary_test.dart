import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/screens/onboarding/screen04_dietary.dart';
import 'package:elio_app/widgets/elio/elio_big_button.dart';
import 'package:elio_app/widgets/elio/elio_onboarding_option_card.dart';
import 'package:elio_app/widgets/elio/elio_onboarding_progress_bar.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  void useTallViewport(WidgetTester t) {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  // ─── Basic rendering ────────────────────────────────────────

  testWidgets('renders all 6 primary dietary cards', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    expect(find.byType(ElioOnboardingOptionCard), findsNWidgets(6));
    expect(find.text('Happy with anything.'), findsOneWidget);
    expect(find.text('Vegetarian'), findsOneWidget);
    expect(find.text('Vegan'), findsOneWidget);
    expect(find.text('Pescatarian'), findsOneWidget);
    expect(find.text('Halal'), findsOneWidget);
    expect(find.text('Kosher'), findsOneWidget);
  });

  testWidgets('progress bar shows 4/15', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    final bar = t.widget<ElioOnboardingProgressBar>(
        find.byType(ElioOnboardingProgressBar));
    expect(bar.value, closeTo(4 / 15, 0.0001));
  });

  // ─── Mutual-exclusion logic (primary selection) ──────────────

  testWidgets('vegan tapped while vegetarian selected — both stay selected',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text('Vegetarian'));
    await t.pump();
    await t.tap(find.text('Vegan'));
    await t.pump();
    expect(c.state.dietary, containsAll(['vegetarian', 'vegan']));
    expect(c.state.dietary.length, 2);
  });

  testWidgets(
      'pescatarian tapped while vegetarian selected — only pescatarian remains',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text('Vegetarian'));
    await t.pump();
    await t.tap(find.text('Pescatarian'));
    await t.pump();
    expect(c.state.dietary, ['pescatarian']);
  });

  testWidgets(
      'pescatarian tapped while vegan selected — only pescatarian remains',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text('Vegan'));
    await t.pump();
    await t.tap(find.text('Pescatarian'));
    await t.pump();
    expect(c.state.dietary, ['pescatarian']);
  });

  testWidgets('"No restrictions" clears all others when tapped', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text('Vegetarian'));
    await t.pump();
    await t.tap(find.text('Halal'));
    await t.pump();
    await t.tap(find.text('Happy with anything.'));
    await t.pump();
    expect(c.state.dietary, ['none']);
  });

  testWidgets('any other tapped while "No restrictions" selected clears none',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text('Happy with anything.'));
    await t.pump();
    expect(c.state.dietary, ['none']);
    await t.tap(find.text('Halal'));
    await t.pump();
    expect(c.state.dietary, ['halal']);
  });

  // ─── Household toggle visibility ────────────────────────────

  testWidgets('householdCount=1: no household toggle rendered', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    // default householdCount=1
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('householdCount=3 + toggle OFF: union section not rendered',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    c.setHouseholdCount(3);
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(
        find.text("Cover everyone's needs"),
        findsNothing);
  });

  testWidgets(
      'householdCount=3 + toggle ON: union section rendered and seeded',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    c.setHouseholdCount(3);
    c.setDietary(['vegetarian']);
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    // Flip the toggle on.
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(
        find.text("Cover everyone's needs"),
        findsOneWidget);
    expect(c.state.householdHasDifferingDiet, isTrue);
    expect(c.state.householdCombinedDietary, ['vegetarian']);
    // Total cards = 6 primary + 6 union.
    expect(find.byType(ElioOnboardingOptionCard), findsNWidgets(12));
  });

  testWidgets('toggle ON→OFF clears householdCombinedDietary', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    c.setHouseholdCount(3);
    c.setDietary(['vegan']);
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(c.state.householdCombinedDietary, ['vegan']);
    // Turn off again.
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(c.state.householdHasDifferingDiet, isFalse);
    expect(c.state.householdCombinedDietary, <String>[]);
    expect(
        find.text("Cover everyone's needs"),
        findsNothing);
  });

  // ─── Union exclusion logic ─────────────────────────────────

  testWidgets('union: tapping Pescatarian while Vegetarian selected replaces',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    c.setHouseholdCount(3);
    c.setDietary(['vegetarian']);
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    // Seeded: combined = [vegetarian]. Tap union Pescatarian (second instance).
    expect(c.state.householdCombinedDietary, ['vegetarian']);
    // Tap the second Pescatarian card (index 1 — the union copy).
    await t.tap(find.text('Pescatarian').last);
    await t.pumpAndSettle();
    expect(c.state.householdCombinedDietary, ['pescatarian']);
  });

  testWidgets('union: tapping "No restrictions" clears other union entries',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    c.setHouseholdCount(3);
    c.setDietary(['vegetarian']);
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    // Tap union "No restrictions" (last instance).
    await t.tap(find.text('Happy with anything.').last);
    await t.pumpAndSettle();
    expect(c.state.householdCombinedDietary, ['none']);
    // Primary user dietary untouched.
    expect(c.state.dietary, ['vegetarian']);
  });

  testWidgets('union: Vegan additive with Vegetarian', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    c.setHouseholdCount(3);
    c.setDietary(['vegetarian']);
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    // Seeded combined = [vegetarian]. Tap union Vegan.
    await t.tap(find.text('Vegan').last);
    await t.pumpAndSettle();
    expect(c.state.householdCombinedDietary,
        containsAll(['vegetarian', 'vegan']));
    expect(c.state.householdCombinedDietary.length, 2);
  });

  // ─── Continue enabled / disabled ───────────────────────────

  testWidgets(
      'Continue disabled when toggle ON and union empty; hint visible',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    c.setHouseholdCount(3);
    // No primary selection; seed will be empty.
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(c.state.householdCombinedDietary, <String>[]);
    final btn = t.widget<ElioBigButton>(find.byType(ElioBigButton));
    expect(btn.onTap, isNull);
    expect(
      find.text(
          "Pick at least one — or turn the toggle off if everyone's the same."),
      findsOneWidget,
    );
  });

  testWidgets(
      'Continue re-enabled when toggle ON and union has ≥1 selection',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    c.setHouseholdCount(3);
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    // Tap union Vegan.
    await t.tap(find.text('Vegan').last);
    await t.pumpAndSettle();
    final btn = t.widget<ElioBigButton>(find.byType(ElioBigButton));
    expect(btn.onTap, isNotNull);
  });

  testWidgets('back button fires onBack', (t) async {
    useTallViewport(t);
    var backed = false;
    await t.pumpWidget(wrap(Screen04Dietary(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () => backed = true,
    )));
    await t.tap(find.byType(BackButton));
    await t.pump();
    expect(backed, isTrue);
  });
}
