import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/elio_models.dart';
import '../models/onboarding_state.dart';
import '../models/recipe_models.dart';
import '../utils/pantry_string_match.dart';
import '../utils/region_utils.dart';
import 'error_service.dart';
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
  ///
  /// Token cap history:
  ///   1024 → 2048 (2026-04-30) — elaborate recipes truncating at 1024.
  ///   2048 → 3072 (Sprint 15.9.3) — Rob hit MAX_TOKENS at 2048 on the
  ///   first post-onboarding generation when the prompt was rich
  ///   (full pantry, household profile, taste profile, recent titles).
  ///   3072 matches the onboarding screen 13 cap that's been stable.
  ///   Belt-and-braces: MAX_TOKENS now also routes through the
  ///   truncation-repair path in `_extractJson` and is retryable.
  static Stream<RecipeGenerationStatus> generateRecipeStream(RecipeGenerationRequest request) async* {
    await for (final event in _streamFromPrompt(
      _buildPrompt(request),
      maxOutputTokens: 3072,
      responseSchema: _recipeResponseSchema,
      // Sprint 15.9.3 SAFETY: defense-in-depth post-gen filter.
      // Even with the ALLERGENS prompt block, Gemini sometimes ignores
      // allergens when the user's craving (e.g. "pad thai") has
      // canonical peanut content. The filter scans every text field
      // of the parsed recipe; if any allergen string appears, the
      // attempt is retried (different sample → likely different recipe).
      allergenGuard: request.customAllergens,
    )) {
      // Sprint 16.1: make the recipe-screen "Vegetarian" pill an honest
      // reflection of the binding constraint. The pill renders from
      // `recipe.dietaryTags.first`, which Gemini sometimes leaves as
      // `[]` even when the prompt specified Vegetarian — leaving the
      // user (Rob) unable to tell whether dietary plumbing is working
      // or whether the recipe just happened to be safe by luck.
      //
      // Merge the request's dietary requirements in front of whatever
      // Gemini emitted: request constraints first (so the pill is
      // deterministic), Gemini-volunteered tags appended de-duped.
      // Custom allergens are NOT included — those are negative
      // constraints ("avoid peanut") and shouldn't render as positive
      // pills.
      if (event is RecipeComplete &&
          request.dietaryRequirements.isNotEmpty) {
        final merged = <String>[
          ...request.dietaryRequirements,
          ...event.recipe.dietaryTags
              .where((t) => !request.dietaryRequirements.contains(t)),
        ];
        yield RecipeComplete(
          recipe: event.recipe.copyWith(dietaryTags: merged),
        );
      } else {
        yield event;
      }
    }
  }

  /// Fire-and-forget connection pre-warm. Called from screen 12 on
  /// onboarding so the TLS handshake + Gemini's first-request warmup
  /// finishes before the real generation kicks off.
  ///
  /// Per memory note `feedback_gemini_api.md`: "Gemini first-attempt
  /// reliability — Rob reports streaming generation commonly fails on
  /// the first attempt after app launch and succeeds on retry." This
  /// burns the cold-start on a throwaway tiny call so the user-facing
  /// call inherits a warm path.
  ///
  /// **Sprint 15.9.2 reliability pass:** previously hit `flash-lite`
  /// with 8 tokens. Switched to `gemini-2.5-flash` with 32 tokens so the
  /// warmup targets the same model the production streaming path uses
  /// — TLS handshake reuse alone wasn't warming Google's per-model pool.
  /// Cost is negligible (~$0.0001 per app launch).
  ///
  /// Errors are swallowed silently — this is best-effort, never blocks.
  static Future<void> prewarmConnection() async {
    const prewarmModel = 'gemini-2.5-flash';
    const prewarmEndpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/$prewarmModel:generateContent';
    try {
      await _httpClient
          .post(
            Uri.parse('$prewarmEndpoint?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': 'ok'}
                  ]
                }
              ],
              'generationConfig': {
                'maxOutputTokens': 32,
                'temperature': 0.0,
                'thinkingConfig': {'thinkingBudget': 0},
              },
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Best-effort warmup — never surface to UI.
    }
  }

  /// Gemini JSON Schema for the recipe contract. Passed alongside
  /// `responseMimeType: application/json` to make the model's output
  /// structurally guaranteed — eliminates "no JSON object found" /
  /// prose-leak failure modes. Keep the required[] list minimal so the
  /// model can omit optional fields without rejection.
  static const Map<String, dynamic> _recipeResponseSchema = {
    'type': 'OBJECT',
    'properties': {
      'title': {'type': 'STRING'},
      'description': {'type': 'STRING'},
      'prepTimeMinutes': {'type': 'INTEGER'},
      'cookTimeMinutes': {'type': 'INTEGER'},
      'servings': {'type': 'INTEGER'},
      'dietaryTags': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'category': {'type': 'STRING'},
      'ingredients': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'name': {'type': 'STRING'},
            'quantity': {'type': 'STRING'},
            'unit': {'type': 'STRING'},
            'fromInventory': {'type': 'BOOLEAN'},
          },
          'required': ['name'],
        },
      },
      'steps': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'substitutions': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'original': {'type': 'STRING'},
            'substitute': {'type': 'STRING'},
            'tradeOff': {'type': 'STRING'},
          },
        },
      },
      'tips': {'type': 'STRING'},
    },
    'required': ['title', 'ingredients', 'steps'],
  };

  // ── Onboarding ephemeral entry point (Task 5.0) ─────────────────────────────
  //
  // Screen 13 of the onboarding rebuild needs to stream a recipe *before*
  // the user has signed in, so no Firestore reads are possible. This entry
  // point accepts an in-memory [pantry] + [prefs] ([OnboardingState]) and
  // funnels them through the existing `_buildPrompt` / `_streamFromPrompt`
  // plumbing.
  //
  // Critical: the dietary block is populated from `prefs.effectiveDietary`
  // (the Option-B household-union getter), NOT `prefs.dietary`.
  //
  // [heroIngredientName] is the client-side hero cascade result
  // (today > thisWeek > fresh > meat > veg — computed on screen 13) and
  // lands in the REQUIRED list so Gemini is forced to use it.
  //
  static Stream<RecipeGenerationStatus> streamGenerateContentEphemeral({
    required List<InventoryItem> pantry,
    required OnboardingState prefs,
    String? heroIngredientName,
    List<String> recentTitles = const [],
  }) async* {
    final request = _buildEphemeralRequest(
      pantry: pantry,
      prefs: prefs,
      heroIngredientName: heroIngredientName,
      recentTitles: recentTitles,
    );
    // Onboarding screen 13 uses a tighter temperature (0.5 vs 0.8) so
    // the model follows the schema strictly during the make-or-break
    // first-recipe demo, and a bigger token cap (3072 vs 2048) as
    // belt-and-braces against truncation. Regular Generate keeps the
    // creative defaults.
    //
    // TODO(onboarding-pantry-floor): consider a pre-flight check that
    // refuses to call Gemini when the onboarding pantry has fewer than
    // ~3 staples / 1 perishable, since starvation prompts produce weird
    // outputs that even the schema can't fully tame. Threshold + copy
    // ("pick a couple more staples first") need a UX call before
    // landing.
    yield* _streamFromPrompt(
      _buildPrompt(request),
      maxOutputTokens: 3072,
      temperature: 0.5,
      responseSchema: _recipeResponseSchema,
      // Sprint 15.9.3 SAFETY: post-gen allergen filter. See comment
      // on generateRecipeStream above for the reasoning.
      allergenGuard: request.customAllergens,
    );
  }

  /// Build the [RecipeGenerationRequest] for an ephemeral onboarding call.
  ///
  /// Pantry split by tier:
  ///   - `alwaysHave`       → request.alwaysHave
  ///   - `almostAlwaysHave` → request.almostAlwaysHave
  ///   - `perishable`       → inventory descriptions (+ REQUIRED hero)
  ///
  /// Dietary pulled from `prefs.effectiveDietary` so Option-B household
  /// union is honoured when the toggle is on.
  static RecipeGenerationRequest _buildEphemeralRequest({
    required List<InventoryItem> pantry,
    required OnboardingState prefs,
    String? heroIngredientName,
    List<String> recentTitles = const [],
  }) {
    final alwaysHave = <String>[];
    final almostAlwaysHave = <String>[];
    final perishableDescs = <String>[];
    final runningLow = <String>[];

    for (final item in pantry) {
      switch (item.tier) {
        case 'alwaysHave':
          alwaysHave.add(item.name);
        case 'almostAlwaysHave':
          almostAlwaysHave.add(item.name);
        case 'perishable':
          perishableDescs.add(item.geminiDescription);
      }
      if (item.isRunningLow) runningLow.add(item.name);
    }

    final perishables = <String>[
      if (heroIngredientName != null && heroIngredientName.isNotEmpty)
        heroIngredientName,
    ];

    // Map maxCookTime int → the informal time preference strings
    // the prompt builder already understands.
    String? timePref;
    final t = prefs.maxCookTime;
    if (t != null) {
      if (t <= 15) {
        timePref = 'Quick (under 20 min)';
      } else if (t <= 30) {
        timePref = 'Around 30 minutes';
      } else if (t <= 45) {
        timePref = 'Around 45 minutes';
      } else {
        timePref = 'No rush';
      }
    }

    return RecipeGenerationRequest(
      perishables: perishables,
      alwaysHave: alwaysHave,
      almostAlwaysHave: almostAlwaysHave,
      dietaryRequirements: prefs.effectiveDietary,
      timePreference: timePref,
      servings: prefs.householdCount,
      appliances: prefs.appliances,
      excludedIngredients: prefs.dislikes,
      runningLowItems: runningLow,
      perishableInventoryDescriptions: perishableDescs,
      recentTitles: recentTitles,
      // Sprint 15.9.3 SAFETY: ephemeral (onboarding screen 13) was
      // omitting allergens entirely. A peanut-allergy user typing
      // "pad thai" in onboarding could have been served peanut butter
      // on their first-ever generation.
      customAllergens: prefs.allergies,
    );
  }

  /// Visible-for-testing hook so Task 5.0's unit tests can inspect the
  /// compiled prompt without hitting the network.
  @visibleForTesting
  static String buildEphemeralPromptForTest({
    required List<InventoryItem> pantry,
    required OnboardingState prefs,
    String? heroIngredientName,
    List<String> recentTitles = const [],
  }) =>
      _buildPrompt(_buildEphemeralRequest(
        pantry: pantry,
        prefs: prefs,
        heroIngredientName: heroIngredientName,
        recentTitles: recentTitles,
      ));

  /// Visible-for-testing hook for direct prompt assertions on a fully-
  /// constructed [RecipeGenerationRequest]. Used by Sprint 16.6 row 5b
  /// tests to verify the meal-type hard constraint line is emitted
  /// (and omitted when [mealType] is null).
  @visibleForTesting
  static String buildPromptForTest(RecipeGenerationRequest request) =>
      _buildPrompt(request);

  /// Public streaming entry point — wraps [_streamAttemptOnce] in a
  /// retry loop so transient failures (5xx, network blip, truncated SSE
  /// stream, JSON parse failure) are retried silently before the user
  /// ever sees an error. Backoff: 500ms after attempt 1, 1500ms after
  /// attempt 2. Non-retryable errors (auth, rate-limit, bad request,
  /// MAX_TOKENS) short-circuit immediately.
  static Stream<RecipeGenerationStatus> _streamFromPrompt(
    String prompt, {
    required int maxOutputTokens,
    double temperature = 0.8,
    Map<String, dynamic>? responseSchema,
    // Sprint 15.9.3 SAFETY: when set, the parsed recipe is scanned for
    // any of these allergen strings (case-insensitive substring match
    // across title, description, ingredient names, steps, tips, and
    // substitutions). A hit triggers a retryable error so the silent
    // retry loop has another go. Empty / null → no filter.
    List<String> allergenGuard = const [],
  }) async* {
    const int maxAttempts = 3;
    RecipeError? lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      RecipeError? attemptError;

      await for (final event in _streamAttemptOnce(
        prompt: prompt,
        maxOutputTokens: maxOutputTokens,
        temperature: temperature,
        responseSchema: responseSchema,
        allergenGuard: allergenGuard,
      )) {
        if (event is RecipeGenerating) {
          yield event;
        } else if (event is RecipeComplete) {
          yield event;
          return;
        } else if (event is RecipeError) {
          attemptError = event;
        }
      }

      if (attemptError == null) return; // shouldn't happen; nothing to do
      lastError = attemptError;

      // Retryable + attempts remaining → silent retry. Otherwise yield.
      if (!attemptError.retryable || attempt == maxAttempts) {
        yield attemptError;
        return;
      }
      final delayMs = attempt == 1 ? 500 : 1500;
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    // Defensive — loop should always return inside.
    if (lastError != null) yield lastError;
  }

  /// Single attempt at the SSE stream. Yields progress events plus a
  /// final terminal event ([RecipeComplete] on success or
  /// [RecipeError] on failure). The wrapper [_streamFromPrompt] decides
  /// whether to retry based on the [RecipeError.retryable] flag.
  static Stream<RecipeGenerationStatus> _streamAttemptOnce({
    required String prompt,
    required int maxOutputTokens,
    required double temperature,
    Map<String, dynamic>? responseSchema,
    List<String> allergenGuard = const [],
  }) async* {
    final client = _httpClient;

    try {
      final httpRequest = http.Request(
        'POST',
        Uri.parse('$_streamUrl?alt=sse&key=$_apiKey'),
      );
      httpRequest.headers['Content-Type'] = 'application/json';
      final generationConfig = <String, dynamic>{
        'temperature': temperature,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': maxOutputTokens,
        'responseMimeType': 'application/json',
        'thinkingConfig': {'thinkingBudget': 0},
        if (responseSchema != null) 'responseSchema': responseSchema,
      };
      httpRequest.body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': generationConfig,
      });

      final streamedResponse = await client.send(httpRequest).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Recipe generation timed out. Please try again.'),
      );

      // Check HTTP status before reading the stream. Retryability is
      // driven by whether a re-attempt could plausibly succeed — auth /
      // bad-request / rate-limit won't recover; 5xx and unknowns might.
      final status = streamedResponse.statusCode;
      if (status == 429) {
        yield RecipeError(
          message: 'Recipe generation is temporarily unavailable (rate limit reached). Please wait a minute and try again.',
        );
        return;
      }
      if (status == 400) {
        yield RecipeError(message: 'Invalid request to recipe service (400). Please try again.');
        return;
      }
      if (status == 401 || status == 403) {
        yield RecipeError(message: 'Recipe service access denied. Please check your API key.');
        return;
      }
      if (status == 404) {
        yield RecipeError(message: 'Recipe service unavailable (model not found). Please try again.');
        return;
      }
      if (status != 200) {
        yield RecipeError(
          message: 'Recipe service error ($status). Please try again.',
          retryable: status >= 500,
        );
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
              // Sprint 16.6 — REVERTED 12 May 2026. The thought-part
              // filter added in 43b34ac coincided with nutrition + cost
              // fields disappearing from generated recipes (Rob 12 May
              // on-device). Theory: filter was correct in principle but
              // under current API behaviour it dropped legitimate
              // content parts, causing _extractJson to truncation-repair
              // the JSON and lose tail fields (nutrition / cost).
              // Reverted to the pre-43b34ac shape pending diagnosis.
              // Substitution / URL import / side dish keep their own
              // filters (they use a different parts-aggregation shape
              // and were working before this change).
              final text = part['text'] as String?;
              if (text != null) buffer.write(text);
            }
          } catch (_) {
            // Malformed SSE chunk — skip and continue accumulating
          }
        }
      }

      // Stream complete — check finish reason and parse.
      //
      // Sprint 15.9.3 fix: MAX_TOKENS used to early-return here, which
      // bypassed `_extractJson`'s truncation-repair branch and left the
      // user staring at an error even though we had usable JSON in the
      // buffer. Fall through to the same parse path the success branch
      // uses; the repair walker closes any unfinished string/array/object
      // and produces a syntactically valid (partial) recipe. Recipe model
      // fields are nullable / list-defaulting so the partial renders.
      // If repair still fails, the retryable flag below lets the silent
      // retry loop have another go — Gemini at temp 0.8 often produces
      // a shorter recipe on the second try.
      final maxTokensHit = finishReason == 'MAX_TOKENS';

      final rawText = buffer.toString().trim();

      // Sprint 16.6 (deliberation-bleed plan, Phase 0.1, 13 May 2026)
      // — log any finish reason other than STOP as a Crashlytics
      // non-fatal so we can dashboard MAX_TOKENS frequency without
      // server-side logging. Includes prompt-shape booleans so we can
      // correlate which feature combinations are most prone to
      // truncation. No PII (no ingredient names, no recipe titles).
      if (finishReason != null && finishReason != 'STOP') {
        // Substring-detect the request-shape flags from the prompt
        // itself — keeps the signature of _streamAttemptOnce stable
        // and avoids plumbing a request-context Map through callers.
        // The substrings are emitted by stable section headers in
        // _buildPrompt, so the detection is reliable.
        final hasPerishables = prompt.contains('Perishables to prioritise') ||
            prompt.contains('Items the user has specifically chosen') ||
            // Legacy pre-Step-2.1 prompt shape (in case of mid-build):
            prompt.contains('PERISHABLE ITEMS') ||
            prompt.contains('REQUIRED ingredients');
        final hasMealType = prompt.contains('Meal type:') ||
            prompt.contains('make a Breakfast recipe') ||
            prompt.contains('make a Lunch recipe') ||
            prompt.contains('make a Dinner recipe');
        final hasVariation = prompt.contains('## VARIATION');
        final hasAllergens = prompt.contains('ALLERGENS —');
        ErrorService.log(
          'recipe_finish_reason',
          '$finishReason | bufLen=${rawText.length} | '
              'perishables=$hasPerishables | mealType=$hasMealType | '
              'variation=$hasVariation | allergens=$hasAllergens',
        );
      }

      if (rawText.isEmpty) {
        // Empty stream — usually a network blip or transient upstream
        // issue; worth retrying.
        yield RecipeError(
          message: 'Empty response from AI. Please try again.',
          retryable: true,
        );
        return;
      }

      try {
        final recipeJson = _extractJson(rawText);
        final recipe = _parseGeneratedRecipe(recipeJson);
        // Sprint 15.9.3 SAFETY: post-gen allergen scan. Even with the
        // ALLERGENS prompt block, Gemini occasionally serves canonical-
        // dish ingredients (e.g. peanuts in pad thai). The filter
        // rejects any recipe that mentions an allergen in any text
        // field, returning a retryable error so the silent retry loop
        // can roll a different recipe.
        final violation = _findAllergenViolation(recipe, allergenGuard);
        if (violation != null) {
          ErrorService.log(
              'recipe_allergen_violation',
              'Recipe contained allergen "$violation"; retrying.');
          yield RecipeError(
            message:
                'That recipe included $violation, which is on your allergen list. Trying a safer alternative…',
            retryable: true,
          );
          return;
        }
        yield RecipeComplete(recipe: recipe);
      } catch (parseErr) {
        // Could be truncation (most common — repaired in _extractJson),
        // model-emitted prose, or a malformed payload. Retryable lets
        // Gemini re-roll a (likely shorter) recipe. MAX_TOKENS where the
        // repair couldn't produce a renderable recipe surfaces a more
        // specific message; everything else uses the parse error.
        ErrorService.log('recipe_generation_parse', parseErr);
        yield RecipeError(
          message: maxTokensHit
              ? 'Recipe got a bit long. Trying again with a tighter version…'
              : parseErr is Exception
                  ? parseErr.toString().replaceFirst('Exception: ', '')
                  : 'Recipe generation failed. Please try again.',
          retryable: true,
        );
      }
    } catch (e) {
      ErrorService.log('recipe_generation_stream', e);
      // Network / timeout / decoder failures are all worth retrying.
      yield RecipeError(
        message: e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Recipe generation failed. Please try again.',
        retryable: true,
      );
    }
  }

  /// Sprint 15.9.3 SAFETY-CRITICAL preamble. When the user has any
  /// allergens, this block is emitted at position #1 of the prompt
  /// (before "You are Elio"). LLMs weight earlier text most heavily —
  /// putting allergens here makes the entire generation task framed
  /// around the exclusion rather than the craving / canonical recipe
  /// shape. Used by [_buildPrompt] and [_buildSingleMealPrompt] (via
  /// the public companion in meal_plan_service.dart).
  ///
  /// Worked example for peanuts is included because Rob's pad-thai
  /// test surfaced that Gemini's prior associations
  /// ("pad thai" → peanut sauce) override generic "STRICTLY EXCLUDE"
  /// language. Spelling out the failure modes in the prompt itself
  /// (peanut butter, satay paste, arachis oil, groundnut) gives the
  /// model concrete things to refuse rather than a vague "peanut-
  /// derived" category.
  /// Public version of [_writeAllergenPreamble] so other prompt
  /// builders (meal plan single-meal, side dish, etc.) can prepend
  /// the same safety frame. Returns the rendered string ready to
  /// concatenate at the very top of the prompt.
  static String allergenPreambleFor(List<String> allergens) {
    if (allergens.isEmpty) return '';
    final buf = StringBuffer();
    _writeAllergenPreamble(buf, allergens);
    return buf.toString();
  }

  static void _writeAllergenPreamble(
    StringBuffer buffer,
    List<String> allergens,
  ) {
    if (allergens.isEmpty) return;
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('SAFETY-CRITICAL ALLERGEN EXCLUSION — READ FIRST');
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('The user has the following MEDICAL ALLERGIES:');
    for (final a in allergens) {
      buffer.writeln('  • $a');
    }
    buffer.writeln();
    buffer.writeln(
        'The recipe MUST contain ZERO mention of these allergens or anything derived from them — in title, description, ingredient names, ingredient quantities, steps, substitutions, or tips.');
    buffer.writeln();
    buffer.writeln(
        'For each allergen, exclude obvious AND non-obvious forms. For example:');
    buffer.writeln(
        '  • peanuts → also exclude peanut butter, peanut oil, peanut paste, peanut sauce, satay (paste/sauce), groundnut, groundnut oil, arachis oil, Reese\'s, "PB", any nut-based Thai sauce that traditionally uses peanuts.');
    buffer.writeln(
        '  • sesame → also exclude tahini, sesame oil, sesame seeds, gomashio, halva.');
    buffer.writeln(
        '  • shellfish → also exclude shrimp, prawn, crab, lobster, scallop, langoustine, crayfish, fish sauce/oyster sauce that contain shellfish.');
    buffer.writeln(
        'Apply the same logic to other listed allergens — exclude derivatives and ingredients that traditionally contain them.');
    buffer.writeln();
    buffer.writeln(
        'If the user\'s craving, pantry, or your training data implies a recipe that traditionally requires any of these allergens (e.g. "pad thai" with a peanut allergy, "satay" with a peanut allergy, "carbonara" with a dairy allergy), DO NOT FORCE the recipe. Pick a different dish that has ZERO risk of containing the allergen — even if it\'s less canonical to the craving.');
    buffer.writeln();
    buffer.writeln(
        'BEFORE returning your JSON: read every ingredient name, every step, every substitution. If you see ANY mention of any listed allergen or its derivatives, regenerate the recipe with a different dish entirely. Treat this like a final gate, not a suggestion.');
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln();
  }

  /// Sprint 15.9.3 SAFETY filter. Returns the first allergen string
  /// that appears anywhere in the recipe's text fields, or null if the
  /// recipe is clean.
  ///
  /// Match strategy: case-insensitive substring against BOTH the raw
  /// lowercased allergen AND its singularised form (via
  /// PantryStringMatch.matchKey). The singularised form is critical:
  /// users type "peanuts" but recipes write "peanut butter", and a
  /// raw substring match misses that ("peanut butter" doesn't contain
  /// "peanuts"). Singularising the needle to "peanut" catches both
  /// "peanut" and "peanuts" in any haystack.
  ///
  /// False positives possible (e.g. a description containing
  /// Sprint 16.6 — single funnel for every Gemini parse path that turns
  /// raw JSON into a [GeneratedRecipe]. Threads a truncation sink through
  /// [GeneratedRecipe.fromJson] so any over-cap ingredient string fields
  /// surface as ONE aggregated `ErrorService.log` per recipe instead of
  /// one log per field (Crashlytics non-fatals would otherwise flood the
  /// dashboard). History read-back (SavedRecipe.fromJson) doesn't go
  /// through here, so old already-truncated recipes from Firestore stay
  /// silent.
  ///
  /// Two failure shapes seen in production motivated this:
  ///   * Wall-of-text deliberation (chickpeas: ~1500 chars in `quantity`)
  ///   * Prompt-echo + repetition collapse (red peppers: "DO NOT REMOVE
  ///     THIS." repeated dozens of times)
  /// Both root-caused in `thinkingBudget: 0` removing Gemini's scratch
  /// space so it deliberates *inside* the JSON value.
  static GeneratedRecipe _parseGeneratedRecipe(Map<String, dynamic> json) {
    final truncated = <String>[];
    final recipe = GeneratedRecipe.fromJson(json, ingredientTruncations: truncated);
    if (truncated.isNotEmpty) {
      final summary = _summariseTruncations(truncated);
      ErrorService.log(
        'recipe_ingredient_truncations',
        '${truncated.length} ingredient field(s) capped: $summary',
      );
    }
    return recipe;
  }

  /// Compresses ['quantity:bleed', 'quantity:long', 'name:long']
  /// -> 'quantity:bleed×1, quantity:long×1, name:long×1' for the
  /// aggregated truncation log. Order is name → quantity → unit
  /// (the sanitizer call order in [RecipeIngredient.fromJson]),
  /// then by classifier within each field, giving stable summaries
  /// for Crashlytics grouping.
  ///
  /// Sprint 16.6 (deliberation-bleed plan, Phase 0.2, 13 May 2026):
  /// sink entries now carry a shape classifier (`bleed` or `long`)
  /// after a colon. `bleed` signals Gemini paraphrased prompt
  /// instructions into a value — the Phase 2 prompt restructure
  /// should drive this to near zero.
  static String _summariseTruncations(List<String> fields) {
    final counts = <String, int>{};
    for (final f in fields) {
      counts[f] = (counts[f] ?? 0) + 1;
    }
    // Stable ordering: by field, then by classifier within the field.
    const fieldOrder = ['name', 'quantity', 'unit'];
    const classifierOrder = ['bleed', 'long'];
    final keys = <String>[];
    for (final field in fieldOrder) {
      for (final classifier in classifierOrder) {
        final key = '$field:$classifier';
        if (counts.containsKey(key)) keys.add(key);
      }
      // Legacy un-classified entries (pre-Phase-0.2 callers): still
      // surface them so older saved-data round-trips don't crash the
      // summariser. Should never fire in production after this commit.
      if (counts.containsKey(field)) keys.add(field);
    }
    return keys.map((k) => '$k×${counts[k]}').join(', ');
  }

  /// "peanut-free"). Cost is a retry — safer than letting a violation
  /// through.
  ///
  /// We do NOT expand to free-form synonyms (groundnuts, arachis oil) —
  /// the prompt's worked examples push Gemini toward producing
  /// recognisable variants. If we see consistent miss patterns in the
  /// wild, a small synonym table is the next lever.
  static String? _findAllergenViolation(
    GeneratedRecipe recipe,
    List<String> allergens,
  ) {
    if (allergens.isEmpty) return null;
    final haystacks = <String>[
      recipe.title,
      recipe.description,
      ...recipe.ingredients.map((i) => i.name),
      ...recipe.steps,
      ...recipe.substitutions
          .map((s) => '${s.original} ${s.substitute} ${s.tradeOff}'),
    ].map((s) => s.toLowerCase()).toList();

    for (final allergen in allergens) {
      final raw = allergen.trim().toLowerCase();
      if (raw.isEmpty) continue;
      // Singularised form catches plural-vs-singular mismatches —
      // "peanuts" (user) vs "peanut butter" (recipe) is the canonical
      // failure case this fix addresses.
      final singular = PantryStringMatch.matchKey(allergen);
      for (final hay in haystacks) {
        if (hay.contains(raw) || hay.contains(singular)) return allergen;
      }
    }
    return null;
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

    // 3. Find outermost { ... } braces.
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      final candidate = text.substring(start, end + 1);
      try {
        return jsonDecode(candidate) as Map<String, dynamic>;
      } catch (_) {
        // Fall through to truncation repair.
      }
    }

    // 4. Truncation repair — common when SSE is cut mid-payload before
    // the MAX_TOKENS finish-reason chunk arrives. Walk forward tracking
    // string state + container nesting, then close any unfinished
    // string / array / object so the result is at least syntactically
    // valid. Recipe model fields are nullable / list-defaulting so a
    // partial recipe usually still renders something.
    if (start != -1) {
      final repaired = _tryRepairTruncatedJson(text.substring(start));
      if (repaired != null) {
        try {
          return jsonDecode(repaired) as Map<String, dynamic>;
        } catch (_) {
          // Repair didn't help — fall through to the throw below.
        }
      }
    }

    if (start != -1 && end != -1 && end > start) {
      throw Exception('Could not parse recipe JSON (response was truncated).');
    }
    throw Exception('No JSON object found in AI response. Please try again.');
  }

  /// Best-effort repair of a truncated JSON object. Walks the string
  /// once, tracking string-literal state + container depth, then
  /// appends the closing characters needed to balance the structure.
  /// Returns null if there is no `{` to anchor to.
  ///
  /// This is deliberately permissive: a truncated string at the tail
  /// is closed with `"`, an unfinished array with `]`, etc. The
  /// resulting JSON may have an empty/short final field, but the rest
  /// of the recipe (title, ingredients up to the cut, partial steps)
  /// renders, which is far better than the user seeing a parse error.
  static String? _tryRepairTruncatedJson(String text) {
    if (!text.contains('{')) return null;
    final stack = <String>[]; // '}' or ']' to append, in reverse open order
    bool inString = false;
    bool escape = false;
    int lastSafeEnd = -1; // index just past the last well-formed value boundary

    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (inString) {
        if (ch == '\\') {
          escape = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      switch (ch) {
        case '"':
          inString = true;
          break;
        case '{':
          stack.add('}');
          break;
        case '[':
          stack.add(']');
          break;
        case '}':
        case ']':
          if (stack.isNotEmpty) stack.removeLast();
          if (stack.isEmpty) lastSafeEnd = i + 1;
          break;
      }
    }

    // If the stream landed exactly at a complete top-level object, no
    // repair needed — caller should have parsed it already, but return
    // anyway for safety.
    if (stack.isEmpty && lastSafeEnd > 0) {
      return text.substring(0, lastSafeEnd);
    }

    final buf = StringBuffer(text);
    // Close any unfinished string first.
    if (inString) buf.write('"');
    // Trim a trailing comma before closing — `[1, 2,` → `[1, 2]`.
    var tail = buf.toString();
    final trimmed = tail.replaceFirst(RegExp(r'[,\s]+$'), '');
    if (trimmed.length != tail.length) {
      buf
        ..clear()
        ..write(trimmed);
    }
    // Likewise drop a trailing colon / partial key — `"steps":` → drop.
    final tail2 = buf.toString();
    final trimmed2 = tail2.replaceFirst(RegExp(r',\s*"[^"]*"\s*:\s*$'), '');
    if (trimmed2.length != tail2.length) {
      buf
        ..clear()
        ..write(trimmed2);
    }
    // Append closing chars in reverse order of opens.
    for (var i = stack.length - 1; i >= 0; i--) {
      buf.write(stack[i]);
    }
    return buf.toString();
  }

  static String _buildPrompt(RecipeGenerationRequest request) {
    final buffer = StringBuffer();

    // Sprint 15.9.3 SAFETY: when allergens are present, lead the prompt
    // with a maximum-strength safety preamble BEFORE the friendly Elio
    // intro. LLMs weight earlier text most heavily — placing allergens
    // at position #1 (rather than buried inside HARD CONSTRAINTS) makes
    // them the primary frame the model reasons against, not an
    // afterthought to the user's craving / training-data priors.
    //
    // The block also asks for an explicit verification step so the
    // model self-checks before responding. The post-gen filter remains
    // as defense-in-depth.
    _writeAllergenPreamble(buffer, request.customAllergens);

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

    // Sprint 15.9.3 SAFETY FIX: allergens get their own line with
    // maximum-strength language. Kept distinct from dietary because
    // these are concrete ingredients tied to medical safety (peanuts,
    // sesame, shellfish), not high-level patterns. ALL CAPS on the
    // action verb so Gemini doesn't soften "exclude" into "minimise".
    if (request.customAllergens.isNotEmpty) {
      buffer.writeln(
          'ALLERGENS — STRICTLY EXCLUDE these ingredients and ANYTHING containing them: ${request.customAllergens.join(', ')}.');
      buffer.writeln(
          'Treat as medical safety, not preference. No exceptions. Do NOT include these in the recipe under any name (e.g. if "peanuts" is listed, never use peanuts, peanut butter, peanut oil, satay sauce, groundnuts, or anything else peanut-derived). If a recipe would normally call for one of these, choose a different recipe entirely.');
    }

    // Style as a hard constraint (unless "Surprise me")
    if (request.stylePreference != null && request.stylePreference != 'Surprise me') {
      buffer.writeln('You MUST make a ${request.stylePreference} recipe. This is a hard requirement — the recipe\'s cuisine/style must clearly be ${request.stylePreference}.');
    }

    // Sprint 16.6 row 5b — meal-type chip selection.
    //
    // 13 May 2026 (deliberation-bleed plan Step 1.2): downgraded from
    // a third HARD `MUST` line to a soft hint. Stacking three HARD
    // constraints (dietary/allergens + perishables REQUIRED + meal
    // type MUST) on a model with `thinkingBudget: 0` was raising the
    // cognitive load past a stability threshold and contributing to
    // deliberation-bleed (Gemini paraphrasing prompt language into
    // JSON values). Gemini's training already strongly biases recipes
    // for "breakfast"/"lunch"/"dinner" language; we don't need the
    // hammer of MUST.
    //
    // Bare assertion, no example list: positive examples ("eggs,
    // toast, oatmeal") anchor the output and narrow regional/cultural
    // breadth.
    if (request.mealType != null) {
      buffer.writeln(
          'Meal type: ${request.mealType}. Tailor the dish to that meal occasion.');
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

      // Sprint 16.6 (deliberation-bleed plan Step 2.1, 13 May 2026):
      // restructured to put DATA and INSTRUCTIONS in separate
      // surfaces. The previous version emitted inline parenthetical
      // instructions next to the item names:
      //
      //   'PERISHABLE ITEMS (use these first): chicken breast (expires today)'
      //   'REQUIRED ingredients — you MUST use ALL of these...: chicken breast.'
      //
      // With `thinkingBudget: 0`, Gemini paraphrased these inline
      // instructions directly into ingredient `quantity` field values
      // ("(use this first)", "(from inventory)", "(expires today)" —
      // Rob's 13 May screenshot showed all three in a single quantity).
      //
      // New shape: bullet list of data, then a separate instruction
      // sentence telling Gemini explicitly that quantities are
      // numeric + unit only with positive examples. The
      // anti-bleed instruction lives BELOW the data, not adjacent
      // to it, so paraphrasing patterns don't pick it up.

      // Perishable inventory items with urgency (from pantry perishable tier).
      if (request.perishableInventoryDescriptions.isNotEmpty) {
        buffer.writeln('Perishables to prioritise:');
        for (final desc in request.perishableInventoryDescriptions) {
          buffer.writeln('- $desc');
        }
      }

      if (request.perishables.isNotEmpty) {
        buffer.writeln('Items the user has specifically chosen to use:');
        for (final p in request.perishables) {
          buffer.writeln('- $p');
        }
        buffer.writeln(
            'Every item in the list above must appear in the recipe\'s '
            '`ingredients` array and be used in the cooking steps. '
            'Do NOT write instructions, reminders, or status notes '
            'inside any ingredient `quantity` value — quantities are '
            'numeric + optional unit only '
            '(e.g. "0.5 lb", "200 g", "2 cloves", "1 cup").');
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
    // Free-text "craving" supplied by the user — high-priority soft signal.
    // Honour it where possible without breaking dietary rules or required
    // perishables. Sits at the top of preferences so it shapes the dish
    // category before time / style / mood are layered on.
    if (request.userRequest != null && request.userRequest!.trim().isNotEmpty) {
      buffer.writeln(
          'User request (high priority — try hard to honour this): "${request.userRequest!.trim()}". Make a recipe that clearly satisfies this craving.');
      // Sprint 15.9.3 SAFETY: the craving line was getting interpreted
      // as overriding allergens (e.g. "pad thai" → peanut butter for a
      // peanut-allergy user). Explicit override: allergens beat
      // craving, full stop. If the craving requires an allergen,
      // pivot to a related-but-safe dish instead of forcing it.
      if (request.customAllergens.isNotEmpty) {
        buffer.writeln(
            'IMPORTANT: if this craving traditionally requires any listed allergen, do NOT force it. Pick a related allergen-free dish instead (e.g. craving "pad thai" + peanut allergy → make a peanut-free Thai noodle dish, or a different Thai stir-fry; never include peanuts/peanut butter just because the craving normally calls for them). Allergens beat cravings — every time.');
      }
    }
    if (request.timePreference != null) {
      buffer.writeln('Time available: ${request.timePreference}');
      final timeGuidance = _expandTimeGuidance(request.timePreference!);
      if (timeGuidance.isNotEmpty) buffer.writeln(timeGuidance);
    }
    // Sprint 15.9.3: was 'Surprise me' only. When the user didn't pick a
    // style at all (null), they got NO creativity push and recipes got
    // repetitive. Default the unselected case to "be creative" too.
    if (request.stylePreference == null ||
        request.stylePreference == 'Surprise me') {
      buffer.writeln(
          'Style: No specific cuisine — be creative. Vary cuisine across recent recipes for variety.');
    }
    if (request.moodPreference != null) {
      buffer.writeln('Mood: ${request.moodPreference}');
      buffer.writeln(_expandMoodGuidance(request.moodPreference!));
    }
    buffer.writeln('Servings: ${request.servings}');

    if (request.runningLowItems.isNotEmpty) {
      buffer.writeln();
      // Sprint 15.9.3: strengthened from "use sparingly or avoid" — that
      // soft language let Gemini still feature these items as the star.
      buffer.writeln('## RUNNING LOW (user is nearly out — AVOID these):');
      buffer.writeln(request.runningLowItems.join(', '));
      buffer.writeln(
          'Do NOT make any of these the main feature. If you must include one, use a minimal quantity and treat it as optional.');
    }

    if (request.excludedIngredients.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## EXCLUDED INGREDIENTS (do NOT use these — user has run out or does not want them):');
      buffer.writeln(request.excludedIngredients.join(', '));
    }

    if (request.appliances.isNotEmpty) {
      buffer.writeln();
      // Sprint 15.9.3: tighter constraint. Was a passive "where appropriate"
      // suggestion that Gemini ignored AND it didn't prevent recipes
      // requiring missing equipment (e.g. oven recipes for users without one).
      buffer.writeln(
          'Available appliances: ${request.appliances.join(', ')}. Recipe must work with these — don\'t require anything else.');
    }

    if (request.recentTitles.isNotEmpty) {
      // Sprint 15.9.3: previously listed titles twice (RECENTLY GENERATED
      // section + VARIETY section). Single combined section saves tokens
      // and reads more clearly.
      buffer.writeln();
      buffer.writeln('## RECENTLY GENERATED (do NOT repeat; vary against these):');
      for (final title in request.recentTitles) {
        buffer.writeln('- $title');
      }
      buffer.writeln(
          'Generate something with a DIFFERENT base ingredient, cooking method, AND cuisine from the list above. '
          'If they\'re pasta-heavy, avoid pasta. If Asian-leaning, try a different region. '
          'If all oven-baked, try stovetop or no-cook. Variety is key.');
    }

    // Sprint 16.6 (Notion XX bug 3) — VARIATION memory.
    //
    // The RECENTLY GENERATED block above gives titles only; Gemini has
    // to *infer* recent hero ingredients and cookware from those
    // strings, which it does unreliably. Rob's complaint on 11 May was
    // explicit: chickpeas appearing 3 in a row, "hearty" overused,
    // "skillet" overused. Feeding the actual signal direct (extracted
    // client-side via RecipeVariation.heroIngredient + .cookware on
    // each recipe completion) makes the variety nudge actionable.
    //
    // Window of 3 recipes (per Rob) — short enough that a user with
    // chicken in the fridge isn't locked out of chicken after one
    // chicken recipe.
    if (request.recentHeroIngredients.isNotEmpty ||
        request.recentCookware.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## VARIATION (last 3 recipes — vary against these):');
      if (request.recentHeroIngredients.isNotEmpty) {
        buffer.writeln(
            'Hero ingredients used: ${request.recentHeroIngredients.join(', ')}.');
      }
      if (request.recentCookware.isNotEmpty) {
        buffer.writeln(
            'Cookware used: ${request.recentCookware.join(', ')}.');
      }
      buffer.writeln(
          'Pick a DIFFERENT hero ingredient AND a different primary cookware from the above. '
          'Also vary your descriptive language — if recent recipes leaned on words like "hearty", "warming", or "comforting", reach for fresher vocabulary this time.');
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
    buffer.writeln('- Assume the user always has water, salt, and basic cooking oil (olive / vegetable / sunflower / rapeseed / canola) — do NOT list these in the ingredients array, but you may reference them in the steps (e.g. "season with salt", "splash of oil", "boil 1 cup of water").');
    buffer.writeln('- Recipe title must sound like home cooking, NOT a pre-made product. E.g. "Lemon Herb Chicken with Roasted Vegetables", not "Cooked Mediterranean Chicken".');
    buffer.writeln('- Ingredients must be raw/purchasable items, NOT pre-prepared dishes. Never list a cooked dish as an ingredient.');
    // Sprint 15.9.3: scale step/ingredient caps with the time the user
    // told us they have. Previously these were universal, so even "No
    // rush" got 8-step weeknight-shaped output. The caps below reward
    // the user for telling us they have time.
    final caps = _capsForTimePreference(request.timePreference);
    buffer.writeln('- ${caps.stepLengthGuidance}');
    buffer.writeln('- Max ${caps.maxSteps} steps total.');
    buffer.writeln('- Max ${caps.maxIngredients} ingredients.');
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
    buffer.writeln('Set "category" to the single best fit for this recipe; use exactly one of the listed values.');
    // Sprint 16.6 (Notion XX-2 nutrition+cost, 13 May 2026) — field
    // order matters under maxOutputTokens.
    //
    // Gemini emits the JSON in the order presented here. When the
    // token cap hits mid-response, fields LATER in the schema are
    // silently dropped — `_extractJson`'s truncation-repair closes
    // the structure but cannot fabricate fields that were never
    // written. Previously `nutrition` + cost were last, so a
    // truncation inside the long ingredients[] or steps[] arrays
    // wiped them and the RecipeScreen pills disappeared.
    //
    // Reordered by survival priority:
    //   * tier 1 (tiny, always survive): title / category / description
    //     / prep+cook times / servings
    //   * tier 2 (short, MUST survive — drive UI conditional pills):
    //     dietaryTags / nutrition / estimatedCostPerServing*
    //   * tier 3 (short array, partial OK): substitutions
    //   * tier 4 (long arrays, partial OK — _tryRepairTruncatedJson
    //     handles the close): ingredients / steps
    //
    // Actual cap on the streaming path is 3072 tokens (see line ~84),
    // not 1024 as an earlier comment on this block claimed; corrected
    // on 13 May 2026.
    //
    // Sprint 16.6 (deliberation-bleed plan Step 2.2, 13 May 2026):
    // quantity field in the example schema now shows a concrete
    // numeric-string shape ("0.5") with a unit example instead of
    // the previous `"string"`. The companion sentence reminds Gemini
    // that quantities are numeric + unit only — never prose, never
    // parentheticals. Reinforces the anti-bleed instruction from
    // Step 2.1's INVENTORY block.
    buffer.writeln(
        'Quantities are numeric + optional unit only. Never write '
        'parentheticals or reminders into a quantity value.');
    buffer.writeln('''{
  "title": "string",
  "category": "<one of: Appetizer | Entrée | Side dish | Dessert | Breakfast | Brunch | Lunch | Snack | Soup | Salad | Drink>",
  "description": "string (1-2 sentences)",
  "prepTimeMinutes": 10,
  "cookTimeMinutes": 20,
  "servings": 2,
  "dietaryTags": ["string"],
  "nutrition": {
    "calories": 450,
    "proteinG": 35.0,
    "carbsG": 42.0,
    "fatG": 12.0,
    "fibreG": 6.0
  },
  "estimatedCostPerServingUSD": 4.50,
  "estimatedCostPerServingGBP": 3.50,
  "substitutions": [
    {"original": "string", "substitute": "string", "tradeOff": "string"}
  ],
  "ingredients": [
    {"name": "Chicken breast", "quantity": "0.5", "unit": "lb", "fromInventory": true}
  ],
  "steps": ["string"]
}''');

    return buffer.toString();
  }

  /// Expand a mood chip label into specific, actionable prompt guidance
  /// so Gemini generates recipes that actually match the mood.
  /// Sprint 15.9.3: time-preference guidance. Was bare text
  /// (`Time: No rush`) which Gemini largely ignored — combined with the
  /// universal "Max 8 steps / 10 ingredients" rule, the user got
  /// weeknight food regardless of what they told us in onboarding.
  /// This expands the time pref into an active instruction so Gemini
  /// matches recipe ambition to the time the user has.
  static String _expandTimeGuidance(String timePref) {
    switch (timePref) {
      case 'Quick (under 20 min)':
        return 'Speedy weeknight cooking. Total time under 20 minutes. '
            'Simple techniques only — one-pan, sheet-pan, stir-fry, '
            'no-bake, microwaveable. Few ingredients, short clear steps. '
            'No long marinades, no slow simmering, no double-cooking.';
      case 'Around 30 minutes':
        return 'Standard weeknight cooking. Total time 25–35 minutes. '
            'Familiar techniques. Balance of effort and ease.';
      case 'Around 45 minutes':
        return 'Relaxed midweek cooking. Total time 40–50 minutes. '
            'Use the extra time for browning meat, reducing sauces, '
            'and building layered flavours. Steps can include sensory '
            'cues ("until deeply caramelised", "until just translucent", '
            '"until the foam subsides"). Aim for genuine depth, not just '
            'a longer weeknight dinner.';
      case 'No rush':
        return 'Weekend or unhurried cooking. 60–90 minutes is fine, '
            'longer is welcome if the dish rewards it. Use techniques '
            'that genuinely benefit from time: braising, slow-roasting, '
            'marinating, multi-stage cooking, layered components. '
            'Be ambitious — pick something with depth, technique, and '
            'a sense of occasion. Steps can be 2–3 sentences with '
            'sensory cues, timing notes, and chef voice. Avoid '
            'weeknight-shaped recipes (basic stir-fries, simple pastas, '
            'one-pan throw-togethers) unless the dish is genuinely '
            'iconic in that form. The user told us they have time — '
            'use it. Treat this as a meal worth cooking, not just '
            'feeding.';
      default:
        return '';
    }
  }

  /// Per-time-preference caps. Looser limits when the user has time,
  /// tighter limits when they're cooking quick. Returned alongside step
  /// length guidance so the rules block reads consistently.
  static ({int maxSteps, int maxIngredients, String stepLengthGuidance})
      _capsForTimePreference(String? timePref) {
    switch (timePref) {
      case 'No rush':
        return (
          maxSteps: 12,
          maxIngredients: 14,
          stepLengthGuidance:
              'Steps can be 2–3 sentences each with sensory cues, '
              'timing, and chef voice (e.g. "until the butter foams '
              'and starts to smell nutty"). Avoid robotic, mechanical '
              'phrasing.',
        );
      case 'Around 45 minutes':
        return (
          maxSteps: 10,
          maxIngredients: 12,
          stepLengthGuidance:
              'Steps should be 1–2 sentences with sensory cues '
              'where appropriate (e.g. "until the onions are deeply '
              'caramelised").',
        );
      case 'Around 30 minutes':
      case 'Quick (under 20 min)':
      default:
        return (
          maxSteps: 8,
          maxIngredients: 10,
          stepLengthGuidance: 'Keep steps SHORT (1–2 sentences each).',
        );
    }
  }

  /// Sprint 15.9.3 fix: previously this function handled
  /// 'Impress someone' / 'Something hearty' / 'Light bite' / 'Use everything
  /// up' — none of which are options the UI actually offers. The
  /// recipe_preferences_screen mood chips are: Easy, Impressive,
  /// Kid-friendly, Date night, Meal prep, Any. Result: every mood the
  /// user picked fell through to bare "Mood: X" text and Gemini ignored
  /// it. This rewrite matches the actual options.
  static String _expandMoodGuidance(String mood) {
    switch (mood) {
      case 'Easy':
        return 'Low-effort weeknight cooking. Few ingredients, simple '
            'familiar techniques, minimal prep, low cognitive load. '
            'Avoid multi-stage prep, exotic ingredients, or unfamiliar '
            'techniques. The user wants something that comes together '
            'with minimum fuss.';
      case 'Impressive':
        return 'A dish meant to impress — for guests, a special occasion, '
            'or just to feel proud of cooking. Restaurant-quality look '
            'and flavour. Use at least one elevated technique (searing, '
            'reducing a sauce, caramelising, layering flavours, making '
            'a dressing or glaze from scratch). Avoid anything that '
            'looks like a basic weeknight dinner. Include a brief plating '
            'or presentation tip in the final step. The title should '
            'sound appealing and sophisticated, not utilitarian.';
      case 'Kid-friendly':
        return 'Appealing to children. Mild flavours (avoid spicy, '
            'bitter, very pungent cheeses, strong herbs). Familiar '
            'shapes and textures, finger-food-friendly where possible. '
            'Hidden vegetables welcome. Sauces on the side rather than '
            'smothered. Avoid challenging textures (mushrooms, oily fish, '
            'anything slimy or strongly-flavoured). The dish should be '
            'recognisable to kids, not adventurous.';
      case 'Date night':
        return 'An at-home date-night dinner — relaxed but special. '
            'Two-portion focused (or scale appropriately). Pleasant '
            'aromatics during cooking are a plus. Slightly indulgent '
            'without being heavy or sleep-inducing. Wine-friendly. '
            'A glossy sauce or gentle char beats a stew. Should feel '
            'like an event, not a Tuesday. Include a small finishing '
            'touch (sprinkle of herbs, drizzle of oil, flaky salt) '
            'in the final step.';
      case 'Meal prep':
        return 'Optimised for batch cooking and storage. The dish must '
            'hold well in the fridge for 3–5 days OR freeze cleanly. '
            'Avoid fresh garnishes, raw greens, anything that wilts or '
            'gets soggy on reheat. Components that can be mixed-and-'
            'matched across the week are a plus (e.g. a sauce that '
            'works on multiple bases). Include portioning and reheating '
            'notes in the steps.';
      case 'Any':
        // Treat 'Any' as no mood preference — caller already wraps the
        // moodPreference field in a null check, so this just suppresses
        // the bare "Mood: Any" line by returning an empty string.
        return '';
      default:
        // Unknown / future mood — let the bare "Mood: X" line stand
        // rather than silently dropping the user's signal.
        return '';
    }
  }

  /// Builds a bulk-prep-specific prompt by extending the base prompt with
  /// batch cooking / freezing instructions and variety constraints.
  static String _buildBulkPrepPrompt(
    RecipeGenerationRequest request, {
    required int portions,
    required int mealNumber,
    required int totalMeals,
    required List<String> previousMealTitles,
  }) {
    final base = _buildPrompt(request);
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
      _buildBulkPrepPrompt(
        request,
        portions: portions,
        mealNumber: mealNumber,
        totalMeals: totalMeals,
        previousMealTitles: previousMealTitles,
      ),
      maxOutputTokens: 2048,
      // Sprint 15.9.3 SAFETY: bulk prep also runs post-gen allergen
      // filter. A peanut-allergy user's batch-cook recipe should
      // never include peanut butter either.
      allergenGuard: request.customAllergens,
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

    final json = _extractJson(rawText);
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

    final json = _extractJson(rawText);
    if (json.containsKey('error')) {
      throw Exception(json['error'] as String);
    }

    return _parseGeneratedRecipe(json);
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

    final json = _extractJson(rawText);
    if (json.containsKey('error')) {
      throw Exception(json['error'] as String);
    }

    return _parseGeneratedRecipe(json);
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
      ..writeln('IMPORTANT: Reply with ONLY a single valid JSON object. No prose, no markdown fences, nothing before or after the JSON.')
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
    const int maxAttempts = 2;
    Object? lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
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

        if (response.statusCode == 401 || response.statusCode == 403 ||
            response.statusCode == 400 || response.statusCode == 429) {
          // Auth / bad-request / rate-limit — retry won't help.
          throw Exception('Side dish generation failed (${response.statusCode}). Please try again.');
        }
        if (response.statusCode != 200) {
          // 5xx and other transient — retry path below.
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

        final json = _extractJson(rawText);
        return _parseGeneratedRecipe(json);
      } catch (e) {
        lastError = e;
        ErrorService.log('side_dish_attempt_$attempt', e);
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
      }
    }

    if (lastError is Exception) throw lastError;
    throw Exception('Side dish generation failed. Please try again.');
  }
}
