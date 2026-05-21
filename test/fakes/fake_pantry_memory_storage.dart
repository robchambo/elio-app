import 'package:elio_app/services/pantry_memory_service.dart';

/// In-memory stand-in for the Firestore-backed PantryMemoryStorage.
/// Tests seed the maps directly. Setting [throwOnRead] simulates a
/// Firestore read error.
class FakePantryMemoryStorage implements PantryMemoryStorage {
  Map<String, Map<String, dynamic>> tierMemoryRows = {};
  Map<String, Map<String, dynamic>> customItemRows = {};
  Map<String, dynamic> userDoc = const {};
  Map<String, Map<String, dynamic>> inventoryRows = const {};

  bool throwOnRead = false;
  bool throwOnWrite = false;

  // Capture writes for assertions.
  final List<Map<String, dynamic>> upsertedCustoms = [];
  final List<Map<String, dynamic>> backfilledTierMemoryRows = [];
  bool backfillFlagSet = false;

  @override
  Future<Map<String, Map<String, dynamic>>> fetchTierMemory() async {
    if (throwOnRead) throw StateError('test: read failed');
    return Map.of(tierMemoryRows);
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchCustomItems() async {
    if (throwOnRead) throw StateError('test: read failed');
    return Map.of(customItemRows);
  }

  @override
  Future<Map<String, dynamic>> fetchUserDoc() async {
    if (throwOnRead) throw StateError('test: read failed');
    return Map.of(userDoc);
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchInventory() async {
    if (throwOnRead) throw StateError('test: read failed');
    return Map.of(inventoryRows.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v))));
  }

  @override
  Future<void> upsertCustom({
    required String normalizedName,
    required Map<String, dynamic> data,
  }) async {
    if (throwOnWrite) throw StateError('test: write failed');
    upsertedCustoms.add({'id': normalizedName, ...data});
    customItemRows[normalizedName] = {...data};
  }

  @override
  Future<void> backfillTierMemory(List<Map<String, dynamic>> rows) async {
    if (throwOnWrite) throw StateError('test: backfill failed');
    backfilledTierMemoryRows.addAll(rows);
    for (final row in rows) {
      final id = row['id'] as String;
      tierMemoryRows[id] = {
        'tier': row['tier'],
        'lastSeen': row['lastSeen'],
      };
    }
  }

  @override
  Future<void> setBackfillFlag(bool value) async {
    if (throwOnWrite) throw StateError('test: flag failed');
    backfillFlagSet = value;
  }
}
