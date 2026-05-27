// lib/models/recipe_preferences.dart
//
// Sprint 16 Phase 6 — lightweight value object returned by
// RecipePreferencesScreen when the user taps "Generate". A null value for
// any field means "Any" / no preference.
//
// Sprint 16.3 — added Saver / Leftover constraints. Home folds these into
// the RecipeGenerationRequest in [_buildRequest].
//
// Sprint 16.3 (later) — added [userRequest] free-text craving and
// [useUpItems] to carry selections from the new Perishables Picker.
// useUpItems supersedes the old leftover-mode chip editor; when populated,
// these items become REQUIRED ingredients in the Gemini prompt.
//
// Sprint 17 (26 May 2026) — added [ignorePantry] for the new
// Pantry / Go Wild segmented toggle on the "set the mood" screen. When
// true, Home's _buildRequest zeroes out every pantry-sourced field
// (perishables, alwaysHave, almostAlwaysHave, runningLowItems,
// perishableInventoryDescriptions) so Gemini has no inventory context to
// honour and is free to suggest anything compatible with the user's
// dietary/style/mood/time prefs. Use case: "I'm going shopping anyway —
// suggest a nice meal." Saver Mode + Bulk Cook are orthogonal (still
// honoured if also on).

class RecipePreferences {
  final String? time;
  final String? style;
  final String? mood;

  /// Sprint 16.6 row 5b — meal-type hard constraint. One of 'Breakfast',
  /// 'Lunch', 'Dinner', or null. Null = no preference (user didn't pick a
  /// chip — most generations). When set, becomes a hard constraint on the
  /// recipe shape in the prompt. Selecting a chip while another is already
  /// selected replaces it (single-select, mutually exclusive).
  final String? mealType;

  /// Budget-friendly mode. When true, Gemini biases toward cheaper
  /// ingredients and shows estimated cost per serving.
  final bool isSaverMode;

  /// "Use up these leftovers" mode. Combined with [leftoverItems] in the
  /// request so Gemini centres the recipe on what's already cooked.
  final bool isLeftoverMode;

  /// Free-text leftover items the user wants to use up. Ignored unless
  /// [isLeftoverMode] is true.
  final List<String> leftoverItems;

  /// Free-text craving from the prefs screen ("soup", "pizza"). Wired
  /// through to RecipeGenerationRequest.userRequest.
  final String? userRequest;

  /// Items the user picked in the Perishables Picker — perishable inventory
  /// items they want to use up plus any custom additions. These become
  /// REQUIRED ingredients in the recipe (mapped onto request.perishables).
  final List<String> useUpItems;

  /// Sprint 17 — "Go Wild" mode. When true the prefs screen tells Home to
  /// drop every pantry-sourced field from the recipe request, so Gemini
  /// generates anything compatible with the user's dietary/style/mood/time
  /// prefs (and the free-text craving, if any) regardless of what's
  /// actually at home. Default false (the existing pantry-aware behaviour
  /// is the canonical recipe-generation path).
  final bool ignorePantry;

  const RecipePreferences({
    this.time,
    this.style,
    this.mood,
    this.mealType,
    this.isSaverMode = false,
    this.isLeftoverMode = false,
    this.leftoverItems = const [],
    this.userRequest,
    this.useUpItems = const [],
    this.ignorePantry = false,
  });

  const RecipePreferences.any()
    : time = null,
      style = null,
      mood = null,
      mealType = null,
      isSaverMode = false,
      isLeftoverMode = false,
      leftoverItems = const [],
      userRequest = null,
      useUpItems = const [],
      ignorePantry = false;
}
