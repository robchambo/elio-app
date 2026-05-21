// test/screens/account/account_actions_test.dart
//
// Sprint 16.1.x — Auth UX fix
//
// Pure-function tests for the sign-out / restart-onboarding helpers
// extracted from AccountScreen. These exist as their own functions
// (not private methods) so the SharedPreferences side-effect can be
// asserted directly without dragging Firebase / FirestoreService /
// PackageInfo into the widget test rig.
//
// The behaviour under test:
//
//   - `performSignOut` MUST sign Firebase out but MUST NOT wipe the
//     `onboardingComplete` SharedPreferences flag. Pre-fix, the
//     AccountScreen wiped it on every sign-out, which forced the
//     user back through the 15-screen onboarding flow just to test
//     a different account or hit the sign-in screen.
//
//   - `performRestartOnboarding` is the deliberate "I want to walk
//     the flow again" action. It signs Firebase out, clears the
//     guest-pantry SharedPreferences keys, and wipes the
//     `onboardingComplete` flag. This is what the *old* sign-out
//     behaviour effectively did, but now it's an opt-in tile under
//     About → Restart Onboarding rather than a side-effect of
//     "Sign Out".

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elio_app/screens/account/account_actions.dart';

void main() {
  group('performSignOut', () {
    test('signs Firebase out via the provided callback', () async {
      SharedPreferences.setMockInitialValues({'onboardingComplete': true});
      var firebaseSignOutCalls = 0;

      await performSignOut(
        firebaseSignOut: () async {
          firebaseSignOutCalls += 1;
        },
      );

      expect(firebaseSignOutCalls, 1);
    });

    test('does NOT wipe onboardingComplete (the bug fix)', () async {
      SharedPreferences.setMockInitialValues({'onboardingComplete': true});

      await performSignOut(firebaseSignOut: () async {});

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('onboardingComplete'),
        isTrue,
        reason: 'Sign-out must not push the user back into the 15-screen '
            'onboarding flow. They should land on AppShell as a guest '
            'with the Sign In tile visible on AccountScreen.',
      );
    });

    test('does NOT clear the guest-pantry SharedPreferences keys',
        () async {
      // Sign-out from a signed-in user should not nuke pantry state — that
      // state was either migrated to Firestore on sign-in (so it's safe in
      // the cloud) or the user added it as a guest later (in which case it
      // belongs to the device).
      SharedPreferences.setMockInitialValues({
        'onboardingComplete': true,
        'guest_staples': '{"Salt":"always"}',
        'guest_perishables': '{"Spinach":"thisWeek"}',
      });

      await performSignOut(firebaseSignOut: () async {});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('guest_staples'), '{"Salt":"always"}');
      expect(prefs.getString('guest_perishables'), '{"Spinach":"thisWeek"}');
    });
  });

  group('performRestartOnboarding', () {
    test('signs Firebase out via the provided callback', () async {
      SharedPreferences.setMockInitialValues({'onboardingComplete': true});
      var firebaseSignOutCalls = 0;

      await performRestartOnboarding(
        firebaseSignOut: () async {
          firebaseSignOutCalls += 1;
        },
        clearGuestPantry: () async {},
      );

      expect(firebaseSignOutCalls, 1);
    });

    test('clears the guest pantry via the provided callback', () async {
      SharedPreferences.setMockInitialValues({'onboardingComplete': true});
      var guestPantryClearCalls = 0;

      await performRestartOnboarding(
        firebaseSignOut: () async {},
        clearGuestPantry: () async {
          guestPantryClearCalls += 1;
        },
      );

      expect(guestPantryClearCalls, 1);
    });

    test('wipes onboardingComplete to false', () async {
      SharedPreferences.setMockInitialValues({'onboardingComplete': true});

      await performRestartOnboarding(
        firebaseSignOut: () async {},
        clearGuestPantry: () async {},
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboardingComplete'), isFalse);
    });

    test('still wipes onboardingComplete when it was never set', () async {
      SharedPreferences.setMockInitialValues({});

      await performRestartOnboarding(
        firebaseSignOut: () async {},
        clearGuestPantry: () async {},
      );

      final prefs = await SharedPreferences.getInstance();
      // Either explicitly false or absent — both route through onboarding
      // via AuthGate. We assert explicit false because that's the contract.
      expect(prefs.getBool('onboardingComplete'), isFalse);
    });
  });
}
