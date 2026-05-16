import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/recipe_models.dart';
import '../utils/json_extractor.dart';
import '../utils/region_utils.dart';
import 'error_service.dart';
import 'gemini_prompt_builder.dart';
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
  static final _httpClient = http.Client();

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
        ErrorService.log('recipe_generation', lastError);
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
    yield* _streamFromPrompt(
      buildRecipePrompt(
        request,
        region: RegionUtils.region == AppRegion.uk ? 'uk' : 'us',
        measurementUnits: RegionUtils.measurementUnits,
      ),
      maxOutputTokens: 1024,
    );
  }

  /// Shared streaming logic — sends prompt to Gemini SSE endpoint,
  /// parses chunks, and yields status updates.
  static Stream<RecipeGenerationStatus> _streamFromPrompt(
    String prompt, {
    required int maxOutputTokens,
  }) async* {
    final client = _httpClient;

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
          'maxOutputTokens': maxOutputTokens,
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

      final recipeJson = extractJsonObject(rawText);
      yield RecipeComplete(recipe: GeneratedRecipe.fromJson(recipeJson));
    } catch (e) {
      ErrorService.log('recipe_generation_stream', e);
      yield RecipeError(
        message: e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Recipe generation failed. Please try again.',
      );
    }
  }

  /// Streaming bulk recipe generation — uses the bulk prep prompt for
  /// batch cooking / freezing recipes with higher token limit.
  static Stream<RecipeGenerationStatus> generateBulkRecipeStream(
    RecipeGenerationRequest request, {
    required int portions,
    required int mealNumber,
    required int totalMeals,
    required List<String> previousMealTitles,
  }) async* {
    yield* _streamFromPrompt(
      buildBulkPrepPrompt(
        request,
        region: RegionUtils.region == AppRegion.uk ? 'uk' : 'us',
        measurementUnits: RegionUtils.measurementUnits,
        portions: portions,
        mealNumber: mealNumber,
        totalMeals: totalMeals,
        previousMealTitles: previousMealTitles,
      ),
      maxOutputTokens: 2048,
    );
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

    final json = extractJsonObject(rawText);
    return IngredientSubstitutionResult.fromJson(json);
  }

  /// Import a recipe from a photo using Gemini Vision.
  /// Extracts title, ingredients, steps, and other details from a recipe image.
  static Future<GeneratedRecipe> importRecipeFromImage(Uint8List imageBytes) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    const prompt = 'Extract the recipe from this image. Return a JSON object with: '
        '{"title":"string","description":"string (1-2 sentences)","prepTimeMinutes":int,"cookTimeMinutes":int,"servings":int,'
        '"dietaryTags":["string"],"ingredients":[{"name":"string","quantity":"string","unit":"string","fromInventory":false}],'
        '"steps":["string"],"substitutions":[]}. '
        'If prep/cook time is not visible, estimate based on the recipe. '
        'If servings is not visible, default to 2. '
        'Clean up ingredient names (remove codes/abbreviations). '
        'Keep steps concise (1-2 sentences each). '
        'If the image is not a recipe or is unreadable, return {"error":"Could not extract recipe from image"}.';

    final content = Content.multi([
      TextPart(prompt),
      DataPart('image/jpeg', imageBytes),
    ]);

    final response = await model.generateContent([content]);
    final rawText = response.text ?? '';
    if (rawText.isEmpty) {
      throw Exception('Empty response from AI. Please try a clearer photo.');
    }

    final json = extractJsonObject(rawText);
    if (json.containsKey('error')) {
      throw Exception(json['error'] as String);
    }

    return GeneratedRecipe.fromJson(json);
  }

  /// Import a recipe from a URL by fetching the webpage, stripping HTML,
  /// and sending the text to Gemini Flash-Lite for extraction.
  static Future<GeneratedRecipe> importRecipeFromUrl(String url) async {
    // Fetch the webpage
    final response = await _httpClient.get(Uri.parse(url)).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Could not reach that URL. Please check it and try again.'),
    );

    if (response.statusCode != 200) {
      throw Exception('Could not fetch the page (${response.statusCode}). Please check the URL.');
    }

    // Strip HTML tags to get plain text
    final plainText = response.body
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Truncate to ~8000 chars (webpages are big)
    final truncated = plainText.length > 8000 ? plainText.substring(0, 8000) : plainText;

    final prompt = 'Extract the recipe from this webpage text. Return a JSON object with: '
        '{"title":"string","description":"string (1-2 sentences)","prepTimeMinutes":int,"cookTimeMinutes":int,"servings":int,'
        '"dietaryTags":["string"],"ingredients":[{"name":"string","quantity":"string","unit":"string","fromInventory":false}],'
        '"steps":["string"],"substitutions":[],"tips":"string (optional, empty string if none)"}. '
        'If prep/cook time is not visible, estimate based on the recipe. '
        'If servings is not visible, default to 2. '
        'Keep steps concise (1-2 sentences each). '
        'If the text does not contain a recipe, return {"error":"Could not extract a recipe from this page"}.\n\n'
        'Webpage text:\n$truncated';

    const urlModel = 'gemini-2.5-flash-lite';
    const urlEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/$urlModel:generateContent';

    final aiResponse = await http.post(
      Uri.parse('$urlEndpoint?key=$_apiKey'),
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
          'temperature': 0.6,
          'maxOutputTokens': 1024,
          'responseMimeType': 'application/json',
        },
      }),
    ).timeout(const Duration(seconds: 30), onTimeout: () {
      throw Exception('Recipe extraction timed out. Please try again.');
    });

    if (aiResponse.statusCode != 200) {
      throw Exception('Recipe extraction failed (${aiResponse.statusCode}). Please try again.');
    }

    final responseData = jsonDecode(aiResponse.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No recipe extracted. Please try a different URL.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Empty response from AI. Please try again.');
    }

    // Skip thinking parts if present
    final textParts = parts.where((p) => p['thought'] != true).toList();
    final rawText = textParts.isNotEmpty
        ? (textParts.last['text'] as String? ?? '')
        : (parts.last['text'] as String? ?? '');

    if (rawText.isEmpty) {
      throw Exception('Empty text in recipe extraction response.');
    }

    final json = extractJsonObject(rawText);
    if (json.containsKey('error')) {
      throw Exception(json['error'] as String);
    }

    return GeneratedRecipe.fromJson(json);
  }

  // ── Side dish generation ──────────────────────────────────────────────────────
  // Uses flash-lite batch call to generate a complementary side dish.
  static Future<GeneratedRecipe> generateSideDish({
    required String mainRecipeTitle,
    required List<String> mainIngredientNames,
    required List<String> dietaryTags,
    int servings = 2,
  }) async {
    final units = RegionUtils.measurementUnits;
    final region = RegionUtils.region;
    final unitLine = units == 'imperial'
        ? 'Use imperial measurements (ounces, cups, Fahrenheit).'
        : 'Use metric measurements (grams, millilitres, Celsius).';
    final regionLine = region == AppRegion.uk
        ? 'User is in the UK — use GBP for cost and UK ingredient names.'
        : 'User is in the US — use USD for cost and US ingredient names.';

    final prompt = StringBuffer()
      ..writeln('You are Elio, a friendly AI cooking assistant.')
      ..writeln()
      ..writeln('The user has made "$mainRecipeTitle". Suggest ONE complementary side dish or accompaniment.')
      ..writeln()
      ..writeln('Rules:')
      ..writeln('- This MUST be a side dish — think: salad, bread, roasted veg, rice, slaw, dipping sauce, gratin, etc.')
      ..writeln('- It should complement the main dish: if the main is heavy, suggest something light/fresh; if light, something more substantial.')
      ..writeln('- Quick to prepare: under 15 minutes total.')
      ..writeln('- Max 6 ingredients, max 5 steps (1-2 sentences each).')
      ..writeln('- $servings servings.')
      ..writeln('- $unitLine')
      ..writeln('- $regionLine');

    if (dietaryTags.isNotEmpty) {
      prompt.writeln('- Dietary requirements (strict): ${dietaryTags.join(', ')}');
    }

    if (mainIngredientNames.isNotEmpty) {
      prompt.writeln('- The main recipe uses these ingredients — do NOT make them the star of the side dish (basic seasonings like salt/oil are fine to share): ${mainIngredientNames.join(', ')}');
    }

    prompt.writeln();
    prompt.writeln('Return a single JSON object:');
    prompt.writeln('{"title":"string","description":"string (1-2 sentences)","prepTimeMinutes":int,"cookTimeMinutes":int,"servings":int,'
        '"dietaryTags":["string"],"ingredients":[{"name":"string","quantity":"string","unit":"string","fromInventory":false}],'
        '"steps":["string"],"substitutions":[],"tips":"string (optional)"}');

    const sideDishModel = 'gemini-2.5-flash-lite';
    const sideDishEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/$sideDishModel:generateContent';

    final response = await http.post(
      Uri.parse('$sideDishEndpoint?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [{'text': prompt.toString()}]
          }
        ],
        'generationConfig': {
          'temperature': 0.8,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 768,
          'responseMimeType': 'application/json',
        },
      }),
    ).timeout(const Duration(seconds: 20), onTimeout: () {
      throw Exception('Side dish generation timed out. Please try again.');
    });

    if (response.statusCode != 200) {
      throw Exception('Side dish generation failed (${response.statusCode}). Please try again.');
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No side dish generated. Please try again.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Empty response. Please try again.');
    }

    final textParts = parts.where((p) => p['thought'] != true).toList();
    final rawText = textParts.isNotEmpty
        ? (textParts.last['text'] as String? ?? '')
        : (parts.last['text'] as String? ?? '');

    if (rawText.isEmpty) {
      throw Exception('Empty side dish response.');
    }

    final json = extractJsonObject(rawText);
    return GeneratedRecipe.fromJson(json);
  }
}
