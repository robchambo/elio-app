// ─────────────────────────────────────────────
// OnboardingState
// Accumulates user choices across all four onboarding screens
// before writing to Firestore in a single batch on completion.
// ─────────────────────────────────────────────

import 'elio_models.dart';

class OnboardingState {
  // Screen 1: Dietary requirements for the primary user
  List<DietaryRequirement> dietaryRequirements;

  // Screen 2: Kitchen preset selection
  KitchenPreset? kitchenPreset;

  // Screen 3: Reviewed and adjusted inventory
  List<InventoryItem> inventory;

  // Screen 4: Additional household members (optional)
  List<HouseholdProfile> additionalMembers;

  // Screen 5: Food style preferences (optional)
  List<String> stylePreferences;

  // Screen 6: Kitchen appliances owned (optional)
  List<String> appliances;

  // Screen 1 extra: custom allergens entered as free text
  List<String> customAllergens;

  OnboardingState({
    List<DietaryRequirement>? dietaryRequirements,
    this.kitchenPreset,
    List<InventoryItem>? inventory,
    List<HouseholdProfile>? additionalMembers,
    List<String>? stylePreferences,
    List<String>? appliances,
    List<String>? customAllergens,
  })  : dietaryRequirements = dietaryRequirements ?? [],
        inventory = inventory ?? [],
        additionalMembers = additionalMembers ?? [],
        stylePreferences = stylePreferences ?? [],
        appliances = appliances ?? [],
        customAllergens = customAllergens ?? [];

  OnboardingState copyWith({
    List<DietaryRequirement>? dietaryRequirements,
    KitchenPreset? kitchenPreset,
    List<InventoryItem>? inventory,
    List<HouseholdProfile>? additionalMembers,
    List<String>? stylePreferences,
    List<String>? appliances,
    List<String>? customAllergens,
  }) {
    return OnboardingState(
      dietaryRequirements: dietaryRequirements ?? this.dietaryRequirements,
      kitchenPreset: kitchenPreset ?? this.kitchenPreset,
      inventory: inventory ?? this.inventory,
      additionalMembers: additionalMembers ?? this.additionalMembers,
      stylePreferences: stylePreferences ?? this.stylePreferences,
      appliances: appliances ?? this.appliances,
      customAllergens: customAllergens ?? this.customAllergens,
    );
  }
}
