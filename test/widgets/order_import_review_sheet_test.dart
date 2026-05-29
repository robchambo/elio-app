// test/widgets/order_import_review_sheet_test.dart
//
// Sprint 17 — Online Order → Pantry Import (Task 8).
//
// Widget tests for the review sheet:
//   1. Food items default-checked, household collapsed under expander.
//   2. Toggling a food row off decrements the CTA's count.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/models/pending_import.dart';
import 'package:elio_app/widgets/order_import_review_sheet.dart';

PendingImport _import({String orderType = 'confirmation'}) => PendingImport(
      id: 'imp-1',
      retailer: 'kroger',
      status: 'pending_review',
      receivedAt: DateTime(2026, 5, 25),
      orderType: orderType,
      parseConfidence: 0.95,
      emailSubject: 'Your Kroger order — receipt',
      items: [
        PendingImportItem(
          rawName: 'Whole Milk 1g',
          normalizedName: 'whole milk',
          quantity: 1,
          unit: 'gal',
          category: 'dairy',
          classification: 'food',
        ),
        PendingImportItem(
          rawName: 'Bounty paper towels',
          normalizedName: 'paper towels',
          quantity: 1,
          unit: 'pack',
          category: 'household',
          classification: 'household',
        ),
        PendingImportItem(
          rawName: 'Bananas',
          normalizedName: 'banana',
          quantity: 6,
          unit: null,
          category: 'produce',
          classification: 'food',
        ),
      ],
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  testWidgets(
    'shows 2 food items checked by default, household collapsed',
    (t) async {
      await t.pumpWidget(_host(OrderImportReviewSheet(
        pendingImport: _import(),
        onApply: (_) async {},
        onDiscard: () {},
      )));
      await t.pumpAndSettle();

      // CTA reflects 2 food rows selected.
      expect(find.textContaining('Add 2 items to pantry'), findsOneWidget);

      // Household expander present and household row hidden.
      expect(find.text('Show 1 household item'), findsOneWidget);
      expect(find.text('paper towels'), findsNothing);

      // Food rows present (text inside TextField).
      expect(find.text('whole milk'), findsOneWidget);
      expect(find.text('banana'), findsOneWidget);
    },
  );

  testWidgets(
    'toggling a row off decrements the CTA count',
    (t) async {
      await t.pumpWidget(_host(OrderImportReviewSheet(
        pendingImport: _import(),
        onApply: (_) async {},
        onDiscard: () {},
      )));
      await t.pumpAndSettle();

      // Starts at 2 selected food rows.
      expect(find.textContaining('Add 2 items to pantry'), findsOneWidget);

      // Tap the first checkbox (the first food row's checkbox).
      final firstCheckbox = find.byType(Checkbox).first;
      await t.tap(firstCheckbox);
      await t.pumpAndSettle();

      expect(find.textContaining('Add 1 item to pantry'), findsOneWidget);
      expect(find.textContaining('Add 2 items to pantry'), findsNothing);
    },
  );

  // Sprint 17 (29 May 2026) — Rob: soy sauce (category `pantry`) imported
  // but never showed in the pantry. ApplyItem.tier returned `pantry`
  // (and `frozen`), neither of which is a real InventoryItem tier
  // (alwaysHave / almostAlwaysHave / perishable), so the item was written
  // to Firestore but matched no displayed tier. Every category must map
  // to a valid tier.
  group('ApplyItem.tier maps every category to a valid pantry tier', () {
    const validTiers = {'alwaysHave', 'almostAlwaysHave', 'perishable'};

    test('perishable categories → perishable', () {
      for (final c in ['produce', 'dairy', 'meat', 'bakery']) {
        expect(ApplyItem(name: 'x', category: c).tier, 'perishable',
            reason: '$c should be perishable');
      }
    });

    test('non-perishable categories → almostAlwaysHave (a real tier)', () {
      // pantry was the soy-sauce case; frozen was the other invalid one.
      for (final c in ['pantry', 'frozen', 'beverage', 'household', 'other']) {
        final tier = ApplyItem(name: 'x', category: c).tier;
        expect(validTiers.contains(tier), isTrue,
            reason: '$c must map to a valid tier, got "$tier"');
        expect(tier, 'almostAlwaysHave', reason: '$c should be almostAlwaysHave');
      }
    });
  });
}
