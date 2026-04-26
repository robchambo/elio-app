import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elio_app/models/recipe_models.dart';
import 'package:elio_app/screens/recipe/recipe_screen.dart';
import 'package:elio_app/screens/recipes/recipes_tab_screen.dart';

SavedRecipe _fixtureSaved({bool bookmarked = false}) {
  return SavedRecipe(
    recipe: const GeneratedRecipe(
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
    ),
    savedAt: '2026-04-25T12:00:00.000',
    isBookmarked: bookmarked,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    final saved = _fixtureSaved(bookmarked: false);
    SharedPreferences.setMockInitialValues({
      'elio_recipe_history': jsonEncode([saved.toJson()]),
      // Skip FirestoreService.deduplicateInventory — it triggers
      // Crashlytics on its catch path, and Crashlytics isn't mocked in
      // widget tests. The flag short-circuits dedup at the top.
      'inventory_deduped_v1': true,
    });
  });

  testWidgets(
      'Tapping the bookmark icon toggles save without opening the recipe',
      (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RecipesTabScreen()),
    ));
    await tester.pumpAndSettle();

    // Find the unsaved bookmark icon (one in history row).
    final bookmark = find.byIcon(Icons.bookmark_outline_rounded).first;
    expect(bookmark, findsOneWidget);

    await tester.tap(bookmark);
    await tester.pumpAndSettle();

    // Recipe was NOT opened.
    expect(find.byType(RecipeScreen), findsNothing);

    // Icon flipped to filled.
    expect(find.byIcon(Icons.bookmark_rounded), findsWidgets);
  });
}
