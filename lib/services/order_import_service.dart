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

import '../models/pending_import.dart';

/// Abstract seam — widget tests use a `FakeOrderImportService`.
abstract class OrderImportService {
  /// Returns the user's `u_<token>@orders.elio.app` import address.
  ///
  /// Reads `users/{uid}.importAddress` first; only calls the
  /// `generateImportAddress` callable on a cache miss. Subsequent
  /// opens of OrderImportScreen do not trigger the callable.
  Future<String> ensureImportAddress();

  /// Streams the current user's pending_imports docs in
  /// `status: pending_review`, newest first. Drives the pantry-tab
  /// dot badge (Task 7) and the inbox host screen (Task 9).
  Stream<List<PendingImport>> pendingImportsStream();
}

/// Production implementation — talks to Firestore + Cloud Functions.
class FirebaseOrderImportService implements OrderImportService {
  // _functions is resolved lazily on first ensureImportAddress() call
  // rather than at construction. Task 7 stream tests build this class
  // with injected `db` + `auth` but no Firebase app initialised, so
  // touching `FirebaseFunctions.instance` in the initialiser list
  // would throw `[core/no-app]` before any method runs.
  final FirebaseFunctions? _functionsOverride;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirebaseOrderImportService({
    FirebaseFunctions? functions,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _functionsOverride = functions,
        _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

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

  @override
  Stream<List<PendingImport>> pendingImportsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <PendingImport>[]);
    return _db
        .collection('users')
        .doc(uid)
        .collection('pending_imports')
        .where('status', isEqualTo: 'pending_review')
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PendingImport.fromDoc).toList());
  }
}
