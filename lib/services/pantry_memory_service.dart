import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/pantry_memory_entry.dart';
import '../utils/pantry_staples.dart';

/// Storage abstraction so the service can be unit-tested without
/// touching Firestore. Production wiring is [_FirestorePantryMemoryStorage]
/// below; tests inject [FakePantryMemoryStorage].
abstract class PantryMemoryStorage {
  Future<Map<String, Map<String, dynamic>>> fetchTierMemory();
  Future<Map<String, Map<String, dynamic>>> fetchCustomItems();
  Future<Map<String, dynamic>> fetchUserDoc();
  Future<Map<String, Map<String, dynamic>>> fetchInventory();

  Future<void> upsertCustom({
    required String normalizedName,
    required Map<String, dynamic> data,
  });

  Future<void> backfillTierMemory(List<Map<String, dynamic>> rows);
  Future<void> setBackfillFlag(bool value);
}

class PantryMemoryService {
  final PantryMemoryStorage _storage;

  PantryMemoryService._(this._storage);

  static PantryMemoryService _instance =
      PantryMemoryService._(_FirestorePantryMemoryStorage());

  static PantryMemoryService get instance => _instance;

  /// Test-only override for [instance]. Pass null to restore the default.
  @visibleForTesting
  static void debugSetTestInstance(PantryMemoryService? svc) {
    _instance = svc ?? PantryMemoryService._(_FirestorePantryMemoryStorage());
  }

  /// Test seam — inject a fake storage.
  @visibleForTesting
  factory PantryMemoryService.test({required PantryMemoryStorage storage}) =>
      PantryMemoryService._(storage);

  /// Top [limit] items from `tierMemory` ordered by lastSeen desc,
  /// universal staples filtered. Returns empty list on read error.
  Future<List<PantryMemoryEntry>> recentUsuals({int limit = 20}) async {
    try {
      final rows = await _storage.fetchTierMemory();
      final entries = <PantryMemoryEntry>[];
      rows.forEach((id, data) {
        if (PantryStaples.isStaple(id)) return;
        entries.add(PantryMemoryEntry.fromTierMemoryDoc(
          id, data,
          displayNameFallback: _titleCase(id),
        ));
      });
      entries.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
      return entries.take(limit).toList(growable: false);
    } catch (_) {
      return const <PantryMemoryEntry>[];
    }
  }

  /// Set of normalised names in `tierMemory` (staples filtered) — for
  /// the "had before" dot lookup on category chips.
  Future<Set<String>> hadBeforeKeys() async {
    try {
      final rows = await _storage.fetchTierMemory();
      return rows.keys
          .where((k) => !PantryStaples.isStaple(k))
          .toSet();
    } catch (_) {
      return const <String>{};
    }
  }

  /// User's persisted custom items grouped by category. Customs are
  /// filtered for staples (defensive — they shouldn't have been
  /// persisted in the first place).
  Future<Map<String, List<PantryMemoryEntry>>> customsByCategory() async {
    try {
      final rows = await _storage.fetchCustomItems();
      final byCategory = <String, List<PantryMemoryEntry>>{};
      rows.forEach((id, data) {
        if (PantryStaples.isStaple(id)) return;
        final entry = PantryMemoryEntry.fromCustomItemDoc(id, data);
        final cat = entry.category;
        if (cat == null) return;
        byCategory.putIfAbsent(cat, () => []).add(entry);
      });
      byCategory.forEach((cat, list) {
        list.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
      });
      return byCategory;
    } catch (_) {
      return const <String, List<PantryMemoryEntry>>{};
    }
  }

  /// Persist a typed custom item. Idempotent on the normalisedName key.
  /// Universal staples are refused (defensive — caller should also
  /// check, but enforce here to keep the storage clean).
  Future<void> upsertCustom({
    required String displayName,
    required String category,
    required String tier,
  }) async {
    final normalised = displayName.trim().toLowerCase();
    if (normalised.isEmpty) return;
    if (PantryStaples.isStaple(normalised)) return;
    try {
      await _storage.upsertCustom(
        normalizedName: normalised,
        data: {
          'displayName': displayName.trim(),
          'category': category,
          'tier': tier,
          'firstSeen': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        },
      );
    } catch (_) {
      // Fire-and-forget — inventory write still succeeds via the
      // existing onAddItem callback.
    }
  }

  /// Walks current inventory and writes any missing tierMemory rows.
  /// Idempotent — skips entirely once `pantryMemoryBackfilled` is true
  /// on the user doc. Universal staples are skipped.
  Future<void> backfillFromInventoryIfNeeded() async {
    try {
      final user = await _storage.fetchUserDoc();
      if (user['pantryMemoryBackfilled'] == true) return;

      final inventory = await _storage.fetchInventory();
      final rows = <Map<String, dynamic>>[];
      for (final entry in inventory.entries) {
        final data = entry.value;
        final name = (data['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        final normalised = name.toLowerCase();
        if (PantryStaples.isStaple(normalised)) continue;
        rows.add({
          'id': normalised,
          'name': name,
          'tier': (data['tier'] as String?) ?? 'alwaysHave',
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      if (rows.isNotEmpty) {
        await _storage.backfillTierMemory(rows);
      }
      await _storage.setBackfillFlag(true);
    } catch (_) {
      // Best-effort — never block the builder.
    }
  }

  /// Rough title-case for the displayName fallback when a tierMemory
  /// row has no `name` field.
  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

// ─── Production storage ──────────────────────────────────────────────

class _FirestorePantryMemoryStorage implements PantryMemoryStorage {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  Future<Map<String, Map<String, dynamic>>> fetchTierMemory() async {
    final uid = _uid;
    if (uid == null) return const <String, Map<String, dynamic>>{};
    final snap = await _db.collection('users').doc(uid).collection('tierMemory').get();
    return {for (final d in snap.docs) d.id: d.data()};
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchCustomItems() async {
    final uid = _uid;
    if (uid == null) return const <String, Map<String, dynamic>>{};
    final snap = await _db.collection('users').doc(uid).collection('customItems').get();
    return {for (final d in snap.docs) d.id: d.data()};
  }

  @override
  Future<Map<String, dynamic>> fetchUserDoc() async {
    final uid = _uid;
    if (uid == null) return const <String, dynamic>{};
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data() ?? const <String, dynamic>{};
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchInventory() async {
    final uid = _uid;
    if (uid == null) return const <String, Map<String, dynamic>>{};
    final snap = await _db.collection('users').doc(uid).collection('inventory').get();
    return {for (final d in snap.docs) d.id: d.data()};
  }

  @override
  Future<void> upsertCustom({
    required String normalizedName,
    required Map<String, dynamic> data,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users').doc(uid)
        .collection('customItems').doc(normalizedName)
        .set(data, SetOptions(merge: true));
  }

  @override
  Future<void> backfillTierMemory(List<Map<String, dynamic>> rows) async {
    final uid = _uid;
    if (uid == null || rows.isEmpty) return;
    final batch = _db.batch();
    final coll = _db.collection('users').doc(uid).collection('tierMemory');
    for (final row in rows) {
      batch.set(
        coll.doc(row['id'] as String),
        {'tier': row['tier'], 'lastSeen': row['lastSeen']},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  @override
  Future<void> setBackfillFlag(bool value) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set(
      {'pantryMemoryBackfilled': value},
      SetOptions(merge: true),
    );
  }
}
