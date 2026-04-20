import '../models/onboarding_state.dart';

// ─────────────────────────────────────────────
// MigrationService
//
// Sprint 16 onboarding rebuild: migrates the in-memory OnboardingState
// (built up in guest mode across screens 01–14) into Firestore after
// the user signs in on screen 15. Full implementation lands in Task
// 6.4; this Phase 0A stub exposes only the payload builder so downstream
// tasks can depend on the API shape.
// ─────────────────────────────────────────────

class MigrationService {
  static Map<String, dynamic> buildUserDocPayload(OnboardingState s) =>
      s.toFirestoreMap();

  // Full implementation (Firestore writes + RevenueCat alias + guest
  // pantry clear) lands in Task 6.4.
  static Future<void> migrateGuestToFirestore(
    String uid,
    OnboardingState s,
  ) async {
    throw UnimplementedError('Implemented in Task 6.4');
  }
}
