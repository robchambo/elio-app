import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:elio_app/models/recipe_models.dart';
import 'package:elio_app/screens/recipe/recipe_screen.dart';

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
}
