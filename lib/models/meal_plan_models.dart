import '../utils/json_num.dart';
import 'recipe_models.dart';

// ─────────────────────────────────────────────
// Meal Plan Models
// Data structures for the weekly meal planner.
//
// Structure:
//   MealPlan
//     └── List<DayPlan> (7 days, Mon–Sun)
//           └── Map<MealType, MealSlot>
//                 └── MealSlot (full recipe data — shared view with single recipe)
// ─────────────────────────────────────────────

enum MealType { breakfast, lunch, dinner }

extension MealTypeExtension on MealType {
  String get displayName {
    switch (this) {
      case MealType.breakfast: return 'Breakfast';
      case MealType.lunch:     return 'Lunch';
      case MealType.dinner:    return 'Dinner';
    }
  }

  String get emoji {
    switch (this) {
      case MealType.breakfast: return '☀️';
      case MealType.lunch:     return '🌤';
      case MealType.dinner:    return '🌙';
    }
  }
}

// ─── Meal slot ────────────────────────────────────────────────────────────────
// A single meal in the plan (one cell in the 7×3 grid).

class MealSlot {
  final String title;
  final String description;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final List<String> dietaryTags;
  final List<MealIngredient> ingredients;
  final List<String> steps;

  /// Full nutrition info per serving (nullable for backwards compat)
  final NutritionInfo? nutrition;

  /// Legacy: calories only (kept for old cached plans). Prefer nutrition.calories.
  final int? caloriesPerServing;

  /// Gemini-estimated cost per serving in USD (budget/own-brand tier)
  final double? estimatedCostPerServingUSD;

  /// Gemini-estimated cost per serving in GBP (budget/own-brand tier)
  final double? estimatedCostPerServingGBP;

  /// Substitution tips (same format as single recipe)
  final List<RecipeSubstitution> substitutions;

  const MealSlot({
    required this.title,
    required this.description,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.dietaryTags,
    required this.ingredients,
    this.servings = 2,
    this.steps = const [],
    this.nutrition,
    this.caloriesPerServing,
    this.estimatedCostPerServingUSD,
    this.estimatedCostPerServingGBP,
    this.substitutions = const [],
  });

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  /// Whether Phase 2 detail (steps, nutrition, substitutions) has been loaded.
  bool get hasDetail => steps.isNotEmpty;

  /// Effective calories — prefers full nutrition object, falls back to legacy field
  int? get effectiveCalories => nutrition?.calories ?? caloriesPerServing;

  factory MealSlot.fromJson(Map<String, dynamic> json) {
    return MealSlot(
      title: json['title'] as String? ?? 'Meal',
      description: json['description'] as String? ?? '',
      prepTimeMinutes: asNum(json['prepTimeMinutes'])?.toInt() ?? 5,
      cookTimeMinutes: asNum(json['cookTimeMinutes'])?.toInt() ?? 15,
      servings: asNum(json['servings'])?.toInt() ?? 2,
      dietaryTags: (json['dietaryTags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => MealIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      nutrition: json['nutrition'] != null
          ? NutritionInfo.fromJson(json['nutrition'] as Map<String, dynamic>)
          : null,
      caloriesPerServing: asNum(json['caloriesPerServing'])?.toInt(),
      estimatedCostPerServingUSD: asNum(json['estimatedCostPerServingUSD'])?.toDouble(),
      estimatedCostPerServingGBP: asNum(json['estimatedCostPerServingGBP'])?.toDouble(),
      substitutions: (json['substitutions'] as List<dynamic>? ?? [])
          .map((e) => RecipeSubstitution.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'prepTimeMinutes': prepTimeMinutes,
    'cookTimeMinutes': cookTimeMinutes,
    'servings': servings,
    'dietaryTags': dietaryTags,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'steps': steps,
    if (nutrition != null) 'nutrition': nutrition!.toMap(),
    if (caloriesPerServing != null) 'caloriesPerServing': caloriesPerServing,
    if (estimatedCostPerServingUSD != null) 'estimatedCostPerServingUSD': estimatedCostPerServingUSD,
    if (estimatedCostPerServingGBP != null) 'estimatedCostPerServingGBP': estimatedCostPerServingGBP,
    if (substitutions.isNotEmpty) 'substitutions': substitutions.map((s) => s.toMap()).toList(),
  };

  /// Merge Phase 2 detail (steps, nutrition, substitutions) into this slot.
  MealSlot copyWithDetail({
    required List<String> steps,
    NutritionInfo? nutrition,
    List<RecipeSubstitution> substitutions = const [],
  }) {
    return MealSlot(
      title: title,
      description: description,
      prepTimeMinutes: prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes,
      servings: servings,
      dietaryTags: dietaryTags,
      ingredients: ingredients,
      steps: steps,
      nutrition: nutrition,
      caloriesPerServing: caloriesPerServing,
      estimatedCostPerServingUSD: estimatedCostPerServingUSD,
      estimatedCostPerServingGBP: estimatedCostPerServingGBP,
      substitutions: substitutions,
    );
  }

  /// Convert to GeneratedRecipe for use with the unified RecipeScreen.
  GeneratedRecipe toGeneratedRecipe() {
    return GeneratedRecipe(
      title: title,
      prepTimeMinutes: prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes,
      servings: servings,
      description: description,
      ingredients: ingredients
          .map((i) => RecipeIngredient(
                name: i.name,
                quantity: i.quantity,
                unit: i.unit,
                fromInventory: false,
              ))
          .toList(),
      steps: steps,
      substitutions: substitutions,
      dietaryTags: dietaryTags,
      nutrition: nutrition,
      estimatedCostPerServingUSD: estimatedCostPerServingUSD,
      estimatedCostPerServingGBP: estimatedCostPerServingGBP,
    );
  }
}

class MealIngredient {
  final String name;
  final String quantity;
  final String unit;

  const MealIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory MealIngredient.fromJson(Map<String, dynamic> json) {
    return MealIngredient(
      name: json['name'] as String? ?? '',
      quantity: json['quantity']?.toString() ?? '',
      unit: json['unit'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
  };

  String get displayString {
    if (quantity.isEmpty && unit.isEmpty) return name;
    if (unit.isEmpty) return '$quantity $name';
    return '$quantity $unit $name';
  }
}

// ─── Day plan ─────────────────────────────────────────────────────────────────

class DayPlan {
  final String dayName; // e.g. "Monday"
  final Map<MealType, MealSlot?> meals;

  const DayPlan({
    required this.dayName,
    required this.meals,
  });

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    return DayPlan(
      dayName: json['dayName'] as String? ?? 'Day',
      meals: {
        MealType.breakfast: json['breakfast'] != null
            ? MealSlot.fromJson(json['breakfast'] as Map<String, dynamic>)
            : null,
        MealType.lunch: json['lunch'] != null
            ? MealSlot.fromJson(json['lunch'] as Map<String, dynamic>)
            : null,
        MealType.dinner: json['dinner'] != null
            ? MealSlot.fromJson(json['dinner'] as Map<String, dynamic>)
            : null,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'dayName': dayName,
    'breakfast': meals[MealType.breakfast]?.toJson(),
    'lunch': meals[MealType.lunch]?.toJson(),
    'dinner': meals[MealType.dinner]?.toJson(),
  };

  DayPlan copyWithMeal(MealType type, MealSlot? meal) {
    return DayPlan(
      dayName: dayName,
      meals: {
        MealType.breakfast: type == MealType.breakfast ? meal : meals[MealType.breakfast],
        MealType.lunch: type == MealType.lunch ? meal : meals[MealType.lunch],
        MealType.dinner: type == MealType.dinner ? meal : meals[MealType.dinner],
      },
    );
  }
}

// ─── Full meal plan ───────────────────────────────────────────────────────────

class MealPlan {
  final List<DayPlan> days;
  final DateTime generatedAt;

  const MealPlan({
    required this.days,
    required this.generatedAt,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      days: (json['days'] as List<dynamic>? ?? [])
          .map((d) => DayPlan.fromJson(d as Map<String, dynamic>))
          .toList(),
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'days': days.map((d) => d.toJson()).toList(),
    'generatedAt': generatedAt.toIso8601String(),
  };

  MealPlan copyWithDay(int index, DayPlan day) {
    final newDays = List<DayPlan>.from(days);
    newDays[index] = day;
    return MealPlan(days: newDays, generatedAt: generatedAt);
  }
}

// ─── Shopping list ────────────────────────────────────────────────────────────
// Derived from a MealPlan by aggregating all ingredients.

class ShoppingItem {
  final String name;
  final List<String> quantities; // one per meal that uses it
  final bool isRestock; // true for Running Low items
  bool isChecked;

  ShoppingItem({
    required this.name,
    required this.quantities,
    this.isRestock = false,
    this.isChecked = false,
  });
}

class ShoppingList {
  final List<ShoppingItem> items;
  final DateTime generatedAt;

  const ShoppingList({
    required this.items,
    required this.generatedAt,
  });

  /// Build a shopping list from a meal plan, excluding items the user already has.
  /// [runningLowItems] are always included regardless of pantry status — user needs to restock.
  factory ShoppingList.fromMealPlan(
    MealPlan plan, {
    List<String> alreadyHave = const [],
    List<String> runningLowItems = const [],
  }) {
    // Aggregate ingredients across all meals
    final aggregated = <String, List<String>>{};
    for (final day in plan.days) {
      for (final meal in day.meals.values) {
        if (meal == null) continue;
        for (final ingredient in meal.ingredients) {
          final key = ingredient.name.toLowerCase().trim();
          aggregated.putIfAbsent(key, () => []);
          if (ingredient.quantity.isNotEmpty) {
            // Store only quantity + unit, not the full name (name is already the key)
            final qtyStr = '${ingredient.quantity} ${ingredient.unit}'.trim();
            aggregated[key]!.add(qtyStr);
          }
        }
      }
    }

    // Filter out items the user already has (case-insensitive)
    final haveSet = alreadyHave.map((s) => s.toLowerCase().trim()).toSet();
    final items = aggregated.entries
        .where((e) => !haveSet.any((h) => e.key.contains(h) || h.contains(e.key)))
        .map((e) => ShoppingItem(name: e.key, quantities: e.value))
        .toList();

    // Add running low items that aren't already in the list
    final existingNames = items.map((i) => i.name.toLowerCase().trim()).toSet();
    for (final item in runningLowItems) {
      final key = item.toLowerCase().trim();
      if (!existingNames.contains(key)) {
        items.add(ShoppingItem(name: key, quantities: ['Restock'], isRestock: true));
        existingNames.add(key);
      }
    }

    items.sort((a, b) => a.name.compareTo(b.name));
    return ShoppingList(items: items, generatedAt: DateTime.now());
  }
}
