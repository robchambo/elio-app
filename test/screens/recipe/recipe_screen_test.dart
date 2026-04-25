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
}
