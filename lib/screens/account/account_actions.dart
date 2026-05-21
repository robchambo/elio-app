// lib/screens/account/account_actions.dart
//
// Sprint 16.1.x — Auth UX fix.
//
// Pure top-level helpers for the "Sign Out" and "Restart Onboarding"
// AccountScreen actions. They live outside the widget so the
// SharedPreferences side-effect can be unit-tested without dragging
// the rest of AccountScreen's Firebase/Firestore initState chain into
// the rig.
//
// Behaviour contract:
//
//   - `performSignOut` — calls the Firebase sign-out callback and
//     INTENTIONALLY does NOT wipe `onboardingComplete`. Pre-fix, the
//     old AccountScreen wiped the flag every sign-out, which forced
//     the user back through the 15-screen onboarding flow just to
//     test a different account or reach the sign-in screen. After
//     the fix, sign-out lands the user on AppShell as a guest, and
//     the Sign In tile (also added in this sprint) is the single-tap
//     path back to a signed-in state. Guest-pantry SharedPreferences
//     keys are deliberately preserved — they're either redundant
//     (already migrated to Firestore on sign-in) or owned by the
//     device (guest additions made later).
//
//   - `performRestartOnboarding` — the opt-in "I want to walk the
//     onboarding flow again" action that lives under About → Restart
//     Onboarding. Signs Firebase out, clears the guest-pantry keys
//     (so we don't pre-fill staples from a stale session), and wipes
//     `onboardingComplete` so AuthGate routes to OnboardingFlow on
//     the next pump.

import 'package:shared_preferences/shared_preferences.dart';

/// Sprint 16.1.x — Auth UX fix.
///
/// Signs Firebase out (via the injected callback) but leaves the
/// `onboardingComplete` SharedPreferences flag and the guest-pantry
/// keys untouched. The user lands on AppShell as a guest, where the
/// Sign In tile on AccountScreen offers a single-tap path back.
///
/// [firebaseSignOut] is injected so this function stays unit-testable
/// without booting Firebase in the test rig. Production callers pass
/// `AuthService().signOut`.
Future<void> performSignOut({
  required Future<void> Function() firebaseSignOut,
}) async {
  await firebaseSignOut();
  // Intentionally NO `prefs.setBool('onboardingComplete', false)` here.
  // See file header.
}

/// Sprint 16.1.x — Auth UX fix.
///
/// Deliberately resets the device back to a fresh-install state from
/// the user's perspective:
///   - Signs Firebase out so AuthGate's Firestore fallback can't
///     re-flip `onboardingComplete` on the next pump.
///   - Clears guest-pantry SharedPreferences keys so the onboarding
///     pantry builder doesn't pre-fill from a stale session.
///   - Wipes `onboardingComplete` so AuthGate routes to OnboardingFlow.
///
/// Both side-effect callbacks are injected so this function stays
/// unit-testable. Production callers pass `AuthService().signOut`
/// and `GuestPantryService().clear`.
Future<void> performRestartOnboarding({
  required Future<void> Function() firebaseSignOut,
  required Future<void> Function() clearGuestPantry,
}) async {
  await firebaseSignOut();
  await clearGuestPantry();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboardingComplete', false);
}
