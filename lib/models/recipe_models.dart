// ─────────────────────────────────────────────
// Recipe Models
// Data structures for recipe generation requests and responses.
// Mirrors the Firestore schema in the design document.
// ─────────────────────────────────────────────

// Sprint 16.6 — defensive cap on RecipeIngredient string fields. Gemini
// occasionally writes deliberation text or echoes prompt instructions
// into string-typed fields when `thinkingBudget: 0` removes its scratch
// space. 80 chars covers every legitimate quantity observed; truncation
// adds an ellipsis (single U+2026 char). Field names are pushed onto an
// optional sink so the calling parse path (GeneratedRecipe.fromJson)
// can fire one aggregated ErrorService.log per recipe instead of one
// per field.
//
// TODO(observability): if Crashlytics shows tips/description/title/
// steps suffer the same failure mode, extend the same defence to those
// fields.
const int _ingredientFieldCharCap = 80;

String _sanitizeIngredientField(
  Object? raw, {
  required String fieldName,
  List<String>? sink,
}) {
  final asString = raw?.toString().trim() ?? '';
  if (asString.length <= _ingredientFieldCharCap) return asString;
  if (sink != null) sink.add(fieldName);
  return '${asString.substring(0, _ingredientFieldCharCap)}…';
}

// ─── Generation request ───────────────────────────────────────────────────────

class RecipeGenerationRequest {
  /// Perishables the user just added for this session
  final List<String> perishables;

  /// Items from the Always Have tier
  final List<String> alwaysHave;

  /// Items from the Almost Always Have tier
  final List<String> almostAlwaysHave;

  /// Dietary requirements (hard constraints)
  final List<String> dietaryRequirements;

  /// Time chip selection (soft preference)
  final String? timePreference; // e.g. "Quick (under 20 min)", "30 minutes", "No rush"

  /// Style chip selection (soft preference)
  final String? stylePreference; // e.g. "Asian", "Mediterranean"

  /// Mood chip selection (soft preference)
  final String? moodPreference; // e.g. "Something hearty", "Light bite"

  /// Sprint 16.6 row 5b — meal-type hard constraint. One of 'Breakfast',
  /// 'Lunch', 'Dinner', or null. Null = no preference. When set, emits a
  /// hard constraint line under `## HARD CONSTRAINTS` in the prompt so
  /// the recipe shape (breakfast vs lunch vs dinner) is locked. No
  /// example list — Gemini's training priors handle the meal-shape
  /// concept; positive example anchors would bias output.
  final String? mealType;

  /// Number of servings to generate for
  final int servings;

  /// Ingredients the user has explicitly excluded (ran out / don't want)
  final List<String> excludedIngredients;

  /// Titles of recently generated recipes — used to prevent duplicates
  final List<String> recentTitles;

  /// Sprint 16.6 (Notion XX bug 3): hero ingredients from the last 3
  /// recipes (window per Rob). Fed into a VARIATION prompt section so
  /// Gemini sees the actual signal instead of having to infer it from
  /// titles. Empty by default → VARIATION section is omitted entirely.
  /// Length cap is enforced upstream (HomeScreen FIFO of 3).
  final List<String> recentHeroIngredients;

  /// Sprint 16.6 (Notion XX bug 3): cookware nouns from the last 3
  /// recipes' steps. Same wiring as recentHeroIngredients — feeds the
  /// VARIATION prompt section so "skillet × 3 in a row" stops
  /// happening. Empty by default → omitted from prompt.
  final List<String> recentCookware;

  /// Pantry items flagged as running low — Gemini will avoid or treat as optional
  final List<String> runningLowItems;

  /// Whether the user is in leftover mode
  final bool isLeftoverMode;

  /// Leftover items the user wants to use up
  final List<String> leftoverItems;

  /// Titles of recipes the user has liked — used for adaptive learning
  final List<String> likedRecipes;

  /// Titles of recipes the user has disliked — used for adaptive learning
  final List<String> dislikedRecipes;

  /// Kitchen appliances the user owns — used to enhance recipe suggestions
  final List<String> appliances;

  /// Whether the user wants budget-friendly recipes
  final bool isSaverMode;

  /// Perishable inventory items with urgency descriptions for Gemini
  /// e.g. "chicken breast (expires in 2d)", "spinach (expires today)"
  final List<String> perishableInventoryDescriptions;

  /// Free-text "craving" supplied by the user on the prefs screen.
  /// e.g. "soup", "something with mushrooms", "pizza".
  /// Treated as a high-priority soft preference — Gemini should honour it
  /// where possible but never break dietary or required-perishable rules.
  final String? userRequest;

  /// Sprint 15.9.3 SAFETY FIX: user-typed custom allergens or specific
  /// ingredients to exclude on safety grounds. Distinct from
  /// [dietaryRequirements] (high-level patterns like 'Vegetarian'):
  /// these are concrete things like 'peanuts', 'sesame', 'shellfish'.
  /// Surfaced as a SEPARATE prompt section with maximum-strength
  /// language so Gemini doesn't conflate them with soft preferences.
  final List<String> customAllergens;

  const RecipeGenerationRequest({
    required this.perishables,
    required this.alwaysHave,
    required this.almostAlwaysHave,
    required this.dietaryRequirements,
    this.timePreference,
    this.stylePreference,
    this.moodPreference,
    this.mealType,
    this.servings = 2,
    this.excludedIngredients = const [],
    this.recentTitles = const [],
    this.recentHeroIngredients = const [],
    this.recentCookware = const [],
    this.runningLowItems = const [],
    this.isLeftoverMode = false,
    this.leftoverItems = const [],
    this.likedRecipes = const [],
    this.dislikedRecipes = const [],
    this.appliances = const [],
    this.isSaverMode = false,
    this.perishableInventoryDescriptions = const [],
    this.userRequest,
    this.customAllergens = const [],
  });
}

// ─── Nutrition info ─────────────────────────────────────────────────────────

class NutritionInfo {
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fibreG;

  const NutritionInfo({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fibreG,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fatG'] as num?)?.toDouble() ?? 0.0,
      fibreG: (json['fibreG'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'calories': calories,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'fibreG': fibreG,
  };
}

// ─── Generated recipe ─────────────────────────────────────────────────────────

class GeneratedRecipe {
  final String title;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final String description;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final List<RecipeSubstitution> substitutions;
  final List<String> dietaryTags;
  final NutritionInfo? nutrition; // per-serving, nullable for backwards compat

  /// Gemini-estimated cost per serving in USD (budget/own-brand tier). Nullable for backwards compat.
  final double? estimatedCostPerServingUSD;

  /// Gemini-estimated cost per serving in GBP (budget/own-brand tier). Nullable for backwards compat.
  final double? estimatedCostPerServingGBP;

  /// Bulk prep info (freezing & storage instructions). Nullable — only present for bulk prep recipes.
  final BulkPrepInfo? bulkPrepInfo;

  /// Recipe category (e.g. "Entrée", "Dessert"). Nullable for legacy
  /// records generated before Task 8b wired Gemini to populate the field.
  /// See `lib/data/recipe_categories.dart` for the canonical list.
  final String? category;

  const GeneratedRecipe({
    required this.title,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.substitutions,
    required this.dietaryTags,
    this.nutrition,
    this.estimatedCostPerServingUSD,
    this.estimatedCostPerServingGBP,
    this.bulkPrepInfo,
    this.category,
  });

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  /// Parse from JSON. When [ingredientTruncations] is non-null, it gets
  /// populated with field names of any over-cap ingredient strings so the
  /// caller (typically `gemini_service.dart:_parseGeneratedRecipe`) can
  /// fire one aggregated `ErrorService.log` per recipe. History read-back
  /// (SavedRecipe.fromJson) doesn't pass a sink — old already-truncated
  /// recipes from Firestore stay quiet.
  factory GeneratedRecipe.fromJson(
    Map<String, dynamic> json, {
    List<String>? ingredientTruncations,
  }) {
    return GeneratedRecipe(
      title: json['title'] as String? ?? 'Recipe',
      prepTimeMinutes: (json['prepTimeMinutes'] as num?)?.toInt() ?? 10,
      cookTimeMinutes: (json['cookTimeMinutes'] as num?)?.toInt() ?? 20,
      servings: (json['servings'] as num?)?.toInt() ?? 2,
      description: json['description'] as String? ?? '',
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => RecipeIngredient.fromJson(
                e as Map<String, dynamic>,
                truncatedSink: ingredientTruncations,
              ))
          .toList(),
      steps: (json['steps'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      substitutions: (json['substitutions'] as List<dynamic>? ?? [])
          .map((e) => RecipeSubstitution.fromJson(e as Map<String, dynamic>))
          .toList(),
      dietaryTags: (json['dietaryTags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      nutrition: json['nutrition'] != null
          ? NutritionInfo.fromJson(json['nutrition'] as Map<String, dynamic>)
          : null,
      estimatedCostPerServingUSD: (json['estimatedCostPerServingUSD'] as num?)?.toDouble(),
      estimatedCostPerServingGBP: (json['estimatedCostPerServingGBP'] as num?)?.toDouble(),
      bulkPrepInfo: json['bulkPrepInfo'] != null ? BulkPrepInfo.fromJson(json['bulkPrepInfo'] as Map<String, dynamic>) : null,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'prepTimeMinutes': prepTimeMinutes,
    'cookTimeMinutes': cookTimeMinutes,
    'servings': servings,
    'description': description,
    'ingredients': ingredients.map((i) => i.toMap()).toList(),
    'steps': steps,
    'substitutions': substitutions.map((s) => s.toMap()).toList(),
    'dietaryTags': dietaryTags,
    'generatedAt': DateTime.now(),
    if (nutrition != null) 'nutrition': nutrition!.toMap(),
    if (estimatedCostPerServingUSD != null) 'estimatedCostPerServingUSD': estimatedCostPerServingUSD,
    if (estimatedCostPerServingGBP != null) 'estimatedCostPerServingGBP': estimatedCostPerServingGBP,
    if (bulkPrepInfo != null) 'bulkPrepInfo': bulkPrepInfo!.toMap(),
    if (category != null) 'category': category,
  };

  GeneratedRecipe copyWith({
    List<RecipeIngredient>? ingredients,
    List<RecipeSubstitution>? substitutions,
    BulkPrepInfo? bulkPrepInfo,
    String? category,
    List<String>? dietaryTags,
  }) {
    return GeneratedRecipe(
      title: title,
      prepTimeMinutes: prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes,
      servings: servings,
      description: description,
      ingredients: ingredients ?? this.ingredients,
      steps: steps,
      substitutions: substitutions ?? this.substitutions,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      nutrition: nutrition,
      estimatedCostPerServingUSD: estimatedCostPerServingUSD,
      estimatedCostPerServingGBP: estimatedCostPerServingGBP,
      bulkPrepInfo: bulkPrepInfo ?? this.bulkPrepInfo,
      category: category ?? this.category,
    );
  }
}

class RecipeIngredient {
  final String name;
  final String quantity;
  final String unit;
  final bool fromInventory; // true if this came from the user's perishables

  const RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.fromInventory,
  });

  /// Parse from JSON with defensive field caps. When [truncatedSink] is
  /// non-null, field names of any truncated string fields get pushed onto
  /// it so the caller (GeneratedRecipe.fromJson) can fire one aggregated
  /// ErrorService.log per recipe instead of one log per field. When null
  /// (e.g. SavedRecipe history read-back), capping still applies but no
  /// observability event fires — old already-truncated recipes in
  /// Firestore stay quiet.
  factory RecipeIngredient.fromJson(
    Map<String, dynamic> json, {
    List<String>? truncatedSink,
  }) {
    return RecipeIngredient(
      name: _sanitizeIngredientField(json['name'],
          fieldName: 'name', sink: truncatedSink),
      quantity: _sanitizeIngredientField(json['quantity'],
          fieldName: 'quantity', sink: truncatedSink),
      unit: _sanitizeIngredientField(json['unit'],
          fieldName: 'unit', sink: truncatedSink),
      fromInventory: json['fromInventory'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'fromInventory': fromInventory,
  };

  String get displayString {
    if (quantity.isEmpty && unit.isEmpty) return name;
    if (unit.isEmpty) return '$quantity $name';
    return '$quantity $unit $name';
  }
}

// ─── Saved recipe (local history) ───────────────────────────────────────────

class SavedRecipe {
  final GeneratedRecipe recipe;
  final String savedAt; // ISO8601 string, used as unique ID
  final bool isBookmarked;
  final List<String> collections;

  const SavedRecipe({
    required this.recipe,
    required this.savedAt,
    this.isBookmarked = false,
    this.collections = const [],
  });

  factory SavedRecipe.fromJson(Map<String, dynamic> json) {
    return SavedRecipe(
      recipe: GeneratedRecipe.fromJson(json['recipe'] as Map<String, dynamic>),
      savedAt: json['savedAt'] as String? ?? DateTime.now().toIso8601String(),
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      collections: List<String>.from(json['collections'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'recipe': {
      'title': recipe.title,
      'description': recipe.description,
      'prepTimeMinutes': recipe.prepTimeMinutes,
      'cookTimeMinutes': recipe.cookTimeMinutes,
      'servings': recipe.servings,
      'dietaryTags': recipe.dietaryTags,
      'ingredients': recipe.ingredients.map((i) => i.toMap()).toList(),
      'steps': recipe.steps,
      'substitutions': recipe.substitutions.map((s) => s.toMap()).toList(),
      if (recipe.nutrition != null) 'nutrition': recipe.nutrition!.toMap(),
      if (recipe.estimatedCostPerServingUSD != null) 'estimatedCostPerServingUSD': recipe.estimatedCostPerServingUSD,
      if (recipe.estimatedCostPerServingGBP != null) 'estimatedCostPerServingGBP': recipe.estimatedCostPerServingGBP,
      if (recipe.bulkPrepInfo != null) 'bulkPrepInfo': recipe.bulkPrepInfo!.toMap(),
      if (recipe.category != null) 'category': recipe.category,
    },
    'savedAt': savedAt,
    'isBookmarked': isBookmarked,
    'collections': collections,
  };

  SavedRecipe copyWith({
    GeneratedRecipe? recipe,
    String? savedAt,
    bool? isBookmarked,
    List<String>? collections,
  }) {
    return SavedRecipe(
      recipe: recipe ?? this.recipe,
      savedAt: savedAt ?? this.savedAt,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      collections: collections ?? this.collections,
    );
  }

  static SavedRecipe fromRecipe(GeneratedRecipe recipe, {bool bookmarked = false}) => SavedRecipe(
    recipe: recipe,
    savedAt: DateTime.now().toIso8601String(),
    isBookmarked: bookmarked,
  );
}

class RecipeSubstitution {
  final String original;
  final String substitute;
  final String tradeOff;

  const RecipeSubstitution({
    required this.original,
    required this.substitute,
    required this.tradeOff,
  });

  factory RecipeSubstitution.fromJson(Map<String, dynamic> json) {
    return RecipeSubstitution(
      original: json['original'] as String? ?? '',
      substitute: json['substitute'] as String? ?? '',
      tradeOff: json['tradeOff'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'original': original,
    'substitute': substitute,
    'tradeOff': tradeOff,
  };
}

// ─── Ingredient substitution result (lightweight AI swap) ───────────────────

// ─── Recipe generation status (streaming) ─────────────────────────────────

sealed class RecipeGenerationStatus {}

class RecipeGenerating extends RecipeGenerationStatus {
  final int bytesReceived;
  RecipeGenerating({required this.bytesReceived});
}

class RecipeComplete extends RecipeGenerationStatus {
  final GeneratedRecipe recipe;
  RecipeComplete({required this.recipe});
}

class RecipeError extends RecipeGenerationStatus {
  final String message;

  /// True when the failure is transient and worth retrying without user
  /// intervention (5xx, network blip, truncated SSE stream, JSON parse
  /// failure). False for definitive failures the retry can't recover —
  /// auth (401/403), bad request (400), rate-limit (429), explicit
  /// MAX_TOKENS finish, or a deliberate user-facing message.
  final bool retryable;

  RecipeError({required this.message, this.retryable = false});
}

// ─── Bulk prep info (freezing & storage) ────────────────────────────────────

class BulkPrepInfo {
  final int totalPortions;
  final String freezingInstructions;
  final String reheatingInstructions;
  final String storageLife;
  final String containerSuggestion;

  const BulkPrepInfo({
    required this.totalPortions,
    required this.freezingInstructions,
    required this.reheatingInstructions,
    required this.storageLife,
    required this.containerSuggestion,
  });

  factory BulkPrepInfo.fromJson(Map<String, dynamic> json) {
    return BulkPrepInfo(
      totalPortions: (json['totalPortions'] as num?)?.toInt() ?? 6,
      freezingInstructions: json['freezingInstructions'] as String? ?? '',
      reheatingInstructions: json['reheatingInstructions'] as String? ?? '',
      storageLife: json['storageLife'] as String? ?? '',
      containerSuggestion: json['containerSuggestion'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'totalPortions': totalPortions,
    'freezingInstructions': freezingInstructions,
    'reheatingInstructions': reheatingInstructions,
    'storageLife': storageLife,
    'containerSuggestion': containerSuggestion,
  };
}

// ─── Ingredient substitution result (lightweight AI swap) ───────────────────

class IngredientSubstitutionResult {
  final String substitute;
  final String adjustedQuantity;
  final String unit;
  final String tradeOff;

  const IngredientSubstitutionResult({
    required this.substitute,
    required this.adjustedQuantity,
    required this.unit,
    required this.tradeOff,
  });

  factory IngredientSubstitutionResult.fromJson(Map<String, dynamic> json) {
    return IngredientSubstitutionResult(
      substitute: json['substitute'] as String? ?? '',
      adjustedQuantity: json['adjustedQuantity']?.toString() ?? '',
      unit: json['unit'] as String? ?? '',
      tradeOff: json['tradeOff'] as String? ?? '',
    );
  }
}
