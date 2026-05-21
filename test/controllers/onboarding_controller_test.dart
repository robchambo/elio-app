import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/controllers/onboarding_controller.dart';

void main() {
  test('setUserGoal updates state and notifies', () {
    final c = OnboardingController();
    var notified = 0;
    c.addListener(() => notified++);
    c.setUserGoal('pantryFirst');
    expect(c.state.userGoal, 'pantryFirst');
    expect(notified, 1);
  });

  test('incrementRegenerateCount caps at 3', () {
    final c = OnboardingController();
    for (var i = 0; i < 5; i++) {
      c.incrementRegenerateCount();
    }
    expect(c.state.regenerateCount, 3);
  });
}
