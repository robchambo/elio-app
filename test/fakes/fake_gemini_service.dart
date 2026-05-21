import 'dart:async';

import 'package:elio_app/models/elio_models.dart';
import 'package:elio_app/models/onboarding_state.dart';
import 'package:elio_app/models/recipe_models.dart';

// ─────────────────────────────────────────────
// FakeGeminiService — test double for screen 13's ephemeral recipe stream.
//
// Captures the arguments passed to each call and exposes a controllable
// [StreamController] per call so tests can drive streaming behaviour
// deterministically (emit partial chunks, complete, or error).
//
// Tests typically:
//   1. Construct FakeGeminiService().
//   2. Pump the screen with fake.stream as the stream function.
//   3. Await `fake.pumpCall()` — returns once the screen has subscribed.
//   4. Emit events via `fake.emitGenerating()` / `fake.emitComplete(...)`
//      / `fake.emitError(...)`.
// ─────────────────────────────────────────────

class FakeGeminiCall {
  final List<InventoryItem> pantry;
  final OnboardingState prefs;
  final String? heroIngredientName;
  final List<String> recentTitles;
  final StreamController<RecipeGenerationStatus> controller;

  FakeGeminiCall({
    required this.pantry,
    required this.prefs,
    required this.heroIngredientName,
    this.recentTitles = const [],
  }) : controller = StreamController<RecipeGenerationStatus>.broadcast();
}

class FakeGeminiService {
  final List<FakeGeminiCall> calls = [];

  FakeGeminiCall get lastCall => calls.last;

  /// Convenience — read `effectiveDietary` on the last call's captured prefs.
  List<String> get capturedDietary => lastCall.prefs.effectiveDietary;

  /// The function to inject as `streamFn` on the screen.
  Stream<RecipeGenerationStatus> stream({
    required List<InventoryItem> pantry,
    required OnboardingState prefs,
    String? heroIngredientName,
    List<String> recentTitles = const [],
  }) {
    final call = FakeGeminiCall(
      pantry: pantry,
      prefs: prefs,
      heroIngredientName: heroIngredientName,
      recentTitles: List<String>.from(recentTitles),
    );
    calls.add(call);
    return call.controller.stream;
  }

  void emitGenerating({int bytes = 100}) {
    lastCall.controller.add(RecipeGenerating(bytesReceived: bytes));
  }

  void emitComplete(GeneratedRecipe recipe) {
    lastCall.controller.add(RecipeComplete(recipe: recipe));
  }

  void emitError(String message) {
    lastCall.controller.add(RecipeError(message: message));
  }

  Future<void> closeAll() async {
    for (final c in calls) {
      await c.controller.close();
    }
  }
}

// ── Test helper — a minimal GeneratedRecipe for the "Complete" state ─────
GeneratedRecipe buildFakeRecipe({
  String title = 'Lemon & Garlic Chicken Traybake',
  List<RecipeIngredient>? ingredients,
}) {
  return GeneratedRecipe(
    title: title,
    description: 'A simple traybake built from your pantry.',
    prepTimeMinutes: 10,
    cookTimeMinutes: 15,
    servings: 2,
    ingredients: ingredients ??
        const [
          RecipeIngredient(
              name: 'Chicken thighs',
              quantity: '4',
              unit: '',
              fromInventory: true),
          RecipeIngredient(
              name: 'Lemon', quantity: '1', unit: '', fromInventory: true),
          RecipeIngredient(
              name: 'Garlic', quantity: '3', unit: 'cloves', fromInventory: true),
          RecipeIngredient(
              name: 'Cherry tomatoes',
              quantity: '200',
              unit: 'g',
              fromInventory: false),
        ],
    steps: const ['Preheat the oven.', 'Roast for 25 minutes.'],
    substitutions: const [],
    dietaryTags: const [],
  );
}
