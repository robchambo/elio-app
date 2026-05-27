import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/screens/onboarding/screen09_region.dart';
import 'package:elio_app/widgets/elio/elio_big_button.dart';
import 'package:elio_app/widgets/elio/elio_onboarding_option_card.dart';
import 'package:elio_app/widgets/elio/elio_onboarding_progress_bar.dart';
import 'package:elio_app/widgets/elio/elio_segmented_toggle.dart';

void main() {
  Widget wrap(Widget child, {Locale locale = const Locale('en', 'GB')}) =>
      MaterialApp(
        locale: locale,
        supportedLocales: const [
          Locale('en', 'GB'),
          Locale('en', 'US'),
          Locale('en', 'CA'),
          Locale('en', 'AU'),
          Locale('en', 'FR'),
        ],
        home: child,
      );

  void useTallViewport(WidgetTester t) {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  testWidgets('renders 4 region cards + units toggle', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen09Region(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    expect(find.byType(ElioOnboardingOptionCard), findsNWidgets(4));
    expect(find.text('United Kingdom'), findsOneWidget);
    expect(find.text('United States'), findsOneWidget);
    expect(find.text('Canada'), findsOneWidget);
    expect(find.text('Australia'), findsOneWidget);
    expect(find.byType(ElioSegmentedToggle), findsOneWidget);
    expect(find.text('Metric'), findsOneWidget);
    expect(find.text('Imperial'), findsOneWidget);
  });

  testWidgets('pre-selects uk + metric when locale is GB', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(
      Screen09Region(controller: c, onContinue: () {}, onBack: () {}),
      locale: const Locale('en', 'GB'),
    ));
    await t.pump();
    expect(c.state.region, 'uk');
    expect(c.state.measurementUnits, 'metric');
  });

  testWidgets('pre-selects us + imperial when locale is US', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(
      Screen09Region(controller: c, onContinue: () {}, onBack: () {}),
      locale: const Locale('en', 'US'),
    ));
    await t.pump();
    expect(c.state.region, 'us');
    expect(c.state.measurementUnits, 'imperial');
  });

  testWidgets('pre-selects ca + metric when locale is CA', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(
      Screen09Region(controller: c, onContinue: () {}, onBack: () {}),
      locale: const Locale('en', 'CA'),
    ));
    await t.pump();
    expect(c.state.region, 'ca');
    expect(c.state.measurementUnits, 'metric');
  });

  testWidgets('pre-selects au + metric when locale is AU', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(
      Screen09Region(controller: c, onContinue: () {}, onBack: () {}),
      locale: const Locale('en', 'AU'),
    ));
    await t.pump();
    expect(c.state.region, 'au');
    expect(c.state.measurementUnits, 'metric');
  });

  testWidgets('falls through to us + imperial for unknown locale (FR)',
      (t) async {
    // Sprint 17 — 'other' option removed. Unknown locales now default
    // to 'us' (mirrors RegionUtils.region's locale-fallback), so the
    // measurement-units default also flips to imperial. Users in
    // long-tail locales can tap UK / CA / AU in one action.
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(
      Screen09Region(controller: c, onContinue: () {}, onBack: () {}),
      locale: const Locale('en', 'FR'),
    ));
    await t.pump();
    expect(c.state.region, 'us');
    expect(c.state.measurementUnits, 'imperial');
  });

  testWidgets('changing region auto-flips units when not overridden',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(
      Screen09Region(controller: c, onContinue: () {}, onBack: () {}),
      locale: const Locale('en', 'GB'),
    ));
    await t.pump();
    expect(c.state.region, 'uk');
    expect(c.state.measurementUnits, 'metric');
    // Switch to US → units should flip to imperial.
    await t.tap(find.text('United States'));
    await t.pump();
    expect(c.state.region, 'us');
    expect(c.state.measurementUnits, 'imperial');
    // Switch to Canada → units flip back to metric.
    await t.tap(find.text('Canada'));
    await t.pump();
    expect(c.state.region, 'ca');
    expect(c.state.measurementUnits, 'metric');
  });

  testWidgets(
      'manual units override sticks across region changes',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(
      Screen09Region(controller: c, onContinue: () {}, onBack: () {}),
      locale: const Locale('en', 'GB'),
    ));
    await t.pump();
    // uk + metric initially.
    expect(c.state.measurementUnits, 'metric');
    // Manually tap Imperial → override flag set.
    await t.tap(find.text('Imperial'));
    await t.pump();
    expect(c.state.measurementUnits, 'imperial');
    expect(c.unitsManuallyEdited, isTrue);
    // Now switch to US → units should STAY imperial (matches by coincidence).
    await t.tap(find.text('United States'));
    await t.pump();
    expect(c.state.measurementUnits, 'imperial');
    // And switch back to UK → units STAY imperial because user overrode.
    await t.tap(find.text('United Kingdom'));
    await t.pump();
    expect(c.state.region, 'uk');
    expect(c.state.measurementUnits, 'imperial');
  });

  testWidgets('Continue always enabled, fires callback', (t) async {
    useTallViewport(t);
    var continued = false;
    await t.pumpWidget(wrap(Screen09Region(
      controller: OnboardingController(),
      onContinue: () => continued = true,
      onBack: () {},
    )));
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
    await t.pumpWidget(wrap(Screen09Region(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () => backed = true,
    )));
    await t.pump();
    await t.tap(find.byType(BackButton));
    await t.pump();
    expect(backed, isTrue);
  });

  testWidgets('progress bar shows 9/15', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen09Region(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    final bar = t.widget<ElioOnboardingProgressBar>(
        find.byType(ElioOnboardingProgressBar));
    expect(bar.value, closeTo(9 / 15, 0.0001));
  });
}
