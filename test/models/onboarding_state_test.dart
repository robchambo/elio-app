import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/models/onboarding_state.dart';

void main() {
  group('OnboardingState', () {
    test('defaults match spec', () {
      final s = OnboardingState();
      expect(s.userGoal, isNull);
      expect(s.householdType, isNull);
      expect(s.householdCount, 1);
      expect(s.householdHasDifferingDiet, false);
      expect(s.householdCombinedDietary, <String>[]);
      expect(s.dietary, <String>[]);
      expect(s.allergies, <String>[]);
      expect(s.dislikes, <String>[]);
      expect(s.maxCookTime, isNull);
      expect(s.cookingConfidence, isNull);
      expect(s.appliances, <String>[]);
      expect(s.region, 'uk');
      expect(s.measurementUnits, 'metric');
      expect(s.inventory, isEmpty);
      expect(s.firstRecipeId, isNull);
      expect(s.entitlement, isNull);
      expect(s.regenerateCount, 0);
    });

    test('copyWith updates userGoal only', () {
      final s = OnboardingState().copyWith(userGoal: 'pantryFirst');
      expect(s.userGoal, 'pantryFirst');
      expect(s.householdCount, 1);
    });

    test('effectiveDietary falls back to user dietary when toggle off', () {
      final s = OnboardingState(
        dietary: ['vegan'],
        householdHasDifferingDiet: false,
        householdCombinedDietary: ['vegan', 'pescatarian'],
      );
      expect(s.effectiveDietary, ['vegan']);
    });

    test('effectiveDietary uses combined when toggle on and non-empty', () {
      final s = OnboardingState(
        dietary: ['vegan'],
        householdHasDifferingDiet: true,
        householdCombinedDietary: ['vegan', 'pescatarian'],
      );
      expect(s.effectiveDietary, ['vegan', 'pescatarian']);
    });

    test('effectiveDietary falls back to user dietary when toggle on but combined empty', () {
      final s = OnboardingState(
        dietary: ['halal'],
        householdHasDifferingDiet: true,
        householdCombinedDietary: [],
      );
      expect(s.effectiveDietary, ['halal']);
    });
  });
}
