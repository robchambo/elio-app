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
  static List<SavedRecipe>? _cache;

  /// Save a recipe to local history. Newest first. Prunes to _maxRecipes.
  static Future<void> saveRecipe(SavedRecipe recipe) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getHistory();
    existing.insert(0, recipe);
    final pruned = existing.take(_maxRecipes).toList();
    final encoded = jsonEncode(pruned.map((r) => r.toJson()).toList());
    await prefs.setString(_key, encoded);
    _cache = null;
  }

  /// Returns all saved recipes, newest first.
  static Future<List<SavedRecipe>> getHistory() async {
    if (_cache != null) return List.from(_cache!);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final result = list
          .map((e) => SavedRecipe.fromJson(e as Map<String, dynamic>))
          .toList();
      _cache = result;
      return List.from(result);
    } catch (_) {
      return [];
    }
  }

  /// Toggle bookmark status for a recipe by its savedAt timestamp.
  static Future<void> toggleBookmark(String savedAt) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getHistory();
    final idx = existing.indexWhere((r) => r.savedAt == savedAt);
    if (idx != -1) {
      existing[idx] = existing[idx].copyWith(isBookmarked: !existing[idx].isBookmarked);
      final encoded = jsonEncode(existing.map((r) => r.toJson()).toList());
      await prefs.setString(_key, encoded);
    }
    _cache = null;
  }

  /// Returns only bookmarked recipes, newest first.
  static Future<List<SavedRecipe>> getBookmarked() async {
    final all = await getHistory();
    return all.where((r) => r.isBookmarked).toList();
  }

  /// Check if a recipe is bookmarked by savedAt.
  static Future<bool> isBookmarked(String savedAt) async {
    final all = await getHistory();
    final match = all.where((r) => r.savedAt == savedAt);
    return match.isNotEmpty && match.first.isBookmarked;
  }

  /// Delete a single recipe by its savedAt timestamp (used as unique ID).
  static Future<void> deleteRecipe(String savedAt) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getHistory();
    existing.removeWhere((r) => r.savedAt == savedAt);
    final encoded = jsonEncode(existing.map((r) => r.toJson()).toList());
    await prefs.setString(_key, encoded);
    _cache = null;
  }

  /// Clear all non-bookmarked history.
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getHistory();
    final bookmarked = existing.where((r) => r.isBookmarked).toList();
    if (bookmarked.isEmpty) {
      await prefs.remove(_key);
    } else {
      final encoded = jsonEncode(bookmarked.map((r) => r.toJson()).toList());
      await prefs.setString(_key, encoded);
    }
    _cache = null;
  }

  /// Clear all history including bookmarks.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _cache = null;
  }
}
