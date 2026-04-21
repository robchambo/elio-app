import 'package:elio_app/models/onboarding_state.dart';
import 'package:elio_app/services/migration_service.dart';

import 'fake_firestore_writer.dart';
import 'fake_guest_pantry_service.dart';

// ─────────────────────────────────────────────
// FakeMigrationService — captures (uid, state) on each call. Does not
// touch Firestore / RevenueCat / GuestPantry.
//
// Overrides `migrateGuestToFirestore` entirely, so the super-class's
// writer/purchases/guestPantry are never used. A no-op writer is
// passed up for safety in case future tests call `super.migrate...`.
// ─────────────────────────────────────────────

class FakeMigrationService extends MigrationService {
  int calls = 0;
  String? capturedUid;
  OnboardingState? capturedState;
  bool throwOnMigrate = false;

  FakeMigrationService()
      : super(
          writer: FakeFirestoreWriter(),
          guestPantry: FakeGuestPantryService(),
        );

  @override
  Future<void> migrateGuestToFirestore(String uid, OnboardingState s) async {
    calls++;
    capturedUid = uid;
    capturedState = s;
    if (throwOnMigrate) {
      throw StateError('FakeMigrationService configured to throw');
    }
  }
}
