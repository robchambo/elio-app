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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onQueryChanged);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    if (_searchController.text != _query) {
      setState(() => _query = _searchController.text);
    }
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

  /// Case-insensitive substring match across title, description,
  /// ingredient names, and dietary tags. Empty query matches everything.
  bool _matchesQuery(SavedRecipe saved) {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return true;
    final r = saved.recipe;
    if (r.title.toLowerCase().contains(q)) return true;
    if (r.description.toLowerCase().contains(q)) return true;
    for (final ing in r.ingredients) {
      if (ing.name.toLowerCase().contains(q)) return true;
    }
    for (final tag in r.dietaryTags) {
      if (tag.toLowerCase().contains(q)) return true;
    }
    return false;
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
  //
  // Layout: NestedScrollView so the hero / import bentos / search / makeable
  // toggle all scroll AWAY as the user scrolls up, leaving only the tab bar
  // pinned at the top. The previous Padding > Column > Expanded(TabBarView)
  // layout left only ~250-300px for recipe content on a typical phone, which
  // showed ~one recipe at a time. NestedScrollView lifts that ceiling.
  //
  // SliverOverlapAbsorber + SliverOverlapInjector pair handles the inner-
  // scroll position correctly when swiping between tabs (without it the body
  // can jump on tab change).
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    bool passes(SavedRecipe r) =>
        (!_makeableOnly || _isMakeableNow(r)) && _matchesQuery(r);

    // No render cap. Pro history is server-capped at 50, free at 20 — a
    // few flicks of the thumb. Capping client-side here was confusing:
    // the count label and the visible list could both top out at 20
    // even when the underlying filtered set was different (toggle on/
    // off both showed "(20)"). Removed 13 May 2026.
    final saved = _all.where((r) => r.isBookmarked).where(passes).toList();
    final history = _all.where(passes).toList();

    final tabBar = TabBar(
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
    );

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverOverlapAbsorber(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ElioSpacing.screenEdge,
              ElioSpacing.lg,
              ElioSpacing.screenEdge,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const ElioHeroHeading(
                  lines: ['your', 'recipes'],
                  amberLastLine: true,
                  showUnderline: true,
                ),
                const SizedBox(height: ElioSpacing.xl),

                // ── Import tiles (mirrors Pantry tab) ──────────────
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

                // ── Search field (filters both tabs; lifts the 20-cap)
                _SearchField(controller: _searchController),
                const SizedBox(height: ElioSpacing.md),

                // ── Makeable-now toggle (filters both tabs) ────────
                _MakeableSwitch(
                  value: _makeableOnly,
                  onChanged: (v) => setState(() => _makeableOnly = v),
                ),
                const SizedBox(height: ElioSpacing.md),
              ]),
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(tabBar: tabBar),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(
            saved,
            emptyText: _makeableOnly
                ? 'No saved recipes you can cook with your pantry right now.'
                : "You haven't bookmarked any recipes yet.",
            storageKey: 'recipes-tab-saved',
          ),
          _buildTabContent(
            history,
            emptyText: _makeableOnly
                ? 'No history recipes you can cook with your pantry right now.'
                : 'Recipes you generate will appear here.',
            storageKey: 'recipes-tab-history',
          ),
        ],
      ),
    );
  }

  /// Inner scroll view per tab. Wrapped in a Builder so each tab has its
  /// own BuildContext for [NestedScrollView.sliverOverlapAbsorberHandleFor].
  /// PageStorageKey preserves scroll position when swiping between tabs.
  Widget _buildTabContent(
    List<SavedRecipe> recipes, {
    required String emptyText,
    required String storageKey,
  }) {
    return Builder(
      builder: (context) {
        return CustomScrollView(
          key: PageStorageKey<String>(storageKey),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            if (recipes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ElioSpacing.screenEdge,
                    ElioSpacing.lg,
                    ElioSpacing.screenEdge,
                    0,
                  ),
                  child: _emptyText(emptyText),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  ElioSpacing.screenEdge,
                  ElioSpacing.md,
                  ElioSpacing.screenEdge,
                  ElioSpacing.xxl,
                ),
                sliver: SliverList.builder(
                  itemCount: recipes.length,
                  itemBuilder: (_, i) => _buildRecipeCard(recipes[i]),
                ),
              ),
          ],
        );
      },
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

/// SliverPersistentHeaderDelegate that keeps the [TabBar] pinned at
/// the top of the [NestedScrollView] body once the hero / bento /
/// search / makeable header content has scrolled away. Solid cream
/// background so recipe cards scrolling beneath the bar are obscured
/// (without it, text would visibly bleed through the bar).
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate({required this.tabBar});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: ElioColors.cream,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}

/// Cream-deep search field with magnifier prefix and a clear (×)
/// suffix that appears once the user has typed. Filters both the
/// Saved and History tabs in real time; the tab labels carry counts
/// so the user can see results in the inactive tab.
///
/// Restored 12 May 2026 (Sprint 16.7c) after Sprint 16.4 Bug 6 had
/// removed it as "noise on a tab whose only purpose is to find a
/// saved or recently generated recipe." Reversed call: when the
/// recipe library scales, search is the primary affordance to find
/// the one you want.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ElioColors.creamDeep,
        borderRadius: BorderRadius.circular(ElioRadii.input),
      ),
      child: TextField(
        controller: controller,
        style: ElioTextStyles.bodyStyle,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search recipes…',
          hintStyle:
              ElioTextStyles.bodyStyle.copyWith(color: ElioColors.mocha),
          prefixIcon:
              const Icon(Icons.search_rounded, color: ElioColors.mocha),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: ElioColors.mocha),
                onPressed: controller.clear,
                tooltip: 'Clear search',
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: ElioSpacing.md,
            vertical: ElioSpacing.sm,
          ),
        ),
      ),
    );
  }
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
