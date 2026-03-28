import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe_models.dart';

// ─────────────────────────────────────────────
// GeminiService
// Calls the Gemini 2.5 Flash API to generate recipes.
//
// Key fixes (Sprint 4 patch):
//   • maxOutputTokens raised to 4096 — prevents truncated JSON
//   • Prompt instructs model to keep steps concise to stay within limit
//   • JSON extraction is more robust: handles missing fences, extra text
//   • Up to 2 automatic retries on parse failure
//   • Daily cap is only incremented AFTER a successful parse (in home_screen)
// ─────────────────────────────────────────────

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _model = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static Future<GeneratedRecipe> generateRecipe(RecipeGenerationRequest request) async {
    Exception? lastError;

    // Up to 2 attempts — Gemini occasionally produces malformed JSON
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        return await _attemptGeneration(request);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        // Only retry on parse errors, not on HTTP/auth errors
        if (e.toString().contains('rate limit') ||
            e.toString().contains('access denied') ||
            e.toString().contains('Invalid request')) {
          rethrow;
        }
        // Brief pause before retry
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    throw lastError ?? Exception('Recipe generation failed. Please try again.');
  }

  static Future<GeneratedRecipe> _attemptGeneration(RecipeGenerationRequest request) async {
    final prompt = _buildPrompt(request);

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.8,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 4096,
          'responseMimeType': 'application/json',
          'thinkingConfig': {'thinkingBudget': 0},
        },
      }),
    );

    if (response.statusCode == 429) {
      throw Exception('Recipe generation is temporarily unavailable (rate limit reached). Please wait a minute and try again.');
    }
    if (response.statusCode == 400) {
      throw Exception('Invalid request to recipe service. Please try again.');
    }
    if (response.statusCode == 403) {
      throw Exception('Recipe service access denied. Please check your API key.');
    }
    if (response.statusCode != 200) {
      throw Exception('Recipe service error (${response.statusCode}). Please try again.');
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;

    // Check for finish reason — STOP is good, MAX_TOKENS means truncation
    final candidates = responseData['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No recipe generated. Please try again.');
    }

    final finishReason = candidates[0]['finishReason'] as String? ?? 'STOP';
    if (finishReason == 'MAX_TOKENS') {
      throw Exception('Response was too long and got cut off. Retrying with a shorter recipe...');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Empty response from AI. Please try again.');
    }

    String rawText = parts[0]['text'] as String? ?? '';
    final recipeJson = _extractJson(rawText);
    return GeneratedRecipe.fromJson(recipeJson);
  }

  /// Robustly extract a JSON object from a string that may contain
  /// markdown fences, leading/trailing prose, or other noise.
  static Map<String, dynamic> _extractJson(String text) {
    text = text.trim();

    // 1. If responseMimeType worked, the whole body IS the JSON
    if (text.startsWith('{')) {
      try {
        return jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        // Fall through to fence stripping
      }
    }

    // 2. Strip markdown code fences (```json ... ``` or ``` ... ```)
    final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
    final fenceMatch = fencePattern.firstMatch(text);
    if (fenceMatch != null) {
      final inner = fenceMatch.group(1)?.trim() ?? '';
      if (inner.isNotEmpty) {
        try {
          return jsonDecode(inner) as Map<String, dynamic>;
        } catch (_) {
          // Fall through to brace extraction
        }
      }
    }

    // 3. Find outermost { ... } braces
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      final candidate = text.substring(start, end + 1);
      try {
        return jsonDecode(candidate) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Could not parse recipe JSON: ${e.toString().substring(0, 80)}');
      }
    }

    throw Exception('No JSON object found in AI response. Please try again.');
  }

  static String _buildPrompt(RecipeGenerationRequest request) {
    final buffer = StringBuffer();

    buffer.writeln('You are Elio, a friendly AI cooking assistant. Generate ONE recipe as valid JSON.');
    buffer.writeln();
    buffer.writeln('IMPORTANT: Your ENTIRE response must be a single valid JSON object. No prose before or after. No markdown fences.');
    buffer.writeln();
    buffer.writeln('## HARD CONSTRAINTS (never override):');

    if (request.dietaryRequirements.isNotEmpty) {
      buffer.writeln('Dietary: ${request.dietaryRequirements.join(', ')} — strictly enforced.');
    } else {
      buffer.writeln('No dietary restrictions.');
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

      if (request.perishables.isNotEmpty) {
        buffer.writeln('Fresh items (use these): ${request.perishables.join(', ')}');
      } else {
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
    if (request.stylePreference != null) {
      buffer.writeln(request.stylePreference == 'Surprise me'
          ? 'Style: Be creative — any cuisine.'
          : 'Style: ${request.stylePreference}');
    }
    if (request.moodPreference != null) buffer.writeln('Mood: ${request.moodPreference}');
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

    if (request.recentTitles.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## RECENTLY GENERATED (do NOT repeat these recipes — generate something different):');
      for (final title in request.recentTitles) {
        buffer.writeln('- $title');
      }
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
}
