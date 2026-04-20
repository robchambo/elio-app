import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/screens/onboarding/screen07_confidence.dart';
import 'package:elio_app/widgets/elio/elio_big_button.dart';
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

  testWidgets('renders 3 confidence cards', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen07Confidence(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    expect(find.byType(ElioOnboardingOptionCard), findsNWidgets(3));
    expect(find.text('Keep it simple'), findsOneWidget);
    expect(find.text('A bit of both'), findsOneWidget);
    expect(find.text('Challenge me'), findsOneWidget);
  });

  testWidgets('Continue disabled until a level is picked', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen07Confidence(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    final btn = t.widget<ElioBigButton>(find.byType(ElioBigButton));
    expect(btn.onTap, isNull);
  });

  testWidgets('tapping sets cookingConfidence and enables CTA', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    var continued = false;
    await t.pumpWidget(wrap(Screen07Confidence(
      controller: c,
      onContinue: () => continued = true,
      onBack: () {},
    )));
    await t.tap(find.text('A bit of both'));
    await t.pump();
    expect(c.state.cookingConfidence, 'mixed');
    await t.tap(find.byType(ElioBigButton));
    await t.pump();
    expect(continued, isTrue);
  });

  testWidgets('single-select deselects previous on new tap', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen07Confidence(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text('Keep it simple'));
    await t.pump();
    expect(c.state.cookingConfidence, 'easy');
    await t.tap(find.text('Challenge me'));
    await t.pump();
    expect(c.state.cookingConfidence, 'challenge');
  });

  testWidgets('default subhead when maxCookTime != 15', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    c.setMaxCookTime(30);
    await t.pumpWidget(wrap(Screen07Confidence(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    expect(
        find.text('Tells us how adventurous to get with techniques.'),
        findsOneWidget);
    expect(find.text("We'll lean easy — no fiddly bits."), findsNothing);
  });

  testWidgets('softened subhead when maxCookTime == 15', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    c.setMaxCookTime(15);
    await t.pumpWidget(wrap(Screen07Confidence(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    expect(find.text("We'll lean easy — no fiddly bits."), findsOneWidget);
    expect(
        find.text('Tells us how adventurous to get with techniques.'),
        findsNothing);
  });

  testWidgets('back button fires onBack', (t) async {
    useTallViewport(t);
    var backed = false;
    await t.pumpWidget(wrap(Screen07Confidence(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () => backed = true,
    )));
    await t.tap(find.byType(BackButton));
    await t.pump();
    expect(backed, isTrue);
  });

  testWidgets('progress bar shows 7/15', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen07Confidence(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    final bar = t.widget<ElioOnboardingProgressBar>(
        find.byType(ElioOnboardingProgressBar));
    expect(bar.value, closeTo(7 / 15, 0.0001));
  });
}
