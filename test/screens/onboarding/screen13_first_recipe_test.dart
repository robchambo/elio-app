import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/models/elio_models.dart';
import 'package:elio_app/screens/onboarding/screen13_first_recipe.dart';
import 'package:elio_app/widgets/elio/elio_hero_heading.dart';
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
    // 19 May 2026 — the complete-state heading is now split across an
    // ElioHeroHeading ("Made just for you.") + a smaller subtitle
    // ("Built from your kitchen.") so the visual hierarchy doesn't
    // collapse on the reveal. Pre-fix both lines lived in a single
    // bodySmall Text widget, which made the screen look "completely
    // different" once streaming finished.
    expect(find.text('Made just for you.'), findsOneWidget);
    expect(find.text('Built from your kitchen.'), findsOneWidget);

    await fake.closeAll();
  });

  testWidgets(
      'complete state keeps a hero heading at top (no hierarchy collapse)',
      (t) async {
    // Regression: pre-19 May 2026 the complete state replaced the
    // streaming-state ElioHeroHeading with a small bodySmall Text, so
    // the screen visually collapsed the moment the recipe arrived.
    // Assert the hero heading is present in the complete state too.
    useTallViewport(t);
    final controller = OnboardingController();
    final fake = FakeGeminiService();

    await t.pumpWidget(wrap(controller: controller, fake: fake));
    await t.pump();

    fake.emitComplete(buildFakeRecipe());
    await t.pump();
    await t.pump();

    final hero = t.widget<ElioHeroHeading>(find.byType(ElioHeroHeading));
    expect(hero.lines, ['Made just for you.']);

    await fake.closeAll();
  });

  testWidgets(
      'every ingredient gets a pantry tag pill (full 6-tag system)',
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

    // 4 ingredients → 4 pills. In-pantry items get fresh/thisWeek/useToday/
    // alwaysHave/usuallyHave; out-of-pantry items get needToBuy.
    expect(
      find.byType(ElioPantryTagPill, skipOffstage: false),
      findsNWidgets(4),
    );
    // Garlic + cherry tomatoes are not in pantry → needToBuy pills
    // (labelled "Shopping list").
    expect(find.text('Shopping list'), findsNWidgets(2));

    await fake.closeAll();
  });

  // ── Pantry-tag classifier — classifyIngredientTag pure function ─────────
  group('classifyIngredientTag', () {
    final now = DateTime(2026, 4, 23, 12);

    test('null (not in pantry) → needToBuy', () {
      expect(classifyIngredientTag(null, now), PantryTagKind.needToBuy);
    });

    test('alwaysHave tier → alwaysHave tag', () {
      final item = const InventoryItem(name: 'Olive oil', tier: 'alwaysHave');
      expect(classifyIngredientTag(item, now), PantryTagKind.alwaysHave);
    });

    test('almostAlwaysHave tier → usuallyHave tag', () {
      final item = const InventoryItem(name: 'Garlic', tier: 'almostAlwaysHave');
      expect(classifyIngredientTag(item, now), PantryTagKind.usuallyHave);
    });

    test('perishable + isRunningLow → useToday', () {
      final item = InventoryItem(
        name: 'Lemon',
        tier: 'perishable',
        isRunningLow: true,
        expiryDate: now.add(const Duration(days: 5)),
      );
      expect(classifyIngredientTag(item, now), PantryTagKind.useToday);
    });

    test('perishable + expiry ≤ now → useToday', () {
      final item = InventoryItem(
        name: 'Spinach',
        tier: 'perishable',
        expiryDate: now,
      );
      expect(classifyIngredientTag(item, now), PantryTagKind.useToday);
    });

    test('perishable + expiry within 3 days → thisWeek', () {
      final item = InventoryItem(
        name: 'Tomato',
        tier: 'perishable',
        expiryDate: now.add(const Duration(days: 2)),
      );
      expect(classifyIngredientTag(item, now), PantryTagKind.thisWeek);
    });

    test('perishable + expiry > 3 days → fresh', () {
      final item = InventoryItem(
        name: 'Carrot',
        tier: 'perishable',
        expiryDate: now.add(const Duration(days: 10)),
      );
      expect(classifyIngredientTag(item, now), PantryTagKind.fresh);
    });

    test('perishable with no expiry → fresh', () {
      final item = const InventoryItem(name: 'Carrot', tier: 'perishable');
      expect(classifyIngredientTag(item, now), PantryTagKind.fresh);
    });
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

    // Tooltip with explanatory copy wraps the disabled button.
    final tooltip = t.widget<Tooltip>(
      find.ancestor(
        of: find.widgetWithText(TextButton, 'Show me another'),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, 'Plenty to choose from later');

    await fake.closeAll();
  });

  testWidgets('meta row shows difficulty derived from cookingConfidence',
      (t) async {
    useTallViewport(t);
    final controller = OnboardingController()
      ..setCookingConfidence('challenge');
    final fake = FakeGeminiService();

    await t.pumpWidget(wrap(controller: controller, fake: fake));
    await t.pump();

    fake.emitComplete(buildFakeRecipe());
    await t.pump();
    await t.pump();

    // 'challenge' → 'Advanced'
    expect(find.textContaining('· Advanced'), findsOneWidget);

    await fake.closeAll();
  });

  testWidgets('error state uses new Elio-branded subhead', (t) async {
    useTallViewport(t);
    final controller = OnboardingController();
    final fake = FakeGeminiService();

    await t.pumpWidget(wrap(controller: controller, fake: fake));
    await t.pump();

    fake.emitError('boom');
    await t.pump();
    await t.pump();

    expect(
      find.text(
        "Couldn't reach Elio right now. Your pantry's saved — tap retry.",
      ),
      findsOneWidget,
    );

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

  testWidgets('Show me another forwards prior titles to Gemini for dedup',
      (t) async {
    // Sprint 16.2 on-device smoke test: "Show me another" often
    // returned the same (or near-identical) recipe because the
    // ephemeral call wasn't using the recent-titles block the rest
    // of the app relies on. The screen now accumulates every title
    // it shows and forwards the list so Gemini is told not to
    // repeat them.
    useTallViewport(t);
    final controller = OnboardingController();
    final fake = FakeGeminiService();

    await t.pumpWidget(wrap(controller: controller, fake: fake));
    await t.pump();

    // First call has nothing to dedup against.
    expect(fake.calls.first.recentTitles, isEmpty);

    fake.emitComplete(buildFakeRecipe(title: 'Lemon Garlic Traybake'));
    await t.pump();
    await t.pump();

    await t.tap(find.text('Show me another'));
    await t.pump();

    // Second call must include the first title so Gemini avoids it.
    expect(fake.calls, hasLength(2));
    expect(fake.calls[1].recentTitles, contains('Lemon Garlic Traybake'));

    // Second recipe returns — third call should exclude both.
    fake.emitComplete(buildFakeRecipe(title: 'Tomato Pasta'));
    await t.pump();
    await t.pump();
    await t.tap(find.text('Show me another'));
    await t.pump();

    expect(fake.calls, hasLength(3));
    expect(
      fake.calls[2].recentTitles,
      containsAll(<String>['Lemon Garlic Traybake', 'Tomato Pasta']),
    );

    await fake.closeAll();
  });

  testWidgets('complete state shows skip-into-app affordance that fires '
      'onContinue without committing firstRecipeId', (t) async {
    // Sprint 16.2: once a recipe has generated, the user should be
    // able to bail into the app without committing that recipe as
    // their firstRecipeId via "Cook this tonight".
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

    fake.emitComplete(buildFakeRecipe());
    await t.pump();
    await t.pump();

    final skipFinder = find.text('Skip — take me to the app');
    expect(skipFinder, findsOneWidget,
        reason: 'complete state must offer a neutral skip affordance');

    await t.tap(skipFinder);
    await t.pump();

    expect(continued, isTrue);
    expect(controller.state.firstRecipeId, isNull,
        reason: 'skip must NOT commit a firstRecipeId');

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
