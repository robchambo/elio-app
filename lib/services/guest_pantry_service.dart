import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/elio_models.dart';
import '../models/onboarding_state.dart';

// ─────────────────────────────────────────────
// GuestPantryService
// Persists guest onboarding data to SharedPreferences so the
// pantry, dietary requirements, and style preferences survive
// app restarts in guest mode.
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
      'stylePreferences': state.stylePreferences,
      'dietaryRequirements':
          state.dietaryRequirements.map((d) => d.name).toList(),
      'customAllergens': state.customAllergens,
      'householdProfiles':
          state.additionalMembers.map((m) => m.toFirestore()).toList(),
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
