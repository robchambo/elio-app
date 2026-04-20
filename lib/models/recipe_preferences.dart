// lib/models/recipe_preferences.dart
//
// Sprint 16 Phase 6 — lightweight value object returned by
// RecipePreferencesScreen when the user taps "Generate". A null value for
// any field means "Any" / no preference.

class RecipePreferences {
  final String? time;
  final String? style;
  final String? mood;

  const RecipePreferences({this.time, this.style, this.mood});

  const RecipePreferences.any() : time = null, style = null, mood = null;
}
