import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/utils/aisle_utils.dart';

void main() {
  group('AisleUtils.orderedFor', () {
    test('returns the default enum order when preference is null', () {
      expect(AisleUtils.orderedFor(null), GroceryAisle.values);
    });

    test('returns the default enum order when preference is empty', () {
      expect(AisleUtils.orderedFor(const []), GroceryAisle.values);
    });

    test('respects the user preference when complete', () {
      final pref = const [
        'frozen',
        'dairy',
        'produce',
        'meatAndFish',
        'bakery',
        'tinsAndDry',
        'condiments',
        'spices',
        'drinks',
        'other',
      ];
      final result = AisleUtils.orderedFor(pref);
      expect(result.first, GroceryAisle.frozen);
      expect(result[1], GroceryAisle.dairy);
      expect(result[2], GroceryAisle.produce);
      expect(result.length, GroceryAisle.values.length);
    });

    test('appends missing aisles in their default order at the end', () {
      // Only specifies 2 aisles; the remaining 8 should append in
      // declaration order.
      final result = AisleUtils.orderedFor(const ['frozen', 'dairy']);
      expect(result.first, GroceryAisle.frozen);
      expect(result[1], GroceryAisle.dairy);
      // The next aisle is the first in default order that isn't
      // already in the preference (produce — index 0 in enum).
      expect(result[2], GroceryAisle.produce);
      // Total length is preserved — every aisle appears exactly once.
      expect(result.length, GroceryAisle.values.length);
      expect(result.toSet(), GroceryAisle.values.toSet());
    });

    test('drops unknown aisle names without affecting valid ones', () {
      final result =
          AisleUtils.orderedFor(const ['nonsense', 'dairy', 'also_unknown']);
      // Dairy should still be first (the only recognised name); the
      // rest fall back to default order.
      expect(result.first, GroceryAisle.dairy);
      expect(result.length, GroceryAisle.values.length);
    });

    test('deduplicates repeats in the user preference', () {
      final result =
          AisleUtils.orderedFor(const ['dairy', 'dairy', 'produce', 'dairy']);
      expect(result[0], GroceryAisle.dairy);
      expect(result[1], GroceryAisle.produce);
      expect(result.length, GroceryAisle.values.length);
      expect(
        result.where((a) => a == GroceryAisle.dairy).length,
        1,
        reason: 'each aisle must appear exactly once',
      );
    });
  });
}
