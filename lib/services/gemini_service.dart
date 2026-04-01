import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe_models.dart';
import '../utils/region_utils.dart';
import 'remote_config_service.dart';

// ─────────────────────────────────────────────
// GeminiService
// Calls the Gemini 2.5 Flash API to generate recipes.
//
// Uses streaming (SSE) for recipe generation to improve
// perceived speed. JSON mode + thinking disabled for
// guaranteed valid JSON without overhead.
//
// Substitutions use a separate batch call (flash-lite).
// ─────────────────────────────────────────────

class GeminiService {
  static String get _apiKey => RemoteConfigService.instance.geminiApiKey;
  static const String _model = 'gemini-2.5-flash';
  static const String _streamUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:streamGenerateContent';

  /// Convenience wrapper — awaits the stream and returns the final recipe.
  /// Used by recipe_screen.dart (remove & regenerate) and anywhere that
  /// doesn't need streaming UI updates.
  static Future<GeneratedRecipe> generateRecipe(RecipeGenerationRequest request) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        GeneratedRecipe? result;
        await for (final status in generateRecipeStream(request)) {
          switch (status) {
            case RecipeComplete():
              result = status.recipe;
            case RecipeError():
              throw Exception(status.message);
            case RecipeGenerating():
              break;
          }
        }
        if (result != null) return result;
        throw Exception('Recipe generation completed without a result.');
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

  /// Streaming recipe generation — yields status updates as chunks arrive.
  /// Subscribe to this from the home screen for skeleton/shimmer UI.
  static Stream<RecipeGenerationStatus> generateRecipeStream(RecipeGenerationRequest request) async* {
    final prompt = _buildPrompt(request);
    final client = http.Client();

    try {
      final httpRequest = http.Request(
        'POST',
        Uri.parse('$_streamUrl?alt=sse&key=$_apiKey'),
      );
      httpRequest.headers['Content-Type'] = 'application/json';
      httpRequest.body = jsonEncode({
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
      });

      final streamedResponse = await client.send(httpRequest).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Recipe generation timed out. Please try again.'),
      );

      // Check HTTP status before reading the stream
      if (streamedResponse.statusCode == 429) {
        yield RecipeError(message: 'Recipe generation is temporarily unavailable (rate limit reached). Please wait a minute and try again.');
        return;
      }
      if (streamedResponse.statusCode == 400) {
        yield RecipeError(message: 'Invalid request to recipe service (400). Please try again.');
        return;
      }
      if (streamedResponse.statusCode == 403) {
        yield RecipeError(message: 'Recipe service access denied. Please check your API key.');
        return;
      }
      if (streamedResponse.statusCode == 404) {
        yield RecipeError(message: 'Recipe service unavailable (model not found). Please try again.');
        return;
      }
      if (streamedResponse.statusCode != 200) {
        yield RecipeError(message: 'Recipe service error (${streamedResponse.statusCode}). Please try again.');
        return;
      }

      // Parse SSE stream — accumulate text chunks
      final buffer = StringBuffer();
      int totalBytes = 0;
      String? finishReason;

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        totalBytes += chunk.length;
        yield RecipeGenerating(bytesReceived: totalBytes);

        // SSE format: lines starting with "data: " followed by JSON
        for (final line in chunk.split('\n')) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('data: ')) continue;
          final jsonStr = trimmed.substring(6); // Strip "data: " prefix
          if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

          try {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            final candidates = data['candidates'] as List<dynamic>?;
            if (candidates == null || candidates.isEmpty) continue;

            // Capture finish reason from the final chunk
            final fr = candidates[0]['finishReason'] as String?;
            if (fr != null) finishReason = fr;

            final content = candidates[0]['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts == null) continue;

            for (final part in parts) {
              final text = part['text'] as String?;
              if (text != null) buffer.write(text);
            }
          } catch (_) {
            // Malformed SSE chunk — skip and continue accumulating
          }
        }
      }

      // Stream complete — check finish reason and parse
      if (finishReason == 'MAX_TOKENS') {
        yield RecipeError(message: 'Response was too long and got cut off. Please try again.');
        return;
      }

      final rawText = buffer.toString().trim();
      if (rawText.isEmpty) {
        yield RecipeError(message: 'Empty response from AI. Please try again.');
        return;
      }

      final recipeJson = _extractJson(rawText);
      yield RecipeComplete(recipe: GeneratedRecipe.fromJson(recipeJson));
    } catch (e) {
      yield RecipeError(
        message: e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Recipe generation failed. Please try again.',
      );
    } finally {
      client.close();
    }
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

    // Measurement units and region
    final units = RegionUtils.measurementUnits;
    if (units == 'imperial') {
      buffer.writeln('Use imperial measurements (ounces, cups, Fahrenheit) for all quantities and temperatures.');
    } else {
      buffer.writeln('Use metric measurements (grams, millilitres, Celsius) for all quantities and temperatures.');
    }
    final appRegion = RegionUtils.region;
    if (appRegion == AppRegion.uk) {
      buffer.writeln('User is in the United Kingdom — use GBP for cost estimates and UK ingredient names.');
    } else {
      buffer.writeln('User is in the United States — use USD for cost estimates and US ingredient names.');
    }

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

      // Perishable inventory items with urgency (from pantry perishable tier)
      if (request.perishableInventoryDescriptions.isNotEmpty) {
        buffer.writeln('PERISHABLE ITEMS (use these first): ${request.perishableInventoryDescriptions.join(', ')}');
      }

      if (request.perishables.isNotEmpty) {
        buffer.writeln('Fresh items (use these): ${request.perishables.join(', ')}');
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

  /// Lightweight Gemini call to suggest a single ingredient substitution.
  /// Designed to be fast and cheap — ~150 output tokens max.
  static Future<IngredientSubstitutionResult> generateSubstitution({
    required String ingredientName,
    required String ingredientQuantity,
    required String ingredientUnit,
    required String recipeTitle,
    required List<String> otherIngredients,
    required List<String> dietaryRequirements,
  }) async {
    final qty = ingredientUnit.isEmpty
        ? ingredientQuantity
        : '$ingredientQuantity $ingredientUnit';

    final prompt = StringBuffer()
      ..writeln('Recipe: "$recipeTitle".')
      ..writeln('I don\'t have: $qty $ingredientName.')
      ..writeln('Other ingredients in recipe: ${otherIngredients.join(', ')}.');
    if (dietaryRequirements.isNotEmpty) {
      prompt.writeln('Dietary: ${dietaryRequirements.join(', ')} — strict.');
    }
    prompt.writeln('Suggest ONE substitute that works in this recipe. Return JSON: {substitute, adjustedQuantity, unit, tradeOff(1 sentence)}.');

    // Use flash-lite for substitutions (cheap, fast)
    const subModel = 'gemini-2.5-flash-lite';
    const subUrl = 'https://generativelanguage.googleapis.com/v1beta/models/$subModel:generateContent';

    final response = await http.post(
      Uri.parse('$subUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt.toString()}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.6,
          'maxOutputTokens': 256,
          'responseMimeType': 'application/json',
        },
      }),
    ).timeout(const Duration(seconds: 15), onTimeout: () {
      throw Exception('Substitution request timed out. Please try again.');
    });

    if (response.statusCode != 200) {
      throw Exception('Substitution failed (${response.statusCode}): ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}');
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No substitution suggested. Please try again.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Empty substitution response.');
    }

    // Skip thinking parts if present
    final textParts = parts.where((p) => p['thought'] != true).toList();
    final rawText = textParts.isNotEmpty
        ? (textParts.last['text'] as String? ?? '')
        : (parts.last['text'] as String? ?? '');

    if (rawText.isEmpty) {
      throw Exception('Empty text in substitution response. Parts: ${parts.length}');
    }

    final json = _extractJson(rawText);
    return IngredientSubstitutionResult.fromJson(json);
  }
}
