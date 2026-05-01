import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/models/pantry_memory_entry.dart';

void main() {
  group('PantryMemoryEntry', () {
    test('fromTierMemoryDoc builds a non-custom entry with the right fields', () {
      final lastSeen = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
      final entry = PantryMemoryEntry.fromTierMemoryDoc(
        'carrot',
        {'tier': 'perishable', 'lastSeen': lastSeen},
        displayNameFallback: 'Carrot',
      );
      expect(entry.normalizedName, 'carrot');
      expect(entry.displayName, 'Carrot');
      expect(entry.tier, 'perishable');
      expect(entry.category, isNull);
      expect(entry.isCustom, isFalse);
      expect(entry.lastSeen.millisecondsSinceEpoch, 1700000000000);
    });

    test('fromCustomItemDoc builds a custom entry with a category', () {
      final lastSeen = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
      final entry = PantryMemoryEntry.fromCustomItemDoc(
        'miso paste',
        {
          'displayName': 'Miso paste',
          'category': 'Asian Pantry',
          'tier': 'alwaysHave',
          'lastSeen': lastSeen,
        },
      );
      expect(entry.normalizedName, 'miso paste');
      expect(entry.displayName, 'Miso paste');
      expect(entry.tier, 'alwaysHave');
      expect(entry.category, 'Asian Pantry');
      expect(entry.isCustom, isTrue);
    });

    test('falls back to safe defaults when fields are missing', () {
      final entry = PantryMemoryEntry.fromTierMemoryDoc(
        'unknown',
        const <String, dynamic>{},
        displayNameFallback: 'Unknown',
      );
      expect(entry.tier, 'alwaysHave');
      expect(entry.lastSeen, isA<DateTime>());
    });
  });
}
