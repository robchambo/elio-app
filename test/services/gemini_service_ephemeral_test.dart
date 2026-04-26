import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/models/elio_models.dart';
import 'package:elio_app/models/onboarding_state.dart';
import 'package:elio_app/services/gemini_service.dart';

// ─────────────────────────────────────────────
// GeminiService ephemeral entry point — Task 5.0
//
// streamGenerateContentEphemeral builds a RecipeGenerationRequest from
// an in-memory pantry + OnboardingState and funnels it through the
// existing _buildPrompt / _streamFromPrompt plumbing — no Firestore reads.
//
// We verify the *prompt* text rather than sending an actual request.
// The service exposes `buildEphemeralPromptForTest` (visibleForTesting)
// so these assertions don't require network/Firebase init.
// ─────────────────────────────────────────────

void main() {
  group('GeminiService.streamGenerateContentEphemeral prompt', () {
    test('hero ingredient appears in the REQUIRED list', () {
      final pantry = [
        const InventoryItem(name: 'Chicken thighs', tier: 'perishable'),
        const InventoryItem(name: 'Lemon', tier: 'perishable'),
      ];
      final prefs = OnboardingState(
        dietary: [],
        householdCount: 2,
      );

      final prompt = GeminiService.buildEphemeralPromptForTest(
        pantry: pantry,
        prefs: prefs,
        heroIngredientName: 'Lemon',
      );

      // _buildPrompt writes "REQUIRED ingredients — you MUST use ALL of these"
      // and lists the items. The hero name must appear in that line.
      expect(prompt, contains('REQUIRED ingredients'));
      expect(prompt, contains('Lemon'));
    });

    test('dietary reflects effectiveDietary when household toggle ON', () {
      final prefs = OnboardingState(
        dietary: ['vegan'],
        householdHasDifferingDiet: true,
        householdCombinedDietary: ['vegan', 'pescatarian'],
      );

      final prompt = GeminiService.buildEphemeralPromptForTest(
        pantry: const [],
        prefs: prefs,
      );

      expect(prompt, contains('Dietary: vegan, pescatarian'));
    });

    test('dietary reflects user own dietary when household toggle OFF', () {
      final prefs = OnboardingState(
        dietary: ['vegan'],
        householdHasDifferingDiet: false,
        householdCombinedDietary: ['vegan', 'pescatarian'],
      );

      final prompt = GeminiService.buildEphemeralPromptForTest(
        pantry: const [],
        prefs: prefs,
      );

      expect(prompt, contains('Dietary: vegan'));
      expect(prompt, isNot(contains('pescatarian')));
    });

    test('pantry items land in the inventory section', () {
      final pantry = [
        const InventoryItem(name: 'Olive oil', tier: 'alwaysHave'),
        const InventoryItem(name: 'Pasta', tier: 'almostAlwaysHave'),
        const InventoryItem(name: 'Spinach', tier: 'perishable'),
      ];
      final prefs = OnboardingState();

      final prompt = GeminiService.buildEphemeralPromptForTest(
        pantry: pantry,
        prefs: prefs,
      );

      expect(prompt, contains('## INVENTORY'));
      expect(prompt, contains('Olive oil'));
      expect(prompt, contains('Pasta'));
      expect(prompt, contains('Spinach'));
    });

    test('servings derives from householdCount', () {
      final prefs = OnboardingState(householdCount: 4);
      final prompt = GeminiService.buildEphemeralPromptForTest(
        pantry: const [],
        prefs: prefs,
      );
      expect(prompt, contains('Servings: 4'));
    });

    test('appliances are passed through', () {
      final prefs = OnboardingState(
        appliances: ['oven', 'hob', 'air fryer'],
      );
      final prompt = GeminiService.buildEphemeralPromptForTest(
        pantry: const [],
        prefs: prefs,
      );
      expect(prompt, contains('oven'));
      expect(prompt, contains('air fryer'));
    });

    // Sprint 16.3 Bug 10 — Gemini must assume the user has water, salt,
    // and basic cooking oil so they aren't listed in the ingredients
    // array. Regression guard: a single rules line covers all three.
    test('assumes water, salt, and cooking oil are always available', () {
      final prompt = GeminiService.buildEphemeralPromptForTest(
        pantry: const [],
        prefs: OnboardingState(),
      );

      // The assumption rule sits in the RULES block and mentions all
      // three so they're treated consistently.
      final rulesIndex = prompt.indexOf('## RULES:');
      expect(rulesIndex, greaterThan(-1));
      final rules = prompt.substring(rulesIndex);
      expect(rules.toLowerCase(), contains('water'));
      expect(rules.toLowerCase(), contains('salt'));
      expect(rules.toLowerCase(), contains('oil'));
      // And tells Gemini NOT to list them as ingredients.
      expect(rules.toLowerCase(), contains('do not list'));
    });
  });
}
