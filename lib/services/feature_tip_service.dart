// lib/services/feature_tip_service.dart
//
// Sprint 16.8 row 7 — one-time educational tip system.
//
// Singleton ChangeNotifier (mirrors UserSettingsService) that owns whether a
// given tip should fire on a given screen. Eligibility rule is usage-gap
// driven: a tip only ever fires after the user has landed on its host
// screen `sessionThreshold` times *without ever using the feature*. The
// moment the user uses the feature (via `markFeatureUsed`), the tip is
// auto-marked seen so we never explain something the user has discovered.
//
// Persistence is two-layer:
//   • SharedPreferences  — hot path, available offline, survives sign-out.
//   • Firestore users/{uid}.seenTips — source of truth, survives reinstall
//                                       and crosses devices.
//
// The Firestore field is a simple map of `tipId -> serverTimestamp`. The
// existing user-doc rules (`isOwner(uid) && protectedSubKeysUnchanged()`)
// permit writes to non-protected keys, so no rules change is needed.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'error_service.dart';
import 'feature_tip_catalog.dart';

class FeatureTipService extends ChangeNotifier {
  FeatureTipService._() {
    // Skip the auth-state listener under `flutter test`. The
    // MethodChannelFirebaseAuth constructor fires off pigeon calls
    // (registerIdTokenListener / registerAuthStateListener) as
    // unawaited futures from its own constructor body — when the host
    // channel isn't mocked (the default for tests that use
    // setupFirebaseCoreMocks() without the auth platform mock), those
    // pigeon calls reject with a PlatformException that escapes to the
    // test zone and fails *unrelated* tests. There's no catch site we
    // own that can swallow it. Detecting the test runtime and short-
    // circuiting is the cleanest avoidance.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen(
        (user) {
          if (user == null) {
            // Don't *clear* — local seen-state should survive sign-out so
            // a re-signed-in user doesn't get re-tipped on every screen.
            // Only the Firestore source-of-truth is per-account; the local
            // mirror is per-device, which is the right grain for "don't
            // bug me again on this phone".
          } else {
            unawaited(_refreshFromFirestore());
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      // Firebase not initialised — production code path is guarded too.
    }
  }

  static final FeatureTipService instance = FeatureTipService._();

  /// Local hot-path cache. Key = tipId.
  final Map<String, bool> _seen = {};

  /// Local mirror of "user has used this feature". Key = requiredFeatureEvent
  /// (the same string passed to [markFeatureUsed]). Used to suppress tips
  /// for features the user has already discovered. Persisted to
  /// SharedPreferences so reinstall doesn't re-tip a returning user (their
  /// Firestore seenTips map covers the reinstall case for tips themselves).
  final Map<String, bool> _used = {};

  /// Per-session view counters. Reset on app restart by design — the
  /// "viewed N times without using" gate should count sessions, not
  /// in-session re-mounts (e.g. swiping tabs back and forth).
  final Map<String, int> _sessionViews = {};

  bool _prefsLoaded = false;
  StreamSubscription<User?>? _authSub;

  static String _seenKey(String tipId) => 'seen_tip_$tipId';
  static String _usedKey(String featureId) => 'feature_used_$featureId';

  // ── Public API ────────────────────────────────────────────────────

  /// Preload the SharedPreferences cache. Call once at app boot before
  /// the first frame so [shouldShow] returns synchronously thereafter.
  Future<void> preload() async {
    if (_prefsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final tip in FeatureTipCatalog.all) {
        if (prefs.getBool(_seenKey(tip.id)) == true) {
          _seen[tip.id] = true;
        }
        if (prefs.getBool(_usedKey(tip.requiredFeatureEvent)) == true) {
          _used[tip.requiredFeatureEvent] = true;
        }
      }
    } catch (_) {}
    _prefsLoaded = true;
  }

  bool hasSeen(String tipId) => _seen[tipId] == true;

  /// Returns the tip definition if eligible to show right now, else null.
  /// Increments the per-tip session view counter as a side effect, so
  /// repeated calls advance toward the catalogue's [sessionThreshold].
  ///
  /// Eligibility rules (all must hold):
  ///   1. Tip exists in the catalogue.
  ///   2. Tip has not been marked seen.
  ///   3. The user has not used the targeted feature this device/account.
  ///   4. The host screen has been entered >= sessionThreshold times this
  ///      session without using the feature.
  FeatureTip? shouldShow(String tipId) {
    final tip = FeatureTipCatalog.byId(tipId);
    if (tip == null) return null;
    if (_seen[tipId] == true) return null;
    if (_used[tip.requiredFeatureEvent] == true) return null;
    final views = (_sessionViews[tipId] ?? 0) + 1;
    _sessionViews[tipId] = views;
    if (views < tip.sessionThreshold) return null;
    return tip;
  }

  /// Mark a tip seen. Writes SharedPreferences immediately, Firestore in
  /// background. Idempotent.
  Future<void> markSeen(String tipId) async {
    if (_seen[tipId] == true) return;
    _seen[tipId] = true;
    notifyListeners();
    await _writeLocalSeen(tipId);
    unawaited(_writeSeenToFirestore(tipId));
  }

  /// Mark a feature as used. Suppresses any catalogue tip pointing at this
  /// feature and auto-marks the matching tip(s) as seen. Wire this into
  /// the tap handler of every feature you have a tip for.
  Future<void> markFeatureUsed(String featureId) async {
    if (_used[featureId] == true) return;
    _used[featureId] = true;
    unawaited(AnalyticsService.instance.logFeatureUsed(featureId));

    // Auto-mark every tip that targets this feature as seen — the user
    // found it without help, so don't surface a "did you know" later.
    for (final tip in FeatureTipCatalog.all) {
      if (tip.requiredFeatureEvent == featureId && _seen[tip.id] != true) {
        _seen[tip.id] = true;
        unawaited(_writeLocalSeen(tip.id));
        unawaited(_writeSeenToFirestore(tip.id));
      }
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_usedKey(featureId), true);
    } catch (_) {}
  }

  // ── Internals ─────────────────────────────────────────────────────

  Future<void> _writeLocalSeen(String tipId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey(tipId), true);
    } catch (_) {}
  }

  Future<void> _writeSeenToFirestore(String tipId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'seenTips': {tipId: FieldValue.serverTimestamp()},
        },
        SetOptions(merge: true),
      );
    } catch (e, st) {
      ErrorService.log('feature_tip_seen_write', e, st);
    }
  }

  Future<void> _refreshFromFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      final remoteSeen = data?['seenTips'] as Map<String, dynamic>?;
      if (remoteSeen == null) return;
      var changed = false;
      for (final id in remoteSeen.keys) {
        if (_seen[id] != true) {
          _seen[id] = true;
          changed = true;
          unawaited(_writeLocalSeen(id));
        }
      }
      if (changed) notifyListeners();
    } catch (e, st) {
      ErrorService.log('feature_tip_seen_refresh', e, st);
    }
  }

  /// Test-only reset. Production code never calls this — the singleton
  /// lives for the app lifecycle.
  @visibleForTesting
  void resetForTesting() {
    _seen.clear();
    _used.clear();
    _sessionViews.clear();
    _prefsLoaded = false;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
