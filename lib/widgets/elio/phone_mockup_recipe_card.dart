import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import 'elio_pantry_tag_pill.dart';

/// Demo ingredient row shown in [PhoneMockupRecipeCard].
class PhoneMockupIngredient {
  final String name;
  final PantryTagKind? tag;
  const PhoneMockupIngredient({required this.name, this.tag});
}

/// Hero element on onboarding screen 01.
///
/// Renders a simple rounded "phone frame" (a placeholder — Kate may refine
/// later) containing a fake recipe card: title, a small hero strip, and a
/// list of ingredient rows with [ElioPantryTagPill] overlays.
class PhoneMockupRecipeCard extends StatelessWidget {
  final String recipeTitle;
  final List<PhoneMockupIngredient> ingredients;

  const PhoneMockupRecipeCard({
    super.key,
    this.recipeTitle = 'Tomato & basil pasta',
    this.ingredients = const [
      PhoneMockupIngredient(
        name: 'Spaghetti',
        tag: PantryTagKind.alwaysHave,
      ),
      PhoneMockupIngredient(
        name: 'Cherry tomatoes',
        tag: PantryTagKind.useToday,
      ),
      PhoneMockupIngredient(
        name: 'Fresh basil',
        tag: PantryTagKind.inYourPantry,
      ),
    ],
  });

  @override
  Widget build(BuildContext context) {
    // "Phone frame" — rounded container, aspect ratio roughly 9:16.
    return Center(
      child: AspectRatio(
        aspectRatio: 9 / 15,
        child: Container(
          padding: const EdgeInsets.all(ElioSpacing.sm),
          decoration: BoxDecoration(
            color: ElioColors.navy,
            borderRadius: BorderRadius.circular(40),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Container(
              color: ElioColors.offWhite,
              padding: const EdgeInsets.all(ElioSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: ElioSpacing.md),
                  _HeroStrip(),
                  const SizedBox(height: ElioSpacing.md),
                  Text(
                    recipeTitle,
                    style: ElioTextStyles.heading4.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: ElioSpacing.sm),
                  Expanded(
                    child: ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ingredients.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: ElioSpacing.xs),
                      itemBuilder: (_, i) => _IngredientRow(ingredients[i]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: ElioColors.amber.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(ElioRadii.md),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.restaurant,
          color: ElioColors.amber.withValues(alpha: 0.7), size: 28),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final PhoneMockupIngredient ingredient;
  const _IngredientRow(this.ingredient);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            ingredient.name,
            style: ElioTextStyles.bodySmall.copyWith(
              color: ElioColors.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (ingredient.tag != null) ElioPantryTagPill(kind: ingredient.tag!),
      ],
    );
  }
}
