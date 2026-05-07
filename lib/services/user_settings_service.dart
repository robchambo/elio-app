// lib/services/user_settings_service.dart
//
// Sprint 16.1 — single source of truth for dietary requirements +
// custom allergens, plus the household profile list that recipe
// generation unions across.
//
// Why this exists: dietary/allergens used to be cached on HomeScreen
// in a `_householdProfiles` list populated once in initState. HomeScreen
// lives forever inside AppShell's `const`-children PageView and never
// remounts, so any in-app edit on the Settings → Dietary screen was
// invisible to the next recipe generation until the app was killed.
// Multiple writers (onboarding, migration, dietary screen) also wrote
// the same logical setting to two different Firestore locations with
// drifting field names, hiding bugs behind defensive fallbacks.
//
// This service makes the canonical store explicit:
//
//   • Firestore: users/{uid}/profiles/{owner}.dietaryRequirements
//                users/{uid}/profiles/{owner}.allergies
//   • In-process: a ChangeNotifier singleton that every consumer
//     (HomeScreen, recipe regeneration, future filters) listens to.
//
// Flow:
//   1. Auth state changes → refresh() reads /profiles/* from server,
//      builds householdProfiles, notifies listeners.
//   2. Dietary screen save → calls refresh() after the verify-after-
//      save check passes → listeners rebuild.
//   3. Recipe generation reads dietaryRequirements / allergies from
//      this singleton (not from a frozen request snapshot).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'error_service.dart';

class UserSettingsService extends ChangeNotifier {
  // ── Canonical-case normalisation ─────────────────────────────────
  //
  // Sprint 16.1 case-mismatch fix.
  //
  // Onboarding screen 04 (`screen04_dietary.dart`) writes dietary
  // tokens in lowercase: 'vegetarian', 'vegan', 'pescatarian', 'halal',
  // 'kosher', 'none'. The Settings → Dietary screen
  // (`dietary_screen.dart`) — which is the canonical UI — uses
  // TitleCase IDs: 'Vegetarian', 'Vegan', 'Pescatarian', 'Halal',
  // 'Kosher'. Without normalisation, an onboarding-set Vegetarian
  // doesn't appear pre-selected in Settings (case-sensitive
  // `.contains()`), so the user can't deselect it.
  //
  // We canonicalise to the Settings-screen TitleCase form on read.
  // Already-TitleCase values (e.g. 'Nut-free') and the 'none'
  // sentinel pass through unchanged. The `'none'` sentinel is then
  // stripped separately inside refresh().
  //
  // When users next save via the Settings dietary screen, the doc
  // gets rewritten in TitleCase, organically migrating any legacy
  // lowercase data forward.
  static const Map<String, String> _dietaryCanonicalCase = {
    'vegetarian': 'Vegetarian',
    'vegan': 'Vegan',
    'pescatarian': 'Pescatarian',
    'halal': 'Halal',
    'kosher': 'Kosher',
  };

  /// Map a single dietary token to its canonical case. Pass-through
  /// for unknown keys (e.g. 'Nut-free', 'Gluten-free') and the
  /// 'none' sentinel.
  static String canonicaliseDietaryToken(String raw) {
    final mapped = _dietaryCanonicalCase[raw.toLowerCase().trim()];
    return mapped ?? raw;
  }

  /// Canonicalise + de-dupe a list of dietary tokens. Preserves order
  /// of first occurrence after canonicalisation.
  static List<String> canonicaliseDietaryList(Iterable<String> raws) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in raws) {
      final c = canonicaliseDietaryToken(raw);
      if (seen.add(c)) out.add(c);
    }
    return out;
  }

  UserSettingsService._() {
    // Auto-refresh on every auth-state transition. New sign-in or
    // sign-out triggers a clean re-read or a clear.
    //
    // Guarded against widget-test environments where Firebase isn't
    // initialised — accessing FirebaseAuth.instance throws at
    // platform-channel time. The catch ensures the singleton is
    // usable in tests; refresh() is also resilient.
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user == null) {
          _clearInPlace();
        } else {
          // Fire-and-forget; consumers will be notified when refresh
          // completes. Errors are swallowed inside refresh().
          refresh();
        }
      });
    } catch (_) {
      // Firebase not initialised (typically widget tests). Singleton
      // stays in its empty default state; no auto-refresh.
    }
  }

  static final UserSettingsService instance = UserSettingsService._();

  // ── State ─────────────────────────────────────────────────────────

  /// Dietary requirements union'd across all household profiles
  /// (canonical source: each profile's `dietaryRequirements` field).
  /// Empty when signed out or before the first refresh.
  List<String> _dietaryRequirements = const [];
  List<String> get dietaryRequirements => _dietaryRequirements;

  /// Custom allergens union'd across all household profiles
  /// (canonical source: each profile's `allergies` field).
  List<String> _allergies = const [];
  List<String> get allergies => _allergies;

  /// Full per-profile list with the same shape FirestoreService.getUserData
  /// produced in `_householdProfiles`. Each entry: {id, name, dietaryRequirements,
  /// allergens, isOwner}. HomeScreen consumes this for any screen that needs
  /// per-profile detail (e.g. household-member toggling).
  List<Map<String, dynamic>> _householdProfiles = const [];
  List<Map<String, dynamic>> get householdProfiles => _householdProfiles;

  /// True after the first successful refresh in the current session.
  /// Lets consumers skip rendering empty defaults during the brief
  /// window before refresh completes.
  bool _hydrated = false;
  bool get hydrated => _hydrated;

  StreamSubscription<User?>? _authSub;

  // ── Public API ────────────────────────────────────────────────────

  /// Re-read dietary + allergens from `users/{uid}/profiles/*`. Source
  /// is the server (not local cache) so a silent server-side denial on
  /// a recent write surfaces as stale data rather than the cached optimistic
  /// value. Notifies listeners when the read completes.
  ///
  /// Errors are logged + swallowed — the next call retries. Consumers
  /// should treat unhydrated state (empty lists) as "no signal" rather
  /// than "user has no preferences".
  Future<void> refresh() async {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      // Firebase not initialised (widget tests). Skip silently.
      return;
    }
    if (uid == null) {
      _clearInPlace();
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profiles')
          .get(const GetOptions(source: Source.server));

      final profiles = <Map<String, dynamic>>[];
      final dietarySet = <String>{};
      final allergenSet = <String>{};

      for (final doc in snap.docs) {
        final data = doc.data();
        // Canonical field name is `allergies`; legacy data may have
        // landed at `customAllergens`. Prefer `allergies`, fall back
        // for back-compat. Will be removed once telemetry confirms
        // no `customAllergens` reads in the wild.
        final allergens = List<String>.from(
          (data['allergies'] as List?) ??
              (data['customAllergens'] as List?) ??
              const <dynamic>[],
        );
        // Sprint 16.1: filter the `none` sentinel that onboarding
        // screen 4 ("Happy with anything") writes to mean
        // "no dietary restrictions". It's a UX flag, not an actual
        // restriction — leaving it in the list would render a literal
        // "none" pill on the prefs screen and pollute the Gemini
        // prompt with "Dietary: none — strictly enforced." Drop it
        // here so every consumer sees a clean empty list instead.
        //
        // Sprint 16.1 case fix: also canonicalise lowercase dietary
        // tokens written by onboarding ('vegetarian' → 'Vegetarian')
        // so the Settings → Dietary screen's case-sensitive .contains
        // check pre-selects them and they can be deselected.
        final dietary = canonicaliseDietaryList(
          List<String>.from(
            (data['dietaryRequirements'] as List?) ?? const <dynamic>[],
          ).where((s) => s.toLowerCase() != 'none'),
        );

        profiles.add({
          'id': doc.id,
          'name': data['name'] as String? ?? 'Member',
          'dietaryRequirements': dietary,
          'allergens': allergens,
          'allergies': allergens,
          'isOwner': data['isOwner'] as bool? ?? false,
        });

        // Union for the simple getters. Recipe-generation paths union
        // across active profiles via the screen-level deactivation
        // logic; for the lite getters here, all profiles count.
        dietarySet.addAll(dietary);
        allergenSet.addAll(allergens.where((s) => s.trim().isNotEmpty));
      }

      _householdProfiles = profiles;
      _dietaryRequirements = dietarySet.toList();
      _allergies = allergenSet.toList();
      _hydrated = true;
      notifyListeners();
    } catch (e, st) {
      ErrorService.log('user_settings_refresh', e, st);
    }
  }

  /// Empty everything + notify. Called on sign-out so the next user's
  /// stale data isn't briefly visible during the auth transition.
  void clearForSignOut() {
    _clearInPlace();
  }

  void _clearInPlace() {
    _dietaryRequirements = const [];
    _allergies = const [];
    _householdProfiles = const [];
    _hydrated = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
