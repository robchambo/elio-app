// test/services/order_import_service_stream_test.dart
//
// Sprint 17 — Task 7. Verifies that `pendingImportsStream()` filters
// to `status: pending_review`, orders by `receivedAt` desc, and that
// `PendingImport.fromDoc` round-trips a Firestore doc.
//
// Uses `fake_cloud_firestore` + `firebase_auth_mocks` (added as
// dev_dependencies in this task) — the production
// `FirebaseOrderImportService` already accepts injected `db` and
// `auth` for exactly this case.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/services/order_import_service.dart';

void main() {
  test('pendingImportsStream emits only pending_review, newest first',
      () async {
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u'),
    );

    final pendingCol = db
        .collection('users')
        .doc('u')
        .collection('pending_imports');

    // pending_review (older)
    await pendingCol.add({
      'status': 'pending_review',
      'retailer': 'tesco',
      'receivedAt': Timestamp.fromDate(DateTime(2026, 5, 24, 10)),
      'items': <Map<String, dynamic>>[],
      'orderType': 'confirmation',
      'parseConfidence': 0.9,
      'emailSubject': 'Tesco order',
    });
    // applied (must be filtered out)
    await pendingCol.add({
      'status': 'applied',
      'retailer': 'walmart',
      'receivedAt': Timestamp.fromDate(DateTime(2026, 5, 24, 11)),
      'items': <Map<String, dynamic>>[],
      'orderType': 'confirmation',
      'parseConfidence': 0.95,
      'emailSubject': 'Walmart order',
    });
    // pending_review (newer) — should sort first
    await pendingCol.add({
      'status': 'pending_review',
      'retailer': 'kroger',
      'receivedAt': Timestamp.fromDate(DateTime(2026, 5, 25, 9)),
      'items': <Map<String, dynamic>>[
        {
          'rawName': 'KRO Whole Milk 1G',
          'normalizedName': 'whole milk',
          'quantity': 1,
          'unit': 'gal',
          'category': 'dairy',
          'classification': 'food',
        },
      ],
      'orderType': 'confirmation',
      'parseConfidence': 0.95,
      'emailSubject': 'Kroger order',
    });

    final svc = FirebaseOrderImportService(db: db, auth: auth);
    final first = await svc.pendingImportsStream().first;

    expect(first.length, 2);
    // Ordered by receivedAt desc — kroger (2026-05-25) before tesco
    // (2026-05-24).
    expect(first[0].retailer, 'kroger');
    expect(first[1].retailer, 'tesco');

    // PendingImport.fromDoc round-trip — items deserialised correctly.
    expect(first[0].items.length, 1);
    expect(first[0].items.first.normalizedName, 'whole milk');
    expect(first[0].items.first.category, 'dairy');
    expect(first[0].parseConfidence, 0.95);
    expect(first[0].orderType, 'confirmation');
  });

  test('pendingImportsStream emits empty list when signed out', () async {
    final svc = FirebaseOrderImportService(
      db: FakeFirebaseFirestore(),
      auth: MockFirebaseAuth(signedIn: false),
    );
    final first = await svc.pendingImportsStream().first;
    expect(first, isEmpty);
  });
}
