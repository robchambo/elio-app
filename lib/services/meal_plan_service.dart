import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/meal_plan_models.dart';
import '../models/recipe_models.dart';
import 'remote_config_service.dart';

// ─────────────────────────────────────────────
// MealPlanService
// Calls Gemini 2.5 Flash-Lite to generate meal plans.
//
// Cost optimisations (Sprint 15):
//   • Switched to gemini-2.5-flash-lite (~35% cheaper, no thinking tokens)
//   • responseMimeType: application/json — guaranteed clean JSON
//   • Prompts compressed ~50% — fewer input tokens per call
//   • Two-phase generation: weekly call returns summaries only (Phase 1),
//     detail (steps, nutrition, substitutions) loaded on-demand (Phase 2)
//   • maxOutputTokens: 6144 weekly / 1024 single meal / 512 detail
//   • HTTP timeouts: 90s weekly / 60s single / 45s detail
// ─────────────────────────────────────────────

class MealPlanService {
  static String get _apiKey => RemoteConfigService.instance.geminiApiKey;
  static const String _model = 'gemini-2.5-flash-lite';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  // ── Full week generation ──────────────────────────────────────────────────────
  static Future<MealPlan> generateWeeklyPlan({
    required List<String> dietaryRequirements,
    required List<String> alwaysHave,
    required List<String> almostAlwaysHave,
    required List<String> stylePreferences,
    List<String>? selectedDays,
    List<MealType>? selectedMealTypes,
    int servings = 2,
  }) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        return await _attemptWeeklyGeneration(
          dietaryRequirements: dietaryRequirements,
          alwaysHave: alwaysHave,
          almostAlwaysHave: almostAlwaysHave,
          stylePreferences: stylePreferences,
          selectedDays: selectedDays ?? _days,
          selectedMealTypes: selectedMealTypes ?? MealType.values,
          servings: servings,
        );
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (e.toString().contains('rate limit') ||
            e.toString().contains('access denied')) {
          rethrow;
        }
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
    }

    throw lastError ?? Exception('Meal plan generation failed. Please try again.');
  }

  static Future<MealPlan> _attemptWeeklyGeneration({
    required List<String> dietaryRequirements,
    required List<String> alwaysHave,
    required List<String> almostAlwaysHave,
    required List<String> stylePreferences,
    required List<String> selectedDays,
    required List<MealType> selectedMealTypes,
    required int servings,
  }) async {
    final prompt = _buildWeeklyPrompt(
      dietaryRequirements: dietaryRequirements,
      alwaysHave: alwaysHave,
      almostAlwaysHave: almostAlwaysHave,
      stylePreferences: stylePreferences,
      selectedDays: selectedDays,
      selectedMealTypes: selectedMealTypes,
      servings: servings,
    );

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [{'text': prompt}]
          }
        ],
        'generationConfig': {
          'temperature': 0.85,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 6144,
          'responseMimeType': 'application/json',
        },
      }),
    ).timeout(const Duration(seconds: 90));

    _checkHttpErrors(response);

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No meal plan generated. Please try again.');
    }

    final finishReason = candidates[0]['finishReason'] as String? ?? 'STOP';
    if (finishReason == 'MAX_TOKENS') {
      throw Exception('Response was too long. Retrying...');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Empty response from AI. Please try again.');
    }

    final rawText = parts.last['text'] as String? ?? '';
    final planJson = _extractJson(rawText);

    final daysJson = planJson['days'] as List<dynamic>?;
    if (daysJson == null || daysJson.isEmpty) {
      throw Exception('Meal plan structure was invalid. Please try again.');
    }

    final days = daysJson
        .map((d) => DayPlan.fromJson(d as Map<String, dynamic>))
        .toList();

    return MealPlan(days: days, generatedAt: DateTime.now());
  }

  // ── Single meal regeneration ──────────────────────────────────────────────────
  static Future<MealSlot> regenerateMeal({
    required String dayName,
    required MealType mealType,
    required List<String> dietaryRequirements,
    required List<String> alwaysHave,
    required List<String> almostAlwaysHave,
    required List<String> existingTitles,
    int servings = 2,
    // Sprint 15.9.3: pass user prefs through so single-meal regen
    // reflects the user's setup (appliances, what they're running low on).
    List<String> appliances = const [],
    List<String> runningLowItems = const [],
    // Sprint 15.9.3 SAFETY: allergens must reach the prompt or a
    // peanut-allergy user could be served peanut butter on regen.
    List<String> customAllergens = const [],
  }) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        return await _attemptSingleMeal(
          dayName: dayName,
          mealType: mealType,
          dietaryRequirements: dietaryRequirements,
          alwaysHave: alwaysHave,
          almostAlwaysHave: almostAlwaysHave,
          existingTitles: existingTitles,
          servings: servings,
          appliances: appliances,
          runningLowItems: runningLowItems,
          customAllergens: customAllergens,
        );
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (e.toString().contains('rate limit') ||
            e.toString().contains('access denied')) {
          rethrow;
        }
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    throw lastError ?? Exception('Could not regenerate meal. Please try again.');
  }

  static Future<MealSlot> _attemptSingleMeal({
    required String dayName,
    required MealType mealType,
    required List<String> dietaryRequirements,
    required List<String> alwaysHave,
    required List<String> almostAlwaysHave,
    required List<String> existingTitles,
    required int servings,
    List<String> appliances = const [],
    List<String> runningLowItems = const [],
    List<String> customAllergens = const [],
  }) async {
    final prompt = _buildSingleMealPrompt(
      dayName: dayName,
      mealType: mealType,
      dietaryRequirements: dietaryRequirements,
      alwaysHave: alwaysHave,
      almostAlwaysHave: almostAlwaysHave,
      existingTitles: existingTitles,
      servings: servings,
      appliances: appliances,
      runningLowItems: runningLowItems,
      customAllergens: customAllergens,
    );

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [{'text': prompt}]
          }
        ],
        'generationConfig': {
          'temperature': 0.9,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
          'responseMimeType': 'application/json',
        },
      }),
    ).timeout(const Duration(seconds: 60));

    _checkHttpErrors(response);

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No meal generated. Please try again.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Empty response. Please try again.');
    }

    final rawText = parts.last['text'] as String? ?? '';
    final mealJson = _extractJson(rawText);
    final meal = MealSlot.fromJson(mealJson);

    // Sprint 15.9.3 SAFETY: post-gen allergen filter. Same logic as
    // the streaming path — case-insensitive substring match across all
    // text fields. Throw a retryable exception so the regenerateMeal
    // caller's 2-attempt loop has another go.
    final violation = _findAllergenViolation(meal, customAllergens);
    if (violation != null) {
      throw Exception(
          'Meal contained allergen "$violation" — retrying with a safer pick.');
    }
    return meal;
  }

  /// See gemini_service.dart `_findAllergenViolation` — same idea,
  /// scoped to a [MealSlot]. Duplicated rather than imported because
  /// MealSlot and GeneratedRecipe have different field shapes.
  static String? _findAllergenViolation(
    MealSlot meal,
    List<String> allergens,
  ) {
    if (allergens.isEmpty) return null;
    final haystacks = <String>[
      meal.title,
      meal.description,
      ...meal.ingredients.map((i) => i.name),
      ...meal.steps,
    ].map((s) => s.toLowerCase()).toList();

    for (final allergen in allergens) {
      final needle = allergen.trim().toLowerCase();
      if (needle.isEmpty) continue;
      for (final hay in haystacks) {
        if (hay.contains(needle)) return allergen;
      }
    }
    return null;
  }

  // ── Phase 2: on-demand detail for a single meal ────────────────────────────────
  // Given a Phase 1 summary (title + ingredients), fetches steps, nutrition,
  // and substitutions. Returns an updated MealSlot with detail merged in.
  static Future<MealSlot> generateMealDetail(MealSlot summary) async {
    final ingredientNames = summary.ingredients.map((i) => i.name).join(', ');
    final prompt = StringBuffer()
      ..writeln('Given this meal, generate cooking steps, nutrition, and substitutions.')
      ..writeln('Title: ${summary.title}')
      ..writeln('Description: ${summary.description}')
      ..writeln('Ingredients: $ingredientNames')
      ..writeln('Servings: ${summary.servings}')
      ..writeln('3-6 concise steps (1-2 sentences each). Nutrition per serving. 1-2 substitutions.')
      ..writeln('Schema: {steps[], nutrition{calories,proteinG,carbsG,fatG,fibreG}, substitutions[{original,substitute,tradeOff}]}');

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [{'text': prompt.toString()}]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 512,
          'responseMimeType': 'application/json',
        },
      }),
    ).timeout(const Duration(seconds: 45));

    _checkHttpErrors(response);

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Could not load meal detail. Please try again.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Empty detail response. Please try again.');
    }

    final rawText = parts.last['text'] as String? ?? '';
    final detailJson = _extractJson(rawText);

    final steps = (detailJson['steps'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final nutrition = detailJson['nutrition'] != null
        ? NutritionInfo.fromJson(detailJson['nutrition'] as Map<String, dynamic>)
        : null;
    final substitutions = (detailJson['substitutions'] as List<dynamic>? ?? [])
        .map((e) => RecipeSubstitution.fromJson(e as Map<String, dynamic>))
        .toList();

    return summary.copyWithDetail(
      steps: steps,
      nutrition: nutrition,
      substitutions: substitutions,
    );
  }

  // ── HTTP error handling ───────────────────────────────────────────────────────
  static void _checkHttpErrors(http.Response response) {
    if (response.statusCode == 429) {
      throw Exception('Rate limit reached. Please wait a minute and try again.');
    }
    if (response.statusCode == 400) {
      throw Exception('Invalid request. Please try again.');
    }
    if (response.statusCode == 403) {
      throw Exception('API access denied. Please check your API key.');
    }
    if (response.statusCode != 200) {
      throw Exception('Service error (${response.statusCode}). Please try again.');
    }
  }

  // ── JSON extraction ───────────────────────────────────────────────────────────
  // With responseMimeType: application/json, direct parse should always work.
  // Minimal fallback kept as safety net.
  static Map<String, dynamic> _extractJson(String text) {
    text = text.trim();

    if (text.startsWith('{')) {
      try { return jsonDecode(text) as Map<String, dynamic>; } catch (_) {}
    }

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      try { return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>; } catch (_) {}
    }

    throw Exception('Could not parse meal plan JSON. Please try again.');
  }

  // ── Prompt builders ───────────────────────────────────────────────────────────
  static String _buildWeeklyPrompt({
    required List<String> dietaryRequirements,
    required List<String> alwaysHave,
    required List<String> almostAlwaysHave,
    required List<String> stylePreferences,
    required List<String> selectedDays,
    required List<MealType> selectedMealTypes,
    required int servings,
  }) {
    final buffer = StringBuffer();
    final mealNames = selectedMealTypes.map((m) => m.name).join(', ');
    final totalMeals = selectedDays.length * selectedMealTypes.length;

    buffer.writeln('Generate a ${selectedDays.length}-day meal plan ($totalMeals meals: $mealNames/day) as JSON.');

    if (dietaryRequirements.isNotEmpty) {
      buffer.writeln('Dietary: ${dietaryRequirements.join(', ')} — strict for ALL meals.');
    }

    if (alwaysHave.isNotEmpty) buffer.writeln('Pantry: ${alwaysHave.join(', ')}');
    if (almostAlwaysHave.isNotEmpty) buffer.writeln('Usually have: ${almostAlwaysHave.join(', ')}');

    if (stylePreferences.isNotEmpty) {
      buffer.writeln('Styles: ${stylePreferences.join(', ')} — vary across week, use as inspiration.');
    }

    buffer.writeln('Rules: $servings servings/meal. Home-cooking titles, raw/purchasable ingredients only. No repeats. Breakfast <15min. Max 8 ingredients. Maximise ingredient crossover across days to reduce waste.');
    buffer.writeln('Days: ${selectedDays.join(', ')}. Meals: $mealNames.');
    buffer.writeln('Include estimatedCostPerServingUSD and estimatedCostPerServingGBP (budget/own-brand pricing).');
    buffer.writeln('Do NOT include steps, nutrition, or substitutions — only summaries.');

    // Phase 1 schema — no steps/nutrition/substitutions
    buffer.writeln('Schema: {days:[{dayName, breakfast/lunch/dinner:{title, description(1 sentence), prepTimeMinutes, cookTimeMinutes, servings, dietaryTags[], ingredients[{name,quantity,unit}], estimatedCostPerServingUSD, estimatedCostPerServingGBP}}]}');

    return buffer.toString();
  }

  /// Sprint 15.9.3: this prompt was missing user preferences — appliances
  /// and runningLow especially. When the user taps "regenerate" on a
  /// single meal, that meal should reflect their setup (no oven recipes
  /// for users without one, AVOID running-low items as the star, etc.)
  /// even though the weekly plan generation stays light.
  static String _buildSingleMealPrompt({
    required String dayName,
    required MealType mealType,
    required List<String> dietaryRequirements,
    required List<String> alwaysHave,
    required List<String> almostAlwaysHave,
    required List<String> existingTitles,
    required int servings,
    List<String> appliances = const [],
    List<String> runningLowItems = const [],
    List<String> customAllergens = const [],
  }) {
    final buffer = StringBuffer();

    buffer.writeln('Generate ONE ${mealType.displayName.toLowerCase()} for $dayName as JSON.');

    if (dietaryRequirements.isNotEmpty) {
      buffer.writeln('Dietary: ${dietaryRequirements.join(', ')} — strict.');
    }
    // Sprint 15.9.3 SAFETY: allergens get a separate, maximally strong
    // exclusion line. Use ALL CAPS for the action verb so Gemini doesn't
    // soften it.
    if (customAllergens.isNotEmpty) {
      buffer.writeln(
          'ALLERGENS — STRICTLY EXCLUDE these and anything containing them: ${customAllergens.join(', ')}. Treat as medical safety, not preference. No exceptions.');
    }
    if (alwaysHave.isNotEmpty) buffer.writeln('Pantry: ${alwaysHave.join(', ')}');
    if (almostAlwaysHave.isNotEmpty) buffer.writeln('Usually have: ${almostAlwaysHave.join(', ')}');
    if (runningLowItems.isNotEmpty) {
      buffer.writeln(
          'Running low (AVOID — do NOT make these the star, treat as optional): ${runningLowItems.join(', ')}.');
    }
    if (appliances.isNotEmpty) {
      buffer.writeln(
          'Available appliances: ${appliances.join(', ')}. Recipe must work with these — don\'t require anything else.');
    }
    if (existingTitles.isNotEmpty) {
      buffer.writeln('Avoid repeats: ${existingTitles.join(', ')}');
    }

    buffer.writeln('$servings servings. Max 8 ingredients. Home-cooking title, raw ingredients only.');
    if (mealType == MealType.breakfast) {
      buffer.writeln('Breakfast — under 15min total.');
    }

    buffer.writeln('Schema: {title, description(1 sentence), prepTimeMinutes, cookTimeMinutes, servings, dietaryTags[], ingredients[{name,quantity,unit}], steps[], nutrition{calories,proteinG,carbsG,fatG,fibreG}, estimatedCostPerServingUSD, estimatedCostPerServingGBP, substitutions[{original,substitute,tradeOff}]}');

    return buffer.toString();
  }
}
