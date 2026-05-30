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
    test('hero ingredient appears in the user-chosen-items list', () {
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

      // 13 May 2026 (deliberation-bleed plan Step 2.1): the section
      // header changed from `REQUIRED ingredients — you MUST use ALL`
      // to `Items the user has specifically chosen to use:` with a
      // bullet list. The anti-bleed instruction sentence lives
      // below the data, not adjacent to it. Hero name still appears.
      expect(prompt, contains('Items the user has specifically chosen'));
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

    test('emits the meal-type hard requirement for Breakfast', () {
      // 13 May 2026 (deliberation-bleed Step 1.2) downgraded meal-type to a
      // soft `Meal type: Breakfast` hint. RE-PROMOTED to a hard requirement
      // in 8aa8b42 (`fix(gemini): mealType promoted back to HARD constraint
      // on flash-lite`) after an on-device finding that meal-type still
      // dropped on regen — flash-lite lacks the reasoning headroom the soft
      // hint relied on. Still position-sensitive inside HARD CONSTRAINTS.
      final prompt = GeminiService.buildPromptForTest(
        const RecipeGenerationRequest(
          perishables: [],
          alwaysHave: [],
          almostAlwaysHave: [],
          dietaryRequirements: [],
          mealType: 'Breakfast',
        ),
      );
      expect(prompt, contains('Meal type: Breakfast'));
      expect(prompt,
          contains('The recipe MUST be appropriate to serve as breakfast'));
      // Still lives inside the HARD CONSTRAINTS block (position
      // matters for LLM attention even when wording is softened).
      final hardIdx = prompt.indexOf('## HARD CONSTRAINTS');
      final mealIdx = prompt.indexOf('Meal type: Breakfast');
      expect(hardIdx, greaterThan(-1));
      expect(mealIdx, greaterThan(hardIdx));
    });

    test('emits the meal-type hint for Lunch', () {
      final prompt = GeminiService.buildPromptForTest(
        const RecipeGenerationRequest(
          perishables: [],
          alwaysHave: [],
          almostAlwaysHave: [],
          dietaryRequirements: [],
          mealType: 'Lunch',
        ),
      );
      expect(prompt, contains('Meal type: Lunch'));
    });

    test('emits the meal-type hint for Dinner', () {
      final prompt = GeminiService.buildPromptForTest(
        const RecipeGenerationRequest(
          perishables: [],
          alwaysHave: [],
          almostAlwaysHave: [],
          dietaryRequirements: [],
          mealType: 'Dinner',
        ),
      );
      expect(prompt, contains('Meal type: Dinner'));
    });

    test('meal-type carries the anti-drift hard requirement (8aa8b42)', () {
      // Supersedes the old "does NOT stack a third MUST (downgraded 13 May)"
      // guard. 8aa8b42 re-promoted meal-type to a hard requirement on
      // flash-lite specifically to stop regen drift, so the prompt now
      // carries the "hard requirement" + anti-drift wording. We still avoid
      // the over-blunt `You MUST make a Dinner` phrasing — the constraint is
      // "the recipe MUST be appropriate to serve as <meal>", not a command.
      final prompt = GeminiService.buildPromptForTest(
        const RecipeGenerationRequest(
          perishables: [],
          alwaysHave: [],
          almostAlwaysHave: [],
          dietaryRequirements: [],
          mealType: 'Dinner',
        ),
      );
      expect(prompt, isNot(contains('You MUST make a Dinner')));
      expect(prompt, contains('this is a hard requirement, not a preference'));
      expect(prompt,
          contains('Do not drift to a different meal occasion on regeneration'));
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

  // Sprint 16.6 (Notion XX bug 3) — VARIATION section. When recent
  // hero ingredients or cookware are present in the request, the
  // prompt must include a `## VARIATION` section telling Gemini to
  // pick a different protagonist + cookware. When both lists are
  // empty, the section must be omitted entirely (no empty header).
  group('VARIATION section (Sprint 16.6 row XX bug 3)', () {
    const RecipeGenerationRequest baseRequest = RecipeGenerationRequest(
      perishables: [],
      alwaysHave: [],
      almostAlwaysHave: [],
      dietaryRequirements: [],
    );

    test('omitted when both lists are empty', () {
      final prompt = GeminiService.buildPromptForTest(baseRequest);
      expect(prompt, isNot(contains('## VARIATION')));
    });

    test('emits the section when recentHeroIngredients is non-empty', () {
      final prompt = GeminiService.buildPromptForTest(
        const RecipeGenerationRequest(
          perishables: [],
          alwaysHave: [],
          almostAlwaysHave: [],
          dietaryRequirements: [],
          recentHeroIngredients: ['chickpeas', 'chickpeas', 'chickpeas'],
        ),
      );
      expect(prompt, contains('## VARIATION'));
      expect(prompt,
          contains('Hero ingredients in the user\'s last 3 recipes: chickpeas, chickpeas, chickpeas'));
      // 14 May 2026 — tightened wording: was "Pick a DIFFERENT hero
      // ingredient", now "Do not use any of the above as the primary
      // protagonist of THIS recipe". Regression guard against the
      // softer phrasing slipping back.
      expect(prompt.toLowerCase(), contains('do not use any of the above'));
      expect(prompt, contains('primary protagonist'));
    });

    test('emits the section when recentCookware is non-empty', () {
      final prompt = GeminiService.buildPromptForTest(
        const RecipeGenerationRequest(
          perishables: [],
          alwaysHave: [],
          almostAlwaysHave: [],
          dietaryRequirements: [],
          recentCookware: ['skillet', 'skillet', 'skillet'],
        ),
      );
      expect(prompt, contains('## VARIATION'));
      expect(prompt,
          contains('Cookware in the user\'s last 3 recipes: skillet, skillet, skillet'));
    });

    test('mentions varying descriptive language', () {
      // Rob's complaint included repetitive language ("hearty") even
      // when ingredients varied. The VARIATION block must call this
      // out so Gemini doesn't paraphrase the same adjectives.
      final prompt = GeminiService.buildPromptForTest(
        const RecipeGenerationRequest(
          perishables: [],
          alwaysHave: [],
          almostAlwaysHave: [],
          dietaryRequirements: [],
          recentHeroIngredients: ['tofu'],
        ),
      );
      expect(prompt.toLowerCase(), contains('vary your descriptive language'));
      expect(prompt.toLowerCase(), contains('hearty'));
    });
  });
}
