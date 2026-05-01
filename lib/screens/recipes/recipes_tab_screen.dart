// lib/screens/recipes/recipes_tab_screen.dart
//
// Sprint 16 Phase 6 — standalone Recipe Book tab.
//
// Body-only (hosted inside ElioAppScaffold via AppShell). Replaces the legacy
// Recipe Book tab that previously lived inside ProfileScreen. Structure
// follows the V1 user flow + Sprint 16.3 polish (mirror the Pantry tab's
// two-tile lead-in):
//   • ElioHeroHeading — "your / recipes" with amber last line + underline
//   • Two ElioBentoCards — Take photo / Paste a URL — mirroring the Pantry
//     tab's Scan receipt / Scan barcode pair.
//   • Search Everything field (filters title / description / ingredient / tag)
//   • Pantry Availability switch — "Show only recipes I can cook now"
//   • Saved section (eyebrow header) — bookmarked recipes
//   • History section (eyebrow header) — all recent recipes
//
// Recipes are local (HistoryService, SharedPreferences). The pantry side of
// the makeable-now filter uses the user's Firestore inventory (+ always have /
// almost always have fields on the user doc) with EXACT matching — fuzzy is
// reserved for add-item dedup per CLAUDE.md.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/recipe_models.dart';
import '../../services/firestore_service.dart';
import '../../services/history_service.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_bento_card.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../profile/recipe_import_screen.dart';
import '../recipe/recipe_screen.dart';

const int _kMaxPerSection = 20;

class RecipesTabScreen extends StatefulWidget {
  const RecipesTabScreen({super.key});

  @override
  State<RecipesTabScreen> createState() => _RecipesTabScreenState();
}

class _RecipesTabScreenState extends State<RecipesTabScreen> {
  List<SavedRecipe> _all = const [];
  Set<String> _pantryLower = const {};
  bool _makeableOnly = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await HistoryService.getHistory();
    final pantry = await _loadPantryNames();
    if (!mounted) return;
    setState(() {
      _all = all;
      _pantryLower = pantry;
      _loading = false;
    });
  }

  /// Build a lowercased set of pantry item names (alwaysHave +
  /// almostAlwaysHave + perishables in inventory) to compare against
  /// recipe ingredient names. Exact match only — fuzzy is reserved for
  /// add-item dedup per CLAUDE.md.
  Future<Set<String>> _loadPantryNames() async {
    try {
      final userData = await FirestoreService().getUserData();
      final alwaysHave = List<String>.from(userData['alwaysHave'] ?? []);
      final almostAlwaysHave =
          List<String>.from(userData['almostAlwaysHave'] ?? []);
      final inventoryWithIds = List<Map<String, dynamic>>.from(
        (userData['inventoryWithIds'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>),
      );
      final inventoryNames = inventoryWithIds
          .map((i) => i['name'] as String? ?? '')
          .where((n) => n.isNotEmpty);
      return {
        ...alwaysHave.map((s) => s.toLowerCase().trim()),
        ...almostAlwaysHave.map((s) => s.toLowerCase().trim()),
        ...inventoryNames.map((s) => s.toLowerCase().trim()),
      }..removeWhere((s) => s.isEmpty);
    } catch (_) {
      return const {};
    }
  }

  /// Every ingredient must have an exact lowercased match in the pantry
  /// set. An empty ingredient list is trivially makeable; an empty pantry
  /// is never.
  bool _isMakeableNow(SavedRecipe saved) {
    final ingredients = saved.recipe.ingredients;
    if (ingredients.isEmpty) return true;
    if (_pantryLower.isEmpty) return false;
    return ingredients.every((ing) {
      final name = ing.name.toLowerCase().trim();
      return _pantryLower.contains(name);
    });
  }

  // ── Actions ────────────────────────────────────────────────────────
  Future<void> _openRecipe(SavedRecipe saved) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RecipeScreen(recipe: saved.recipe, savedAt: saved.savedAt),
      ),
    );
    // Refresh on return in case bookmark state changed.
    _load();
  }

  Future<void> _openImport({int initialTab = 0}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeImportScreen(initialTab: initialTab),
      ),
    );
    _load();
  }

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // The makeable-now toggle was restored 2026-04-30 after a family
    // tester missed it. Search field + category chip row stay removed
    // (Sprint 16.4 Bug 6) — they were noise on a tab whose only purpose
    // is to find a saved or recently generated recipe.
    bool passes(SavedRecipe r) => !_makeableOnly || _isMakeableNow(r);

    final saved = _all
        .where((r) => r.isBookmarked)
        .where(passes)
        .take(_kMaxPerSection)
        .toList();
    final history = _all.where(passes).take(_kMaxPerSection).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ElioSpacing.screenEdge,
        ElioSpacing.lg,
        ElioSpacing.screenEdge,
        ElioSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ElioHeroHeading(
            lines: ['your', 'recipes'],
            amberLastLine: true,
            showUnderline: true,
          ),
          const SizedBox(height: ElioSpacing.xl),

          // ── Import tiles (mirrors Pantry tab) ──────────────────────
          Row(
            children: [
              Expanded(
                child: ElioBentoCard(
                  icon: Icons.photo_camera_outlined,
                  kicker: 'Photo Or Camera',
                  title: 'Take Photo',
                  iconBackgroundColor: ElioColors.peach,
                  onTap: () => _openImport(initialTab: 0),
                ),
              ),
              const SizedBox(width: ElioSpacing.lg),
              Expanded(
                child: ElioBentoCard(
                  icon: Icons.link_rounded,
                  kicker: 'URL Or Text',
                  title: 'Manual Entry',
                  iconBackgroundColor: const Color(0xFFF5C26B),
                  onTap: () => _openImport(initialTab: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: ElioSpacing.xl),

          // ── Makeable-now toggle ────────────────────────────────────
          _MakeableSwitch(
            value: _makeableOnly,
            onChanged: (v) => setState(() => _makeableOnly = v),
          ),
          const SizedBox(height: ElioSpacing.lg),

          // ── Saved ──────────────────────────────────────────────────
          const ElioEyebrow('saved'),
          const SizedBox(height: ElioSpacing.sm),
          if (saved.isEmpty)
            _emptyText(_makeableOnly
                ? 'No saved recipes you can cook with your pantry right now.'
                : "You haven't bookmarked any recipes yet.")
          else
            ...saved.map(_buildRecipeCard),

          const SizedBox(height: ElioSpacing.lg),

          // ── History ────────────────────────────────────────────────
          const ElioEyebrow('history'),
          const SizedBox(height: ElioSpacing.sm),
          if (history.isEmpty)
            _emptyText(_makeableOnly
                ? 'No history recipes you can cook with your pantry right now.'
                : 'Recipes you generate will appear here.')
          else
            ...history.map(_buildRecipeCard),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(SavedRecipe saved) {
    final r = saved.recipe;
    final subtitle = r.description.isNotEmpty
        ? r.description
        : '${r.totalTimeMinutes} min · ${r.servings} servings';
    return Padding(
      padding: const EdgeInsets.only(bottom: ElioSpacing.sm),
      child: InkWell(
        onTap: () => _openRecipe(saved),
        borderRadius: BorderRadius.circular(ElioRadii.card),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ElioColors.creamDeep,
            borderRadius: BorderRadius.circular(ElioRadii.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: ElioTextStyles.uiLabelStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: ElioTextStyles.bodySmallStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await HistoryService.toggleBookmark(saved.savedAt);
                  if (!mounted) return;
                  // Reload history only (not pantry) so the icon reflects
                  // the new bookmark state and the saved/history sections
                  // re-partition.
                  final updated = await HistoryService.getHistory();
                  if (!mounted) return;
                  setState(() => _all = updated);
                },
                child: Padding(
                  // CLAUDE.md: 48px touch target on bare GestureDetectors.
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    saved.isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                    color: saved.isBookmarked
                        ? ElioColors.terracotta
                        : ElioColors.mocha,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyText(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: ElioSpacing.md),
        child: Text(text, style: ElioTextStyles.bodySmallStyle),
      );
}

/// Cream-deep panel + terracotta switch — toggles the makeable-now
/// filter. Restored 2026-04-30 after a family tester missed it.
class _MakeableSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MakeableSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ElioSpacing.md,
        vertical: ElioSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: ElioColors.creamDeep,
        borderRadius: BorderRadius.circular(ElioRadii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Show only recipes I can cook now',
              style: ElioTextStyles.uiLabelStyle,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: ElioColors.terracotta,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: ElioColors.rule,
          ),
        ],
      ),
    );
  }
}

