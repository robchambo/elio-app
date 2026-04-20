import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/screens/onboarding/screen02_goal.dart';
import 'package:elio_app/widgets/elio/elio_big_button.dart';
import 'package:elio_app/widgets/elio/elio_onboarding_option_card.dart';
import 'package:elio_app/widgets/elio/elio_onboarding_progress_bar.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  /// All 5 option cards + heading + CTA exceed the default 800x600 surface.
  /// Tall viewport keeps every tap target on-stage without scroll gymnastics.
  void useTallViewport(WidgetTester t) {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  const labels = [
    "Cook with what I've got",
    'Waste less food',
    'Decide dinner faster',
    'Feed the whole household',
    'Stop ordering takeaway',
  ];

  testWidgets('renders all 5 option cards with spec labels', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen02Goal(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    expect(find.byType(ElioOnboardingOptionCard), findsNWidgets(5));
    for (final l in labels) {
      expect(find.text(l), findsOneWidget);
    }
  });

  testWidgets('Continue disabled until a goal is picked', (t) async {
    final c = OnboardingController();
    var continued = false;
    await t.pumpWidget(wrap(Screen02Goal(
      controller: c,
      onContinue: () => continued = true,
      onBack: () {},
    )));
    final btn = t.widget<ElioBigButton>(find.byType(ElioBigButton));
    expect(btn.onTap, isNull);
    await t.tap(find.byType(ElioBigButton));
    await t.pump();
    expect(continued, isFalse);
  });

  testWidgets(
      'tapping "Cook with what I\'ve got" sets userGoal=pantryFirst and enables CTA',
      (t) async {
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen02Goal(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text("Cook with what I've got"));
    await t.pump();
    expect(c.state.userGoal, 'pantryFirst');
    final btn = t.widget<ElioBigButton>(find.byType(ElioBigButton));
    expect(btn.onTap, isNotNull);
  });

  testWidgets('tapping different cards maintains single-select', (t) async {
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen02Goal(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text("Cook with what I've got"));
    await t.pump();
    expect(c.state.userGoal, 'pantryFirst');

    await t.tap(find.text('Waste less food'));
    await t.pump();
    expect(c.state.userGoal, 'wasteReduction');

    // Exactly one card should be selected.
    final cards = t
        .widgetList<ElioOnboardingOptionCard>(
            find.byType(ElioOnboardingOptionCard))
        .toList();
    final selected = cards.where((c) => c.selected).toList();
    expect(selected.length, 1);
    expect(selected.first.value, 'wasteReduction');
  });

  testWidgets('all 5 values map to correct enum keys', (t) async {
    useTallViewport(t);
    final expected = {
      "Cook with what I've got": 'pantryFirst',
      'Waste less food': 'wasteReduction',
      'Decide dinner faster': 'decisionFatigue',
      'Feed the whole household': 'household',
      'Stop ordering takeaway': 'takeawayEscape',
    };
    for (final entry in expected.entries) {
      final c = OnboardingController();
      await t.pumpWidget(wrap(Screen02Goal(
        controller: c,
        onContinue: () {},
        onBack: () {},
      )));
      await t.tap(find.text(entry.key));
      await t.pump();
      expect(c.state.userGoal, entry.value,
          reason: 'Tapping "${entry.key}" should set ${entry.value}');
    }
  });

  testWidgets('Continue fires onContinue when selection made', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    var continued = false;
    await t.pumpWidget(wrap(Screen02Goal(
      controller: c,
      onContinue: () => continued = true,
      onBack: () {},
    )));
    await t.tap(find.text('Decide dinner faster'));
    await t.pump();
    await t.tap(find.byType(ElioBigButton));
    await t.pump();
    expect(continued, isTrue);
  });

  testWidgets('back button present and fires onBack', (t) async {
    useTallViewport(t);
    var backed = false;
    await t.pumpWidget(wrap(Screen02Goal(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () => backed = true,
    )));
    expect(find.byType(BackButton), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pump();
    expect(backed, isTrue);
  });

  testWidgets('progress bar shows 2/15', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen02Goal(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    final bar = t.widget<ElioOnboardingProgressBar>(
        find.byType(ElioOnboardingProgressBar));
    expect(bar.value, closeTo(2 / 15, 0.0001));
  });
}
