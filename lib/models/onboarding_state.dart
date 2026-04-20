import 'elio_models.dart';

// ─────────────────────────────────────────────
// OnboardingState
// In-memory state for the 15-screen onboarding flow.
// Persisted to Firestore post-sign-in by MigrationService.
// ─────────────────────────────────────────────

class OnboardingState {
  String? userGoal;
  String? householdType;
  int householdCount;
  bool householdHasDifferingDiet;
  List<String> householdCombinedDietary;
  List<String> dietary;
  List<String> allergies;
  List<String> dislikes;
  int? maxCookTime;
  String? cookingConfidence;
  List<String> appliances;
  String region;
  String measurementUnits;
  List<InventoryItem> inventory;
  String? firstRecipeId;
  String? entitlement;
  int regenerateCount;

  OnboardingState({
    this.userGoal,
    this.householdType,
    this.householdCount = 1,
    this.householdHasDifferingDiet = false,
    List<String>? householdCombinedDietary,
    List<String>? dietary,
    List<String>? allergies,
    List<String>? dislikes,
    this.maxCookTime,
    this.cookingConfidence,
    List<String>? appliances,
    this.region = 'uk',
    this.measurementUnits = 'metric',
    List<InventoryItem>? inventory,
    this.firstRecipeId,
    this.entitlement,
    this.regenerateCount = 0,
  })  : dietary = dietary ?? [],
        householdCombinedDietary = householdCombinedDietary ?? [],
        allergies = allergies ?? [],
        dislikes = dislikes ?? [],
        appliances = appliances ?? [],
        inventory = inventory ?? [];

  /// Dietary constraints to pass to Gemini.
  /// Returns the household union when the "differing diet" toggle is on
  /// AND the union has been populated; otherwise the user's own dietary.
  List<String> get effectiveDietary =>
      (householdHasDifferingDiet && householdCombinedDietary.isNotEmpty)
          ? householdCombinedDietary
          : dietary;

  OnboardingState copyWith({
    String? userGoal,
    String? householdType,
    int? householdCount,
    bool? householdHasDifferingDiet,
    List<String>? householdCombinedDietary,
    List<String>? dietary,
    List<String>? allergies,
    List<String>? dislikes,
    int? maxCookTime,
    String? cookingConfidence,
    List<String>? appliances,
    String? region,
    String? measurementUnits,
    List<InventoryItem>? inventory,
    String? firstRecipeId,
    String? entitlement,
    int? regenerateCount,
  }) =>
      OnboardingState(
        userGoal: userGoal ?? this.userGoal,
        householdType: householdType ?? this.householdType,
        householdCount: householdCount ?? this.householdCount,
        householdHasDifferingDiet:
            householdHasDifferingDiet ?? this.householdHasDifferingDiet,
        householdCombinedDietary:
            householdCombinedDietary ?? this.householdCombinedDietary,
        dietary: dietary ?? this.dietary,
        allergies: allergies ?? this.allergies,
        dislikes: dislikes ?? this.dislikes,
        maxCookTime: maxCookTime ?? this.maxCookTime,
        cookingConfidence: cookingConfidence ?? this.cookingConfidence,
        appliances: appliances ?? this.appliances,
        region: region ?? this.region,
        measurementUnits: measurementUnits ?? this.measurementUnits,
        inventory: inventory ?? this.inventory,
        firstRecipeId: firstRecipeId ?? this.firstRecipeId,
        entitlement: entitlement ?? this.entitlement,
        regenerateCount: regenerateCount ?? this.regenerateCount,
      );

  Map<String, dynamic> toFirestoreMap() => {
        'userGoal': userGoal,
        'householdType': householdType,
        'householdCount': householdCount,
        'householdHasDifferingDiet': householdHasDifferingDiet,
        'householdCombinedDietary': householdCombinedDietary,
        'dietary': dietary,
        'allergies': allergies,
        'dislikes': dislikes,
        'maxCookTime': maxCookTime,
        'cookingConfidence': cookingConfidence,
        'appliances': appliances,
        'region': region,
        'measurementUnits': measurementUnits,
        'firstRecipeId': firstRecipeId,
        'entitlement': entitlement,
      };
}
