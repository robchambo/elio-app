import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/models/onboarding_state.dart';
import 'package:elio_app/services/migration_service.dart';

void main() {
  test('buildUserDocPayload includes all spec fields', () {
    final s = OnboardingState()
      ..userGoal = 'pantryFirst'
      ..householdType = 'couple';
    final payload = MigrationService.buildUserDocPayload(s);
    expect(payload['userGoal'], 'pantryFirst');
    expect(payload['householdType'], 'couple');
    expect(payload['dietary'], <String>[]);
  });
}
