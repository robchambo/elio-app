import 'package:flutter/material.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../models/recipe_models.dart';
import '../recipe/recipe_screen.dart';

/// Shows the results of a bulk prep generation session.
/// Displays 1-3 recipe cards that the user can tap to view in full.
class BulkPrepResultsScreen extends StatelessWidget {
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
              itemCount: recipes.length,
              itemBuilder: (context, index) => _RecipeCard(
                recipe: recipes[index],
                mealNumber: index + 1,
                bulkPrepInfo: recipes[index].bulkPrepInfo,
                onTap: () => _openRecipe(context, recipes[index]),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  String _subtitleText() {
    final mealCount = recipes.length;
    final mealWord = mealCount == 1 ? 'meal' : 'meals';
    if (recipes.isNotEmpty) {
      final portions = recipes.first.servings;
      return '$mealCount $mealWord \u00b7 $portions portions each';
    }
    return '$mealCount $mealWord';
  }

  void _openRecipe(BuildContext context, GeneratedRecipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeScreen(
          recipe: recipe,
          originalRequest: originalRequest,
          isGuest: isGuest,
        ),
      ),
    );
  }

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
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.mealNumber,
    required this.bulkPrepInfo,
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
              _buildMealChip(),
              const SizedBox(height: 10),
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
              if (bulkPrepInfo != null &&
                  bulkPrepInfo!.storageLife.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildStorageRow(),
              ],
            ],
          ),
        ),
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
