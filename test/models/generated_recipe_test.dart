// Sprint 16.1 — `GeneratedRecipe.copyWith` was missing a `dietaryTags`
// override. We now use it in `GeminiService.generateRecipeStream` to
// stamp the request's dietary constraints onto the recipe so the
// recipe-screen pill is an honest reflection of what the recipe was
// constrained under (rather than depending on whether Gemini chose to
// echo `dietaryTags` in its JSON response).

import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/models/recipe_models.dart';

GeneratedRecipe _bareRecipe({
  List<String> dietaryTags = const [],
}) {
  return GeneratedRecipe(
    title: 'Pad thai',
    prepTimeMinutes: 10,
    cookTimeMinutes: 15,
    servings: 2,
    description: 'A noodle dish.',
    ingredients: const [],
    steps: const [],
    substitutions: const [],
    dietaryTags: dietaryTags,
  );
}

void main() {
  group('GeneratedRecipe.copyWith dietaryTags', () {
    test('overrides dietaryTags when provided', () {
      final r = _bareRecipe(dietaryTags: const []);
      final copy = r.copyWith(dietaryTags: const ['Vegetarian']);
      expect(copy.dietaryTags, ['Vegetarian']);
    });

    test('preserves dietaryTags when not provided', () {
      final r = _bareRecipe(dietaryTags: const ['Vegan']);
      final copy = r.copyWith();
      expect(copy.dietaryTags, ['Vegan']);
    });

    test('preserves all other fields (title/desc/steps) untouched', () {
      final r = _bareRecipe(dietaryTags: const ['Vegan']);
      final copy = r.copyWith(dietaryTags: const ['Vegetarian']);
      expect(copy.title, 'Pad thai');
      expect(copy.description, 'A noodle dish.');
      expect(copy.servings, 2);
      expect(copy.prepTimeMinutes, 10);
      expect(copy.cookTimeMinutes, 15);
    });
  });
}
