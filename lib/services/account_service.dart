// lib/services/account_service.dart
//
// Sprint 17 — GDPR right-to-erasure (Article 17) + Play/App Store
// account-deletion requirement.
//
// AccountService owns the destructive end of the user lifecycle:
// deleting a signed-in account and every trace of its data, in the
// right order, with a sane re-auth dance for `requires-recent-login`.
//
// Why a service rather than wiring everything into the eventual
// SettingsScreen: Kate's settings UI is still in design but the
// store-listing-blocker pieces (this + DataExportService + hosted
// legal pages) are independent of UI and need to ship for launch.
// When the screen lands, the button calls `deleteAccount(reauth: ...)`
// and that's it.
//
// ── Order of operations ──────────────────────────────────────────
//   1. Re-authenticate (proactive — fails fast before any data loss
//      if the user cancels the password prompt or the Google sheet).
//   2. Best-effort FCM cleanup so the device stops receiving pushes.
//   3. Wipe every `users/{uid}/...` subcollection then the user doc.
//   4. RevenueCat `logOut()` so the alias doesn't outlive the uid.
//   5. `FirebaseAuth.currentUser.delete()`.
//   6. Clear SharedPreferences (history, guest pantry, onboarding flag).
//   7. Defensive `AuthService.signOut()` to clear Google's local state.
//
// Steps 2 and 4 are best-effort: if they fail, the GDPR delete still
// proceeds. Steps 1, 3, 5 are mandatory — failure short-circuits with
// a clear result so the caller can show an error and let the user retry.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'error_service.dart';
import 'purchase_service.dart';

/// Provider-id literals from `firebase_auth`. Centralised so the
/// reauth callback receives a stable string the UI can switch on
/// without importing `firebase_auth` itself.
class AccountProviderIds {
  static const String password = 'password';
  static const String google = 'google.com';
  static const String apple = 'apple.com';
  AccountProviderIds._();
}

/// What the re-auth callback hands back to the service.
///
/// The UI is responsible for prompting (password dialog, Google
/// sheet, Apple prompt) and turning the answer into a credential.
/// Returning `null` means the user cancelled → the delete aborts
/// before any data is touched.
typedef ReauthCallback =
    Future<AuthCredential?> Function(String providerId);

/// Result returned to the caller (typically a SettingsScreen tile
/// or the eventual delete-account confirm dialog).
sealed class DeleteAccountResult {
  const DeleteAccountResult();
}

class DeleteAccountSuccess extends DeleteAccountResult {
  const DeleteAccountSuccess();
}

/// User cancelled the re-auth prompt, or wasn't signed in to begin
/// with. No data was deleted.
class DeleteAccountCancelled extends DeleteAccountResult {
  final String reason;
  const DeleteAccountCancelled(this.reason);
}

/// Re-auth or one of the mandatory steps failed. [stage] tells the
/// caller where in the flow we stopped so the UI can decide whether
/// to suggest a retry or send the user to support.
class DeleteAccountFailed extends DeleteAccountResult {
  final String stage;
  final String message;
  const DeleteAccountFailed({required this.stage, required this.message});
}

/// Singleton — holds no state, just orchestrates.
class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  /// Subcollections under `users/{uid}` that must be wiped — also
  /// the canonical "what is the user's data?" list that
  /// [DataExportService] iterates for GDPR access requests.
  ///
  /// Sourced from CLAUDE.md's Firestore Schema and verified by code
  /// search (Sprint 17 GDPR survey). If a new subcollection is added
  /// to the user doc, append its name here AND update CLAUDE.md.
  /// `account_service_test.dart` asserts this list matches the schema
  /// doc so the failure mode is a red test, not a quiet data leak.
  static const List<String> userSubcollections = <String>[
    'profiles',
    'inventory',
    'recipes',
    'ratings',
    'mealPlan',
    'shoppingItems',
    'tierMemory',
    'fcmTokens',
  ];

  /// FCM topics the app subscribes to. Must match
  /// `notification_service.dart`. Listed here (not imported) so the
  /// delete flow doesn't pull in NotificationService just to read
  /// constants.
  @visibleForTesting
  static const List<String> fcmTopics = <String>[
    'weekly_meal_reminder',
    'restock_reminder',
    'tips_and_updates',
  ];

  /// Test seam — when set, replaces the SharedPreferences-clear step.
  /// Lets unit tests assert it ran without booting the platform
  /// channel.
  @visibleForTesting
  Future<void> Function()? debugPrefsClearOverride;

  /// Test seam — when set, replaces the FCM cleanup step.
  @visibleForTesting
  Future<void> Function()? debugFcmCleanupOverride;

  /// Delete the signed-in account and every trace of its data.
  ///
  /// The caller MUST provide a [reauth] callback that prompts the
  /// user for fresh credentials matching their sign-in provider.
  /// See [ReauthCallback] for the contract.
  Future<DeleteAccountResult> deleteAccount({
    required ReauthCallback reauth,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const DeleteAccountCancelled('not signed in');
    }

    // ── 1. Re-authenticate ────────────────────────────────────
    // Pick the user's primary provider. If they linked multiple,
    // password wins (re-auth is most reliable) — Google/Apple are
    // tried in order otherwise. providerData is empty for anonymous
    // users; we treat that as a hard fail because Elio doesn't
    // expose anonymous accounts to the delete flow.
    final providerId = _pickProvider(user);
    if (providerId == null) {
      return const DeleteAccountFailed(
        stage: 'reauth',
        message: 'Could not determine sign-in provider.',
      );
    }

    final AuthCredential? credential;
    try {
      credential = await reauth(providerId);
    } catch (e) {
      ErrorService.log('account_delete_reauth_callback', e);
      return DeleteAccountFailed(
        stage: 'reauth',
        message: 'Re-authentication failed: $e',
      );
    }
    if (credential == null) {
      return const DeleteAccountCancelled('reauth cancelled');
    }

    try {
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      ErrorService.log('account_delete_reauth_firebase', e);
      return DeleteAccountFailed(
        stage: 'reauth',
        message: e.message ?? e.code,
      );
    }

    // From here on every step is destructive. We log failures and
    // continue for best-effort steps; we abort for mandatory ones.
    final uid = user.uid;

    // ── 2. FCM cleanup (best-effort) ──────────────────────────
    await _cleanupFcm();

    // ── 3. Firestore wipe (mandatory) ─────────────────────────
    try {
      await _wipeFirestore(uid);
    } catch (e) {
      ErrorService.log('account_delete_firestore', e);
      return DeleteAccountFailed(
        stage: 'firestore',
        message: 'Could not delete your data. Please try again.',
      );
    }

    // ── 4. RevenueCat (best-effort) ───────────────────────────
    try {
      await PurchaseService.instance.logOut();
    } catch (e) {
      ErrorService.log('account_delete_rc_logout', e);
      // best-effort
    }

    // ── 5. Auth delete (mandatory) ────────────────────────────
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      ErrorService.log('account_delete_auth', e);
      return DeleteAccountFailed(
        stage: 'auth',
        message: e.message ?? e.code,
      );
    }

    // ── 6. SharedPreferences (best-effort) ────────────────────
    try {
      final override = debugPrefsClearOverride;
      if (override != null) {
        await override();
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      }
    } catch (e) {
      ErrorService.log('account_delete_prefs', e);
    }

    // ── 7. Defensive sign-out (best-effort) ───────────────────
    // user.delete() already ends the Firebase session, but Google's
    // local sign-in cache survives unless we explicitly drop it.
    try {
      await AuthService().signOut();
    } catch (e) {
      ErrorService.log('account_delete_signout', e);
    }

    return const DeleteAccountSuccess();
  }

  // ─── Internals ────────────────────────────────────────────────

  String? _pickProvider(User user) {
    final ids = user.providerData.map((p) => p.providerId).toSet();
    if (ids.contains(AccountProviderIds.password)) {
      return AccountProviderIds.password;
    }
    if (ids.contains(AccountProviderIds.google)) {
      return AccountProviderIds.google;
    }
    if (ids.contains(AccountProviderIds.apple)) {
      return AccountProviderIds.apple;
    }
    return null;
  }

  Future<void> _cleanupFcm() async {
    final override = debugFcmCleanupOverride;
    if (override != null) {
      try {
        await override();
      } catch (e) {
        ErrorService.log('account_delete_fcm_override', e);
      }
      return;
    }
    final messaging = FirebaseMessaging.instance;
    for (final topic in fcmTopics) {
      try {
        await messaging.unsubscribeFromTopic(topic);
      } catch (e) {
        ErrorService.log('account_delete_fcm_unsubscribe_$topic', e);
      }
    }
    try {
      await messaging.deleteToken();
    } catch (e) {
      ErrorService.log('account_delete_fcm_delete_token', e);
    }
  }

  /// Wipes every doc under `users/{uid}` and the user doc itself.
  /// Uses batched writes (500 ops per batch — Firestore's hard cap)
  /// so a heavy user with thousands of saved recipes can't fail
  /// halfway.
  Future<void> _wipeFirestore(String uid) async {
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(uid);

    for (final name in userSubcollections) {
      await _deleteCollection(userRef.collection(name));
    }

    // The user doc last, so a partial failure leaves the doc as the
    // sentinel that retry-from-the-start can use.
    await userRef.delete();
  }

  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> ref) async {
    const int batchSize = 400; // < Firestore's 500 ceiling, room for safety
    while (true) {
      final snap = await ref.limit(batchSize).get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < batchSize) return;
    }
  }
}
