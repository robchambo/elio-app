import 'package:flutter/material.dart';

import '../data/recipe_categories.dart';
import 'elio/elio_chip.dart';

/// Horizontal-scroll filter chip row for recipe categories.
///
/// Single-select: tapping a chip sets it as the active filter; tapping
/// the active chip clears back to "All". `selected == null` means All.
///
/// Reuses [ElioChip] to keep visual styling consistent with other Elio
/// chip surfaces (preferences, dietary, etc.).
class RecipeCategoryChipRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const RecipeCategoryChipRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // null sentinel = "All".
    final entries = <String?>[null, ...RecipeCategories.all];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final value = entries[i];
          final label = value ?? 'All';
          final isActive = value == null
              ? selected == null
              : selected == value;
          return ElioChip(
            label: label,
            selected: isActive,
            onTap: () {
              // Tapping the active non-null chip clears back to All.
              if (isActive && value != null) {
                onSelected(null);
              } else {
                onSelected(value);
              }
            },
          );
        },
      ),
    );
  }
}
