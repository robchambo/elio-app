import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/screens/onboarding/screen10_pantry_intro.dart';
import 'package:elio_app/widgets/elio/elio_big_button.dart';
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

  const defaultSubhead =
      "This is the bit that makes Elio different — every recipe starts from what you've got. Takes about a minute, in two quick steps.";
  const wasteSubhead =
      "Let's see what's in your kitchen — especially anything that needs using soon. Takes about a minute, in two quick steps.";
  const decisionSubhead =
      'Quick tour of your kitchen — then dinner gets a lot faster. Takes about a minute, in two quick steps.';
  const householdSubhead =
      "Let's stock the kitchen for everyone. Takes about a minute, in two quick steps.";
  const takeawaySubhead =
      "Let's see what's in — so you've always got an answer to \"what's for dinner?\". Takes about a minute, in two quick steps.";

  testWidgets('renders headline + CTA + progress bar', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen10PantryIntro(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    expect(find.text("Now, what's already"), findsOneWidget);
    expect(find.text('in your kitchen?'), findsOneWidget);
    expect(find.text("Let's have a look"), findsOneWidget);
    expect(find.byType(ElioOnboardingProgressBar), findsOneWidget);
  });

  testWidgets('CTA fires onContinue', (t) async {
    useTallViewport(t);
    var tapped = false;
    await t.pumpWidget(wrap(Screen10PantryIntro(
      controller: OnboardingController(),
      onContinue: () => tapped = true,
      onBack: () {},
    )));
    await t.pump();
    await t.tap(find.byType(ElioBigButton));
    await t.pump();
    expect(tapped, isTrue);
  });

  testWidgets('back button fires onBack', (t) async {
    useTallViewport(t);
    var backed = false;
    await t.pumpWidget(wrap(Screen10PantryIntro(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () => backed = true,
    )));
    await t.pump();
    await t.tap(find.byType(BackButton));
    await t.pump();
    expect(backed, isTrue);
  });

  testWidgets('subhead is default when userGoal is null', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen10PantryIntro(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    expect(find.text(defaultSubhead), findsOneWidget);
  });

  testWidgets('subhead for pantryFirst goal matches default', (t) async {
    useTallViewport(t);
    final c = OnboardingController()..setUserGoal('pantryFirst');
    await t.pumpWidget(wrap(Screen10PantryIntro(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    expect(find.text(defaultSubhead), findsOneWidget);
  });

  testWidgets('subhead for wasteReduction goal', (t) async {
    useTallViewport(t);
    final c = OnboardingController()..setUserGoal('wasteReduction');
    await t.pumpWidget(wrap(Screen10PantryIntro(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    expect(find.text(wasteSubhead), findsOneWidget);
  });

  testWidgets('subhead for decisionFatigue goal', (t) async {
    useTallViewport(t);
    final c = OnboardingController()..setUserGoal('decisionFatigue');
    await t.pumpWidget(wrap(Screen10PantryIntro(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    expect(find.text(decisionSubhead), findsOneWidget);
  });

  testWidgets('subhead for household goal', (t) async {
    useTallViewport(t);
    final c = OnboardingController()..setUserGoal('household');
    await t.pumpWidget(wrap(Screen10PantryIntro(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    expect(find.text(householdSubhead), findsOneWidget);
  });

  testWidgets('subhead for takeawayEscape goal', (t) async {
    useTallViewport(t);
    final c = OnboardingController()..setUserGoal('takeawayEscape');
    await t.pumpWidget(wrap(Screen10PantryIntro(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    expect(find.text(takeawaySubhead), findsOneWidget);
  });

  testWidgets('progress bar shows 10/15', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen10PantryIntro(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    final bar = t.widget<ElioOnboardingProgressBar>(
        find.byType(ElioOnboardingProgressBar));
    expect(bar.value, closeTo(10 / 15, 0.0001));
  });
}
