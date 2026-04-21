import 'package:elio_app/services/migration_service.dart';

// ─────────────────────────────────────────────
// FakeFirestoreWriter — captures calls to `setUserDoc` and
// `writeInventory` without touching Firestore. Used by
// migration_service_test and FakeMigrationService.
// ─────────────────────────────────────────────

class FakeFirestoreWriter implements MigrationFirestoreWriter {
  String? userDocUid;
  Map<String, dynamic>? userDocData;
  int setUserDocCalls = 0;

  String? inventoryUid;
  List<Map<String, dynamic>> inventoryItems = const [];
  int writeInventoryCalls = 0;

  @override
  Future<void> setUserDoc(String uid, Map<String, dynamic> data) async {
    setUserDocCalls++;
    userDocUid = uid;
    userDocData = data;
  }

  @override
  Future<void> writeInventory(
    String uid,
    List<Map<String, dynamic>> items,
  ) async {
    writeInventoryCalls++;
    inventoryUid = uid;
    inventoryItems = items;
  }
}
