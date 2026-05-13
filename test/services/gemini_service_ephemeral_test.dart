import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/models/elio_models.dart';
import 'package:elio_app/models/onboarding_state.dart';
import 'package:elio_app/models/recipe_models.dart';
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

  // Sprint 16.6 row 5b — meal-type hard constraint. When the user picks a
  // chip on RecipePreferencesScreen, the request carries `mealType` and
  // the prompt must emit a hard MUST line. When null, no line at all
  // (option A — trust Gemini's priors, no positive example anchors).
  group('mealType hard constraint (Sprint 16.6 row 5b)', () {
    const RecipeGenerationRequest baseRequest = RecipeGenerationRequest(
      perishables: [],
      alwaysHave: [],
      almostAlwaysHave: [],
      dietaryRequirements: [],
    );

    test('omits the meal-type line when mealType is null', () {
      final prompt = GeminiService.buildPromptForTest(baseRequest);
      expect(prompt.toLowerCase(), isNot(contains('breakfast recipe')));
      expect(prompt.toLowerCase(), isNot(contains('lunch recipe')));
      expect(prompt.toLowerCase(), isNot(contains('dinner recipe')));
    });

    test('emits the hard constraint for Breakfast', () {
      final prompt = GeminiService.buildPromptForTest(
        const RecipeGenerationRequest(
          perishables: [],
          alwaysHave: [],
          almostAlwaysHave: [],
          dietaryRequirements: [],
          mealType: 'Breakfast',
        ),
      );
      expect(prompt, contains('You MUST make a Breakfast recipe'));
      expect(prompt, contains('hard requirement'));
      // Lives inside HARD CONSTRAINTS block, not buried after.
      final hardIdx = prompt.indexOf('## HARD CONSTRAINTS');
      final mealIdx = prompt.indexOf('Breakfast recipe');
      expect(hardIdx, greaterThan(-1));
      expect(mealIdx, greaterThan(hardIdx));
    });

    test('emits the hard constraint for Lunch', () {
      final prompt = GeminiService.buildPromptForTest(
        const RecipeGenerationRequest(
          perishables: [],
          alwaysHave: [],
          almostAlwaysHave: [],
          dietaryRequirements: [],
          mealType: 'Lunch',
        ),
      );
      expect(prompt, contains('You MUST make a Lunch recipe'));
    });

    test('emits the hard constraint for Dinner', () {
      final prompt = GeminiService.buildPromptForTest(
        const RecipeGenerationRequest(
          perishables: [],
          alwaysHave: [],
          almostAlwaysHave: [],
          dietaryRequirements: [],
          mealType: 'Dinner',
        ),
      );
      expect(prompt, contains('You MUST make a Dinner recipe'));
    });

    test('no positive example list (no anchoring on specific dishes)', () {
      // Deliberate: we do NOT list "eggs / toast / oatmeal" etc. The
      // concern is anchoring — concrete examples bias Gemini toward those
      // exact items and narrow regional/cultural breadth. Bare assertion
      // only. If on-device shows drift later, add negative constraints
      // surgically — never positive example lists. Regression guard.
      final prompt = GeminiService.buildPromptForTest(
        const RecipeGenerationRequest(
          perishables: [],
          alwaysHave: [],
          almostAlwaysHave: [],
          dietaryRequirements: [],
          mealType: 'Breakfast',
        ),
      );
      // Common breakfast-example words that should NOT appear in the
      // prompt as part of the mealType guidance.
      for (final word in const ['oatmeal', 'pancakes', 'granola', 'smoothie']) {
        expect(prompt.toLowerCase(), isNot(contains(word)),
            reason: 'mealType prompt must not list "$word" — anchors output.');
      }
    });
  });
}
