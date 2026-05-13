// test/utils/recipe_variation_test.dart
//
// Sprint 16.6 (Notion XX bug 3) — variation memory extractors.
//
// Recipe-screen-side bookkeeping pushes hero ingredient + cookware
// onto FIFOs of length 3 after every completion; those FIFOs feed the
// VARIATION prompt section. The extractors must be deterministic so
// the FIFOs stay stable across regenerates (and so the prompt doesn't
// randomly include or omit signals based on input order).

import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/models/recipe_models.dart';
import 'package:elio_app/utils/recipe_variation.dart';

RecipeIngredient _ing(String name, {bool fromInventory = false}) =>
    RecipeIngredient(
      name: name,
      quantity: '1',
      unit: '',
      fromInventory: fromInventory,
    );

GeneratedRecipe _recipe({
  required List<RecipeIngredient> ingredients,
  List<String> steps = const [],
  String title = 'Test',
}) =>
    GeneratedRecipe(
      title: title,
      description: '',
      prepTimeMinutes: 5,
      cookTimeMinutes: 20,
      servings: 2,
      ingredients: ingredients,
      steps: steps,
      substitutions: const [],
      dietaryTags: const [],
    );

void main() {
  group('RecipeVariation.heroIngredient', () {
    test('returns first non-staple ingredient, cleaned + lowercased', () {
      final r = _recipe(ingredients: [
        _ing('Salt'),
        _ing('Olive oil'),
        _ing('Chickpeas'),
        _ing('Tomato'),
      ]);
      expect(RecipeVariation.heroIngredient(r), 'chickpeas');
    });

    test('skips multi-word staples like "olive oil"', () {
      final r = _recipe(ingredients: [
        _ing('Olive oil'),
        _ing('Black pepper'),
        _ing('Chicken thighs'),
      ]);
      expect(RecipeVariation.heroIngredient(r), 'chicken thighs');
    });

    test('strips prep words via cleanForShopping', () {
      // The Notion bug 2 cleaner fix means "Diced onion" cleans to
      // "Onion" before lowercasing — that's what lands in the FIFO,
      // not "diced onion".
      final r = _recipe(ingredients: [
        _ing('Diced onion'),
      ]);
      expect(RecipeVariation.heroIngredient(r), 'onion');
    });

    test('garlic and onion remain eligible heroes', () {
      // Deliberately NOT in the staples set — French onion soup is
      // a real recipe with onion as the hero.
      final r = _recipe(ingredients: [_ing('Garlic'), _ing('Tomato')]);
      expect(RecipeVariation.heroIngredient(r), 'garlic');
    });

    test('returns null when only staples are listed', () {
      final r = _recipe(ingredients: [_ing('Salt'), _ing('Water')]);
      expect(RecipeVariation.heroIngredient(r), isNull);
    });

    test('returns null on empty ingredients', () {
      final r = _recipe(ingredients: const []);
      expect(RecipeVariation.heroIngredient(r), isNull);
    });
  });

  group('RecipeVariation.cookware', () {
    test('finds skillet in steps', () {
      final r = _recipe(
        ingredients: [_ing('Chickpeas')],
        steps: const ['Heat a large skillet over medium heat.', 'Stir.'],
      );
      expect(RecipeVariation.cookware(r), 'skillet');
    });

    test('multi-word wins over single-word substring — "dutch oven" not "oven"',
        () {
      final r = _recipe(
        ingredients: [_ing('Beef')],
        steps: const ['Sear the beef in a dutch oven.', 'Cover and bake.'],
      );
      expect(RecipeVariation.cookware(r), 'dutch oven');
    });

    test('"instant pot" wins over "pot"', () {
      final r = _recipe(
        ingredients: [_ing('Rice')],
        steps: const ['Add rice and water to the instant pot.'],
      );
      expect(RecipeVariation.cookware(r), 'instant pot');
    });

    test('word-boundary prevents "potato" matching "pot"', () {
      final r = _recipe(
        ingredients: [_ing('Potato')],
        steps: const ['Boil the potato until tender.', 'Mash and season.'],
      );
      // No real cookware noun in steps → null. "potato" must not
      // match "pot" because the trailing "ato" is a letter.
      expect(RecipeVariation.cookware(r), isNull);
    });

    test('word-boundary prevents "ovenproof" matching "oven"', () {
      final r = _recipe(
        ingredients: [_ing('Chicken')],
        steps: const ['Transfer to an ovenproof dish and roast.'],
      );
      // "ovenproof" contains "oven" but with a letter after — must
      // NOT match. ("dish" isn't in the cookware set either, so the
      // expected return is null.)
      expect(RecipeVariation.cookware(r), isNull);
    });

    test('returns null when no recognised cookware appears', () {
      final r = _recipe(
        ingredients: [_ing('Cucumber')],
        steps: const ['Slice cucumbers thinly.', 'Toss with vinegar.'],
      );
      expect(RecipeVariation.cookware(r), isNull);
    });

    test('returns null on empty steps', () {
      final r = _recipe(ingredients: [_ing('Anything')], steps: const []);
      expect(RecipeVariation.cookware(r), isNull);
    });
  });
}
