import 'package:flutter/material.dart';

import '../../models/recipe_models.dart';
import '../../services/analytics_service.dart';
import '../../services/gemini_service.dart';
import '../../services/history_service.dart';
import '../../services/user_settings_service.dart';
import '../../utils/friendly_error.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../recipe/recipe_screen.dart';

/// Shows the results of a bulk prep generation session.
/// Displays 1-3 recipe cards that the user can tap to view in full.
///
/// Sprint 16.6 row 3: each card has a per-meal refresh icon (top-right)
/// that re-rolls just that meal via [GeminiService.generateBulkRecipeStream],
/// keeping the other meals untouched. Mirrors `MealPlanScreen._regenerateMeal`
/// 1:1 in pattern (Sprint 16.1 dietary refresh, dedup against other titles,
/// snackbar on failure, keep both old + new in history).
class BulkPrepResultsScreen extends StatefulWidget {
  final List<GeneratedRecipe> recipes;
  final RecipeGenerationRequest? originalRequest;
  final bool isGuest;

  const BulkPrepResultsScreen({
    super.key,
    required this.recipes,
    this.originalRequest,
    this.isGuest = false,
  });

  @override
  State<BulkPrepResultsScreen> createState() => _BulkPrepResultsScreenState();
}

class _BulkPrepResultsScreenState extends State<BulkPrepResultsScreen> {
  final AnalyticsService _analytics = AnalyticsService.instance;

  /// Local mutable copy of the batch — per-card regen replaces an entry
  /// in this list and rebuilds.
  late List<GeneratedRecipe> _recipes;

  /// Indices of meal cards currently regenerating. Disables the card tap
  /// and the refresh button while in flight to prevent double-fire.
  final Set<int> _regenerating = <int>{};

  @override
  void initState() {
    super.initState();
    _recipes = List<GeneratedRecipe>.from(widget.recipes);
  }

  /// Whether per-meal regen is available. Older saved bulk recipes opened
  /// from history won't have an [originalRequest] envelope — without it
  /// we can't rebuild a generation request, so the icon is hidden.
  bool get _canRegenerate => widget.originalRequest != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.ac_unit_rounded,
                  size: 18,
                  color: ElioColors.terracotta,
                ),
                const SizedBox(width: 6),
                Text('Bulk cook', style: ElioText.headingMedium),
              ],
            ),
            Text(
              _subtitleText(),
              style: ElioText.label.copyWith(
                color: ElioColors.mocha,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              itemCount: _recipes.length,
              itemBuilder: (context, index) {
                final isRegenerating = _regenerating.contains(index);
                return _RecipeCard(
                  recipe: _recipes[index],
                  mealNumber: index + 1,
                  bulkPrepInfo: _recipes[index].bulkPrepInfo,
                  isRegenerating: isRegenerating,
                  // Hide the icon when we can't regen (no originalRequest)
                  // so the slot doesn't show a dead button.
                  onRegenerate: _canRegenerate && !isRegenerating
                      ? () => _regenerateMeal(index)
                      : null,
                  onTap: isRegenerating
                      ? null
                      : () => _openRecipe(_recipes[index]),
                );
              },
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  String _subtitleText() {
    final mealCount = _recipes.length;
    final mealWord = mealCount == 1 ? 'meal' : 'meals';
    if (_recipes.isNotEmpty) {
      final portions = _recipes.first.servings;
      return '$mealCount $mealWord · $portions portions each';
    }
    return '$mealCount $mealWord';
  }

  void _openRecipe(GeneratedRecipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeScreen(
          recipe: recipe,
          originalRequest: widget.originalRequest,
          isGuest: widget.isGuest,
        ),
      ),
    );
  }

  /// Re-rolls a single meal in the batch via the bulk generation stream.
  /// Mirrors [MealPlanScreen._regenerateMeal]:
  ///   * Sprint 16.1 pattern — refresh dietary/allergens from server first
  ///     so an edit since this batch was generated is honoured.
  ///   * Dedup against all OTHER meals in the batch so the replacement is
  ///     meaningfully different. (The replaced title is intentionally NOT
  ///     in the dedup list — a close variant is fine.)
  ///   * Keeps both old + new in history (matches meal planner).
  ///   * Disables the card tap + refresh button while in flight.
  Future<void> _regenerateMeal(int index) async {
    final request = widget.originalRequest;
    if (request == null) return;
    if (_regenerating.contains(index)) return;

    setState(() => _regenerating.add(index));

    try {
      // Sprint 16.1: pick up any dietary edits since the batch was generated.
      await UserSettingsService.instance.refresh();

      // Dedup against the other meals — not the one being replaced.
      final otherTitles = <String>[
        for (int i = 0; i < _recipes.length; i++)
          if (i != index) _recipes[i].title,
      ];

      GeneratedRecipe? replacement;
      String? errorMsg;
      await for (final status in GeminiService.generateBulkRecipeStream(
        request,
        portions: _recipes[index].servings,
        mealNumber: index + 1,
        totalMeals: _recipes.length,
        previousMealTitles: otherTitles,
      )) {
        if (!mounted) return;
        switch (status) {
          case RecipeGenerating():
            break;
          case RecipeComplete():
            replacement = status.recipe;
          case RecipeError():
            errorMsg = status.message;
        }
      }

      if (errorMsg != null) {
        throw Exception(errorMsg);
      }
      if (replacement == null) {
        throw Exception('Bulk cook regeneration returned no recipe.');
      }
      if (!mounted) return;

      setState(() {
        final updated = List<GeneratedRecipe>.from(_recipes);
        updated[index] = replacement!;
        _recipes = updated;
      });

      // Save the replacement to history with a fresh timestamp. The
      // previous one stays — matches meal planner behaviour.
      HistoryService.saveRecipe(SavedRecipe(
        recipe: replacement,
        savedAt: DateTime.now().toUtc().toIso8601String(),
      ));

      _analytics.logEvent('bulk_prep_meal_regenerated', {
        'meal_number': index + 1,
        'total_meals': _recipes.length,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          backgroundColor: ElioColors.espresso,
        ),
      );
    } finally {
      if (mounted) setState(() => _regenerating.remove(index));
    }
  }
  // 14 May 2026 (Notion XX-2 #2/#3): local `_friendlyError` helper
  // promoted to a shared `lib/utils/friendly_error.dart`. Now used
  // across every Gemini error surface in the app (recipe gen, bulk
  // regen, side dish, meal plan, recipe import). Also strips the
  // Gemini API key from any URL embedded in exception text — Kate's
  // 14 May screenshot showed the key visible in the in-app error.

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: ElioColors.mocha.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              'Recipes saved to your history',
              style: ElioText.bodyMedium.copyWith(
                color: ElioColors.mocha.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recipe card ──────────────────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  final GeneratedRecipe recipe;
  final int mealNumber;
  final BulkPrepInfo? bulkPrepInfo;
  final bool isRegenerating;

  /// Null when regen isn't available (no originalRequest) — the refresh
  /// button is hidden entirely in that case.
  final VoidCallback? onRegenerate;

  /// Null while [isRegenerating] is true — disables opening a half-stale
  /// recipe mid-regen.
  final VoidCallback? onTap;

  const _RecipeCard({
    required this.recipe,
    required this.mealNumber,
    required this.bulkPrepInfo,
    required this.isRegenerating,
    required this.onRegenerate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: ElioColors.cream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ElioColors.rule),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meal chip + refresh icon row — matches the meal planner's
              // per-slot regen affordance (meal_plan_screen.dart ~L1018).
              Row(
                children: [
                  _buildMealChip(),
                  const Spacer(),
                  if (onRegenerate != null) _RegenerateButton(
                    isRegenerating: isRegenerating,
                    onTap: isRegenerating ? null : onRegenerate,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Notion XX-2 B4 (Rob 13 May 2026): during regen, swap
              // the title/description/meta block for skeleton blocks +
              // a tiny "Re-rolling…" label. Previously only the 32×32
              // refresh button changed (spinner), which Rob reported
              // as "looks like nothing's working". The card body
              // skeleton makes the whole card visibly active.
              if (isRegenerating) ..._regeneratingBody() else ..._normalBody(),
            ],
          ),
        ),
      ),
    );
  }

  /// Recipe content as normally rendered (title / description / meta / storage).
  List<Widget> _normalBody() => [
        Text(recipe.title, style: ElioText.headingMedium),
        if (recipe.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            recipe.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ElioText.bodyMedium.copyWith(
              color: ElioColors.mocha,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildMetaRow(),
        if (bulkPrepInfo != null && bulkPrepInfo!.storageLife.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildStorageRow(),
        ],
      ];

  /// Skeleton placeholders while [isRegenerating] is true. Matches the
  /// shape of [_normalBody] so the card height doesn't jump when the
  /// real recipe lands.
  List<Widget> _regeneratingBody() => [
        Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                color: ElioColors.terracotta,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Re-rolling this meal…',
              style: ElioText.label.copyWith(
                color: ElioColors.mocha,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Title placeholder
        _skeletonBar(height: 22, widthFraction: 0.7),
        const SizedBox(height: 8),
        // Description placeholders (two lines)
        _skeletonBar(height: 14, widthFraction: 1.0),
        const SizedBox(height: 6),
        _skeletonBar(height: 14, widthFraction: 0.6),
        const SizedBox(height: 14),
        // Meta-chip placeholders
        Row(
          children: [
            _skeletonChip(width: 76),
            const SizedBox(width: 8),
            _skeletonChip(width: 80),
            const SizedBox(width: 8),
            _skeletonChip(width: 92),
          ],
        ),
      ];

  Widget _skeletonBar({required double height, required double widthFraction}) {
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height: height,
        width: constraints.maxWidth * widthFraction,
        decoration: BoxDecoration(
          color: ElioColors.rule.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _skeletonChip({required double width}) {
    return Container(
      height: 24,
      width: width,
      decoration: BoxDecoration(
        color: ElioColors.rule.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildMealChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ElioColors.terracotta.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Meal $mealNumber',
        style: ElioText.label.copyWith(
          color: ElioColors.terracotta,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildMetaRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetaChip(
          icon: Icons.timer_outlined,
          label: '${recipe.prepTimeMinutes}m prep',
        ),
        _MetaChip(
          icon: Icons.local_fire_department_outlined,
          label: '${recipe.cookTimeMinutes}m cook',
        ),
        _MetaChip(
          icon: Icons.restaurant_outlined,
          label: '${recipe.servings} servings',
        ),
      ],
    );
  }

  Widget _buildStorageRow() {
    return Row(
      children: [
        const Icon(
          Icons.ac_unit_rounded,
          size: 14,
          color: ElioColors.mocha,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            bulkPrepInfo!.storageLife,
            style: ElioTextStyles.bodySmallStyle.copyWith(
              color: ElioColors.mocha,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Regenerate button ────────────────────────────────────────────────────────
//
// 32×32 cream square with rule border, Icons.refresh 16 mocha. Swaps to a
// terracotta CircularProgressIndicator (strokeWidth 2) while regenerating.
// Visual is a 1:1 mirror of MealPlanScreen's per-slot regen button
// (meal_plan_screen.dart ~L1019-1039) so the affordance is consistent
// across bulk cook and meal planner.
class _RegenerateButton extends StatelessWidget {
  final bool isRegenerating;
  final VoidCallback? onTap;

  const _RegenerateButton({
    required this.isRegenerating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: ElioColors.cream,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ElioColors.rule),
        ),
        child: isRegenerating
            ? const Padding(
                padding: EdgeInsets.all(7),
                child: CircularProgressIndicator(
                  color: ElioColors.terracotta,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.refresh, size: 16, color: ElioColors.mocha),
      ),
    );
  }
}

// ─── Meta chip ────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ElioColors.rule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ElioColors.mocha),
          const SizedBox(width: 4),
          Text(
            label,
            style: ElioTextStyles.bodySmallStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: ElioColors.mocha,
            ),
          ),
        ],
      ),
    );
  }
}
