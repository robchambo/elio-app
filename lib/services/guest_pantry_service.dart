import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/onboarding_state.dart';

// ─────────────────────────────────────────────
// GuestPantryService
//
// Persists guest onboarding pantry selections to SharedPreferences so
// screens 11 (staples) and 12 (perishables) survive app restarts
// before sign-in. Sprint 16 rebuild: replaces the legacy whole-state
// snapshot with targeted `saveStaples` / `savePerishables` /
// `loadAll` / `clear` methods keyed off of 2-tier (staples) and
// 3-tier (perishables) label maps.
//
// Static legacy helpers (`save`, `load`) are retained for the handful
// of call sites that still exist pre-Task 7.1.
// ─────────────────────────────────────────────

class GuestPantrySnapshot {
  final Map<String, String> staples;
  final Map<String, String> perishables;

  const GuestPantrySnapshot({
    required this.staples,
    required this.perishables,
  });
}

class GuestPantryService {
  static const _legacyKey = 'guest_pantry_v1';
  static const _staplesKey = 'guest_staples';
  static const _perishablesKey = 'guest_perishables';
  static const _householdCountKey = 'guest_household_count';

  /// Persist the guest user's household size locally. Mirrors the
  /// Firestore `users/{uid}.householdCount` field used for signed-in
  /// users (FirestoreService.saveHouseholdCount). 16 May 2026 — added
  /// after Rob hit the household-stepper failure path on the 17 May
  /// build: he’d skipped account creation, so the Firestore write
  /// blew up on a null `currentUser.uid` and the stepper toasted
  /// “Could not save household size” every tap.
  static Future<void> saveHouseholdCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_householdCountKey, count);
  }

  /// Read the guest household size with int / null coercion + clamp +
  /// default-to-2 fallback. Mirrors FirestoreService.getHouseholdCount.
  static Future<int> loadHouseholdCount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_householdCountKey);
    if (raw == null) return 2;
    return raw.clamp(1, 10);
  }

  Future<void> saveStaples(Map<String, String> tiers) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_staplesKey, jsonEncode(tiers));
  }

  Future<void> savePerishables(Map<String, String> tiers) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_perishablesKey, jsonEncode(tiers));
  }

  Future<GuestPantrySnapshot> loadAll() async {
    final p = await SharedPreferences.getInstance();
    return GuestPantrySnapshot(
      staples: _decode(p.getString(_staplesKey)),
      perishables: _decode(p.getString(_perishablesKey)),
    );
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_staplesKey);
    await p.remove(_perishablesKey);
    await p.remove(_legacyKey);
    await p.remove(_householdCountKey);
  }

  Map<String, String> _decode(String? s) => s == null
      ? <String, String>{}
      : Map<String, String>.from(jsonDecode(s) as Map);

  // ─── Legacy helpers retained for pre-Task-7.1 call sites ──────────

  static Future<void> save(OnboardingState state) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'alwaysHave': state.inventory
          .where((i) => i.tier == 'alwaysHave')
          .map((i) => i.name)
          .toList(),
      'almostAlwaysHave': state.inventory
          .where((i) => i.tier == 'almostAlwaysHave')
          .map((i) => i.name)
          .toList(),
      'dietary': state.dietary,
      'allergies': state.allergies,
    };
    await prefs.setString(_legacyKey, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
