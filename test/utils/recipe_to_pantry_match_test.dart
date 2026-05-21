// test/utils/recipe_to_pantry_match_test.dart
//
// Sprint 16.6 (Notion XX bug 2): regression guard for the
// "recipe-import path adds items already in pantry" failure.
//
// The bug: RecipeScreen._isInPantry compared the RAW recipe ingredient
// name ("Diced onion", "Large eggs", "Chopped garlic, peeled") against
// the live pantry's normalised name set. Pantry entries are short
// product names ("Onion", "Eggs", "Garlic") so the raw-name compare
// never matched, the dedup branch never fired, and the "Add to
// shopping list" path piled items the user already had into the list.
//
// Fix: clean the recipe name via `ShoppingService.cleanForShopping`
// FIRST (strips prep words / size adjectives / parentheticals) and
// then normalise via `PantryUtils.normalise` (plurals + variant map).
// The result matches the normalised pantry entry.
//
// These tests pin the combined behaviour so a future refactor to
// either helper that breaks the chain fails CI.

import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/services/shopping_service.dart';
import 'package:elio_app/utils/pantry_utils.dart';

void main() {
  // Mirror of the chain in RecipeScreen._isInPantry. Apply to both
  // sides of the comparison so prep-word recipe names match clean
  // pantry names AND clean pantry names still match themselves.
  String pipeline(String name) =>
      PantryUtils.normalise(ShoppingService.cleanForShopping(name));

  group('recipe-name → pantry-key pipeline', () {
    test('"Diced onion" matches pantry "Onion"', () {
      expect(pipeline('Diced onion'), pipeline('Onion'));
    });

    test('"Large eggs" matches pantry "Eggs"', () {
      expect(pipeline('Large eggs'), pipeline('Eggs'));
    });

    test('"Chopped garlic" matches pantry "Garlic"', () {
      expect(pipeline('Chopped garlic'), pipeline('Garlic'));
    });

    test('"Ham, cut into cubes or thin strips" matches pantry "Ham"', () {
      expect(pipeline('Ham, cut into cubes or thin strips'), pipeline('Ham'));
    });

    test('"Shrimp (raw, peeled and deveined)" matches pantry "Shrimp"', () {
      expect(
        pipeline('Shrimp (raw, peeled and deveined)'),
        pipeline('Shrimp'),
      );
    });

    test('"Butter, melted" matches pantry "Butter"', () {
      expect(pipeline('Butter, melted'), pipeline('Butter'));
    });

    test('plurals + prep words combine — "Diced onions" matches "Onion"', () {
      expect(pipeline('Diced onions'), pipeline('Onion'));
    });

    test('already-clean pantry names are idempotent under the pipeline', () {
      // The pipeline must be a no-op on names the pantry stores
      // directly. If it transforms "Onion" into something other than
      // "Onion"-normalised, the live-pantry hash-set lookup would
      // silently miss.
      const pantryNames = [
        'Onion', 'Tomato', 'Garlic', 'Lemon', 'Eggs', 'Butter',
        'Olive oil', 'Milk', 'Chicken thighs', 'Chickpeas',
      ];
      for (final name in pantryNames) {
        // Compare clean-then-normalised against just-normalised.
        expect(pipeline(name), PantryUtils.normalise(name),
            reason: 'Pipeline must be a no-op on "$name" (pantry-style).');
      }
    });

    test('a recipe name with no pantry match doesnt accidentally match', () {
      // Defensive: weird recipe names shouldn't collide with random
      // pantry items just because the cleaner over-strips.
      expect(pipeline('Saffron threads'), isNot(pipeline('Onion')));
      expect(pipeline('Star anise'), isNot(pipeline('Eggs')));
    });
  });
}
