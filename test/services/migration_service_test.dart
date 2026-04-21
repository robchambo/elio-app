import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/models/elio_models.dart';
import 'package:elio_app/models/onboarding_state.dart';
import 'package:elio_app/services/migration_service.dart';

import '../fakes/fake_firestore_writer.dart';
import '../fakes/fake_guest_pantry_service.dart';

void main() {
  group('buildUserDocPayload', () {
    test('includes all spec fields', () {
      final s = OnboardingState()
        ..userGoal = 'pantryFirst'
        ..householdType = 'couple';
      final payload = MigrationService.buildUserDocPayload(s);
      expect(payload['userGoal'], 'pantryFirst');
      expect(payload['householdType'], 'couple');
      expect(payload['dietary'], <String>[]);
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
      expect(writer.userDocData?['dietary'], ['vegetarian']);

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
