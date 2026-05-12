// lib/services/data_export_service.dart
//
// Sprint 17 — GDPR Article 15 (right of access / data portability).
// Returns the user's full profile + every subcollection as a single
// JSON file the user can save, mail to themselves, or hand to a
// regulator. Same UI-agnostic shape as AccountService: builds a
// service the eventual Settings tile calls; no widgets here.
//
// We deliberately avoid `path_provider` — `Directory.systemTemp` from
// dart:io maps to the platform's app-cache dir on Android/iOS without
// pulling in another plugin. The exported file is regenerated each
// time and ephemeral; no need to persist it.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'account_service.dart';
import 'error_service.dart';

/// Result returned by [DataExportService.exportAndShare].
sealed class DataExportResult {
  const DataExportResult();
}

class DataExportSuccess extends DataExportResult {
  final String filePath;
  final int byteCount;
  const DataExportSuccess({required this.filePath, required this.byteCount});
}

class DataExportNotSignedIn extends DataExportResult {
  const DataExportNotSignedIn();
}

class DataExportFailed extends DataExportResult {
  final String message;
  const DataExportFailed(this.message);
}

class DataExportService {
  DataExportService._();
  static final DataExportService instance = DataExportService._();

  /// Schema version baked into the export so future readers (or a
  /// future Elio that imports its own exports) can branch on it.
  /// Bump when the exported shape changes incompatibly.
  static const int schemaVersion = 1;

  /// Test seam — replaces the Share.shareXFiles step. Lets unit tests
  /// assert the orchestrator wrote a well-formed file without booting
  /// the platform share sheet.
  @visibleForTesting
  Future<void> Function(String filePath)? debugShareOverride;

  /// Builds the full export as a pretty-printed JSON string. Pure
  /// data — no file IO, no share sheet — so tests can assert the
  /// shape with a fake Firestore.
  ///
  /// Reads `users/{uid}` plus every subcollection in
  /// [AccountService.userSubcollections] (single source of truth for
  /// "what is the user's data?"). If a subcollection is missing or
  /// permission-denied it's recorded as an empty list rather than
  /// failing the whole export.
  Future<String> buildExportJson() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Not signed in.');
    }

    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(user.uid);

    // ── User doc ────────────────────────────────────────────────
    Map<String, dynamic> userDoc = {};
    try {
      final snap = await userRef.get();
      if (snap.exists) {
        userDoc = _normalise(snap.data() ?? {}) as Map<String, dynamic>;
      }
    } catch (e) {
      ErrorService.log('data_export_user_doc', e);
    }

    // ── Subcollections ──────────────────────────────────────────
    final Map<String, List<Map<String, dynamic>>> subcollections = {};
    for (final name in AccountService.userSubcollections) {
      try {
        final snap = await userRef.collection(name).get();
        subcollections[name] = [
          for (final doc in snap.docs)
            <String, dynamic>{
              'id': doc.id,
              ...(_normalise(doc.data()) as Map<String, dynamic>),
            },
        ];
      } catch (e) {
        ErrorService.log('data_export_sub_$name', e);
        subcollections[name] = const [];
      }
    }

    final payload = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'account': {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'providerIds':
            user.providerData.map((p) => p.providerId).toList(),
        'creationTime':
            user.metadata.creationTime?.toUtc().toIso8601String(),
        'lastSignInTime':
            user.metadata.lastSignInTime?.toUtc().toIso8601String(),
      },
      'user': userDoc,
      'subcollections': subcollections,
    };

    // Pretty-print so the user can open the file in any text editor.
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Builds the export, writes it to a temp file, and hands it to
  /// the system share sheet. The caller (typically a Settings tile)
  /// just awaits this and shows a toast on the result.
  Future<DataExportResult> exportAndShare() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const DataExportNotSignedIn();

    final String json;
    try {
      json = await buildExportJson();
    } catch (e) {
      ErrorService.log('data_export_build', e);
      return DataExportFailed('Could not build export: $e');
    }

    final File file;
    try {
      file = await _writeTempFile(uid: user.uid, json: json);
    } catch (e) {
      ErrorService.log('data_export_write', e);
      return DataExportFailed('Could not write export file: $e');
    }

    try {
      final override = debugShareOverride;
      if (override != null) {
        await override(file.path);
      } else {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/json')],
          subject: 'My Elio data export',
        );
      }
    } catch (e) {
      ErrorService.log('data_export_share', e);
      return DataExportFailed('Could not open the share sheet: $e');
    }

    return DataExportSuccess(
      filePath: file.path,
      byteCount: await file.length(),
    );
  }

  // ─── Internals ────────────────────────────────────────────────

  Future<File> _writeTempFile({
    required String uid,
    required String json,
  }) async {
    final dir = await Directory.systemTemp.createTemp('elio_export_');
    // Short uid suffix so the file name is identifiable but doesn't
    // leak the full uid into share-sheet recipients' chat history.
    final shortUid = uid.length > 8 ? uid.substring(0, 8) : uid;
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('${dir.path}/elio-data-$shortUid-$stamp.json');
    await file.writeAsString(json);
    return file;
  }

  /// Recursively converts Firestore-specific types (Timestamp,
  /// GeoPoint, Blob, DocumentReference) into JSON-safe primitives.
  /// Anything else falls through unchanged — which is correct for
  /// String/num/bool/null and for Lists/Maps of those.
  @visibleForTesting
  static Object? normaliseForTest(Object? value) => _normalise(value);

  static Object? _normalise(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is GeoPoint) {
      return {'lat': value.latitude, 'lng': value.longitude};
    }
    if (value is Blob) return base64Encode(value.bytes);
    if (value is DocumentReference) return value.path;
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is List) {
      return [for (final v in value) _normalise(v)];
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _normalise(entry.value),
      };
    }
    return value;
  }
}
