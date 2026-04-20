import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/screens/onboarding/screen08_appliances.dart';
import 'package:elio_app/widgets/elio/elio_appliance_tile.dart';
import 'package:elio_app/widgets/elio/elio_big_button.dart';
import 'package:elio_app/widgets/elio/elio_onboarding_progress_bar.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  void useTallViewport(WidgetTester t) {
    t.view.physicalSize = const Size(800, 2000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  testWidgets('renders all 11 appliance tiles', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen08Appliances(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    // GridView builds lazily; use skipOffstage:false to count all children.
    for (final label in [
      'Oven',
      'Hob / stove',
      'Microwave',
      'Air fryer',
      'Slow cooker',
      'Pressure cooker',
      'Blender',
      'Food processor',
      'Stand mixer',
      'Rice cooker',
      'BBQ / grill',
    ]) {
      expect(find.text(label, skipOffstage: false), findsOneWidget,
          reason: 'Missing label: $label');
    }
    expect(find.byType(ElioApplianceTile, skipOffstage: false),
        findsNWidgets(11));
  });

  testWidgets('pre-selects oven, hob, microwave on first render',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen08Appliances(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    // Post-frame callback applies defaults.
    await t.pump();
    expect(c.state.appliances, containsAll(['oven', 'hob', 'microwave']));
    expect(c.state.appliances.length, 3);
  });

  testWidgets('tap toggles presence in state.appliances', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen08Appliances(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump(); // apply defaults
    // Add air fryer.
    await t.tap(find.text('Air fryer'));
    await t.pump();
    expect(c.state.appliances.contains('airfryer'), isTrue);
    // Un-tick oven (was pre-selected).
    await t.tap(find.text('Oven'));
    await t.pump();
    expect(c.state.appliances.contains('oven'), isFalse);
  });

  testWidgets('Continue always enabled, fires callback', (t) async {
    useTallViewport(t);
    var continued = false;
    await t.pumpWidget(wrap(Screen08Appliances(
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

  testWidgets('Continue enabled even when all unticked', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen08Appliances(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    // Untick all three defaults.
    await t.tap(find.text('Oven'));
    await t.pump();
    await t.tap(find.text('Hob / stove'));
    await t.pump();
    await t.tap(find.text('Microwave'));
    await t.pump();
    expect(c.state.appliances, isEmpty);
    final btn = t.widget<ElioBigButton>(find.byType(ElioBigButton));
    expect(btn.onTap, isNotNull);
  });

  testWidgets('back button fires onBack', (t) async {
    useTallViewport(t);
    var backed = false;
    await t.pumpWidget(wrap(Screen08Appliances(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () => backed = true,
    )));
    await t.pump();
    await t.tap(find.byType(BackButton));
    await t.pump();
    expect(backed, isTrue);
  });

  testWidgets('progress bar shows 8/15', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen08Appliances(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    final bar = t.widget<ElioOnboardingProgressBar>(
        find.byType(ElioOnboardingProgressBar));
    expect(bar.value, closeTo(8 / 15, 0.0001));
  });
}
