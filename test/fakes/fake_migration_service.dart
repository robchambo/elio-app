import 'package:elio_app/models/onboarding_state.dart';
import 'package:elio_app/services/migration_service.dart';

// ─────────────────────────────────────────────
// FakeMigrationService — captures (uid, state) on each call. Does not
// touch Firestore / RevenueCat / GuestPantry.
// ─────────────────────────────────────────────

class FakeMigrationService extends MigrationService {
  int calls = 0;
  String? capturedUid;
  OnboardingState? capturedState;
  bool throwOnMigrate = false;

  FakeMigrationService() : super();

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
