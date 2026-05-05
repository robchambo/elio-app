// lib/services/inventory_writer.dart
//
// Dedup-aware inventory writer + lazy migration of legacy rows.
//
// Mirrors the ShoppingService matchKey + nameLower dedup pattern. The
// existing FirestoreService.addInventoryItem delegates here so callers
// keep their existing API (no signature change).
//
// Storage is abstracted via [InventoryWriteStorage] so the dedup logic
// can be unit-tested without fake_cloud_firestore. Production wiring is
// [_FirestoreInventoryWriteStorage]; tests inject FakeInventoryWriteStorage.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../utils/pantry_string_match.dart';

/// Storage abstraction so the dedup logic can be tested without
/// touching Firestore. Production: [_FirestoreInventoryWriteStorage].
abstract class InventoryWriteStorage {
  /// Look up an existing row by [matchKey] first, falling back to
  /// [nameLower] for legacy rows that don't have matchKey yet. Returns
  /// the existing doc id + data, or null if no match.
  Future<({String id, Map<String, dynamic> data})?> findExistingByKey({
    required String matchKey,
    required String nameLower,
  });

  /// Update fields on an existing inventory doc. The caller has already
  /// built the update map per the rule book.
  Future<void> updateInventoryDoc(String docId, Map<String, dynamic> updates);

  /// Insert a brand-new inventory doc. Returns the assigned doc id.
  Future<String> insertInventoryDoc(Map<String, dynamic> data);

  /// Read all inventory docs (used by the migrator).
  Future<List<({String id, Map<String, dynamic> data})>> fetchAllInventory();

  /// Read the user doc (used to check the migration flag).
  Future<Map<String, dynamic>> fetchUserDoc();

  /// Atomic batched migration: update each [rows] doc with the supplied
  /// fields and set the [inventoryDedupBackfilled] flag on the user doc
  /// in a single Firestore batch. [rows] is a list of (docId, fields).
  Future<void> migrateLegacyRows(List<({String id, Map<String, dynamic> updates})> rows);

  /// Sprint 15.9.3 second migration step: collapse duplicate inventory
  /// rows that pre-date the dedup logic. Updates each winner with merged
  /// fields, deletes each loser, and sets the `inventoryDuplicatesCollapsed`
  /// flag — all in one atomic batch so a partial failure leaves nothing
  /// half-collapsed. [winnerUpdates] keys are doc ids; [loserIds] are docs
  /// to delete outright.
  Future<void> collapseDuplicates({
    required Map<String, Map<String, dynamic>> winnerUpdates,
    required List<String> loserIds,
  });
}

class InventoryWriter {
  final InventoryWriteStorage _storage;

  /// Session-local cache so we only hit the user doc for the migration
  /// flag once. Stays null until the first call resolves it; once true
  /// the migrator short-circuits forever within this app launch.
  bool? _migrationDoneCache;

  InventoryWriter._(this._storage);

  static InventoryWriter _instance =
      InventoryWriter._(_FirestoreInventoryWriteStorage());

  static InventoryWriter get instance => _instance;

  /// Test-only override for [instance]. Pass null to restore the default.
  @visibleForTesting
  static void debugSetTestInstance(InventoryWriter? svc) {
    _instance = svc ?? InventoryWriter._(_FirestoreInventoryWriteStorage());
  }

  @visibleForTesting
  factory InventoryWriter.test({required InventoryWriteStorage storage}) =>
      InventoryWriter._(storage);

  /// Dedup-aware inventory add. Returns the doc id (existing on update,
  /// new on insert). Universal staples are NOT silently filtered here
  /// (caller responsibility — different surfaces handle staples
  /// differently; the builder dialog already blocks them inline, and
  /// the receipt scanner relies on the staple filter at recipe-time).
  ///
  /// Per the spec rule book:
  ///   - tier        sticky on re-add (existing wins)
  ///   - expiryDate  refreshes if existing is perishable AND new value supplied
  ///   - lastPurchasedAt  always refreshed
  ///   - firstAddedAt     never overwritten on update; set on insert
  ///   - runningLow       cleared (false) on every re-add
  ///   - price       replaced if supplied; sticky if not
  ///   - category    sticky
  ///   - name        sticky (existing display casing preserved)
  Future<String> addItem({
    required String name,
    required String tier,
    DateTime? expiryDate,
    String? category,
    String? price,
  }) async {
    // Lazy migration runs first so the dedup query has the new fields
    // populated on legacy rows. (Implemented in Task 4.)
    await _runMigrationIfNeeded();

    final nameLower = PantryStringMatch.nameLower(name);
    final matchKey = PantryStringMatch.matchKey(name);

    final existing = await _storage.findExistingByKey(
      matchKey: matchKey,
      nameLower: nameLower,
    );

    if (existing != null) {
      final existingTier = (existing.data['tier'] as String?) ?? tier;
      final updates = <String, dynamic>{
        'lastPurchasedAt': FieldValue.serverTimestamp(),
        'runningLow': false,
        // Defensive backfill — these may be missing on legacy rows.
        'matchKey': matchKey,
        'nameLower': nameLower,
      };
      // Refresh expiry only if existing tier is perishable AND a new
      // value is supplied. Existing non-perishable rows ignore expiry.
      if (existingTier == 'perishable' && expiryDate != null) {
        updates['expiryDate'] = Timestamp.fromDate(expiryDate);
      }
      // Replace price only if supplied; never clear an existing price.
      if (price != null && price.isNotEmpty) {
        updates['price'] = price;
      }
      await _storage.updateInventoryDoc(existing.id, updates);
      return existing.id;
    }

    // Insert path.
    final data = <String, dynamic>{
      'name': name,
      'tier': tier,
      'nameLower': nameLower,
      'matchKey': matchKey,
      'runningLow': false,
      'firstAddedAt': FieldValue.serverTimestamp(),
      'lastPurchasedAt': FieldValue.serverTimestamp(),
    };
    if (expiryDate != null) {
      data['expiryDate'] = Timestamp.fromDate(expiryDate);
    }
    if (category != null) {
      data['category'] = category;
    }
    if (price != null && price.isNotEmpty) {
      data['price'] = price;
    }
    return _storage.insertInventoryDoc(data);
  }

  /// Lazy one-shot migration. Two steps, each gated by its own user-doc
  /// flag so they run exactly once per user across all devices:
  ///
  ///   1. **Backfill** missing `matchKey` / `nameLower` / timestamps on
  ///      legacy rows. Sets `inventoryDedupBackfilled: true`.
  ///   2. **Collapse** duplicate rows that share a `matchKey`. Picks the
  ///      oldest as the winner, merges any non-null fields from losers
  ///      (latest expiry for perishables, fallback price/category, max
  ///      lastPurchasedAt), deletes the losers. Sets
  ///      `inventoryDuplicatesCollapsed: true`.
  ///
  /// Step 2 was added in Sprint 15.9.3 after Rob found his dev pantry
  /// littered with 5–7 copies of common items from many onboarding
  /// runs — Step 1 alone backfills the keys but doesn't consolidate.
  ///
  /// Idempotent: short-circuits via the session cache and per-step flags.
  /// Read failures silently no-op — we never block addItem for an
  /// optional polish migration.
  Future<void> _runMigrationIfNeeded() async {
    if (_migrationDoneCache == true) return;
    try {
      final user = await _storage.fetchUserDoc();
      final backfilled = user['inventoryDedupBackfilled'] == true;
      final collapsed = user['inventoryDuplicatesCollapsed'] == true;

      if (backfilled && collapsed) {
        _migrationDoneCache = true;
        return;
      }

      // ── Step 1: backfill ─────────────────────────────────────────────
      if (!backfilled) {
        final inventory = await _storage.fetchAllInventory();
        final rows = <({String id, Map<String, dynamic> updates})>[];
        for (final entry in inventory) {
          if (entry.data.containsKey('matchKey')) continue;
          final name = (entry.data['name'] as String?)?.trim() ?? '';
          if (name.isEmpty) continue;
          rows.add((
            id: entry.id,
            updates: {
              'nameLower': PantryStringMatch.nameLower(name),
              'matchKey': PantryStringMatch.matchKey(name),
              'firstAddedAt': FieldValue.serverTimestamp(),
              'lastPurchasedAt': FieldValue.serverTimestamp(),
            },
          ));
        }
        // Always commit (even if rows empty) so the flag lands.
        await _storage.migrateLegacyRows(rows);
      }

      // ── Step 2: collapse duplicates ──────────────────────────────────
      if (!collapsed) {
        // Re-fetch so any backfill that just landed is visible to the
        // grouping pass. The fake's migrateLegacyRows updates docs in
        // place, and Firestore reads are strongly consistent within a
        // single client, so this sees the latest state.
        final inventory = await _storage.fetchAllInventory();
        final groups = <String, List<({String id, Map<String, dynamic> data})>>{};
        for (final entry in inventory) {
          final mk = entry.data['matchKey'] as String?;
          if (mk == null || mk.isEmpty) continue;
          groups.putIfAbsent(mk, () => []).add(entry);
        }

        final winnerUpdates = <String, Map<String, dynamic>>{};
        final loserIds = <String>[];

        for (final entries in groups.values) {
          if (entries.length < 2) continue;
          // Pick winner: oldest firstAddedAt wins; doc id is the
          // tiebreaker so the choice is deterministic.
          entries.sort(_compareWinner);
          final winner = entries.first;
          final losers = entries.skip(1).toList();
          final merged = _mergeLoserFields(winner: winner, losers: losers);
          if (merged.isNotEmpty) {
            winnerUpdates[winner.id] = merged;
          }
          loserIds.addAll(losers.map((e) => e.id));
        }

        // Always commit (even if both maps empty) so the flag lands.
        await _storage.collapseDuplicates(
          winnerUpdates: winnerUpdates,
          loserIds: loserIds,
        );
      }

      _migrationDoneCache = true;
    } catch (_) {
      // Best-effort — never block addItem. _migrationDoneCache stays null
      // so the next addItem call retries. A transient failure shouldn't
      // permanently disable the migrator.
    }
  }

  /// Sort comparator that puts the migration winner first. Oldest
  /// `firstAddedAt` wins; rows missing the field rank after rows that
  /// have it; doc id is the deterministic tiebreaker.
  static int _compareWinner(
    ({String id, Map<String, dynamic> data}) a,
    ({String id, Map<String, dynamic> data}) b,
  ) {
    final aFirst = a.data['firstAddedAt'];
    final bFirst = b.data['firstAddedAt'];
    if (aFirst is Timestamp && bFirst is Timestamp) {
      final c = aFirst.compareTo(bFirst);
      if (c != 0) return c;
    } else if (aFirst is Timestamp) {
      return -1;
    } else if (bFirst is Timestamp) {
      return 1;
    }
    return a.id.compareTo(b.id);
  }

  /// Compute the field merges to apply to a winner row from its losers.
  /// Returns only fields that need to change so the storage update is
  /// minimal. See spec §5 rule book for the per-field rules.
  static Map<String, dynamic> _mergeLoserFields({
    required ({String id, Map<String, dynamic> data}) winner,
    required List<({String id, Map<String, dynamic> data})> losers,
  }) {
    final merged = <String, dynamic>{};

    // expiryDate: latest across all rows, but only if the WINNER is
    // perishable. Non-perishable winners never carry an expiry.
    if (winner.data['tier'] == 'perishable') {
      Timestamp? latestExpiry = winner.data['expiryDate'] as Timestamp?;
      for (final l in losers) {
        final exp = l.data['expiryDate'] as Timestamp?;
        if (exp != null &&
            (latestExpiry == null || exp.compareTo(latestExpiry) > 0)) {
          latestExpiry = exp;
        }
      }
      if (latestExpiry != null && latestExpiry != winner.data['expiryDate']) {
        merged['expiryDate'] = latestExpiry;
      }
    }

    // price: if winner missing, take the first non-empty loser price.
    final winnerPrice = winner.data['price'] as String?;
    if (winnerPrice == null || winnerPrice.isEmpty) {
      for (final l in losers) {
        final p = l.data['price'] as String?;
        if (p != null && p.isNotEmpty) {
          merged['price'] = p;
          break;
        }
      }
    }

    // category: if winner missing, take the first non-empty loser category.
    final winnerCat = winner.data['category'] as String?;
    if (winnerCat == null || winnerCat.isEmpty) {
      for (final l in losers) {
        final c = l.data['category'] as String?;
        if (c != null && c.isNotEmpty) {
          merged['category'] = c;
          break;
        }
      }
    }

    // lastPurchasedAt: max across all rows.
    Timestamp? latestPurchase = winner.data['lastPurchasedAt'] as Timestamp?;
    for (final l in losers) {
      final lp = l.data['lastPurchasedAt'] as Timestamp?;
      if (lp != null &&
          (latestPurchase == null || lp.compareTo(latestPurchase) > 0)) {
        latestPurchase = lp;
      }
    }
    if (latestPurchase != null &&
        latestPurchase != winner.data['lastPurchasedAt']) {
      merged['lastPurchasedAt'] = latestPurchase;
    }

    // runningLow: clear it. Any merged item is "active" by definition.
    if (winner.data['runningLow'] == true) {
      merged['runningLow'] = false;
    }

    return merged;
  }
}

// ─── Production storage ──────────────────────────────────────────────

class _FirestoreInventoryWriteStorage implements InventoryWriteStorage {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _inventory(String uid) =>
      _db.collection('users').doc(uid).collection('inventory');

  @override
  Future<({String id, Map<String, dynamic> data})?> findExistingByKey({
    required String matchKey,
    required String nameLower,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    final coll = _inventory(uid);
    var snap = await coll.where('matchKey', isEqualTo: matchKey).limit(1).get();
    if (snap.docs.isEmpty) {
      snap = await coll.where('nameLower', isEqualTo: nameLower).limit(1).get();
    }
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return (id: doc.id, data: doc.data());
  }

  @override
  Future<void> updateInventoryDoc(String docId, Map<String, dynamic> updates) async {
    final uid = _uid;
    if (uid == null) return;
    await _inventory(uid).doc(docId).update(updates);
  }

  @override
  Future<String> insertInventoryDoc(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Cannot insert inventory doc without a signed-in user.');
    }
    final ref = _inventory(uid).doc();
    await ref.set(data);
    return ref.id;
  }

  @override
  Future<List<({String id, Map<String, dynamic> data})>> fetchAllInventory() async {
    final uid = _uid;
    if (uid == null) return const [];
    final snap = await _inventory(uid).get();
    return [for (final d in snap.docs) (id: d.id, data: d.data())];
  }

  @override
  Future<Map<String, dynamic>> fetchUserDoc() async {
    final uid = _uid;
    if (uid == null) return const <String, dynamic>{};
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data() ?? const <String, dynamic>{};
  }

  @override
  Future<void> migrateLegacyRows(
    List<({String id, Map<String, dynamic> updates})> rows,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    final batch = _db.batch();
    final coll = _inventory(uid);
    for (final row in rows) {
      batch.update(coll.doc(row.id), row.updates);
    }
    batch.set(
      _db.collection('users').doc(uid),
      {'inventoryDedupBackfilled': true},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  @override
  Future<void> collapseDuplicates({
    required Map<String, Map<String, dynamic>> winnerUpdates,
    required List<String> loserIds,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final coll = _inventory(uid);
    // Firestore caps batches at 500 writes. The flag-set is +1 write.
    // Pathological pantries (500+ duplicates) are unrealistic but the
    // chunk loop keeps us safe. Each chunk commits independently; if a
    // later chunk fails the flag never lands and the migrator retries.
    const chunkSize = 450;
    final winners = winnerUpdates.entries.toList();
    final losers = List<String>.from(loserIds);

    int writeBudget = 0;
    WriteBatch batch = _db.batch();
    Future<void> flush() async {
      if (writeBudget == 0) return;
      await batch.commit();
      batch = _db.batch();
      writeBudget = 0;
    }

    for (final w in winners) {
      if (writeBudget >= chunkSize) await flush();
      batch.update(coll.doc(w.key), w.value);
      writeBudget++;
    }
    for (final id in losers) {
      if (writeBudget >= chunkSize) await flush();
      batch.delete(coll.doc(id));
      writeBudget++;
    }
    // Final chunk gets the flag-set so it only lands if everything else
    // committed cleanly.
    batch.set(
      _db.collection('users').doc(uid),
      {'inventoryDuplicatesCollapsed': true},
      SetOptions(merge: true),
    );
    await batch.commit();
  }
}
