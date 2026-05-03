import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/services/inventory_writer.dart';

import '../fakes/fake_inventory_write_storage.dart';

void main() {
  group('InventoryWriter.addItem (no migration)', () {
    setUp(() {
      // Pre-set the migration flag so addItem doesn't try to migrate.
    });

    test('inserts a new doc when nothing matches', () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {'inventoryDedupBackfilled': true};
      final writer = InventoryWriter.test(storage: storage);

      final id = await writer.addItem(name: 'Carrots', tier: 'perishable');

      expect(storage.insertCalls.length, 1);
      expect(storage.updateCalls, isEmpty);
      final inserted = storage.insertCalls.first;
      expect(inserted['name'], 'Carrots');
      expect(inserted['tier'], 'perishable');
      expect(inserted['nameLower'], 'carrots');
      expect(inserted['matchKey'], 'carrot');
      expect(inserted['runningLow'], false);
      expect(inserted.containsKey('firstAddedAt'), isTrue);
      expect(inserted.containsKey('lastPurchasedAt'), isTrue);
      expect(id, startsWith('fake_'));
    });

    test('updates the existing doc when matchKey matches', () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {'inventoryDedupBackfilled': true}
        ..docs = {
          'existing_id': {
            'name': 'Carrots',
            'nameLower': 'carrots',
            'matchKey': 'carrot',
            'tier': 'perishable',
            'runningLow': true,
          },
        };
      final writer = InventoryWriter.test(storage: storage);

      final id = await writer.addItem(name: 'Carrots', tier: 'perishable');

      expect(storage.insertCalls, isEmpty);
      expect(storage.updateCalls.length, 1);
      expect(id, 'existing_id');
      final updates = storage.updateCalls.first.updates;
      expect(updates['runningLow'], false); // cleared
      expect(updates.containsKey('lastPurchasedAt'), isTrue);
      // firstAddedAt should NOT be in updates — it's only set on insert.
      expect(updates.containsKey('firstAddedAt'), isFalse);
    });

    test('merges singular and plural via matchKey', () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {'inventoryDedupBackfilled': true}
        ..docs = {
          'existing_id': {
            'name': 'Carrots',
            'nameLower': 'carrots',
            'matchKey': 'carrot',
            'tier': 'perishable',
          },
        };
      final writer = InventoryWriter.test(storage: storage);

      // Re-add as singular.
      final id = await writer.addItem(name: 'Carrot', tier: 'perishable');

      expect(id, 'existing_id');
      expect(storage.insertCalls, isEmpty);
      expect(storage.updateCalls.length, 1);
      // Existing display name preserved.
      expect(storage.docs['existing_id']!['name'], 'Carrots');
    });

    test('tier sticks on re-add — existing alwaysHave wins over new perishable',
        () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {'inventoryDedupBackfilled': true}
        ..docs = {
          'existing_id': {
            'name': 'Salt',
            'nameLower': 'salt',
            'matchKey': 'salt',
            'tier': 'alwaysHave',
          },
        };
      final writer = InventoryWriter.test(storage: storage);

      await writer.addItem(
        name: 'Salt',
        tier: 'perishable',
        expiryDate: DateTime(2026, 5, 8),
      );

      final updates = storage.updateCalls.first.updates;
      expect(updates.containsKey('tier'), isFalse);
      expect(updates.containsKey('expiryDate'), isFalse); // existing not perishable
    });

    test('expiry refreshes for existing perishable', () async {
      final oldExpiry = Timestamp.fromDate(DateTime(2026, 4, 24));
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {'inventoryDedupBackfilled': true}
        ..docs = {
          'existing_id': {
            'name': 'Carrots',
            'nameLower': 'carrots',
            'matchKey': 'carrot',
            'tier': 'perishable',
            'expiryDate': oldExpiry,
            'runningLow': true,
          },
        };
      final writer = InventoryWriter.test(storage: storage);

      final newExpiry = DateTime(2026, 5, 8);
      await writer.addItem(
        name: 'Carrots',
        tier: 'perishable',
        expiryDate: newExpiry,
      );

      final updates = storage.updateCalls.first.updates;
      expect(updates['expiryDate'], isA<Timestamp>());
      final newTs = updates['expiryDate'] as Timestamp;
      expect(newTs.toDate(), newExpiry);
      expect(updates['runningLow'], false);
    });

    test('price refreshes when supplied; sticks when not', () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {'inventoryDedupBackfilled': true}
        ..docs = {
          'existing_id': {
            'name': 'Carrots',
            'nameLower': 'carrots',
            'matchKey': 'carrot',
            'tier': 'perishable',
            'price': '£1.20',
          },
        };
      final writer = InventoryWriter.test(storage: storage);

      // With new price → replaces.
      await writer.addItem(name: 'Carrots', tier: 'perishable', price: '£1.50');
      expect(storage.updateCalls.last.updates['price'], '£1.50');

      // Without new price → not in update map (sticky).
      storage.updateCalls.clear();
      await writer.addItem(name: 'Carrots', tier: 'perishable');
      expect(storage.updateCalls.last.updates.containsKey('price'), isFalse);
    });

    test('legacy fallback — finds row by nameLower when matchKey missing',
        () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {'inventoryDedupBackfilled': true}
        ..docs = {
          'legacy_id': {
            'name': 'Carrots',
            'nameLower': 'carrots',
            // matchKey missing — pre-15.9.1 doc
            'tier': 'perishable',
          },
        };
      final writer = InventoryWriter.test(storage: storage);

      final id = await writer.addItem(name: 'Carrots', tier: 'perishable');

      expect(id, 'legacy_id');
      expect(storage.insertCalls, isEmpty);
      // The update should backfill matchKey defensively.
      expect(storage.updateCalls.first.updates['matchKey'], 'carrot');
    });
  });
}
