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

  OnboardingState({
    List<DietaryRequirement>? dietaryRequirements,
    this.kitchenPreset,
    List<InventoryItem>? inventory,
    List<HouseholdProfile>? additionalMembers,
    List<String>? stylePreferences,
  })  : dietaryRequirements = dietaryRequirements ?? [],
        inventory = inventory ?? [],
        additionalMembers = additionalMembers ?? [],
        stylePreferences = stylePreferences ?? [];

  OnboardingState copyWith({
    List<DietaryRequirement>? dietaryRequirements,
    KitchenPreset? kitchenPreset,
    List<InventoryItem>? inventory,
    List<HouseholdProfile>? additionalMembers,
    List<String>? stylePreferences,
  }) {
    return OnboardingState(
      dietaryRequirements: dietaryRequirements ?? this.dietaryRequirements,
      kitchenPreset: kitchenPreset ?? this.kitchenPreset,
      inventory: inventory ?? this.inventory,
      additionalMembers: additionalMembers ?? this.additionalMembers,
      stylePreferences: stylePreferences ?? this.stylePreferences,
    );
  }
}
