import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/screens/onboarding/screen05_allergies.dart';
import 'package:elio_app/widgets/elio/elio_chip.dart';
import 'package:elio_app/widgets/elio/elio_chip_text_input.dart';
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

  testWidgets('renders all 9 preset allergy chips + Other', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen05Allergies(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    for (final label in [
      'Peanuts',
      'Tree nuts',
      'Milk / dairy',
      'Eggs',
      'Fish',
      'Shellfish',
      'Soy',
      'Wheat / gluten',
      'Sesame',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('+ Other'), findsOneWidget);
  });

  testWidgets('tapping a preset chip adds to state.allergies', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen05Allergies(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text('Peanuts'));
    await t.pump();
    expect(c.state.allergies, contains('peanut'));
    // Tapping again deselects.
    await t.tap(find.text('Peanuts'));
    await t.pump();
    expect(c.state.allergies, isEmpty);
  });

  testWidgets('tapping Other reveals chip text input', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen05Allergies(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    // Initially there is ONE chip input (for dislikes). Tapping Other
    // reveals a second one for custom allergies.
    expect(find.byType(ElioChipTextInput), findsOneWidget);
    await t.tap(find.text('+ Other'));
    await t.pumpAndSettle();
    expect(find.byType(ElioChipTextInput), findsNWidgets(2));
  });

  testWidgets('custom allergy token commits to state.allergies', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen05Allergies(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.tap(find.text('+ Other'));
    await t.pumpAndSettle();
    final allergyField = find.byType(TextField).first;
    await t.enterText(allergyField, 'mustard');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(c.state.allergies, contains('mustard'));
  });

  testWidgets('dislikes input writes to state.dislikes', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen05Allergies(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    // Dislikes input is always visible — there's exactly one field until
    // Other is tapped.
    final field = find.byType(TextField).first;
    await t.enterText(field, 'mushrooms');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(c.state.dislikes, contains('mushrooms'));
    expect(c.state.allergies, isEmpty);
  });

  testWidgets('skip link persists [] to both and advances', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    c.setAllergies(['peanut']);
    c.setDislikes(['olives']);
    var continued = false;
    await t.pumpWidget(wrap(Screen05Allergies(
      controller: c,
      onContinue: () => continued = true,
      onBack: () {},
    )));
    await t.tap(find.text('Skip — no allergies or dislikes'));
    await t.pump();
    expect(c.state.allergies, isEmpty);
    expect(c.state.dislikes, isEmpty);
    expect(continued, isTrue);
  });

  testWidgets('progress bar shows 5/15', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen05Allergies(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    final bar = t.widget<ElioOnboardingProgressBar>(
        find.byType(ElioOnboardingProgressBar));
    expect(bar.value, closeTo(5 / 15, 0.0001));
  });

  testWidgets('chip widget renders and reflects selected state', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen05Allergies(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    // 9 preset chips + "Other" chip = 10 ElioChip instances.
    expect(find.byType(ElioChip), findsNWidgets(10));
    await t.tap(find.text('Shellfish'));
    await t.pump();
    final selectedChips = t
        .widgetList<ElioChip>(find.byType(ElioChip))
        .where((ch) => ch.selected)
        .toList();
    expect(selectedChips.length, 1);
    expect(selectedChips.first.label, 'Shellfish');
  });

  testWidgets('back button fires onBack', (t) async {
    useTallViewport(t);
    var backed = false;
    await t.pumpWidget(wrap(Screen05Allergies(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () => backed = true,
    )));
    await t.tap(find.byType(BackButton));
    await t.pump();
    expect(backed, isTrue);
  });

  testWidgets('Continue fires onContinue', (t) async {
    useTallViewport(t);
    var continued = false;
    await t.pumpWidget(wrap(Screen05Allergies(
      controller: OnboardingController(),
      onContinue: () => continued = true,
      onBack: () {},
    )));
    await t.tap(find.text('Continue'));
    await t.pump();
    expect(continued, isTrue);
  });
}
