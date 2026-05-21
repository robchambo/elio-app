import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/screens/onboarding/screen14_paywall.dart';

import '../../fakes/fake_trial_starter.dart';

void main() {
  void useTallViewport(WidgetTester t) {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  Widget wrap({
    required OnboardingController controller,
    required FakeTrialStarter starter,
    VoidCallback? onBack,
    VoidCallback? onContinue,
  }) =>
      MaterialApp(
        home: Screen14Paywall(
          controller: controller,
          onBack: onBack ?? () {},
          onContinue: onContinue ?? () {},
          trialStarter: starter,
        ),
      );

  testWidgets('close (✕) fires onBack and leaves entitlement unchanged',
      (t) async {
    useTallViewport(t);
    final controller = OnboardingController();
    final starter = FakeTrialStarter();
    var backs = 0;
    await t.pumpWidget(wrap(
      controller: controller,
      starter: starter,
      onBack: () => backs++,
    ));
    await t.pump();

    await t.tap(find.byIcon(Icons.close));
    await t.pump();

    expect(backs, 1);
    expect(controller.state.entitlement, isNull);
    expect(starter.calls, 0);
  });

  testWidgets('Continue with Free sets entitlement="free" and fires onContinue',
      (t) async {
    useTallViewport(t);
    final controller = OnboardingController();
    final starter = FakeTrialStarter();
    var continues = 0;
    await t.pumpWidget(wrap(
      controller: controller,
      starter: starter,
      onContinue: () => continues++,
    ));
    await t.pump();

    final freeCta = find.text('Continue with Free', skipOffstage: false);
    await t.ensureVisible(freeCta);
    await t.pump();
    await t.tap(freeCta);
    await t.pump();

    expect(controller.state.entitlement, 'free');
    expect(continues, 1);
    expect(starter.calls, 0);
  });

  testWidgets(
      'Start trial (success) sets entitlement="pro" and fires onContinue',
      (t) async {
    useTallViewport(t);
    final controller = OnboardingController();
    final starter = FakeTrialStarter(simulatedSuccess: true);
    var continues = 0;
    await t.pumpWidget(wrap(
      controller: controller,
      starter: starter,
      onContinue: () => continues++,
    ));
    await t.pump();

    // The primary CTA label starts with "Start my" (trial copy renders
    // in dry-mode since packages are empty and _showTrialState → true).
    final cta = find.byKey(const Key('paywallPrimaryCta'));
    expect(cta, findsOneWidget);
    await t.ensureVisible(cta);
    await t.pump();
    await t.tap(cta, warnIfMissed: false);
    await t.pumpAndSettle();

    expect(starter.calls, 1);
    expect(controller.state.entitlement, 'pro');
    expect(continues, 1);
  });

  testWidgets(
      'Start trial (failure) leaves entitlement untouched and shows toast',
      (t) async {
    useTallViewport(t);
    final controller = OnboardingController();
    final starter = FakeTrialStarter(simulatedSuccess: false);
    var continues = 0;
    await t.pumpWidget(wrap(
      controller: controller,
      starter: starter,
      onContinue: () => continues++,
    ));
    await t.pump();

    final cta = find.byKey(const Key('paywallPrimaryCta'));
    await t.ensureVisible(cta);
    await t.pump();
    await t.tap(cta, warnIfMissed: false);
    await t.pump(); // kick off the future
    await t.pump(const Duration(milliseconds: 200));

    expect(starter.calls, 1);
    expect(controller.state.entitlement, isNull);
    expect(continues, 0);
    expect(
      find.textContaining("Couldn't start the trial", skipOffstage: false),
      findsOneWidget,
    );
  });
}
