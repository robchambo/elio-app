import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/screens/onboarding/screen06_time.dart';
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

  testWidgets('renders 4 time-bucket cards', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen06Time(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    expect(find.byType(ElioOnboardingOptionCard), findsNWidgets(4));
    expect(find.text('15 minutes or less'), findsOneWidget);
    expect(find.text('About 30 minutes'), findsOneWidget);
    expect(find.text('Up to 45 minutes'), findsOneWidget);
    expect(find.text('An hour or more'), findsOneWidget);
  });

  testWidgets('Continue disabled until a time is picked', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen06Time(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    final btn = t.widget<ElioBigButton>(find.byType(ElioBigButton));
    expect(btn.onTap, isNull);
  });

  testWidgets('tapping "About 30 minutes" sets maxCookTime=30', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen06Time(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text('About 30 minutes'));
    await t.pump();
    expect(c.state.maxCookTime, 30);
  });

  testWidgets('single-select deselects previous on new tap', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen06Time(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text('About 30 minutes'));
    await t.pump();
    expect(c.state.maxCookTime, 30);
    await t.tap(find.text('An hour or more'));
    await t.pump();
    expect(c.state.maxCookTime, 75);
  });

  testWidgets('Continue enabled once time picked, fires callback', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    var continued = false;
    await t.pumpWidget(wrap(Screen06Time(
      controller: c,
      onContinue: () => continued = true,
      onBack: () {},
    )));
    await t.tap(find.text('15 minutes or less'));
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
    await t.pumpWidget(wrap(Screen06Time(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () => backed = true,
    )));
    await t.tap(find.byType(BackButton));
    await t.pump();
    expect(backed, isTrue);
  });

  testWidgets('progress bar shows 6/15', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen06Time(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    final bar = t.widget<ElioOnboardingProgressBar>(
        find.byType(ElioOnboardingProgressBar));
    expect(bar.value, closeTo(6 / 15, 0.0001));
  });
}
