import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe_models.dart';
import '../utils/region_utils.dart';
import 'remote_config_service.dart';

// ─────────────────────────────────────────────
// GeminiService
// Calls Gemini 2.5 Flash-Lite to generate recipes.
//
// Cost optimisations (Sprint 15):
//   • Switched to gemini-2.5-flash-lite (~35% cheaper, no thinking tokens)
//   • responseMimeType: application/json — guaranteed clean JSON
//   • Prompt compressed ~50% — fewer input tokens per call
//   • maxOutputTokens capped at 2048 (single recipe ≈ 500-800 tokens)
// ─────────────────────────────────────────────

class GeminiService {
  static String get _apiKey => RemoteConfigService.instance.geminiApiKey;
  static const String _model = 'gemini-2.5-flash-lite';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static Future<GeneratedRecipe> generateRecipe(RecipeGenerationRequest request) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        return await _attemptGeneration(request);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (e.toString().contains('rate limit') ||
            e.toString().contains('access denied') ||
            e.toString().contains('Invalid request')) {
          rethrow;
        }
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
          'maxOutputTokens': 2048,
          'responseMimeType': 'application/json',
        },
      }),
    ).timeout(const Duration(seconds: 60), onTimeout: () {
      throw Exception('Recipe generation timed out. Please try again.');
    });

    if (response.statusCode == 429) {
      throw Exception('Recipe generation is temporarily unavailable (rate limit reached). Please wait a minute and try again.');
    }
    if (response.statusCode == 400) {
      throw Exception('Invalid request to recipe service (400). Please try again.');
    }
    if (response.statusCode == 403) {
      throw Exception('Recipe service access denied. Please check your API key.');
    }
    if (response.statusCode == 404) {
      throw Exception('Recipe service unavailable (model not found). Please try again.');
    }
    if (response.statusCode != 200) {
      throw Exception('Recipe service error (${response.statusCode}). Please try again.');
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;

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

    final rawText = parts.last['text'] as String? ?? '';
    final recipeJson = _extractJson(rawText);
    return GeneratedRecipe.fromJson(recipeJson);
  }

  /// Extract JSON from response. With responseMimeType set, the response
  /// should already be clean JSON, but we keep a minimal fallback.
  static Map<String, dynamic> _extractJson(String text) {
    text = text.trim();

    // 1. Direct parse — expected path with responseMimeType: application/json
    if (text.startsWith('{')) {
      try {
        return jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {}
    }

    // 2. Fallback: find outermost braces
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

    buffer.writeln('Generate ONE recipe as JSON.');

    // Region & units
    final units = RegionUtils.measurementUnits;
    final appRegion = RegionUtils.region;
    if (units == 'imperial') {
      buffer.writeln('Units: imperial (oz, cups, °F).');
    } else {
      buffer.writeln('Units: metric (g, ml, °C).');
    }
    if (appRegion == AppRegion.uk) {
      buffer.writeln('Region: UK (GBP, UK ingredient names).');
    } else {
      buffer.writeln('Region: US (USD, US ingredient names).');
    }

    // Dietary
    if (request.dietaryRequirements.isNotEmpty) {
      buffer.writeln('Dietary: ${request.dietaryRequirements.join(', ')} — strict.');
    }

    // ── Leftover mode ──
    if (request.isLeftoverMode && request.leftoverItems.isNotEmpty) {
      buffer.writeln('LEFTOVER MODE — build recipe around: ${request.leftoverItems.join(', ')}. Minimise waste.');
      if (request.alwaysHave.isNotEmpty) {
        buffer.writeln('Pantry: ${request.alwaysHave.join(', ')}');
      }
      if (request.almostAlwaysHave.isNotEmpty) {
        buffer.writeln('Usually have: ${request.almostAlwaysHave.join(', ')}');
      }
    } else {
      // Normal mode inventory
      if (request.perishableInventoryDescriptions.isNotEmpty) {
        buffer.writeln('PERISHABLE (use first): ${request.perishableInventoryDescriptions.join(', ')}');
      }
      if (request.perishables.isNotEmpty) {
        buffer.writeln('Fresh: ${request.perishables.join(', ')}');
      } else if (request.perishableInventoryDescriptions.isEmpty) {
        buffer.writeln('No fresh items — use pantry staples.');
      }
      if (request.alwaysHave.isNotEmpty) {
        buffer.writeln('Pantry: ${request.alwaysHave.join(', ')}');
      }
      if (request.almostAlwaysHave.isNotEmpty) {
        buffer.writeln('Usually have: ${request.almostAlwaysHave.join(', ')}');
      }
    }

    // Preferences
    if (request.timePreference != null) buffer.writeln('Time: ${request.timePreference}');
    if (request.stylePreference != null) {
      buffer.writeln(request.stylePreference == 'Surprise me'
          ? 'Style: any cuisine, be creative.'
          : 'Style: ${request.stylePreference}');
    }
    if (request.moodPreference != null) buffer.writeln('Mood: ${request.moodPreference}');
    buffer.writeln('Servings: ${request.servings}');

    if (request.runningLowItems.isNotEmpty) {
      buffer.writeln('RUNNING LOW (use sparingly): ${request.runningLowItems.join(', ')}');
    }
    if (request.excludedIngredients.isNotEmpty) {
      buffer.writeln('EXCLUDED: ${request.excludedIngredients.join(', ')}');
    }
    if (request.appliances.isNotEmpty) {
      buffer.writeln('Appliances: ${request.appliances.join(', ')}');
    }
    if (request.recentTitles.isNotEmpty) {
      buffer.writeln('AVOID (recently generated): ${request.recentTitles.join(', ')}');
    }

    // Taste profile
    if (request.likedRecipes.isNotEmpty) {
      buffer.writeln('Liked: ${request.likedRecipes.take(5).join(', ')} — lean into similar styles.');
    }
    if (request.dislikedRecipes.isNotEmpty) {
      buffer.writeln('Disliked: ${request.dislikedRecipes.take(5).join(', ')} — avoid similar.');
    }

    if (request.isSaverMode) {
      buffer.writeln('BUDGET MODE: under £2/\$3 per serving, own-brand pricing, bulk staples.');
    }

    // Rules (compressed)
    buffer.writeln('Rules: home-cooking title (not pre-made product names). Raw/purchasable ingredients only. Max 10 ingredients, max 8 steps (1-2 sentences). estimatedCost: budget/own-brand pricing, exclude pantry staples, err low.');

    // Compact schema
    buffer.writeln('Schema: {title, description(1-2 sentences), prepTimeMinutes, cookTimeMinutes, servings, dietaryTags[], ingredients[{name,quantity,unit,fromInventory}], steps[], substitutions[{original,substitute,tradeOff}], nutrition{calories,proteinG,carbsG,fatG,fibreG}, estimatedCostPerServingUSD, estimatedCostPerServingGBP}');

    return buffer.toString();
  }
}
