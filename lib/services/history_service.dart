import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe_models.dart';

// ─────────────────────────────────────────────
// HistoryService
// Persists generated recipes locally using shared_preferences.
// Recipes are stored as a JSON list, newest first.
// Max 50 recipes retained (oldest pruned automatically).
// ─────────────────────────────────────────────

class HistoryService {
  static const String _key = 'elio_recipe_history';
  static const int _maxRecipes = 50;

  /// Save a recipe to local history. Newest first. Prunes to _maxRecipes.
  static Future<void> saveRecipe(SavedRecipe recipe) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getHistory();
    existing.insert(0, recipe);
    final pruned = existing.take(_maxRecipes).toList();
    final encoded = jsonEncode(pruned.map((r) => r.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  /// Returns all saved recipes, newest first.
  static Future<List<SavedRecipe>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedRecipe.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete a single recipe by its savedAt timestamp (used as unique ID).
  static Future<void> deleteRecipe(String savedAt) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getHistory();
    existing.removeWhere((r) => r.savedAt == savedAt);
    final encoded = jsonEncode(existing.map((r) => r.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  /// Clear all history.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
