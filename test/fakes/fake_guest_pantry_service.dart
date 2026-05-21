import 'package:elio_app/services/guest_pantry_service.dart';

// ─────────────────────────────────────────────
// FakeGuestPantryService — tracks `clear()` calls without touching
// SharedPreferences. Used by migration_service_test and
// FakeMigrationService.
// ─────────────────────────────────────────────

class FakeGuestPantryService extends GuestPantryService {
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
  }
}
