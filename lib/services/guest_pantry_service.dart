import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/onboarding_state.dart';

// ─────────────────────────────────────────────
// GuestPantryService
//
// Persists guest onboarding data to SharedPreferences so the pantry
// survives app restarts before the user signs in.
//
// Sprint 16 rebuild: the legacy field set (stylePreferences,
// customAllergens, additionalMembers, dietaryRequirements as enums)
// was removed in Task 0.1. Task 0.4 will flesh this service out with
// `saveStaples`, `savePerishables`, `loadAll`, `clear`. Until then this
// file intentionally keeps a minimal surface that compiles against the
// new `OnboardingState`.
// ─────────────────────────────────────────────

class GuestPantryService {
  static const _key = 'guest_pantry_v1';

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
    await prefs.setString(_key, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
