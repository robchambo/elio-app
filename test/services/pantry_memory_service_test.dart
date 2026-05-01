import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/services/pantry_memory_service.dart';

import '../fakes/fake_pantry_memory_storage.dart';

void main() {
  group('PantryMemoryService.recentUsuals', () {
    test('returns top N tierMemory rows ordered by lastSeen desc, staples filtered', () async {
      final storage = FakePantryMemoryStorage()
        ..tierMemoryRows = {
          'carrot': {'tier': 'perishable', 'lastSeen': DateTime.fromMillisecondsSinceEpoch(3000)},
          'rice': {'tier': 'alwaysHave', 'lastSeen': DateTime.fromMillisecondsSinceEpoch(5000)},
          'salt': {'tier': 'alwaysHave', 'lastSeen': DateTime.fromMillisecondsSinceEpoch(9999)}, // staple — drop
          'onion': {'tier': 'perishable', 'lastSeen': DateTime.fromMillisecondsSinceEpoch(4000)},
        };
      final service = PantryMemoryService.test(storage: storage);

      final usuals = await service.recentUsuals(limit: 10);

      expect(usuals.map((e) => e.normalizedName).toList(),
          ['rice', 'onion', 'carrot']); // newest-first, salt excluded
    });

    test('respects the limit parameter', () async {
      final storage = FakePantryMemoryStorage()
        ..tierMemoryRows = {
          for (var i = 0; i < 30; i++)
            'item$i': {'tier': 'alwaysHave', 'lastSeen': DateTime.fromMillisecondsSinceEpoch(i)},
        };
      final service = PantryMemoryService.test(storage: storage);

      expect((await service.recentUsuals(limit: 5)).length, 5);
    });

    test('returns empty list when storage throws', () async {
      final storage = FakePantryMemoryStorage()..throwOnRead = true;
      final service = PantryMemoryService.test(storage: storage);

      expect(await service.recentUsuals(), isEmpty);
    });
  });

  group('PantryMemoryService.hadBeforeKeys', () {
    test('returns the set of normalised names, staples filtered', () async {
      final storage = FakePantryMemoryStorage()
        ..tierMemoryRows = {
          'carrot': {'tier': 'perishable'},
          'salt': {'tier': 'alwaysHave'},
          'rice': {'tier': 'alwaysHave'},
        };
      final service = PantryMemoryService.test(storage: storage);

      final keys = await service.hadBeforeKeys();
      expect(keys, {'carrot', 'rice'});
    });
  });

  group('PantryMemoryService.customsByCategory', () {
    test('groups custom items by category, staples filtered', () async {
      final storage = FakePantryMemoryStorage()
        ..customItemRows = {
          'miso paste': {
            'displayName': 'Miso paste',
            'category': 'Asian Pantry',
            'tier': 'alwaysHave',
            'lastSeen': DateTime.fromMillisecondsSinceEpoch(2000),
          },
          'salt': {
            'displayName': 'Salt',
            'category': 'Spices & Seasonings',
            'tier': 'alwaysHave',
            'lastSeen': DateTime.fromMillisecondsSinceEpoch(9999),
          },
          'gochujang': {
            'displayName': 'Gochujang',
            'category': 'Asian Pantry',
            'tier': 'alwaysHave',
            'lastSeen': DateTime.fromMillisecondsSinceEpoch(5000),
          },
        };
      final service = PantryMemoryService.test(storage: storage);

      final byCategory = await service.customsByCategory();
      expect(byCategory.keys, {'Asian Pantry'});
      expect(byCategory['Asian Pantry']!.map((e) => e.displayName).toList(),
          ['Gochujang', 'Miso paste']); // newest first
    });
  });

  group('PantryMemoryService.upsertCustom', () {
    test('writes a custom-item doc with normalised key + supplied fields', () async {
      final storage = FakePantryMemoryStorage();
      final service = PantryMemoryService.test(storage: storage);

      await service.upsertCustom(
        displayName: 'Miso Paste',
        category: 'Asian Pantry',
        tier: 'alwaysHave',
      );

      expect(storage.upsertedCustoms.length, 1);
      final row = storage.upsertedCustoms.first;
      expect(row['id'], 'miso paste');
      expect(row['displayName'], 'Miso Paste');
      expect(row['category'], 'Asian Pantry');
      expect(row['tier'], 'alwaysHave');
      expect(row.containsKey('firstSeen'), isTrue);
      expect(row.containsKey('lastSeen'), isTrue);
    });

    test('refuses to write a staple', () async {
      final storage = FakePantryMemoryStorage();
      final service = PantryMemoryService.test(storage: storage);

      await service.upsertCustom(
        displayName: 'Salt',
        category: 'Spices & Seasonings',
        tier: 'alwaysHave',
      );

      expect(storage.upsertedCustoms, isEmpty);
    });

    test('swallows write errors silently', () async {
      final storage = FakePantryMemoryStorage()..throwOnWrite = true;
      final service = PantryMemoryService.test(storage: storage);

      await service.upsertCustom(
        displayName: 'Miso paste',
        category: 'Asian Pantry',
        tier: 'alwaysHave',
      );
      // No throw → pass.
    });
  });

  group('PantryMemoryService.backfillFromInventoryIfNeeded', () {
    test('writes one tierMemory row per inventory item, sets the flag', () async {
      final storage = FakePantryMemoryStorage()
        ..userDoc = const {} // no flag
        ..inventoryRows = const {
          'a': {'name': 'Carrot', 'tier': 'perishable'},
          'b': {'name': 'Rice', 'tier': 'alwaysHave'},
          'c': {'name': 'Salt', 'tier': 'alwaysHave'}, // staple — skip
        };
      final service = PantryMemoryService.test(storage: storage);

      await service.backfillFromInventoryIfNeeded();

      expect(storage.backfilledTierMemoryRows.length, 2);
      expect(
        storage.backfilledTierMemoryRows.map((r) => r['id']).toSet(),
        {'carrot', 'rice'},
      );
      expect(storage.backfillFlagSet, isTrue);
    });

    test('no-ops when the flag is already set', () async {
      final storage = FakePantryMemoryStorage()
        ..userDoc = const {'pantryMemoryBackfilled': true}
        ..inventoryRows = const {
          'a': {'name': 'Carrot', 'tier': 'perishable'},
        };
      final service = PantryMemoryService.test(storage: storage);

      await service.backfillFromInventoryIfNeeded();

      expect(storage.backfilledTierMemoryRows, isEmpty);
    });

    test('swallows read errors silently (does not block the builder)', () async {
      final storage = FakePantryMemoryStorage()..throwOnRead = true;
      final service = PantryMemoryService.test(storage: storage);

      await service.backfillFromInventoryIfNeeded();
      // No throw → pass.
    });
  });
}
