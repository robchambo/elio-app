// ─────────────────────────────────────────────
// Recipe Models
// Data structures for recipe generation requests and responses.
// Mirrors the Firestore schema in the design document.
// ─────────────────────────────────────────────

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

  /// Number of servings to generate for
  final int servings;

  /// Ingredients the user has explicitly excluded (ran out / don't want)
  final List<String> excludedIngredients;

  /// Titles of recently generated recipes — used to prevent duplicates
  final List<String> recentTitles;

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

  const RecipeGenerationRequest({
    required this.perishables,
    required this.alwaysHave,
    required this.almostAlwaysHave,
    required this.dietaryRequirements,
    this.timePreference,
    this.stylePreference,
    this.moodPreference,
    this.servings = 2,
    this.excludedIngredients = const [],
    this.recentTitles = const [],
    this.runningLowItems = const [],
    this.isLeftoverMode = false,
    this.leftoverItems = const [],
    this.likedRecipes = const [],
    this.dislikedRecipes = const [],
    this.appliances = const [],
    this.isSaverMode = false,
    this.perishableInventoryDescriptions = const [],
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
  });

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  factory GeneratedRecipe.fromJson(Map<String, dynamic> json) {
    return GeneratedRecipe(
      title: json['title'] as String? ?? 'Recipe',
      prepTimeMinutes: (json['prepTimeMinutes'] as num?)?.toInt() ?? 10,
      cookTimeMinutes: (json['cookTimeMinutes'] as num?)?.toInt() ?? 20,
      servings: (json['servings'] as num?)?.toInt() ?? 2,
      description: json['description'] as String? ?? '',
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
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
  };

  GeneratedRecipe copyWith({
    List<RecipeIngredient>? ingredients,
    List<RecipeSubstitution>? substitutions,
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
      dietaryTags: dietaryTags,
      nutrition: nutrition,
      estimatedCostPerServingUSD: estimatedCostPerServingUSD,
      estimatedCostPerServingGBP: estimatedCostPerServingGBP,
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

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] as String? ?? '',
      quantity: json['quantity']?.toString() ?? '',
      unit: json['unit'] as String? ?? '',
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

  const SavedRecipe({required this.recipe, required this.savedAt});

  factory SavedRecipe.fromJson(Map<String, dynamic> json) {
    return SavedRecipe(
      recipe: GeneratedRecipe.fromJson(json['recipe'] as Map<String, dynamic>),
      savedAt: json['savedAt'] as String? ?? DateTime.now().toIso8601String(),
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
    },
    'savedAt': savedAt,
  };

  static SavedRecipe fromRecipe(GeneratedRecipe recipe) => SavedRecipe(
    recipe: recipe,
    savedAt: DateTime.now().toIso8601String(),
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
