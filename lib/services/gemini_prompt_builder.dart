import '../models/recipe_models.dart';

// ─────────────────────────────────────────────
// GeminiPromptBuilder
// Pure Dart prompt construction for recipe generation.
//
// Lifted out of GeminiService so the multi-provider eval harness
// (tool/eval/) can call the same function and test against models
// without any prompt drift. No Flutter imports — region and units
// are passed as strings.
// ─────────────────────────────────────────────

/// Build the standard recipe-generation prompt.
///
/// [region] must be 'us' or 'uk'. [measurementUnits] must be 'metric' or
/// 'imperial'. These come from RegionUtils inside the Flutter app, or
/// directly from a fixture in the eval harness.
String buildRecipePrompt(
  RecipeGenerationRequest request, {
  required String region,
  required String measurementUnits,
}) {
  final buffer = StringBuffer();

  buffer.writeln('You are Elio, a friendly AI cooking assistant. Generate ONE recipe as valid JSON.');
  buffer.writeln();
  buffer.writeln('IMPORTANT: Your ENTIRE response must be a single valid JSON object. No prose before or after. No markdown fences.');
  buffer.writeln();
  buffer.writeln('## HARD CONSTRAINTS (never override):');

  // Measurement units and region
  if (measurementUnits == 'imperial') {
    buffer.writeln('Use imperial measurements (ounces, cups, Fahrenheit) for all quantities and temperatures.');
  } else {
    buffer.writeln('Use metric measurements (grams, millilitres, Celsius) for all quantities and temperatures.');
  }
  if (region == 'uk') {
    buffer.writeln('User is in the United Kingdom — use GBP for cost estimates and UK ingredient names.');
  } else {
    buffer.writeln('User is in the United States — use USD for cost estimates and US ingredient names.');
  }

  if (request.dietaryRequirements.isNotEmpty) {
    buffer.writeln('Dietary: ${request.dietaryRequirements.join(', ')} — strictly enforced.');
  } else {
    buffer.writeln('No dietary restrictions.');
  }

  // Style as a hard constraint (unless "Surprise me")
  if (request.stylePreference != null && request.stylePreference != 'Surprise me') {
    buffer.writeln('You MUST make a ${request.stylePreference} recipe. This is a hard requirement — the recipe\'s cuisine/style must clearly be ${request.stylePreference}.');
  }

  // ── Leftover mode: completely different framing ──────────────────
  if (request.isLeftoverMode && request.leftoverItems.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('## LEFTOVER MODE:');
    buffer.writeln('The user has these leftovers and wants to use them up creatively. Build the recipe AROUND these items.');
    buffer.writeln('Leftovers to use: ${request.leftoverItems.join(', ')}');
    buffer.writeln('Goal: transform these leftovers into something delicious. Minimise food waste.');
    if (request.alwaysHave.isNotEmpty) {
      buffer.writeln('Pantry staples available: ${request.alwaysHave.join(', ')}');
    }
    if (request.almostAlwaysHave.isNotEmpty) {
      buffer.writeln('Usually have: ${request.almostAlwaysHave.join(', ')}');
    }
  } else {
    buffer.writeln();
    buffer.writeln('## INVENTORY:');

    // Perishable inventory items with urgency (from pantry perishable tier)
    if (request.perishableInventoryDescriptions.isNotEmpty) {
      buffer.writeln('PERISHABLE ITEMS (use these first): ${request.perishableInventoryDescriptions.join(', ')}');
    }

    if (request.perishables.isNotEmpty) {
      buffer.writeln('REQUIRED ingredients — you MUST use ALL of these in the recipe (not just some of them): ${request.perishables.join(', ')}. Every single one of these must appear in the ingredients list and be used meaningfully in the cooking steps.');
    } else if (request.perishableInventoryDescriptions.isEmpty) {
      buffer.writeln('No fresh items — use pantry staples.');
    }

    if (request.alwaysHave.isNotEmpty) {
      buffer.writeln('Pantry staples: ${request.alwaysHave.join(', ')}');
    }
    if (request.almostAlwaysHave.isNotEmpty) {
      buffer.writeln('Usually have: ${request.almostAlwaysHave.join(', ')}');
    }
  } // end else (normal mode)

  buffer.writeln();
  buffer.writeln('## PREFERENCES:');
  if (request.timePreference != null) buffer.writeln('Time: ${request.timePreference}');
  if (request.stylePreference == 'Surprise me') {
    buffer.writeln('Style: Be creative — any cuisine.');
  }
  if (request.moodPreference != null) {
    buffer.writeln('Mood: ${request.moodPreference}');
    buffer.writeln(_expandMoodGuidance(request.moodPreference!));
  }
  buffer.writeln('Servings: ${request.servings}');

  if (request.runningLowItems.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('## RUNNING LOW (use sparingly or avoid — user is nearly out of these):');
    buffer.writeln(request.runningLowItems.join(', '));
  }

  if (request.excludedIngredients.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('## EXCLUDED INGREDIENTS (do NOT use these — user has run out or does not want them):');
    buffer.writeln(request.excludedIngredients.join(', '));
  }

  if (request.appliances.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('## AVAILABLE APPLIANCES:');
    buffer.writeln('User has: ${request.appliances.join(', ')}. Where appropriate, suggest using these appliances to enhance the recipe.');
  }

  if (request.recentTitles.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('## RECENTLY GENERATED (do NOT repeat these recipes — generate something different):');
    for (final title in request.recentTitles) {
      buffer.writeln('- $title');
    }

    // Variety constraint — use last 5 to steer away from repetitive styles
    final recentFive = request.recentTitles.length <= 5
        ? request.recentTitles
        : request.recentTitles.sublist(request.recentTitles.length - 5);
    buffer.writeln();
    buffer.writeln('## VARIETY (important):');
    buffer.writeln('Look at these recent recipes: ${recentFive.join(', ')}.');
    buffer.writeln('Generate something with a DIFFERENT base ingredient, cooking method, AND cuisine.');
    buffer.writeln('If recent recipes are pasta-heavy, avoid pasta. If they are Asian-leaning, try a different region. If they are all oven-baked, try stovetop or no-cook.');
    buffer.writeln('Variety is key — surprise the user with something fresh.');
  }

  // Taste profile is injected by caller via request fields
  if (request.likedRecipes.isNotEmpty || request.dislikedRecipes.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('## TASTE PROFILE (adapt suggestions based on this):');
    if (request.likedRecipes.isNotEmpty) {
      buffer.writeln('User has LIKED recipes similar to: ${request.likedRecipes.take(5).join(', ')} — lean into similar styles, flavours, and techniques.');
    }
    if (request.dislikedRecipes.isNotEmpty) {
      buffer.writeln('User has DISLIKED recipes similar to: ${request.dislikedRecipes.take(5).join(', ')} — avoid similar styles and flavour profiles.');
    }
  }

  if (request.isSaverMode) {
    buffer.writeln();
    buffer.writeln('## BUDGET MODE:');
    buffer.writeln('Prioritise affordable, budget-friendly ingredients. Use own-brand/store-brand pricing. Favour bulk staples (rice, pasta, lentils, beans, frozen veg). Avoid premium, organic, or specialty ingredients. Aim for under £2 / \$3 per serving. Suggest the cheapest viable option for each ingredient.');
  }

  buffer.writeln();
  buffer.writeln('## RULES:');
  buffer.writeln('- Recipe title must sound like home cooking, NOT a pre-made product. E.g. "Lemon Herb Chicken with Roasted Vegetables", not "Cooked Mediterranean Chicken".');
  buffer.writeln('- Ingredients must be raw/purchasable items, NOT pre-prepared dishes. Never list a cooked dish as an ingredient.');
  buffer.writeln('- Keep steps SHORT (1-2 sentences each). Max 8 steps total.');
  buffer.writeln('- Max 10 ingredients.');
  buffer.writeln('- substitutions array may be empty [].');
  buffer.writeln('- dietaryTags array may be empty [].');
  buffer.writeln('- estimatedCostPerServingUSD and estimatedCostPerServingGBP: estimate the cost per serving in USD and GBP respectively.');
  buffer.writeln('  Use BUDGET/OWN-BRAND pricing (e.g. Kroger brand, Walmart Great Value, Tesco Everyday Value, Asda Smart Price).');
  buffer.writeln('  Do NOT use organic, premium, or specialty variants. Choose the standard, most affordable option.');
  buffer.writeln('  Account for the fact that users buy whole packs (e.g. a 1lb chicken pack, not just the exact grams used).');
  buffer.writeln('  Exclude pantry staples (salt, pepper, oil, basic spices) from the estimate — assume the user already has these.');
  buffer.writeln('  Provide a realistic low-end estimate. If uncertain, err on the lower side.');

  buffer.writeln();
  buffer.writeln('## JSON SCHEMA (return exactly this structure):');
  buffer.writeln('Include estimated per-serving nutritional values in the "nutrition" field.');
  buffer.writeln('''{
  "title": "string",
  "description": "string (1-2 sentences)",
  "prepTimeMinutes": 10,
  "cookTimeMinutes": 20,
  "servings": 2,
  "dietaryTags": ["string"],
  "ingredients": [
    {"name": "string", "quantity": "string", "unit": "string", "fromInventory": true}
  ],
  "steps": ["string"],
  "substitutions": [
    {"original": "string", "substitute": "string", "tradeOff": "string"}
  ],
  "nutrition": {
    "calories": 450,
    "proteinG": 35.0,
    "carbsG": 42.0,
    "fatG": 12.0,
    "fibreG": 6.0
  },
  "estimatedCostPerServingUSD": 4.50,
  "estimatedCostPerServingGBP": 3.50
}''');

  return buffer.toString();
}

/// Build the bulk-prep prompt: extends the base prompt with batch cooking
/// and freezing instructions.
String buildBulkPrepPrompt(
  RecipeGenerationRequest request, {
  required String region,
  required String measurementUnits,
  required int portions,
  required int mealNumber,
  required int totalMeals,
  required List<String> previousMealTitles,
}) {
  final base = buildRecipePrompt(request, region: region, measurementUnits: measurementUnits);
  final buffer = StringBuffer(base);

  buffer.writeln();
  buffer.writeln('## BULK PREP MODE:');
  buffer.writeln('This recipe MUST be suitable for batch cooking and freezing.');
  buffer.writeln('- Scale for $portions portions total');
  buffer.writeln('- Choose recipes that freeze and reheat well (casseroles, curries, stews, pasta bakes, chilli, bolognese, soups, etc.)');
  buffer.writeln('- Do NOT suggest: salads, dishes with raw vegetables, anything with fresh garnishes that won\'t survive freezing, fried foods that lose crispness');
  buffer.writeln('- Steps should include batch cooking tips (use largest pans, cook in stages if needed)');
  if (mealNumber > 1 && previousMealTitles.isNotEmpty) {
    buffer.writeln('This is meal $mealNumber of $totalMeals. Previous meals already generated: ${previousMealTitles.join(', ')}. Generate something DIFFERENT — different cuisine, different protein, different base.');
  }

  buffer.writeln();
  buffer.writeln('Add this to the JSON output:');
  buffer.writeln('"bulkPrepInfo": {');
  buffer.writeln('  "totalPortions": $portions,');
  buffer.writeln('  "freezingInstructions": "string (how to cool, portion, and freeze)",');
  buffer.writeln('  "reheatingInstructions": "string (how to defrost and reheat safely)",');
  buffer.writeln('  "storageLife": "string (e.g. \'Up to 3 months frozen, 3 days in fridge\')",');
  buffer.writeln('  "containerSuggestion": "string (e.g. \'Portion into 500ml containers\')"');
  buffer.writeln('}');

  return buffer.toString();
}

/// Expand a mood chip label into specific, actionable prompt guidance
/// so the model generates recipes that actually match the mood.
String _expandMoodGuidance(String mood) {
  switch (mood) {
    case 'Impress someone':
      return 'This meal is for a special occasion or to impress a guest. '
          'Choose a dish that looks and tastes restaurant-quality. '
          'Use at least one elevated technique (e.g. searing, reducing a sauce, '
          'caramelising, layering flavours, making a dressing or glaze from scratch). '
          'Avoid anything that looks like a basic weeknight dinner. '
          'Include a brief plating or presentation tip in the final step. '
          'The title should sound appealing and sophisticated.';
    case 'Something hearty':
      return 'Make this a filling, comforting, warming dish. '
          'Think stews, braises, bakes, curries, hearty pastas, or one-pot meals. '
          'Generous portions, rich flavours, the kind of meal that satisfies completely.';
    case 'Light bite':
      return 'Keep this light and fresh. Salads, wraps, grain bowls, broth-based soups, '
          'or small plates. Lower calorie, not heavy or stodgy. '
          'Prioritise vegetables, lean proteins, and bright flavours.';
    case 'Use everything up':
      return 'The goal is to use up as many of the available fresh/perishable ingredients '
          'as possible in a single recipe. Prioritise ingredients that spoil fastest. '
          'A stir-fry, frittata, soup, curry, or similar flexible dish works well.';
    default:
      return '';
  }
}
