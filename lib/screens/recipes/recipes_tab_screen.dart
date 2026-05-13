// lib/screens/recipes/recipes_tab_screen.dart
//
// Sprint 16.7c — Saved / History tab split.
//
// Replaces the single-column "two sequential sections" layout with a proper
// TabBar + TabBarView. Saved is the default landing tab (per Rob 12 May
// 2026 — "Saved being left and the default start point"); user can swipe
// or tap to switch to History. Tab labels carry filtered counts so the
// user can spot results in the inactive tab.
//
// Above the tabs, in fixed position so they apply to both tabs:
//   • ElioHeroHeading — "your / recipes" with amber last line + underline
//   • Two ElioBentoCards — Take photo / Manual entry — recipe import
//   • Makeable-now switch — "Show only recipes I can cook now"
//   • TabBar — Saved (N) | History (N)
//
// Body-only (hosted inside ElioAppScaffold via AppShell). Recipes are local
// (HistoryService, SharedPreferences). The pantry side of the makeable-now
// filter uses the user's Firestore inventory (+ always-have / almost-always-
// have fields on the user doc) with EXACT matching — fuzzy is reserved for
// add-item dedup per CLAUDE.md.

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
import '../../widgets/elio/elio_hero_heading.dart';
import '../profile/recipe_import_screen.dart';
import '../recipe/recipe_screen.dart';

const int _kMaxPerSection = 20;

class RecipesTabScreen extends StatefulWidget {
  const RecipesTabScreen({super.key});

  @override
  State<RecipesTabScreen> createState() => _RecipesTabScreenState();
}

class _RecipesTabScreenState extends State<RecipesTabScreen>
    with SingleTickerProviderStateMixin {
  List<SavedRecipe> _all = const [];
  Set<String> _pantryLower = const {};
  bool _makeableOnly = false;
  bool _loading = true;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    bool passes(SavedRecipe r) => !_makeableOnly || _isMakeableNow(r);

    final saved = _all
        .where((r) => r.isBookmarked)
        .where(passes)
        .take(_kMaxPerSection)
        .toList();
    final history = _all.where(passes).take(_kMaxPerSection).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ElioSpacing.screenEdge,
        ElioSpacing.lg,
        ElioSpacing.screenEdge,
        0,
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

          // ── Makeable-now toggle (above tabs so it filters both) ────
          _MakeableSwitch(
            value: _makeableOnly,
            onChanged: (v) => setState(() => _makeableOnly = v),
          ),
          const SizedBox(height: ElioSpacing.md),

          // ── Tab bar with filtered counts in labels ─────────────────
          TabBar(
            controller: _tabController,
            labelColor: ElioColors.terracotta,
            unselectedLabelColor: ElioColors.mocha,
            indicatorColor: ElioColors.terracotta,
            labelStyle: ElioTextStyles.tabLabelStyle,
            unselectedLabelStyle: ElioTextStyles.tabLabelStyle,
            tabs: [
              Tab(text: 'Saved (${saved.length})'),
              Tab(text: 'History (${history.length})'),
            ],
          ),

          // ── Tab content (each tab has its own scroll view) ─────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(
                  saved,
                  emptyText: _makeableOnly
                      ? 'No saved recipes you can cook with your pantry right now.'
                      : "You haven't bookmarked any recipes yet.",
                ),
                _buildList(
                  history,
                  emptyText: _makeableOnly
                      ? 'No history recipes you can cook with your pantry right now.'
                      : 'Recipes you generate will appear here.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<SavedRecipe> recipes, {required String emptyText}) {
    if (recipes.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: ElioSpacing.lg),
        child: _emptyText(emptyText),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        0,
        ElioSpacing.md,
        0,
        ElioSpacing.xxl,
      ),
      itemCount: recipes.length,
      itemBuilder: (_, i) => _buildRecipeCard(recipes[i]),
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
                  // the new bookmark state and the saved/history tabs
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
