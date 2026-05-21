// lib/utils/pantry_staples.dart
//
// Universal staples — items every kitchen has and that we always assume
// recipes can use without asking. Used to:
//   1. Filter shopping-list output (existing — ShoppingService).
//   2. Exclude from the Pantry Builder grid (Sprint 15.9).
//
// Sourced from `ShoppingService._stapleWords` + `_genericOilsExact`,
// extracted here so both services consume the same set.
//
// IMPORTANT: keep this list conservative. Adding ingredients risks hiding
// items some users genuinely want to track. Specific flavour oils
// (sesame, olive, chilli, truffle, …) are deliberately NOT staples —
// they are recipe-defining.

class PantryStaples {
  PantryStaples._();

  /// Whole-word matches: "salt" in "sea salt" but NOT "salted butter".
  static const _stapleWords = <String>{
    'water',
    'salt',
    'pepper',
    'sugar',
  };

  /// Exact matches only (so "sesame oil" is NOT a staple).
  static const _genericOilsExact = <String>{
    'oil',
    'cooking oil',
    'vegetable oil',
    'sunflower oil',
    'canola oil',
    'rapeseed oil',
    'neutral oil',
    'generic oil',
  };

  /// Returns true if [name] is a universal staple. Input is
  /// case-insensitive and trim-tolerant.
  static bool isStaple(String name) {
    final normalised = name.trim().toLowerCase();
    if (_genericOilsExact.contains(normalised)) return true;
    return _stapleWords.any((term) => _containsWord(normalised, term));
  }

  /// True when [word] appears as a whole word in [text].
  /// Treats space as the only word separator.
  static bool _containsWord(String text, String word) {
    if (text == word) return true;
    return text.startsWith('$word ') ||
        text.endsWith(' $word') ||
        text.contains(' $word ');
  }

  /// Inline-note copy shown when a user types a staple as a custom item.
  /// e.g. PantryStaples.assumedNote('Salt') → "Salt is always assumed — no need to add it"
  static String assumedNote(String displayName) =>
      '$displayName is always assumed — no need to add it';
}
