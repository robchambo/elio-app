import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/models/elio_models.dart';
import 'package:elio_app/screens/onboarding/screen13_first_recipe.dart';
import 'package:elio_app/widgets/elio/elio_pantry_tag_pill.dart';

import '../../fakes/fake_gemini_service.dart';

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
    required FakeGeminiService fake,
    VoidCallback? onContinue,
  }) =>
      MaterialApp(
        home: Screen13FirstRecipe(
          controller: controller,
          streamFn: fake.stream,
          onContinue: onContinue ?? () {},
        ),
      );

  // ── Hero cascade — pickHeroIngredient pure function ──────────────────────
  group('pickHeroIngredient cascade', () {
    final now = DateTime(2026, 4, 20, 12);

    test('today item beats thisWeek', () {
      final inventory = [
        InventoryItem(
          name: 'Spinach',
          tier: 'perishable',
          expiryDate: now.add(const Duration(days: 2)),
        ),
        InventoryItem(
          name: 'Lemon',
          tier: 'perishable',
          isRunningLow: true,
          expiryDate: now,
        ),
      ];
      expect(pickHeroIngredient(inventory, now)!.name, 'Lemon');
    });

    test('thisWeek beats fresh', () {
      final inventory = [
        InventoryItem(
          name: 'Potato',
          tier: 'perishable',
          expiryDate: now.add(const Duration(days: 10)),
        ),
        InventoryItem(
          name: 'Spinach',
          tier: 'perishable',
          expiryDate: now.add(const Duration(days: 2)),
        ),
      ];
      expect(pickHeroIngredient(inventory, now)!.name, 'Spinach');
    });

    test('fresh-meat beats fresh-veg', () {
      final inventory = [
        InventoryItem(
          name: 'Carrot',
          tier: 'perishable',
          category: 'Fresh veg',
          expiryDate: now.add(const Duration(days: 10)),
        ),
        InventoryItem(
          name: 'Chicken thighs',
          tier: 'perishable',
          category: 'Fresh meat & fish',
          expiryDate: now.add(const Duration(days: 10)),
        ),
      ];
      expect(pickHeroIngredient(inventory, now)!.name, 'Chicken thighs');
    });

    test('falls back to fresh-veg when no meat', () {
      final inventory = [
        InventoryItem(
          name: 'Carrot',
          tier: 'perishable',
          category: 'Fresh veg',
          expiryDate: now.add(const Duration(days: 10)),
        ),
      ];
      expect(pickHeroIngredient(inventory, now)!.name, 'Carrot');
    });

    test('empty inventory returns null', () {
      expect(pickHeroIngredient(const [], now), isNull);
    });
  });

  // ── Dietary plumbing — Option B ─────────────────────────────────────────
  group('Option B dietary plumbing', () {
    testWidgets(
        'toggle ON → fake receives householdCombinedDietary in effectiveDietary',
        (t) async {
      useTallViewport(t);
      final controller = OnboardingController()
        ..setDietary(['vegan'])
        ..setHouseholdCount(2)
        ..setHouseholdDiffering(true)
        ..setHouseholdCombinedDietary(['vegan', 'pescatarian']);
      final fake = FakeGeminiService();

      await t.pumpWidget(wrap(controller: controller, fake: fake));
      await t.pump();

      expect(fake.calls, hasLength(1));
      expect(fake.capturedDietary, ['vegan', 'pescatarian']);

      await fake.closeAll();
    });

    testWidgets('toggle OFF → fake receives user own dietary', (t) async {
      useTallViewport(t);
      final controller = OnboardingController()
        ..setDietary(['vegan'])
        ..setHouseholdCount(2)
        ..setHouseholdDiffering(false)
        ..setHouseholdCombinedDietary(['vegan', 'pescatarian']);
      final fake = FakeGeminiService();

      await t.pumpWidget(wrap(controller: controller, fake: fake));
      await t.pump();

      expect(fake.capturedDietary, ['vegan']);

      await fake.closeAll();
    });
  });

  // ── Streaming + complete states ─────────────────────────────────────────
  testWidgets('streaming state shows generating subhead', (t) async {
    useTallViewport(t);
    final controller = OnboardingController();
    final fake = FakeGeminiService();

    await t.pumpWidget(wrap(controller: controller, fake: fake));
    await t.pump();

    expect(find.text("Tonight's dinner, coming up…"), findsOneWidget);
    expect(find.textContaining('Working out what to cook'), findsOneWidget);

    await fake.closeAll();
  });

  testWidgets('complete state shows recipe card + CTAs', (t) async {
    useTallViewport(t);
    final controller = OnboardingController();
    final fake = FakeGeminiService();

    await t.pumpWidget(wrap(controller: controller, fake: fake));
    await t.pump();

    fake.emitComplete(buildFakeRecipe());
    await t.pump();
    await t.pump();

    expect(find.text('Lemon & Garlic Chicken Traybake'), findsOneWidget);
    expect(find.text('Cook this tonight'), findsOneWidget);
    expect(find.text('Show me another'), findsOneWidget);
    expect(
      find.text('Made just for you. Built from your kitchen.'),
      findsOneWidget,
    );

    await fake.closeAll();
  });

  testWidgets(
      'ElioPantryTagPill rendered for ingredients matching pantry (case-insensitive)',
      (t) async {
    useTallViewport(t);
    final controller = OnboardingController()
      ..setInventory([
        const InventoryItem(name: 'chicken thighs', tier: 'perishable'),
        const InventoryItem(name: 'LEMON', tier: 'perishable'),
      ]);
    final fake = FakeGeminiService();

    await t.pumpWidget(wrap(controller: controller, fake: fake));
    await t.pump();

    fake.emitComplete(buildFakeRecipe());
    await t.pump();
    await t.pump();

    // Chicken thighs (pantry) + Lemon (pantry) = 2 pills. Garlic + tomatoes
    // are not in pantry so they get no pill.
    expect(
      find.byType(ElioPantryTagPill, skipOffstage: false),
      findsNWidgets(2),
    );

    await fake.closeAll();
  });

  testWidgets('"Show me another" disabled at regenerateCount >= 3',
      (t) async {
    useTallViewport(t);
    final controller = OnboardingController();
    for (var i = 0; i < 3; i++) {
      controller.incrementRegenerateCount();
    }
    final fake = FakeGeminiService();

    await t.pumpWidget(wrap(controller: controller, fake: fake));
    await t.pump();

    fake.emitComplete(buildFakeRecipe());
    await t.pump();
    await t.pump();

    final btn = t.widget<TextButton>(
      find.widgetWithText(TextButton, 'Show me another'),
    );
    expect(btn.onPressed, isNull);

    await fake.closeAll();
  });

  testWidgets('"Cook this tonight" sets firstRecipeId and fires onContinue',
      (t) async {
    useTallViewport(t);
    final controller = OnboardingController();
    final fake = FakeGeminiService();
    var continued = false;

    await t.pumpWidget(wrap(
      controller: controller,
      fake: fake,
      onContinue: () => continued = true,
    ));
    await t.pump();

    fake.emitComplete(buildFakeRecipe(title: 'Test Recipe'));
    await t.pump();
    await t.pump();

    await t.tap(find.text('Cook this tonight'));
    await t.pump();

    expect(continued, isTrue);
    expect(controller.state.firstRecipeId, isNotNull);

    await fake.closeAll();
  });

  testWidgets('error state "Skip for now" advances without firstRecipeId',
      (t) async {
    useTallViewport(t);
    final controller = OnboardingController();
    final fake = FakeGeminiService();
    var continued = false;

    await t.pumpWidget(wrap(
      controller: controller,
      fake: fake,
      onContinue: () => continued = true,
    ));
    await t.pump();

    fake.emitError('Gemini went on a tea break');
    await t.pump();
    await t.pump();

    expect(find.text("Hmm, let's try that again."), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);

    await t.tap(find.text('Skip for now'));
    await t.pump();

    expect(continued, isTrue);
    expect(controller.state.firstRecipeId, isNull);

    await fake.closeAll();
  });

  testWidgets('regenerate re-fires stream and bumps count', (t) async {
    useTallViewport(t);
    final controller = OnboardingController();
    final fake = FakeGeminiService();

    await t.pumpWidget(wrap(controller: controller, fake: fake));
    await t.pump();

    fake.emitComplete(buildFakeRecipe());
    await t.pump();
    await t.pump();

    await t.tap(find.text('Show me another'));
    await t.pump();

    expect(fake.calls, hasLength(2));
    expect(controller.state.regenerateCount, 1);

    await fake.closeAll();
  });

  testWidgets('hero ingredient is passed to the fake', (t) async {
    useTallViewport(t);
    final now = DateTime.now();
    final controller = OnboardingController()
      ..setInventory([
        InventoryItem(
          name: 'Lemon',
          tier: 'perishable',
          expiryDate: now,
          isRunningLow: true,
        ),
      ]);
    final fake = FakeGeminiService();

    await t.pumpWidget(wrap(controller: controller, fake: fake));
    await t.pump();

    expect(fake.lastCall.heroIngredientName, 'Lemon');

    await fake.closeAll();
  });
}
