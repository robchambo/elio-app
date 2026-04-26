/// Canonical recipe categories used for filtering.
///
/// US terminology — the labels shown to users AND the values Gemini
/// must emit in the recipe JSON. Keep this list in sync with the
/// schema instruction in `_buildPrompt` (gemini_service.dart) and the
/// chip row in `RecipesTabScreen`.
class RecipeCategories {
  static const List<String> all = [
    'Appetizer',
    'Entrée',
    'Side dish',
    'Dessert',
    'Breakfast',
    'Brunch',
    'Lunch',
    'Snack',
    'Soup',
    'Salad',
    'Drink',
  ];

  /// Returns true if [value] is one of the canonical categories.
  static bool isValid(String? value) => value != null && all.contains(value);
}
