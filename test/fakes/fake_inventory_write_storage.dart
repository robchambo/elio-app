// test/fakes/fake_inventory_write_storage.dart
import 'package:elio_app/services/inventory_writer.dart';

/// In-memory stand-in for the Firestore-backed InventoryWriteStorage.
/// Tests seed [docs] + [userDoc] directly. Setting [throwOnRead]/
/// [throwOnWrite] simulates a Firestore failure.
class FakeInventoryWriteStorage implements InventoryWriteStorage {
  /// Map of docId → doc data. Tests seed legacy rows here.
  Map<String, Map<String, dynamic>> docs = {};

  Map<String, dynamic> userDoc = const {};

  bool throwOnRead = false;
  bool throwOnWrite = false;

  /// Auto-incrementing id used when [insertInventoryDoc] needs to
  /// allocate a fresh doc id.
  int _nextId = 1;

  // Capture lists for assertions.
  final List<({String matchKey, String nameLower})> findCalls = [];
  final List<({String id, Map<String, dynamic> updates})> updateCalls = [];
  final List<Map<String, dynamic>> insertCalls = [];
  final List<({String id, Map<String, dynamic> updates})> migratedRows = [];
  bool migrationFlagSet = false;

  @override
  Future<({String id, Map<String, dynamic> data})?> findExistingByKey({
    required String matchKey,
    required String nameLower,
  }) async {
    if (throwOnRead) throw StateError('test: read failed');
    findCalls.add((matchKey: matchKey, nameLower: nameLower));

    // Primary: matchKey.
    for (final entry in docs.entries) {
      if (entry.value['matchKey'] == matchKey) {
        return (id: entry.key, data: Map<String, dynamic>.from(entry.value));
      }
    }
    // Fallback: nameLower (for legacy rows without matchKey).
    for (final entry in docs.entries) {
      if (entry.value['nameLower'] == nameLower) {
        return (id: entry.key, data: Map<String, dynamic>.from(entry.value));
      }
    }
    return null;
  }

  @override
  Future<void> updateInventoryDoc(
    String docId,
    Map<String, dynamic> updates,
  ) async {
    if (throwOnWrite) throw StateError('test: write failed');
    updateCalls.add((id: docId, updates: Map<String, dynamic>.from(updates)));
    final existing = docs[docId];
    if (existing != null) {
      docs[docId] = {...existing, ...updates};
    }
  }

  @override
  Future<String> insertInventoryDoc(Map<String, dynamic> data) async {
    if (throwOnWrite) throw StateError('test: write failed');
    insertCalls.add(Map<String, dynamic>.from(data));
    final id = 'fake_${_nextId++}';
    docs[id] = Map<String, dynamic>.from(data);
    return id;
  }

  @override
  Future<List<({String id, Map<String, dynamic> data})>> fetchAllInventory() async {
    if (throwOnRead) throw StateError('test: read failed');
    return [
      for (final e in docs.entries)
        (id: e.key, data: Map<String, dynamic>.from(e.value)),
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchUserDoc() async {
    if (throwOnRead) throw StateError('test: read failed');
    return Map<String, dynamic>.from(userDoc);
  }

  @override
  Future<void> migrateLegacyRows(
    List<({String id, Map<String, dynamic> updates})> rows,
  ) async {
    if (throwOnWrite) throw StateError('test: migration failed');
    migratedRows.addAll(rows);
    for (final row in rows) {
      final existing = docs[row.id];
      if (existing != null) {
        docs[row.id] = {...existing, ...row.updates};
      }
    }
    migrationFlagSet = true;
    userDoc = {...userDoc, 'inventoryDedupBackfilled': true};
  }
}
