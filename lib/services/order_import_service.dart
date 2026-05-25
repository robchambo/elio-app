// lib/services/order_import_service.dart
//
// Sprint 17 — Online Order → Pantry Import.
//
// Seam between the OrderImportScreen UI and Firebase. The Pro-gated
// "Order import" settings row pushes the screen, which calls
// `ensureImportAddress()` on first build. The implementation prefers
// the cached `importAddress` on the user doc (server-written, client-
// read-only — see firestore.rules `importAddressUnchanged()`), and
// only invokes the `generateImportAddress` callable on a cache miss.
//
// Streaming pending_imports + apply actions land in Tasks 7 and 9.
// This file intentionally exposes only what Task 6 needs so the seam
// stays small and the widget tests can fake it without stubbing
// anything not yet used.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Abstract seam — widget tests use a `FakeOrderImportService`.
abstract class OrderImportService {
  /// Returns the user's `u_<token>@orders.elio.app` import address.
  ///
  /// Reads `users/{uid}.importAddress` first; only calls the
  /// `generateImportAddress` callable on a cache miss. Subsequent
  /// opens of OrderImportScreen do not trigger the callable.
  Future<String> ensureImportAddress();
}

/// Production implementation — talks to Firestore + Cloud Functions.
class FirebaseOrderImportService implements OrderImportService {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirebaseOrderImportService({
    FirebaseFunctions? functions,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<String> ensureImportAddress() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to set up order import.');
    }
    final doc = await _db.collection('users').doc(uid).get();
    final existing = doc.data()?['importAddress'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    final res = await _functions.httpsCallable('generateImportAddress').call();
    final data = res.data;
    if (data is Map && data['address'] is String) {
      return data['address'] as String;
    }
    throw StateError('generateImportAddress returned an unexpected shape.');
  }
}
