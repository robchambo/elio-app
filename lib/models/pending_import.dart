// lib/models/pending_import.dart
//
// Sprint 17 — Online Order → Pantry Import.
//
// Dart model for the `users/{uid}/pending_imports/{id}` doc written
// by the `postmarkInbound` Cloud Function (see Task 5). One doc
// per incoming order email. The client streams docs in
// `status: pending_review` (Task 7), the review sheet (Task 8) lets
// the user edit/toggle items, and Task 9's apply flow flips the
// status to `applied` (or `discarded`).
//
// Field shape matches the Admin SDK writer in
// `functions/src/orderImport/postmarkInbound.ts`. Missing fields fall
// back to safe defaults so a partially-written stub (status:parsing)
// is still decodable without crashing the stream consumer.

import 'package:cloud_firestore/cloud_firestore.dart';

/// One parsed line item from an order email.
class PendingImportItem {
  final String rawName;
  final String normalizedName;
  final num? quantity;
  final String? unit;
  final String category;
  final String classification;

  PendingImportItem({
    required this.rawName,
    required this.normalizedName,
    this.quantity,
    this.unit,
    required this.category,
    required this.classification,
  });

  factory PendingImportItem.fromMap(Map<String, dynamic> m) =>
      PendingImportItem(
        rawName: (m['rawName'] as String?) ?? '',
        normalizedName: (m['normalizedName'] as String?) ?? '',
        quantity: m['quantity'] as num?,
        unit: m['unit'] as String?,
        category: (m['category'] as String?) ?? 'other',
        classification: (m['classification'] as String?) ?? 'unknown',
      );
}

/// One pending order import — a parsed email waiting for the user
/// to review and apply into their pantry.
class PendingImport {
  final String id;
  final String retailer;
  final String status;
  final List<PendingImportItem> items;
  final DateTime? receivedAt;
  final String orderType;
  final double parseConfidence;
  final String emailSubject;

  PendingImport({
    required this.id,
    required this.retailer,
    required this.status,
    required this.items,
    required this.receivedAt,
    required this.orderType,
    required this.parseConfidence,
    required this.emailSubject,
  });

  factory PendingImport.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return PendingImport(
      id: d.id,
      retailer: (m['retailer'] as String?) ?? 'unknown',
      status: (m['status'] as String?) ?? 'pending_review',
      items: ((m['items'] as List?) ?? const <dynamic>[])
          .map((e) => PendingImportItem.fromMap(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      receivedAt: (m['receivedAt'] as Timestamp?)?.toDate(),
      orderType: (m['orderType'] as String?) ?? 'unknown',
      parseConfidence: ((m['parseConfidence'] as num?) ?? 0).toDouble(),
      emailSubject: (m['emailSubject'] as String?) ?? '',
    );
  }
}
