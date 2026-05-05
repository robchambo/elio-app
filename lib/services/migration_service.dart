import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/onboarding_state.dart';
import 'error_service.dart';
import 'guest_pantry_service.dart';
import 'purchase_service.dart';

// ─────────────────────────────────────────────
// MigrationService
//
// Sprint 16 onboarding rebuild: migrates the in-memory OnboardingState
// (built up in guest mode across screens 01–14) into Firestore after
// the user signs in on screen 15.
//
// Steps:
//   1. Write `users/{uid}` with OnboardingState.toFirestoreMap(), merged
//      with any existing doc (SetOptions(merge: true)).
//   2. Batch-write each inventory item to
//      `users/{uid}/inventory/{auto-id}` using InventoryItem.toFirestore.
//      Skipped entirely when the inventory is empty.
//   3. Alias the signed-in uid with RevenueCat via
//      PurchaseService.aliasToUid(uid).
//   4. Clear the guest pantry from SharedPreferences.
//
// Firestore writes are abstracted behind [MigrationFirestoreWriter] so
// tests can substitute a hand-rolled fake without pulling in
// `fake_cloud_firestore`. Production uses [_RealFirestoreWriter] wrapping
// the injected [FirebaseFirestore] (defaults to `FirebaseFirestore.instance`).
// ─────────────────────────────────────────────

/// Abstracts the Firestore writes MigrationService performs. Allows
/// tests to inject a fake without `fake_cloud_firestore`.
abstract class MigrationFirestoreWriter {
  Future<void> setUserDoc(String uid, Map<String, dynamic> data);
  Future<void> writeInventory(
    String uid,
    List<Map<String, dynamic>> items,
  );

  /// Sprint 15.9.3: writes the owner profile so onboarding-set
  /// dietary requirements + allergies are visible to the in-app
  /// dietary screen AND to the recipe-generation prompt.
  Future<void> setOwnerProfile(String uid, Map<String, dynamic> data);
}

class _RealFirestoreWriter implements MigrationFirestoreWriter {
  final FirebaseFirestore _db;
  _RealFirestoreWriter(this._db);

  @override
  Future<void> setUserDoc(String uid, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  @override
  Future<void> writeInventory(
    String uid,
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) return;
    final batch = _db.batch();
    final inventory = _db.collection('users').doc(uid).collection('inventory');
    for (final item in items) {
      batch.set(inventory.doc(), item);
    }
    await batch.commit();
  }

  @override
  Future<void> setOwnerProfile(String uid, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('profiles')
        .doc('owner')
        .set(data, SetOptions(merge: true));
  }
}

/// Typedef for the RevenueCat alias step. Lets tests inject a stub
/// without subclassing the PurchaseService singleton.
typedef PurchaseAliasFn = Future<void> Function(String uid);

Future<void> _defaultPurchaseAlias(String uid) =>
    PurchaseService.instance.aliasToUid(uid);

class MigrationService {
  final MigrationFirestoreWriter _writer;
  final PurchaseAliasFn _aliasFn;
  final GuestPantryService _guestPantry;

  MigrationService({
    FirebaseFirestore? firestore,
    MigrationFirestoreWriter? writer,
    PurchaseAliasFn? purchaseAlias,
    GuestPantryService? guestPantry,
  })  : _writer = writer ??
            _RealFirestoreWriter(firestore ?? FirebaseFirestore.instance),
        _aliasFn = purchaseAlias ?? _defaultPurchaseAlias,
        _guestPantry = guestPantry ?? GuestPantryService();

  static Map<String, dynamic> buildUserDocPayload(OnboardingState s) =>
      s.toFirestoreMap();

  /// Migrates the guest onboarding state to Firestore under [uid].
  ///
  /// Ordering is deliberate:
  ///   1. User doc first — establishes the parent before children.
  ///   2. Inventory batch — skipped on empty.
  ///   3. RevenueCat alias — non-fatal on failure (purchase_service logs).
  ///   4. Guest pantry clear — last, so a failure earlier leaves the
  ///      local cache intact for retry.
  Future<void> migrateGuestToFirestore(
    String uid,
    OnboardingState state,
  ) async {
    await _writer.setUserDoc(uid, buildUserDocPayload(state));

    // Sprint 15.9.3 SAFETY FIX: persist dietary + allergies on the owner
    // profile. The in-app dietary screen reads/writes profiles/{owner},
    // and recipe generation now reads allergies from there too. Without
    // this write, an onboarding allergy ("peanuts") would land on the
    // user doc but be invisible to both the dietary screen AND the
    // prompt — and Gemini could suggest peanut butter.
    await _writer.setOwnerProfile(uid, {
      'name': '', // populated on first edit if user fills the household screen
      'isOwner': true,
      'dietaryRequirements': state.dietary,
      'allergies': state.allergies,
    });

    final items = state.inventory.map((i) => i.toFirestore()).toList();
    await _writer.writeInventory(uid, items);

    try {
      await _aliasFn(uid);
    } catch (e) {
      ErrorService.log('migration_rc_alias', e);
    }

    await _guestPantry.clear();
  }
}
