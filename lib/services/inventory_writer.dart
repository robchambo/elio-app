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
}

class InventoryWriter {
  // ignore: unused_field // used by addItem (Task 3) + migrator (Task 4)
  final InventoryWriteStorage _storage;

  /// Session-local cache so we only hit the user doc for the migration
  /// flag once. Stays null until the first call resolves it; once true
  /// the migrator short-circuits forever within this app launch.
  // ignore: unused_field // wired by migrator in Task 4
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
}
