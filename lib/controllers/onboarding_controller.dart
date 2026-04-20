import 'package:flutter/foundation.dart';
import '../models/elio_models.dart';
import '../models/onboarding_state.dart';

// ─────────────────────────────────────────────
// OnboardingController
//
// ChangeNotifier that wraps OnboardingState for the 15-screen
// onboarding flow. Screens listen via AnimatedBuilder /
// ListenableBuilder to observe state changes without rebuilding
// the whole flow on every setter call.
// ─────────────────────────────────────────────

class OnboardingController extends ChangeNotifier {
  OnboardingState _state = OnboardingState();
  OnboardingState get state => _state;

  void setUserGoal(String v) {
    _state = _state.copyWith(userGoal: v);
    notifyListeners();
  }

  void setHouseholdType(String v) {
    _state = _state.copyWith(householdType: v);
    notifyListeners();
  }

  void setHouseholdCount(int v) {
    _state = _state.copyWith(householdCount: v);
    notifyListeners();
  }

  void setHouseholdDiffering(bool v) {
    // When toggling OFF, clear the union so effectiveDietary falls back cleanly.
    _state = _state.copyWith(
      householdHasDifferingDiet: v,
      householdCombinedDietary:
          v ? _state.householdCombinedDietary : <String>[],
    );
    notifyListeners();
  }

  void setHouseholdCombinedDietary(List<String> v) {
    _state = _state.copyWith(householdCombinedDietary: v);
    notifyListeners();
  }

  void setDietary(List<String> v) {
    _state = _state.copyWith(dietary: v);
    notifyListeners();
  }

  void setAllergies(List<String> v) {
    _state = _state.copyWith(allergies: v);
    notifyListeners();
  }

  void setDislikes(List<String> v) {
    _state = _state.copyWith(dislikes: v);
    notifyListeners();
  }

  void setMaxCookTime(int v) {
    _state = _state.copyWith(maxCookTime: v);
    notifyListeners();
  }

  void setCookingConfidence(String v) {
    _state = _state.copyWith(cookingConfidence: v);
    notifyListeners();
  }

  void setAppliances(List<String> v) {
    _state = _state.copyWith(appliances: v);
    notifyListeners();
  }

  void setRegion(String v) {
    _state = _state.copyWith(region: v);
    notifyListeners();
  }

  void setMeasurementUnits(String v) {
    _state = _state.copyWith(measurementUnits: v);
    notifyListeners();
  }

  void setInventory(List<InventoryItem> v) {
    _state = _state.copyWith(inventory: List<InventoryItem>.from(v));
    notifyListeners();
  }

  void setFirstRecipeId(String v) {
    _state = _state.copyWith(firstRecipeId: v);
    notifyListeners();
  }

  void setEntitlement(String v) {
    _state = _state.copyWith(entitlement: v);
    notifyListeners();
  }

  void incrementRegenerateCount() {
    if (_state.regenerateCount >= 3) return;
    _state = _state.copyWith(regenerateCount: _state.regenerateCount + 1);
    notifyListeners();
  }
}
