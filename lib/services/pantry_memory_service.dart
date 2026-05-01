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

  static final PantryMemoryService instance =
      PantryMemoryService._(_FirestorePantryMemoryStorage());

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
      return const [];
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
      return const {};
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
      return byCategory;
    } catch (_) {
      return const {};
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
    if (uid == null) return const {};
    final snap = await _db.collection('users').doc(uid).collection('tierMemory').get();
    return {for (final d in snap.docs) d.id: d.data()};
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchCustomItems() async {
    final uid = _uid;
    if (uid == null) return const {};
    final snap = await _db.collection('users').doc(uid).collection('customItems').get();
    return {for (final d in snap.docs) d.id: d.data()};
  }

  @override
  Future<Map<String, dynamic>> fetchUserDoc() async {
    final uid = _uid;
    if (uid == null) return const {};
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data() ?? const {};
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchInventory() async {
    final uid = _uid;
    if (uid == null) return const {};
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
