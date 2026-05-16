import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:elio_app/models/recipe_models.dart';
import 'package:elio_app/screens/recipe/recipe_screen.dart';
import 'package:elio_app/utils/pantry_utils.dart';
import 'package:elio_app/widgets/elio/elio_pantry_icon.dart';

GeneratedRecipe _fixtureRecipe() {
  return const GeneratedRecipe(
    title: 'Test Recipe',
    prepTimeMinutes: 5,
    cookTimeMinutes: 10,
    servings: 2,
    description: 'A simple test recipe.',
    ingredients: [
      RecipeIngredient(
        name: 'Tomato',
        quantity: '2',
        unit: '',
        fromInventory: true,
      ),
    ],
    steps: ['Chop tomato.', 'Serve.'],
    substitutions: [],
    dietaryTags: [],
  );
}

RecipeGenerationRequest _fixtureRequest() {
  return const RecipeGenerationRequest(
    perishables: [],
    alwaysHave: [],
    almostAlwaysHave: [],
    dietaryRequirements: [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('Suggest a side dish button hides after generation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: RecipeScreen(
        recipe: _fixtureRecipe(),
        originalRequest: _fixtureRequest(),
      ),
    ));
    await tester.pump();

    expect(find.text('Suggest a side dish'), findsOneWidget);

    final dynamic state = tester.state<State>(find.byType(RecipeScreen));
    state.debugMarkSideDishGenerated();
    await tester.pump();

    expect(find.text('Suggest a side dish'), findsNothing);
  });

  testWidgets(
      'Pantry icon is green for ingredients matching inventory and red otherwise',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const recipe = GeneratedRecipe(
      title: 'Pantry Match Test',
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      servings: 2,
      description: 'Tests pantry membership rendering.',
      ingredients: [
        // fromInventory=false intentionally — proves we're checking the
        // live inventory set, not the Gemini-supplied perishables flag.
        RecipeIngredient(
          name: 'Olive oil',
          quantity: '2',
          unit: 'tbsp',
          fromInventory: false,
        ),
        RecipeIngredient(
          name: 'Salt',
          quantity: '1',
          unit: 'tsp',
          fromInventory: false,
        ),
        RecipeIngredient(
          name: 'Saffron',
          quantity: '1',
          unit: 'pinch',
          fromInventory: false,
        ),
      ],
      steps: ['Mix.', 'Serve.'],
      substitutions: [],
      dietaryTags: [],
    );

    await tester.pumpWidget(MaterialApp(
      home: RecipeScreen(
        recipe: recipe,
        originalRequest: _fixtureRequest(),
      ),
    ));
    await tester.pump();

    final dynamic state = tester.state<State>(find.byType(RecipeScreen));
    state.normalizedInventoryNames = <String>{
      PantryUtils.normalise('Olive oil'),
      PantryUtils.normalise('Salt'),
    };
    state.setState(() {});
    await tester.pump();

    final icons = tester
        .widgetList<ElioPantryIcon>(find.byType(ElioPantryIcon))
        .toList();
    final inStockCount = icons.where((w) => w.inStock).length;
    final missingCount = icons.where((w) => !w.inStock).length;
    expect(inStockCount, 2, reason: 'Olive oil and Salt should be in pantry');
    expect(missingCount, 1, reason: 'Saffron should be missing');
  });

  // Regression: Sprint 16.3 added a free-text `userRequest` ("craving")
  // on RecipePreferencesScreen, threaded to RecipeGenerationRequest and
  // emitted by Gemini's _buildPrompt as a high-priority soft preference.
  // The "Generate another" regen builder on RecipeScreen was dropping
  // it (along with mealType + the variation FIFOs), so successive
  // recipes silently ignored the craving. This guards the carry-forward.
  testWidgets(
    "'Generate another' regen carries forward userRequest + variation fields",
    (tester) async {
      const base = RecipeGenerationRequest(
        perishables: ['Chicken'],
        alwaysHave: ['Salt'],
        almostAlwaysHave: ['Pasta'],
        dietaryRequirements: ['Vegetarian'],
        timePreference: 'Quick',
        stylePreference: 'Comfort',
        moodPreference: 'Cosy',
        mealType: 'dinner',
        servings: 4,
        excludedIngredients: ['Mushroom'],
        recentTitles: ['Old Recipe'],
        recentHeroIngredients: ['chicken', 'pasta'],
        recentCookware: ['skillet'],
        runningLowItems: ['Oil'],
        isLeftoverMode: false,
        leftoverItems: [],
        likedRecipes: ['Carbonara'],
        dislikedRecipes: ['Liver'],
        appliances: ['Oven'],
        isSaverMode: true,
        perishableInventoryDescriptions: ['chicken (expires today)'],
        userRequest: 'something with mushrooms',
        customAllergens: ['Peanut'],
      );

      await tester.pumpWidget(MaterialApp(
        home: RecipeScreen(
          recipe: _fixtureRecipe(),
          originalRequest: base,
        ),
      ));
      await tester.pump();

      final dynamic state = tester.state<State>(find.byType(RecipeScreen));
      final RecipeGenerationRequest regen =
          state.debugBuildRegenRequest(base);

      // The reported bug — userRequest MUST survive regen.
      expect(regen.userRequest, 'something with mushrooms',
          reason: 'Sprint 16.3 craving was being dropped on Generate Another');

      // Same shape-of-bug fields fixed alongside userRequest.
      expect(regen.mealType, 'dinner');
      expect(regen.recentHeroIngredients, ['chicken', 'pasta']);
      expect(regen.recentCookware, ['skillet']);

      // Spot-check the rest of the carry-forward + the documented merges.
      expect(regen.perishables, ['Chicken']);
      expect(regen.alwaysHave, ['Salt']);
      expect(regen.almostAlwaysHave, ['Pasta']);
      expect(regen.dietaryRequirements, ['Vegetarian']);
      expect(regen.timePreference, 'Quick');
      expect(regen.stylePreference, 'Comfort');
      expect(regen.moodPreference, 'Cosy');
      expect(regen.servings, 4);
      expect(regen.runningLowItems, ['Oil']);
      expect(regen.isLeftoverMode, isFalse);
      expect(regen.likedRecipes, ['Carbonara']);
      expect(regen.dislikedRecipes, ['Liver']);
      expect(regen.appliances, ['Oven']);
      expect(regen.isSaverMode, isTrue);
      expect(regen.perishableInventoryDescriptions,
          ['chicken (expires today)']);
      expect(regen.customAllergens, ['Peanut']);

      // recentTitles MUST gain the current recipe title (dedup signal).
      expect(regen.recentTitles, ['Old Recipe', 'Test Recipe']);

      // excludedIngredients merges base + session exclusions (empty here).
      expect(regen.excludedIngredients, ['Mushroom']);
    },
  );
}
