// lib/utils/recipe_variation.dart
//
// Sprint 16.6 (Notion XX bug 3): post-generation extractors for the
// "variation memory" that drives the VARIATION prompt section.
//
// Rob's complaint on the 11 May test pass: chickpeas appear at high
// frequency, "skillet" overused, repetitive language ("hearty"). Root
// cause: the prompt's RECENTLY GENERATED block lists recent titles
// only — Gemini has to infer hero ingredient + cookware from those
// strings, which it does unreliably. Direct signal lands cleaner.
//
// Window of 3 recipes (per Rob): short enough that someone with
// chicken in the fridge isn't locked out of chicken because they
// didn't like one chicken recipe; long enough to catch the
// "chickpeas 3 times in a row" failure shape.

import '../models/recipe_models.dart';
import '../services/shopping_service.dart';

class RecipeVariation {
  RecipeVariation._();

  /// Ingredients to skip when picking a "hero". Tight list — these are
  /// the things in every recipe regardless of cuisine. Notable
  /// inclusions (garlic, onion, flour, sugar) are deliberately omitted
  /// because they CAN legitimately be the hero (garlic confit, French
  /// onion soup, sourdough, caramel) and the cost of false-negative
  /// (treating them as the hero when they're not) is lower than the
  /// cost of false-positive (skipping the actual hero).
  static const _staples = <String>{
    'salt', 'pepper', 'water', 'oil', 'olive oil', 'butter',
    'black pepper', 'sea salt', 'kosher salt', 'cooking oil',
    'vegetable oil',
  };

  /// Cookware nouns to recognise in step text. Sorted descending by
  /// length at runtime so multi-word matches ("dutch oven", "instant
  /// pot", "cast iron") win over substrings ("oven", "pot", "iron").
  static const _cookware = <String>{
    'instant pot',
    'pressure cooker',
    'slow cooker',
    'dutch oven',
    'cast iron',
    'baking sheet',
    'sheet pan',
    'roasting pan',
    'frying pan',
    'sauce pan',
    'saucepan',
    'air fryer',
    'crock pot',
    'crockpot',
    'griddle',
    'skillet',
    'grill',
    'wok',
    'oven',
    'pot',
    'pan',
  };

  /// The "hero" ingredient — first non-staple in the recipe's
  /// ingredient list, cleaned via [ShoppingService.cleanForShopping]
  /// (so prep words / size adjectives / parentheticals don't bleed
  /// into the FIFO) and lowercased.
  ///
  /// Returns null when every ingredient is a staple (rare — empty
  /// list or salt-water-only edge case).
  static String? heroIngredient(GeneratedRecipe recipe) {
    for (final ing in recipe.ingredients) {
      final cleaned =
          ShoppingService.cleanForShopping(ing.name).toLowerCase().trim();
      if (cleaned.isEmpty) continue;
      if (_staples.contains(cleaned)) continue;
      return cleaned;
    }
    return null;
  }

  /// First cookware noun mentioned across the recipe's step list.
  /// Multi-word entries ("dutch oven") match before single-word
  /// substrings ("oven") so the more specific signal wins.
  ///
  /// Returns null when no recognised cookware appears in the steps —
  /// in that case nothing gets pushed to the FIFO for this recipe.
  static String? cookware(GeneratedRecipe recipe) {
    if (recipe.steps.isEmpty) return null;
    final corpus = recipe.steps.join(' ').toLowerCase();
    final sorted = _cookware.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final c in sorted) {
      // Word-boundary-ish check: surrounding chars must be non-letter
      // so "potato" doesn't match "pot" and "ovenproof" doesn't match
      // "oven". Cheap implementation via space-padding the haystack.
      final padded = ' $corpus ';
      final pattern = RegExp(
        r'(?<![a-z])' + RegExp.escape(c) + r'(?![a-z])',
        caseSensitive: false,
      );
      if (pattern.hasMatch(padded)) return c;
    }
    return null;
  }
}
