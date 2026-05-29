import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe_models.dart';

// ─────────────────────────────────────────────
// HistoryService
// Persists generated recipes locally using shared_preferences.
// Recipes are stored as a JSON list, newest first.
// Max 50 recipes retained (oldest pruned automatically).
//
// Sprint 17 (28 May 2026) — storage key is scoped per account. The
// pre-Sprint-17 single global key `elio_recipe_history` leaked one
// account's saved recipes to the next account signed in on the same
// device: history is device-local (no Firestore mirror yet — v1.2
// backlog) and sign-out only dropped the in-memory cache, not the
// on-disk blob. Scoping by uid gives each account its own blob, so
// account B no longer sees account A's recipes and signing back into A
// restores A's. Guests use a dedicated `…guest` key. The in-memory
// cache is tagged with the key it was built for, so it auto-invalidates
// the moment the signed-in uid changes — no explicit clear needed on
// the auth transition.
// ─────────────────────────────────────────────

class HistoryService {
  /// Pre-Sprint-17 global key. Migrated into the per-account key on the
  /// first read after upgrade, then removed (see [getHistory]).
  static const String _legacyKey = 'elio_recipe_history';
  static const String _keyPrefix = 'elio_recipe_history_';
  static const int _maxRecipes = 50;
  static List<SavedRecipe>? _cache;
  static String? _cacheKey;

  /// Storage key scoped to the current account, or `…guest` when signed
  /// out. Resolved fresh on every access so an auth change is picked up
  /// without a restart.
  static String get _key {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      // Firebase not initialised (e.g. unit tests, or a guest session
      // before init) — fall back to the guest blob.
      uid = null;
    }
    return uid != null ? '$_keyPrefix$uid' : '${_keyPrefix}guest';
  }

  /// Fires after every history mutation. Views that read history
  /// (RecipesTabScreen, Home recents) listen so they refresh when an
  /// auto-saved import lands while they're already mounted — the import
  /// flow uses pushReplacement, which would otherwise prevent the
  /// usual `await Navigator.push(...); _load();` refresh from running.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void _notifyChange() {
    changes.value = changes.value + 1;
  }

  /// Save a recipe to local history. Newest first. Prunes to _maxRecipes.
  static Future<void> saveRecipe(SavedRecipe recipe) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getHistory();
    existing.insert(0, recipe);
    final pruned = existing.take(_maxRecipes).toList();
    final encoded = jsonEncode(pruned.map((r) => r.toJson()).toList());
    await prefs.setString(_key, encoded);
    _cache = null;
    _notifyChange();
  }

  /// Returns all saved recipes for the current account, newest first.
  static Future<List<SavedRecipe>> getHistory() async {
    final key = _key;
    // Cache is tagged with the key it was built for — a uid change
    // (sign-in / sign-out / account switch) changes `key`, so the stale
    // cache is ignored and the right blob is reloaded.
    if (_cache != null && _cacheKey == key) return List.from(_cache!);

    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(key);

    // One-time migration of the pre-Sprint-17 global blob. The first
    // account (or guest) to read after upgrade claims it, then it's
    // removed. Pre-launch there's only ever one real tester per device,
    // so misattribution risk is nil and this preserves existing saved
    // recipes across the key change.
    if (raw == null || raw.isEmpty) {
      final legacy = prefs.getString(_legacyKey);
      if (legacy != null && legacy.isNotEmpty) {
        await prefs.setString(key, legacy);
        await prefs.remove(_legacyKey);
        raw = legacy;
      }
    }

    if (raw == null || raw.isEmpty) {
      _cache = [];
      _cacheKey = key;
      return [];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final result = list
          .map((e) => SavedRecipe.fromJson(e as Map<String, dynamic>))
          .toList();
      _cache = result;
      _cacheKey = key;
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
    _notifyChange();
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
    _notifyChange();
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
    _notifyChange();
  }

  /// Update collections for a recipe by its savedAt timestamp.
  static Future<void> updateCollections(String savedAt, List<String> collections) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getHistory();
    final idx = existing.indexWhere((r) => r.savedAt == savedAt);
    if (idx != -1) {
      existing[idx] = existing[idx].copyWith(collections: collections);
      final encoded = jsonEncode(existing.map((r) => r.toJson()).toList());
      await prefs.setString(_key, encoded);
    }
    _cache = null;
    _notifyChange();
  }

  /// Clear all history including bookmarks.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _cache = null;
    _notifyChange();
  }

  /// Drop the in-memory cache without touching disk.
  ///
  /// AccountService.deleteAccount calls `SharedPreferences.clear()` which
  /// wipes the on-disk `elio_recipe_history` blob, but the static
  /// `_cache` survives the process lifetime — so after a delete-and-
  /// re-onboard the next call to `getHistory()` would return the
  /// pre-deletion recipes from memory. Rob's 21 May 2026 report
  /// against 19may-e: "delete my account ... I then login and it
  /// still has all my recipes there ... so it's not deleted?" Same
  /// stale-cache pattern is the leading suspect for the linked
  /// "saved recipe missing ingredients / instructions" bug from the
  /// same test (stale SavedRecipe object referenced, underlying body
  /// gone after disk wipe).
  ///
  /// Separate from [clearAll] because that touches disk; this is
  /// in-memory only and idempotent. Safe to call from sign-out paths
  /// too.
  static void clearCache() {
    _cache = null;
    _notifyChange();
  }
}
