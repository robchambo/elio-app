// test/models/recipe_ingredient_test.dart
//
// Sprint 16.6 — defensive sanitization of RecipeIngredient string fields.
//
// Two production failures motivated this guard:
//   1. Chickpea wall-of-text: ~1500 chars of model deliberation in `quantity`
//      ("Let's stick with 400g for consistency... Let's clarify...").
//   2. Red peppers prompt-echo + repetition collapse: `quantity` contained
//      "REQUIRED INVENTORY ITEM. MUST BE INCLUDED IN RECIPE..." followed by
//      "DO NOT REMOVE THIS." repeated dozens of times.
//
// Root cause: with `thinkingConfig: {thinkingBudget: 0}` Gemini has no
// scratch space; when the prompt invites deliberation the model deliberates
// *inside* the JSON value. Plus prompt-echo + sampling collapse.
//
// Fix: cap at 80 chars + ellipsis. Aggregated `ErrorService.log` lives on
// the GeneratedRecipe parse path so observability fires once per recipe,
// not once per ingredient — see gemini_service_truncation_test.dart for
// that integration. This file covers the field-level sanitizer.

import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/models/recipe_models.dart';

void main() {
  group('RecipeIngredient.fromJson sanitization', () {
    test('clean quantity passes through unchanged', () {
      final i = RecipeIngredient.fromJson({
        'name': 'Chickpeas',
        'quantity': '400g',
        'unit': '',
        'fromInventory': true,
      });
      expect(i.quantity, '400g');
      expect(i.name, 'Chickpeas');
      expect(i.fromInventory, isTrue);
    });

    test('whitespace is trimmed on all string fields', () {
      final i = RecipeIngredient.fromJson({
        'name': '  Chickpeas  ',
        'quantity': '  400g  ',
        'unit': ' g ',
      });
      expect(i.name, 'Chickpeas');
      expect(i.quantity, '400g');
      expect(i.unit, 'g');
    });

    test('quantity longer than cap is truncated with ellipsis', () {
      // Real chickpea wall-of-text shape from a captured production failure.
      const wall = '400 grams can rinsed and drained), 150 grams (dry, '
          'cooked to yield approx. 400 grams cooked weight or 1.5 cups '
          'cooked chickpeas if using dried chickpeas and cooking from scratch.';
      final i = RecipeIngredient.fromJson({
        'name': 'Chickpeas',
        'quantity': wall,
      });
      // 80-char cap + 1-char ellipsis = 81 max.
      expect(i.quantity.length, lessThanOrEqualTo(81));
      expect(i.quantity, endsWith('…'));
      expect(i.quantity, startsWith('400 grams can rinsed and drained'));
    });

    test('repetition-collapse pattern is truncated', () {
      // Mirrors the red-peppers failure where the field collapsed into a
      // repeat loop of "DO NOT REMOVE THIS." for dozens of iterations.
      final repeat = 'DO NOT REMOVE THIS. ' * 50;
      final i = RecipeIngredient.fromJson({
        'name': 'red peppers',
        'quantity': repeat,
      });
      expect(i.quantity.length, lessThanOrEqualTo(81));
      expect(i.quantity, endsWith('…'));
    });

    test('long name is truncated', () {
      final i = RecipeIngredient.fromJson({
        'name': 'A' * 200,
        'quantity': '1',
      });
      expect(i.name.length, lessThanOrEqualTo(81));
      expect(i.name, endsWith('…'));
    });

    test('long unit is truncated', () {
      final i = RecipeIngredient.fromJson({
        'name': 'Salt',
        'quantity': '1',
        'unit': 'g — Note: this is approximate, see notes below for details ' * 5,
      });
      expect(i.unit.length, lessThanOrEqualTo(81));
      expect(i.unit, endsWith('…'));
    });

    test('null and missing fields default to empty string', () {
      final i = RecipeIngredient.fromJson({'name': 'Salt'});
      expect(i.quantity, '');
      expect(i.unit, '');
      expect(i.fromInventory, isFalse);
    });

    test('non-string quantity is coerced via toString', () {
      // Gemini occasionally emits int/double for whole quantities.
      final i = RecipeIngredient.fromJson({
        'name': 'Eggs',
        'quantity': 4,
      });
      expect(i.quantity, '4');
    });

    test('truncated-field sink captures field names when provided', () {
      // The aggregated-logging path: GeneratedRecipe.fromJson passes a sink
      // through so it can fire ONE ErrorService.log per recipe instead of
      // per field. When no sink is passed, the sanitizer just caps silently.
      final sink = <String>[];
      RecipeIngredient.fromJson(
        {
          'name': 'A' * 200,
          'quantity': 'B' * 200,
          'unit': 'C' * 200,
        },
        truncatedSink: sink,
      );
      // Order is name, quantity, unit (the sanitizer call order in fromJson).
      expect(sink, containsAll(['name', 'quantity', 'unit']));
    });

    test('no truncation = empty sink', () {
      final sink = <String>[];
      RecipeIngredient.fromJson(
        {'name': 'Salt', 'quantity': '1', 'unit': 'tsp'},
        truncatedSink: sink,
      );
      expect(sink, isEmpty);
    });
  });
}
