import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/meal_plan_models.dart';

// ─────────────────────────────────────────────
// MealPlanService
// Calls Gemini 2.0 Flash to generate a full 7-day meal plan
// or a single replacement meal.
//
// The full-week prompt asks for all 21 meals in one call.
// This is more efficient than 21 separate calls and ensures
// variety across the week (Gemini sees the full context).
//
// Token budget: 21 meals × ~150 tokens each ≈ 3150 tokens.
// We request 6000 to be safe.
// ─────────────────────────────────────────────

class MealPlanService {
  static const String _apiKey = 'AIzaSyCZvDMHsOI3NZjNaAes84LJvyg6yLrfKuU';
  static const String _model = 'gemini-flash-latest';
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
          'maxOutputTokens': 8192,
          'responseMimeType': 'application/json',
        },
      }),
    );

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

    final rawText = parts[0]['text'] as String? ?? '';
    final planJson = _extractJson(rawText);

    // Parse the 7-day structure
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
    required List<String> existingTitles, // avoid repeats
    int servings = 2,
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
  }) async {
    final prompt = _buildSingleMealPrompt(
      dayName: dayName,
      mealType: mealType,
      dietaryRequirements: dietaryRequirements,
      alwaysHave: alwaysHave,
      almostAlwaysHave: almostAlwaysHave,
      existingTitles: existingTitles,
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
          'temperature': 0.9,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
          'responseMimeType': 'application/json',
        },
      }),
    );

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

    final rawText = parts[0]['text'] as String? ?? '';
    final mealJson = _extractJson(rawText);
    return MealSlot.fromJson(mealJson);
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
  static Map<String, dynamic> _extractJson(String text) {
    text = text.trim();

    if (text.startsWith('{')) {
      try { return jsonDecode(text) as Map<String, dynamic>; } catch (_) {}
    }

    final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
    final fenceMatch = fencePattern.firstMatch(text);
    if (fenceMatch != null) {
      final inner = fenceMatch.group(1)?.trim() ?? '';
      if (inner.isNotEmpty) {
        try { return jsonDecode(inner) as Map<String, dynamic>; } catch (_) {}
      }
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

    buffer.writeln('You are Elio, an AI cooking assistant. Generate a meal plan for ${selectedDays.length} days ($totalMeals meals total: $mealNames for each day) as valid JSON.');
    buffer.writeln('Your ENTIRE response must be a single valid JSON object. No prose, no markdown fences.');
    buffer.writeln();
    buffer.writeln('## HARD CONSTRAINTS:');

    if (dietaryRequirements.isNotEmpty) {
      buffer.writeln('Dietary: ${dietaryRequirements.join(', ')} — strictly enforced for ALL meals.');
    } else {
      buffer.writeln('No dietary restrictions.');
    }

    buffer.writeln();
    buffer.writeln('## PANTRY (items the user always has):');
    if (alwaysHave.isNotEmpty) buffer.writeln(alwaysHave.join(', '));
    if (almostAlwaysHave.isNotEmpty) buffer.writeln('Usually have: ${almostAlwaysHave.join(', ')}');

    if (stylePreferences.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## STYLE PREFERENCES: ${stylePreferences.join(', ')}');
      buffer.writeln('Vary cuisines across the week. Use these as inspiration, not a strict rule.');
    }

    buffer.writeln();
    buffer.writeln('## RULES:');
    buffer.writeln('- Servings: $servings per meal.');
    buffer.writeln('- Vary meals across the week — no repeated dishes.');
    buffer.writeln('- Breakfast should be quick (under 15 min). Lunch moderate. Dinner can be more involved.');
    buffer.writeln('- Each meal: max 8 ingredients, description 1 sentence, 3-6 cooking steps.');
    buffer.writeln('- Keep ingredient quantities realistic for $servings servings.');
    buffer.writeln('- ONLY generate meals for the following days: ${selectedDays.join(', ')}.');
    buffer.writeln('- ONLY generate the following meal types per day: $mealNames.');

    buffer.writeln();
    buffer.writeln('- Include caloriesPerServing (integer kcal), estimatedCostPerServingUSD, and estimatedCostPerServingGBP for each meal (budget/own-brand pricing).');
    buffer.writeln();
    buffer.writeln('## JSON SCHEMA (return EXACTLY this structure with all 7 days):');
    buffer.writeln('''
{
  "days": [
    {
      "dayName": "Monday",
      "breakfast": {
        "title": "string",
        "description": "string",
        "prepTimeMinutes": 5,
        "cookTimeMinutes": 10,
        "dietaryTags": ["string"],
        "ingredients": [{"name": "string", "quantity": "string", "unit": "string"}],
        "steps": ["Step 1: ...", "Step 2: ...", "Step 3: ..."],
        "caloriesPerServing": 400,
        "estimatedCostPerServingUSD": 3.50,
        "estimatedCostPerServingGBP": 2.80
      },
      "lunch": { ... same structure ... },
      "dinner": { ... same structure ... }
    },
    ... repeat for Tuesday through Sunday ...
  ]
}''');

    return buffer.toString();
  }

  static String _buildSingleMealPrompt({
    required String dayName,
    required MealType mealType,
    required List<String> dietaryRequirements,
    required List<String> alwaysHave,
    required List<String> almostAlwaysHave,
    required List<String> existingTitles,
    required int servings,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('You are Elio. Generate ONE ${mealType.displayName.toLowerCase()} meal for $dayName as valid JSON.');
    buffer.writeln('Your ENTIRE response must be a single valid JSON object. No prose, no markdown fences.');
    buffer.writeln();

    if (dietaryRequirements.isNotEmpty) {
      buffer.writeln('Dietary constraints: ${dietaryRequirements.join(', ')} — strictly enforced.');
    }

    if (alwaysHave.isNotEmpty) {
      buffer.writeln('Pantry: ${alwaysHave.join(', ')}');
    }
    if (almostAlwaysHave.isNotEmpty) {
      buffer.writeln('Usually have: ${almostAlwaysHave.join(', ')}');
    }

    if (existingTitles.isNotEmpty) {
      buffer.writeln('Do NOT repeat these meals: ${existingTitles.join(', ')}');
    }

    buffer.writeln('Servings: $servings. Max 8 ingredients. Description: 1 sentence.');

    if (mealType == MealType.breakfast) {
      buffer.writeln('This is breakfast — keep it quick (under 15 min total).');
    }

    buffer.writeln();
    buffer.writeln('JSON schema:');
    buffer.writeln('''
{
  "title": "string",
  "description": "string",
  "prepTimeMinutes": 5,
  "cookTimeMinutes": 10,
  "dietaryTags": ["string"],
  "ingredients": [{"name": "string", "quantity": "string", "unit": "string"}],
  "steps": ["Step 1: ...", "Step 2: ...", "Step 3: ..."],
  "caloriesPerServing": 400,
  "estimatedCostPerServingUSD": 3.50,
  "estimatedCostPerServingGBP": 2.80
}''');
    return buffer.toString();
  }
}
