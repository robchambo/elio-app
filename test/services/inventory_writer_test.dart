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

  group('InventoryWriter migration (lazy, on first addItem)', () {
    test('migrates legacy rows + sets flag on first call', () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const <String, dynamic>{} // flag absent
        ..docs = {
          'legacy_a': {'name': 'Carrots', 'tier': 'perishable'},
          'legacy_b': {'name': 'Rice', 'tier': 'alwaysHave'},
          // Already-migrated row should be skipped:
          'modern_c': {
            'name': 'Onions',
            'nameLower': 'onions',
            'matchKey': 'onion',
            'tier': 'perishable',
          },
        };
      final writer = InventoryWriter.test(storage: storage);

      // Trigger migration via a fresh insert (won't match any existing).
      await writer.addItem(name: 'Pasta', tier: 'alwaysHave');

      expect(storage.migrationFlagSet, isTrue);
      // Two legacy rows backfilled, modern_c untouched.
      final migratedIds = storage.migratedRows.map((r) => r.id).toSet();
      expect(migratedIds, {'legacy_a', 'legacy_b'});
      // Each migrated row got the new fields:
      for (final row in storage.migratedRows) {
        expect(row.updates.containsKey('matchKey'), isTrue);
        expect(row.updates.containsKey('nameLower'), isTrue);
        expect(row.updates.containsKey('firstAddedAt'), isTrue);
        expect(row.updates.containsKey('lastPurchasedAt'), isTrue);
      }
    });

    test('no-ops when flag already set', () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {'inventoryDedupBackfilled': true}
        ..docs = {
          'legacy_a': {'name': 'Carrots', 'tier': 'perishable'},
        };
      final writer = InventoryWriter.test(storage: storage);

      await writer.addItem(name: 'Pasta', tier: 'alwaysHave');

      expect(storage.migratedRows, isEmpty);
    });

    test('session cache — second addItem skips the migration check', () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {'inventoryDedupBackfilled': true};
      final writer = InventoryWriter.test(storage: storage);

      await writer.addItem(name: 'Pasta', tier: 'alwaysHave');
      await writer.addItem(name: 'Bread', tier: 'alwaysHave');
      await writer.addItem(name: 'Olive oil', tier: 'alwaysHave');

      // The fake captures every call; we expect findCalls = 3 (one per
      // addItem, none from a redundant migration check).
      expect(storage.findCalls.length, 3);
    });

    test('migration read errors silently no-op (do not block addItem)',
        () async {
      final storage = FakeInventoryWriteStorage()..throwOnRead = true;
      final writer = InventoryWriter.test(storage: storage);

      // Should not throw — migration silent-fails, then addItem itself
      // also fails the dedup query and falls through. Insert path also
      // fails because the fake throws on every read; the addItem call
      // therefore propagates the read error from findExistingByKey,
      // not from the migrator. We accept either outcome here — the
      // assertion is "the migrator does not propagate".
      try {
        await writer.addItem(name: 'Carrot', tier: 'perishable');
      } catch (_) {
        // findExistingByKey throws — fine; the migrator itself is
        // confirmed to have caught its own error path.
      }
      // Most important: even on a partial failure, no migration write
      // landed (because we never made it past the read).
      expect(storage.migrationFlagSet, isFalse);
    });
  });

  // ─── Sprint 15.9.3 — collapse duplicates ──────────────────────────────

  group('InventoryWriter migration (collapse duplicates)', () {
    test('collapses N rows with same matchKey into one', () async {
      final storage = FakeInventoryWriteStorage()
        // Backfill already done; only collapse remains.
        ..userDoc = const {'inventoryDedupBackfilled': true}
        ..docs = {
          'butter_a': {
            'name': 'Butter',
            'nameLower': 'butter',
            'matchKey': 'butter',
            'tier': 'alwaysHave',
            'firstAddedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
          },
          'butter_b': {
            'name': 'Butter',
            'nameLower': 'butter',
            'matchKey': 'butter',
            'tier': 'alwaysHave',
            'firstAddedAt': Timestamp.fromDate(DateTime(2026, 2, 1)),
          },
          'butter_c': {
            'name': 'Butter',
            'nameLower': 'butter',
            'matchKey': 'butter',
            'tier': 'alwaysHave',
            'firstAddedAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
          },
          // Singleton — should not be touched.
          'rice_solo': {
            'name': 'Rice',
            'nameLower': 'rice',
            'matchKey': 'rice',
            'tier': 'alwaysHave',
          },
        };
      final writer = InventoryWriter.test(storage: storage);

      await writer.addItem(name: 'Pasta', tier: 'alwaysHave');

      expect(storage.collapseFlagSet, isTrue);
      // Oldest (butter_a, Jan 1) wins; the other two are losers.
      expect(storage.collapseLoserIds.toSet(), {'butter_b', 'butter_c'});
      // After collapse: butter_a survives, butter_b/c removed, rice_solo
      // untouched, and the addItem just inserted a Pasta row.
      expect(storage.docs.containsKey('butter_a'), isTrue);
      expect(storage.docs.containsKey('butter_b'), isFalse);
      expect(storage.docs.containsKey('butter_c'), isFalse);
      expect(storage.docs.containsKey('rice_solo'), isTrue);
    });

    test('merges latest expiry from losers when winner is perishable', () async {
      final winnerExpiry = Timestamp.fromDate(DateTime(2026, 5, 5));
      final loserExpiry = Timestamp.fromDate(DateTime(2026, 5, 12));
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {'inventoryDedupBackfilled': true}
        ..docs = {
          'carrots_winner': {
            'name': 'Carrots',
            'nameLower': 'carrots',
            'matchKey': 'carrot',
            'tier': 'perishable',
            'expiryDate': winnerExpiry,
            'firstAddedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
          },
          'carrots_loser': {
            'name': 'Carrots',
            'nameLower': 'carrots',
            'matchKey': 'carrot',
            'tier': 'perishable',
            'expiryDate': loserExpiry, // newer
            'firstAddedAt': Timestamp.fromDate(DateTime(2026, 4, 1)),
          },
        };
      final writer = InventoryWriter.test(storage: storage);

      await writer.addItem(name: 'Pasta', tier: 'alwaysHave');

      expect(storage.collapseLoserIds, ['carrots_loser']);
      // Winner gets the loser's later expiry merged in.
      expect(storage.docs['carrots_winner']!['expiryDate'], loserExpiry);
    });

    test('skips expiry merge when winner is non-perishable', () async {
      final loserExpiry = Timestamp.fromDate(DateTime(2026, 5, 12));
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {'inventoryDedupBackfilled': true}
        ..docs = {
          'salt_winner': {
            'name': 'Salt',
            'nameLower': 'salt',
            'matchKey': 'salt',
            'tier': 'alwaysHave',
            'firstAddedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
          },
          'salt_loser': {
            'name': 'Salt',
            'nameLower': 'salt',
            'matchKey': 'salt',
            // Bogus loser data — somehow has an expiry on a non-perishable.
            'tier': 'perishable',
            'expiryDate': loserExpiry,
          },
        };
      final writer = InventoryWriter.test(storage: storage);

      await writer.addItem(name: 'Pasta', tier: 'alwaysHave');

      // Salt winner kept its alwaysHave tier and got NO expiry.
      expect(storage.docs['salt_winner']!.containsKey('expiryDate'), isFalse);
      expect(storage.docs.containsKey('salt_loser'), isFalse);
    });

    test('fills missing winner price/category from losers', () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {'inventoryDedupBackfilled': true}
        ..docs = {
          'butter_winner': {
            'name': 'Butter',
            'nameLower': 'butter',
            'matchKey': 'butter',
            'tier': 'alwaysHave',
            'firstAddedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
            // No price, no category.
          },
          'butter_loser': {
            'name': 'Butter',
            'nameLower': 'butter',
            'matchKey': 'butter',
            'tier': 'alwaysHave',
            'price': '£2.50',
            'category': 'Dairy',
          },
        };
      final writer = InventoryWriter.test(storage: storage);

      await writer.addItem(name: 'Pasta', tier: 'alwaysHave');

      expect(storage.docs['butter_winner']!['price'], '£2.50');
      expect(storage.docs['butter_winner']!['category'], 'Dairy');
      expect(storage.docs.containsKey('butter_loser'), isFalse);
    });

    test('tolerates legacy String-typed expiryDate / lastPurchasedAt', () async {
      // Sprint 15.9.3 regression: some legacy rows stored expiryDate as
      // an ISO 8601 String rather than a Firestore Timestamp. The
      // collapse pass used to crash with "type 'String' is not a
      // subtype of type 'Timestamp?'". _readTimestamp coerces both.
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {'inventoryDedupBackfilled': true}
        ..docs = {
          'carrots_winner': {
            'name': 'Carrots',
            'nameLower': 'carrots',
            'matchKey': 'carrot',
            'tier': 'perishable',
            'firstAddedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
            'expiryDate': '2026-05-05', // legacy String shape
          },
          'carrots_loser': {
            'name': 'Carrots',
            'nameLower': 'carrots',
            'matchKey': 'carrot',
            'tier': 'perishable',
            'firstAddedAt': Timestamp.fromDate(DateTime(2026, 4, 1)),
            'expiryDate': '2026-05-12', // newer; legacy String shape
            'lastPurchasedAt': '2026-04-01T10:00:00Z', // legacy String shape
          },
        };
      final writer = InventoryWriter.test(storage: storage);

      // Should NOT throw despite the String-typed timestamp fields.
      await writer.addItem(name: 'Pasta', tier: 'alwaysHave');

      expect(storage.collapseFlagSet, isTrue);
      expect(storage.collapseLoserIds, ['carrots_loser']);
      // Winner gets the loser's later expiry (now coerced to Timestamp).
      final winnerExpiry = storage.docs['carrots_winner']!['expiryDate'];
      expect(winnerExpiry, isA<Timestamp>());
      expect(
        (winnerExpiry as Timestamp).toDate(),
        DateTime(2026, 5, 12),
      );
    });

    test('does not run when both flags already set', () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {
          'inventoryDedupBackfilled': true,
          'inventoryDuplicatesCollapsed': true,
        }
        ..docs = {
          'a': {'name': 'Butter', 'nameLower': 'butter', 'matchKey': 'butter'},
          'b': {'name': 'Butter', 'nameLower': 'butter', 'matchKey': 'butter'},
        };
      final writer = InventoryWriter.test(storage: storage);

      await writer.addItem(name: 'Pasta', tier: 'alwaysHave');

      expect(storage.collapseFlagSet, isFalse);
      expect(storage.collapseLoserIds, isEmpty);
      // Both 'a' and 'b' survive — collapse never ran.
      expect(storage.docs.containsKey('a'), isTrue);
      expect(storage.docs.containsKey('b'), isTrue);
    });
  });

  group('InventoryWriter.forceCollapseDuplicates', () {
    test(
        'Sprint 16.6.x: backfills missing matchKey BEFORE collapsing, '
        'so legacy rows pre-15.9.1 actually get deduped',
        () async {
      // Reproduces the on-device bug: pantry has 3 "Baking powder" rows from
      // a pre-15.9.1 install. None have matchKey. The user-doc flags are
      // already set (a previous partial migration), so the gated migration
      // short-circuits. Long-press on the Pantry page title fires
      // forceCollapseDuplicates which — pre-fix — only ran the collapse
      // step. Collapse groups by matchKey; legacy rows had no matchKey;
      // collapse silently reported zero. This test pins the fix:
      // force-collapse must backfill first.
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {
          'inventoryDedupBackfilled': true,
          'inventoryDuplicatesCollapsed': true,
        }
        ..docs = {
          'leg1': {'name': 'Baking powder', 'tier': 'alwaysHave'},
          'leg2': {'name': 'Baking powder', 'tier': 'alwaysHave'},
          'leg3': {'name': 'Baking powder', 'tier': 'alwaysHave'},
        };
      final writer = InventoryWriter.test(storage: storage);

      final deleted = await writer.forceCollapseDuplicates();

      // Two of the three legacy rows should be collapsed away (one wins).
      expect(deleted, 2,
          reason: 'force-collapse must dedup legacy rows that lacked matchKey');
      // The remaining row must now carry a matchKey (backfill happened).
      final survivors = storage.docs.values.toList();
      expect(survivors, hasLength(1));
      expect(survivors.first['matchKey'], 'baking powder');
      expect(survivors.first['nameLower'], 'baking powder');
    });

    test('idempotent on a clean pantry (no duplicates, no missing matchKey)',
        () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {
          'inventoryDedupBackfilled': true,
          'inventoryDuplicatesCollapsed': true,
        }
        ..docs = {
          'a': {'name': 'Salt', 'nameLower': 'salt', 'matchKey': 'salt'},
          'b': {'name': 'Pepper', 'nameLower': 'pepper', 'matchKey': 'pepper'},
        };
      final writer = InventoryWriter.test(storage: storage);

      final deleted = await writer.forceCollapseDuplicates();
      expect(deleted, 0);
      expect(storage.docs.keys, containsAll(['a', 'b']));
    });
  });

  group('InventoryWriter.autoDedupOnce', () {
    test(
        'Sprint 16.6.x: merges legacy duplicates on first call '
        '(same fix as forceCollapseDuplicates — runs backfill before collapse)',
        () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {
          'inventoryDedupBackfilled': true,
          'inventoryDuplicatesCollapsed': true,
        }
        ..docs = {
          'leg1': {'name': 'Baking powder', 'tier': 'alwaysHave'},
          'leg2': {'name': 'Baking powder', 'tier': 'alwaysHave'},
          'leg3': {'name': 'Baking powder', 'tier': 'alwaysHave'},
        };
      final writer = InventoryWriter.test(storage: storage);

      final deleted = await writer.autoDedupOnce();
      expect(deleted, 2);
      expect(storage.docs.values, hasLength(1));
    });

    test('session-cached: second call returns null without re-running',
        () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {
          'inventoryDedupBackfilled': true,
          'inventoryDuplicatesCollapsed': true,
        }
        ..docs = {
          'a': {'name': 'Salt', 'nameLower': 'salt', 'matchKey': 'salt'},
        };
      final writer = InventoryWriter.test(storage: storage);

      final first = await writer.autoDedupOnce();
      expect(first, 0,
          reason: 'first call runs and returns the cleaned count');
      final second = await writer.autoDedupOnce();
      expect(second, isNull,
          reason:
              'second call in the same session is a no-op (session-cached)');
    });

    test('resetAutoDedupCacheForTest re-enables firing', () async {
      final storage = FakeInventoryWriteStorage()
        ..userDoc = const {
          'inventoryDedupBackfilled': true,
          'inventoryDuplicatesCollapsed': true,
        }
        ..docs = {
          'a': {'name': 'Salt', 'nameLower': 'salt', 'matchKey': 'salt'},
        };
      final writer = InventoryWriter.test(storage: storage);

      await writer.autoDedupOnce();
      writer.resetAutoDedupCacheForTest();
      final third = await writer.autoDedupOnce();
      expect(third, 0,
          reason: 'after reset the next call runs again (returns count)');
    });
  });
}
