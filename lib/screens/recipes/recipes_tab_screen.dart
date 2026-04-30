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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await HistoryService.getHistory();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loading = false;
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

    // TODO(Bug 6 / Sprint 16.4): Filters removed (search field, makeable-now
    // pantry switch, category chips). Revisit after launch — likely re-add as
    // a single unified search + saved/history split, but only once we know
    // what users actually need from this surface.
    final saved = _all
        .where((r) => r.isBookmarked)
        .take(_kMaxPerSection)
        .toList();
    final history = _all.take(_kMaxPerSection).toList();

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
                  kicker: 'From a photo',
                  title: 'Take photo',
                  onTap: () => _openImport(initialTab: 0),
                ),
              ),
              const SizedBox(width: ElioSpacing.lg),
              Expanded(
                child: ElioBentoCard(
                  icon: Icons.link_rounded,
                  kicker: 'URL or text',
                  title: 'Manual entry',
                  onTap: () => _openImport(initialTab: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: ElioSpacing.xl),

          // ── Saved ──────────────────────────────────────────────────
          const ElioEyebrow('saved'),
          const SizedBox(height: ElioSpacing.sm),
          if (saved.isEmpty)
            _emptyText("You haven't bookmarked any recipes yet.")
          else
            ...saved.map(_buildRecipeCard),

          const SizedBox(height: ElioSpacing.lg),

          // ── History ────────────────────────────────────────────────
          const ElioEyebrow('history'),
          const SizedBox(height: ElioSpacing.sm),
          if (history.isEmpty)
            _emptyText('Recipes you generate will appear here.')
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

