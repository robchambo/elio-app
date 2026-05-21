import 'package:cloud_firestore/cloud_firestore.dart';

/// A row sourced either from `users/{uid}/tierMemory/{name}` or from
/// `users/{uid}/customItems/{name}`, normalised into a single shape the
/// Pantry Builder can render uniformly.
///
/// Sprint 16.6: the `isCustom` flag was dropped — it was set by both
/// factories but never read by any consumer. The builder differentiates
/// customs vs tier-memory rows by which map they came from (see
/// `PantryMemoryService.recentUsuals` vs `customsByCategory`), not by a
/// flag on the entry. If the flag is needed again, restore via the
/// `category != null` heuristic (only `fromCustomItemDoc` populates a
/// category).
class PantryMemoryEntry {
  final String normalizedName;
  final String displayName;
  final String tier; // 'alwaysHave' | 'almostAlwaysHave' | 'perishable'
  final String? category; // null for tierMemory rows; non-null for customs
  final DateTime lastSeen;

  const PantryMemoryEntry({
    required this.normalizedName,
    required this.displayName,
    required this.tier,
    required this.lastSeen,
    this.category,
  });

  /// Build from a `tierMemory` doc. The doc id IS the normalized name.
  /// Display name is recovered from the optional `name` field, falling
  /// back to the supplied [displayNameFallback] (typically the doc id
  /// title-cased by the caller).
  factory PantryMemoryEntry.fromTierMemoryDoc(
    String docId,
    Map<String, dynamic> data, {
    required String displayNameFallback,
  }) {
    return PantryMemoryEntry(
      normalizedName: docId,
      displayName: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : displayNameFallback,
      tier: (data['tier'] as String?) ?? 'alwaysHave',
      category: null,
      lastSeen: _readTimestamp(data['lastSeen']),
    );
  }

  /// Build from a `customItems` doc. Doc id is the normalized name.
  factory PantryMemoryEntry.fromCustomItemDoc(
    String docId,
    Map<String, dynamic> data,
  ) {
    return PantryMemoryEntry(
      normalizedName: docId,
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : docId,
      tier: (data['tier'] as String?) ?? 'alwaysHave',
      category: data['category'] as String?,
      lastSeen: _readTimestamp(data['lastSeen']),
    );
  }

  static DateTime _readTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
