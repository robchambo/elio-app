import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/models/elio_models.dart';
import 'package:elio_app/models/onboarding_state.dart';
import 'package:elio_app/services/migration_service.dart';

import '../fakes/fake_firestore_writer.dart';
import '../fakes/fake_guest_pantry_service.dart';

void main() {
  group('buildUserDocPayload', () {
    test('includes spec fields except dietary/allergies (Sprint 16.1)', () {
      final s = OnboardingState()
        ..userGoal = 'pantryFirst'
        ..householdType = 'couple'
        ..dietary = ['vegetarian']
        ..allergies = ['peanuts'];
      final payload = MigrationService.buildUserDocPayload(s);
      expect(payload['userGoal'], 'pantryFirst');
      expect(payload['householdType'], 'couple');
      expect(payload['onboardingComplete'], true);
      // Sprint 16.1: dietary + allergies are stripped from the user
      // doc payload. Canonical home is users/{uid}/profiles/{ownerId}.
      expect(payload.containsKey('dietary'), isFalse);
      expect(payload.containsKey('allergies'), isFalse);
    });
  });

  group('migrateGuestToFirestore', () {
    test('writes user doc, inventory batch, aliases RC, clears guest pantry',
        () async {
      final writer = FakeFirestoreWriter();
      final guestPantry = FakeGuestPantryService();
      final aliasCalls = <String>[];

      final service = MigrationService(
        writer: writer,
        guestPantry: guestPantry,
        purchaseAlias: (uid) async => aliasCalls.add(uid),
      );

      final state = OnboardingState()
        ..userGoal = 'pantryFirst'
        ..dietary = ['vegetarian']
        ..inventory = [
          const InventoryItem(name: 'Rice', tier: 'alwaysHave'),
          const InventoryItem(
            name: 'Milk',
            tier: 'perishable',
            isRunningLow: true,
          ),
        ];

      await service.migrateGuestToFirestore('uid-xyz', state);

      expect(writer.setUserDocCalls, 1);
      expect(writer.userDocUid, 'uid-xyz');
      expect(writer.userDocData?['userGoal'], 'pantryFirst');
      // Sprint 16.1: dietary now lives on the owner profile, not the
      // user doc. Verify both — user doc clean, owner profile populated.
      expect(writer.userDocData?.containsKey('dietary'), isFalse);
      expect(writer.setOwnerProfileCalls, 1);
      expect(writer.ownerProfileUid, 'uid-xyz');
      expect(writer.ownerProfileData?['dietaryRequirements'], ['vegetarian']);

      expect(writer.writeInventoryCalls, 1);
      expect(writer.inventoryUid, 'uid-xyz');
      expect(writer.inventoryItems.length, 2);
      expect(writer.inventoryItems[0]['name'], 'Rice');
      expect(writer.inventoryItems[0]['tier'], 'alwaysHave');
      expect(writer.inventoryItems[1]['name'], 'Milk');
      expect(writer.inventoryItems[1]['runningLow'], true);

      expect(aliasCalls, ['uid-xyz']);
      expect(guestPantry.clearCalls, 1);
    });

    test('empty inventory still writes user doc, skips inventory batch',
        () async {
      final writer = FakeFirestoreWriter();
      final guestPantry = FakeGuestPantryService();
      var aliasCalled = false;

      final service = MigrationService(
        writer: writer,
        guestPantry: guestPantry,
        purchaseAlias: (uid) async => aliasCalled = true,
      );

      final state = OnboardingState()..userGoal = 'wasteReduction';

      await service.migrateGuestToFirestore('uid-empty', state);

      expect(writer.setUserDocCalls, 1);
      // writeInventory is invoked but with 0 items — the real impl
      // short-circuits on empty, and the fake still records the call.
      expect(writer.inventoryItems, isEmpty);
      expect(aliasCalled, isTrue);
      expect(guestPantry.clearCalls, 1);
    });

    test('empty-state guard: dietary/allergies omitted when state is empty', () async {
      // Sprint 16.1 critical safety: re-onboarding with an empty state
      // must NOT clobber an existing owner profile's dietary/allergies.
      // The fix is in migrateGuestToFirestore — only emit a key in the
      // owner profile patch when the corresponding state field is
      // non-empty.
      final writer = FakeFirestoreWriter();
      final guestPantry = FakeGuestPantryService();

      final service = MigrationService(
        writer: writer,
        guestPantry: guestPantry,
        purchaseAlias: (uid) async {},
      );

      final state = OnboardingState()
        ..userGoal = 'pantryFirst'; // dietary + allergies remain []

      await service.migrateGuestToFirestore('uid-empty', state);

      expect(writer.setOwnerProfileCalls, 1);
      // Owner profile patch must NOT contain dietaryRequirements or
      // allergies keys — set(merge: true) would otherwise overwrite
      // any previously-saved values with empty arrays.
      expect(
        writer.ownerProfileData?.containsKey('dietaryRequirements'),
        isFalse,
        reason: 'empty state must not clobber existing dietary',
      );
      expect(
        writer.ownerProfileData?.containsKey('allergies'),
        isFalse,
        reason: 'empty state must not clobber existing allergies',
      );
      // isOwner + name still flow through — they're metadata, not
      // user-set preferences.
      expect(writer.ownerProfileData?['isOwner'], true);
    });

    test('non-empty allergies write through to owner profile', () async {
      final writer = FakeFirestoreWriter();
      final guestPantry = FakeGuestPantryService();

      final service = MigrationService(
        writer: writer,
        guestPantry: guestPantry,
        purchaseAlias: (uid) async {},
      );

      final state = OnboardingState()
        ..userGoal = 'pantryFirst'
        ..dietary = ['vegan']
        ..allergies = ['peanuts', 'shellfish'];

      await service.migrateGuestToFirestore('uid-allergic', state);

      expect(writer.ownerProfileData?['dietaryRequirements'], ['vegan']);
      expect(writer.ownerProfileData?['allergies'], ['peanuts', 'shellfish']);
    });

    test('dedupes inventory by matchKey before batch write (Sprint 17)',
        () async {
      // Repro for the post-onboarding dup bug: user picks the same
      // item across screens 11 + 12 (custom-add "Tomato" as a staple
      // + tap the Tomato tile as a perishable), OnboardingState
      // carries both. Without dedup, MigrationService writes both
      // and the user lands on the pantry with a visible duplicate.
      final writer = FakeFirestoreWriter();
      final guestPantry = FakeGuestPantryService();

      final service = MigrationService(
        writer: writer,
        guestPantry: guestPantry,
        purchaseAlias: (uid) async {},
      );

      final state = OnboardingState()
        ..userGoal = 'pantryFirst'
        ..inventory = [
          // Staple pick on screen 11 (e.g. custom-added under "Mediterranean").
          const InventoryItem(
            name: 'Tomato',
            tier: 'alwaysHave',
            category: 'Mediterranean',
          ),
          // Perishable pick on screen 12 (Produce tile). Same logical item.
          const InventoryItem(
            name: 'Tomato',
            tier: 'perishable',
            category: 'Produce',
          ),
          // Plural-of-singular variant — still the same matchKey.
          const InventoryItem(name: 'Tomatoes', tier: 'almostAlwaysHave'),
          // Genuinely distinct item — should NOT be deduped.
          const InventoryItem(name: 'Rice', tier: 'alwaysHave'),
        ];

      await service.migrateGuestToFirestore('uid-dup', state);

      // 4 input items → 2 output rows (one Tomato + one Rice).
      expect(writer.inventoryItems.length, 2);

      final tomato = writer.inventoryItems
          .firstWhere((i) => (i['matchKey'] as String) == 'tomato');
      // Perishable wins on conflict — it carries the expiry/urgency
      // signal and tends to be the later, more deliberate pick.
      expect(tomato['tier'], 'perishable');
      expect(tomato['category'], 'Produce');

      final rice = writer.inventoryItems
          .firstWhere((i) => (i['matchKey'] as String) == 'rice');
      expect(rice['tier'], 'alwaysHave');
    });

    test('inventory rows include matchKey + nameLower for dedup (Sprint 17)',
        () async {
      // Without these keys, InventoryWriter.findExistingByKey can't
      // match the onboarding-imported rows on subsequent PantryBuilder
      // adds, so it INSERTs duplicates instead of UPDATEing.
      final writer = FakeFirestoreWriter();
      final guestPantry = FakeGuestPantryService();

      final service = MigrationService(
        writer: writer,
        guestPantry: guestPantry,
        purchaseAlias: (uid) async {},
      );

      final state = OnboardingState()
        ..userGoal = 'pantryFirst'
        ..inventory = [
          const InventoryItem(name: 'Carrots', tier: 'perishable'),
        ];

      await service.migrateGuestToFirestore('uid-keys', state);

      expect(writer.inventoryItems.length, 1);
      final carrots = writer.inventoryItems.first;
      expect(carrots['nameLower'], 'carrots');
      // matchKey singularises — "Carrots" → "carrot".
      expect(carrots['matchKey'], 'carrot');
      // Lifecycle timestamps populated (matches InventoryWriter inserts).
      expect(carrots.containsKey('firstAddedAt'), isTrue);
      expect(carrots.containsKey('lastPurchasedAt'), isTrue);
    });

    test('RC alias failure does not prevent guest pantry clear', () async {
      final writer = FakeFirestoreWriter();
      final guestPantry = FakeGuestPantryService();

      final service = MigrationService(
        writer: writer,
        guestPantry: guestPantry,
        purchaseAlias: (uid) async => throw StateError('rc down'),
      );

      final state = OnboardingState()..userGoal = 'pantryFirst';

      await service.migrateGuestToFirestore('uid-rcfail', state);

      expect(writer.setUserDocCalls, 1);
      expect(guestPantry.clearCalls, 1);
    });
  });
}
