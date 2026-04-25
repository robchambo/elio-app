// lib/models/recipe_preferences.dart
//
// Sprint 16 Phase 6 — lightweight value object returned by
// RecipePreferencesScreen when the user taps "Generate". A null value for
// any field means "Any" / no preference.
//
// Sprint 16.3 — added Saver / Leftover constraints. Home folds these into
// the RecipeGenerationRequest in [_buildRequest].

class RecipePreferences {
  final String? time;
  final String? style;
  final String? mood;

  /// Budget-friendly mode. When true, Gemini biases toward cheaper
  /// ingredients and shows estimated cost per serving.
  final bool isSaverMode;

  /// "Use up these leftovers" mode. Combined with [leftoverItems] in the
  /// request so Gemini centres the recipe on what's already cooked.
  final bool isLeftoverMode;

  /// Free-text leftover items the user wants to use up. Ignored unless
  /// [isLeftoverMode] is true.
  final List<String> leftoverItems;

  const RecipePreferences({
    this.time,
    this.style,
    this.mood,
    this.isSaverMode = false,
    this.isLeftoverMode = false,
    this.leftoverItems = const [],
  });

  const RecipePreferences.any()
    : time = null,
      style = null,
      mood = null,
      isSaverMode = false,
      isLeftoverMode = false,
      leftoverItems = const [];
}
