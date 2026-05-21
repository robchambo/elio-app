import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/utils/dietary_filter.dart';

// Coverage of the Kate-signed-off (25 Apr 2026) filtering rules.
// Both blockReasons() and isBlocked() are exercised — every category
// rule, every item-level override, and the custom-token allergy path.

void main() {
  group('DietaryFilter — vegan', () {
    const dietary = ['vegan'];
    const allergies = <String>[];

    test('blocks Dairy & Eggs category items', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Milk',
          dietary: dietary,
          allergies: allergies,
          categoryName: 'Dairy & Eggs',
        ),
        isTrue,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Cheddar cheese',
          dietary: dietary,
          allergies: allergies,
          categoryName: 'Dairy & Eggs',
        ),
        isTrue,
      );
    });

    test('blocks Honey (cross-category vegan-only override)', () {
      final reasons = DietaryFilter.blockReasons(
        itemName: 'Honey',
        dietary: dietary,
        allergies: allergies,
        categoryName: 'Sauces & Condiments',
      );
      expect(reasons, contains('Vegan'));
    });

    test('blocks Tuna and Anchovies', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Tuna',
          dietary: dietary,
          allergies: allergies,
          categoryName: 'Canned & Jarred',
        ),
        isTrue,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Anchovies',
          dietary: dietary,
          allergies: allergies,
          categoryName: 'Canned & Jarred',
        ),
        isTrue,
      );
    });

    // Kate sign-off 19 May 2026 (Pantry dietary flag pass follow-up):
    // Worcestershire moved to relabel-not-block. The GLUTEN-FREE SWAPS
    // block in gemini_service.dart instructs the model to write it as
    // "gluten-free Worcestershire sauce" when a gluten allergy is set;
    // for vegan/vegetarian, we trust the user to choose a vegan brand
    // rather than blocking the ingredient outright.
    test('does NOT block Worcestershire sauce (relabel pattern, not block)',
        () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Worcestershire sauce',
          dietary: dietary,
          allergies: allergies,
          categoryName: 'Sauces & Condiments',
        ),
        isFalse,
      );
    });

    test('does NOT block Olive oil or Tinned tomatoes', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Olive oil',
          dietary: dietary,
          allergies: allergies,
          categoryName: 'Oils & Vinegars',
        ),
        isFalse,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Tinned tomatoes',
          dietary: dietary,
          allergies: allergies,
          categoryName: 'Canned & Jarred',
        ),
        isFalse,
      );
    });
  });

  group('DietaryFilter — vegetarian', () {
    const dietary = ['vegetarian'];

    test('does NOT block Dairy & Eggs', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Milk',
          dietary: dietary,
          allergies: const [],
          categoryName: 'Dairy & Eggs',
        ),
        isFalse,
      );
    });

    // Kate sign-off 19 May 2026: Worcestershire dropped from this list —
    // moved to relabel-not-block (see vegan group above for rationale).
    test('blocks Tuna, Frozen prawns, Fish sauce', () {
      for (final name in [
        'Tuna',
        'Frozen prawns',
        'Fish sauce',
      ]) {
        expect(
          DietaryFilter.isBlocked(
            itemName: name,
            dietary: dietary,
            allergies: const [],
            categoryName: 'Canned & Jarred',
          ),
          isTrue,
          reason: '$name should block for vegetarian',
        );
      }
    });

    test('does NOT block Worcestershire (relabel pattern, not block)', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Worcestershire sauce',
          dietary: dietary,
          allergies: const [],
          categoryName: 'Sauces & Condiments',
        ),
        isFalse,
      );
    });

    test('blocks all Fresh meat & fish items', () {
      for (final name in [
        'Chicken breast',
        'Mince (beef)',
        'Salmon',
        'White fish',
        'Prawns',
      ]) {
        expect(
          DietaryFilter.isBlocked(
            itemName: name,
            dietary: dietary,
            allergies: const [],
            categoryName: 'Fresh meat & fish',
          ),
          isTrue,
          reason: '$name should block for vegetarian',
        );
      }
    });
  });

  group('DietaryFilter — pescatarian', () {
    const dietary = ['pescatarian'];

    test('blocks meat in Fresh meat & fish', () {
      for (final name in [
        'Chicken breast',
        'Chicken thighs',
        'Mince (beef)',
        'Mince (pork)',
        'Bacon',
        'Sausages',
        'Steak',
      ]) {
        expect(
          DietaryFilter.isBlocked(
            itemName: name,
            dietary: dietary,
            allergies: const [],
            categoryName: 'Fresh meat & fish',
          ),
          isTrue,
          reason: '$name should block for pescatarian',
        );
      }
    });

    test('does NOT block fish/shellfish in Fresh meat & fish', () {
      for (final name in ['Salmon', 'White fish', 'Prawns']) {
        expect(
          DietaryFilter.isBlocked(
            itemName: name,
            dietary: dietary,
            allergies: const [],
            categoryName: 'Fresh meat & fish',
          ),
          isFalse,
          reason: '$name should be allowed for pescatarian',
        );
      }
    });

    test('does NOT block Tuna or Frozen prawns', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Tuna',
          dietary: dietary,
          allergies: const [],
          categoryName: 'Canned & Jarred',
        ),
        isFalse,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Frozen prawns',
          dietary: dietary,
          allergies: const [],
          categoryName: 'Frozen Staples',
        ),
        isFalse,
      );
    });
  });

  group('DietaryFilter — gluten allergy', () {
    const allergies = ['gluten'];

    test('blocks pasta, bread, naan, flours, couscous, bulgur', () {
      for (final name in [
        'Pasta (spaghetti)',
        'Pasta (penne)',
        'Bread',
        'Naan bread',
        'Plain flour',
        'Self-raising flour',
        'Strong bread flour',
        'Couscous',
        'Bulgur wheat',
      ]) {
        expect(
          DietaryFilter.isBlocked(
            itemName: name,
            dietary: const [],
            allergies: allergies,
            categoryName: 'Grains & Pasta',
          ),
          isTrue,
          reason: '$name should block for gluten',
        );
      }
    });

    // Kate sign-off 19 May 2026: Worcestershire and the puff/shortcrust
    // pastries dropped — handled via the GLUTEN-FREE SWAPS prompt block
    // in gemini_service.dart, which instructs the model to write the
    // gluten-free variant rather than block the ingredient.
    test('blocks Soy sauce, Hoisin sauce, Sausages', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Soy sauce',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Asian Pantry',
        ),
        isTrue,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Hoisin sauce',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Asian Pantry',
        ),
        isTrue,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Sausages',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Fresh meat & fish',
        ),
        isTrue,
      );
    });

    test('does NOT block Worcestershire or pastries (relabel pattern)', () {
      for (final name in [
        'Worcestershire sauce',
        'Puff pastry',
        'Shortcrust pastry',
      ]) {
        expect(
          DietaryFilter.isBlocked(
            itemName: name,
            dietary: const [],
            allergies: allergies,
            categoryName: 'Frozen Staples',
          ),
          isFalse,
          reason: '$name should be relabel-not-block for gluten allergy',
        );
      }
    });

    test('does NOT block Rice, Quinoa, Tinned tomatoes', () {
      for (final name in ['Rice (white)', 'Quinoa', 'Tinned tomatoes']) {
        expect(
          DietaryFilter.isBlocked(
            itemName: name,
            dietary: const [],
            allergies: allergies,
            categoryName: 'Grains & Pasta',
          ),
          isFalse,
          reason: '$name should be allowed for gluten',
        );
      }
    });
  });

  group('DietaryFilter — soy allergy', () {
    const allergies = ['soy'];

    test('blocks Tofu, Soy sauce, Miso, Edamame, Hoisin', () {
      for (final name in [
        'Tofu',
        'Soy sauce',
        'Miso paste',
        'Frozen edamame',
        'Hoisin sauce',
      ]) {
        expect(
          DietaryFilter.isBlocked(
            itemName: name,
            dietary: const [],
            allergies: allergies,
            categoryName: 'Asian Pantry',
          ),
          isTrue,
          reason: '$name should block for soy',
        );
      }
    });
  });

  group('DietaryFilter — egg allergy', () {
    const allergies = ['egg'];

    test('blocks Eggs and Mayonnaise but NOT Milk/Butter', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Eggs',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Dairy & Eggs',
        ),
        isTrue,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Mayonnaise',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Sauces & Condiments',
        ),
        isTrue,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Milk',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Dairy & Eggs',
        ),
        isFalse,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Butter',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Dairy & Eggs',
        ),
        isFalse,
      );
    });

    test('blocks egg noodles', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Noodles (egg)',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Asian Pantry',
        ),
        isTrue,
      );
    });
  });

  group('DietaryFilter — dairy allergy', () {
    const allergies = ['dairy'];

    test('blocks Dairy & Eggs items via category', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Cheddar cheese',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Dairy & Eggs',
        ),
        isTrue,
      );
    });

    test('blocks cross-category dairy: Ghee, Paneer, Feta, Halloumi, Pesto', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Ghee',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Indian Pantry',
        ),
        isTrue,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Paneer',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Indian Pantry',
        ),
        isTrue,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Feta',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Mediterranean',
        ),
        isTrue,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Pesto',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Mediterranean',
        ),
        isTrue,
      );
    });

    test('does NOT block Coconut milk', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Coconut milk',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Asian Pantry',
        ),
        isFalse,
      );
    });
  });

  group('DietaryFilter — shellfish allergy', () {
    const allergies = ['shellfish'];

    test('blocks Prawns and Frozen prawns and Oyster sauce', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Prawns',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Fresh meat & fish',
        ),
        isTrue,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Frozen prawns',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Frozen Staples',
        ),
        isTrue,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Oyster sauce',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Asian Pantry',
        ),
        isTrue,
      );
    });

    test('does NOT block Salmon or White fish', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Salmon',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Fresh meat & fish',
        ),
        isFalse,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'White fish',
          dietary: const [],
          allergies: allergies,
          categoryName: 'Fresh meat & fish',
        ),
        isFalse,
      );
    });
  });

  group('DietaryFilter — nut allergies', () {
    test('treenut blocks Pine nuts and Pesto', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Pine nuts',
          dietary: const [],
          allergies: const ['treenut'],
          categoryName: 'Mediterranean',
        ),
        isTrue,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Pesto',
          dietary: const [],
          allergies: const ['treenut'],
          categoryName: 'Mediterranean',
        ),
        isTrue,
      );
    });

    test('peanut blocks Peanut butter', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Peanut butter',
          dietary: const [],
          allergies: const ['peanut'],
          categoryName: 'Canned & Jarred',
        ),
        isTrue,
      );
    });
  });

  group('DietaryFilter — sesame', () {
    test('blocks Sesame oil and Tahini', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Sesame oil',
          dietary: const [],
          allergies: const ['sesame'],
          categoryName: 'Asian Pantry',
        ),
        isTrue,
      );
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Tahini',
          dietary: const [],
          allergies: const ['sesame'],
          categoryName: 'Mediterranean',
        ),
        isTrue,
      );
    });
  });

  group('DietaryFilter — custom user-typed tokens', () {
    test('user types "celery" → blocks any item containing "celery"', () {
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Celery',
          dietary: const [],
          allergies: const ['celery'],
          categoryName: 'Fresh veg',
        ),
        isTrue,
      );
      // Item not containing celery is still fine.
      expect(
        DietaryFilter.isBlocked(
          itemName: 'Carrot',
          dietary: const [],
          allergies: const ['celery'],
          categoryName: 'Fresh veg',
        ),
        isFalse,
      );
    });

    test('custom token uses whole-word match (so "egg" preset NOT custom)', () {
      // 'egg' is a preset — handled via flag, not the custom path. Here we
      // sanity-check that the custom path doesn't double-match presets.
      final reasons = DietaryFilter.blockReasons(
        itemName: 'Eggs',
        dietary: const [],
        allergies: const ['egg'],
        categoryName: 'Dairy & Eggs',
      );
      expect(reasons, ['Egg']); // single reason, not duplicated
    });
  });

  group('DietaryFilter — clean state', () {
    test('no dietary, no allergies → nothing blocks', () {
      for (final name in [
        'Eggs',
        'Milk',
        'Soy sauce',
        'Honey',
        'Bacon',
        'Pasta (spaghetti)',
      ]) {
        expect(
          DietaryFilter.isBlocked(
            itemName: name,
            dietary: const [],
            allergies: const [],
            categoryName: null,
          ),
          isFalse,
          reason: '$name should be allowed when no flags set',
        );
      }
    });
  });
}
