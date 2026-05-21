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

    test('truncated-field sink captures field names with :long classifier', () {
      // Sprint 16.6 deliberation-bleed plan, Phase 0.2 — sink entries
      // now carry a shape classifier suffix (`:long` for generic
      // verbose, `:bleed` for prompt-instruction echo). Plain wall-of-
      // A's don't contain any prompt markers, so they all classify as
      // `:long`.
      final sink = <String>[];
      RecipeIngredient.fromJson(
        {
          'name': 'A' * 200,
          'quantity': 'B' * 200,
          'unit': 'C' * 200,
        },
        truncatedSink: sink,
      );
      expect(sink,
          containsAll(['name:long', 'quantity:long', 'unit:long']));
    });

    test('sink classifies prompt-instruction echo as `:bleed`', () {
      // Real failure shape from the 13 May Rob screenshot: Gemini
      // paraphrased our prompt language ("(use this first)",
      // "(from inventory)", "(expires today)") into the quantity
      // value. The classifier flags these for Crashlytics so we can
      // dashboard the bleed-vs-long ratio after the Phase 2 prompt
      // restructure.
      final sink = <String>[];
      RecipeIngredient.fromJson(
        {
          'name': 'Chicken breast',
          'quantity':
              '0.5 lb (about 1 breast) (from inventory) (expires today) (use this first) ) (from in',
        },
        truncatedSink: sink,
      );
      expect(sink, contains('quantity:bleed'));
      expect(sink, isNot(contains('quantity:long')));
    });

    test('sink classifies MUST USE ALL paraphrase as `:bleed`', () {
      // 100+ chars so the field actually trips the 80-char cap and
      // hits the classifier branch.
      final sink = <String>[];
      RecipeIngredient.fromJson(
        {
          'name': 'Spinach',
          'quantity':
              '80 grams — REQUIRED, you MUST use ALL of this in the recipe, do not omit any of it, every gram counts',
        },
        truncatedSink: sink,
      );
      expect(sink, contains('quantity:bleed'));
    });

    test('long verbose quantity without prompt markers classifies as `:long`',
        () {
      // Regression guard: a verbose-but-innocent quantity shouldn't
      // be flagged as bleed. 100+ chars to trip the cap.
      final sink = <String>[];
      RecipeIngredient.fromJson(
        {
          'name': 'Pasta',
          'quantity':
              '500 grams uncooked, approximately two-thirds of a standard 750g pack, drained well after boiling',
        },
        truncatedSink: sink,
      );
      expect(sink, contains('quantity:long'));
      expect(sink, isNot(contains('quantity:bleed')));
    });

    test('non-Latin script (Tamil) deliberation classifies as `:bleed-script`',
        () {
      // Sprint 16.6 (Notion XX-2 #4): Rob's screenshot showed a
      // quantity that started in English then switched to Tamil
      // script mid-sentence. Classify as `:bleed-script` so we can
      // distinguish in Crashlytics from English instruction
      // paraphrase (`:bleed`).
      final sink = <String>[];
      RecipeIngredient.fromJson(
        {
          'name': 'White fish',
          'quantity':
              '300 grams செ ன்னல் சால்மன் மீன் வகையறாக்கள், பஸ்ஸா மீன், Tilapia மீன், மற்றும் Cod மீன்',
        },
        truncatedSink: sink,
      );
      expect(sink, contains('quantity:bleed-script'));
      expect(sink, isNot(contains('quantity:bleed')));
      expect(sink, isNot(contains('quantity:long')));
    });

    test('CJK script (Chinese) deliberation also classifies as `:bleed-script`',
        () {
      // Defensive — Gemini occasionally pivots to other Asian
      // scripts. The classifier covers anything outside extended
      // Latin / common punctuation, so any non-Latin foreign
      // content qualifies. >80 chars to trip the truncation cap.
      final cjkLong = '300 grams of fish 白色鱼类包括三文鱼巴沙鱼罗非鱼鳕鱼' * 3;
      final sink = <String>[];
      RecipeIngredient.fromJson(
        {'name': 'Fish', 'quantity': cjkLong},
        truncatedSink: sink,
      );
      expect(cjkLong.length, greaterThan(80),
          reason: 'Test setup: string must exceed cap to trip the classifier.');
      expect(sink, contains('quantity:bleed-script'));
    });

    test('Latin-1 supplement chars (£, €, é) do NOT trigger bleed-script',
        () {
      // Regression guard: a legitimate quantity using Latin-1
      // accented characters or currency symbols shouldn't be
      // mistakenly classified as foreign script.
      final sink = <String>[];
      RecipeIngredient.fromJson(
        {
          'name': 'Cheese',
          'quantity':
              '200g of brie de Meaux — approximately a quarter of a standard wheel, refrigerated until serving and then sliced',
        },
        truncatedSink: sink,
      );
      expect(sink, isNot(contains('quantity:bleed-script')));
      expect(sink, contains('quantity:long'));
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
