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
          },
          'salt': {
            'displayName': 'Salt',
            'category': 'Spices & Seasonings',
            'tier': 'alwaysHave',
          },
          'gochujang': {
            'displayName': 'Gochujang',
            'category': 'Asian Pantry',
            'tier': 'alwaysHave',
          },
        };
      final service = PantryMemoryService.test(storage: storage);

      final byCategory = await service.customsByCategory();
      expect(byCategory.keys, {'Asian Pantry'});
      expect(byCategory['Asian Pantry']!.map((e) => e.displayName).toList(),
          ['Miso paste', 'Gochujang']);
    });
  });
}
