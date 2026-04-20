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
