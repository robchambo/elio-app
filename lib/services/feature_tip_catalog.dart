// lib/services/feature_tip_catalog.dart
//
// Sprint 16.8 row 7 — one-time educational tips for hidden / Pro features.
//
// Pure-Dart registry of every tip the FeatureTipService can fire. Adding a
// new tip means: append an entry to [all], wire a `markFeatureUsed` call
// into the feature's tap handler, and call `FeatureTipService.shouldShow`
// from the screen where the tip should land.
//
// The `requiredFeatureEvent` is the local feature-id string that
// `FeatureTipService.markFeatureUsed` consumes — it MUST match the string
// passed into `markFeatureUsed(...)` at the feature's tap site. Once the
// user has used the feature, the matching tip is auto-marked seen so it
// never fires retroactively.
//
// `sessionThreshold` is the number of times the user has to land on the
// host screen (without ever using the feature) before the tip fires.
// 1 = first visit; 3 = "after a couple of misses". Higher = quieter.

class FeatureTip {
  final String id;
  final String title;
  final String body;
  final String? ctaLabel;
  final String requiredFeatureEvent;
  final int sessionThreshold;

  const FeatureTip({
    required this.id,
    required this.title,
    required this.body,
    this.ctaLabel,
    required this.requiredFeatureEvent,
    required this.sessionThreshold,
  });
}

class FeatureTipCatalog {
  FeatureTipCatalog._();

  /// Recipe Book → photo / URL / manual import (Pro). Sprint 16.4 wired
  /// the bento cards but they're easy to miss — first-time-discoverability
  /// gap called out in roadmap Sprint 16.8 row 7.
  static const FeatureTip recipeImport = FeatureTip(
    id: 'recipe_import',
    title: 'Got a recipe from somewhere else?',
    body:
        'Snap a photo, paste a URL, or type one in — Elio will add it to your library so you can cook from it just like a generated recipe.',
    ctaLabel: 'Try it',
    requiredFeatureEvent: 'recipe_import_opened',
    sessionThreshold: 3,
  );

  /// Meal Plan → "Add to shopping list" FAB. Bottom-right FAB on the
  /// meal-plan screen — only visible once a plan is generated, and easy
  /// to skip past on the way to viewing the actual days.
  static const FeatureTip mealPlanToShopping = FeatureTip(
    id: 'meal_plan_to_shopping',
    title: 'Turn your plan into a shop',
    body:
        'One tap pulls every ingredient from your week into a shopping list — minus anything you already have in the pantry.',
    ctaLabel: 'Show me',
    requiredFeatureEvent: 'meal_plan_shopping_opened',
    sessionThreshold: 2,
  );

  static const List<FeatureTip> all = [
    recipeImport,
    mealPlanToShopping,
  ];

  static FeatureTip? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}
