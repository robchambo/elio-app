// lib/widgets/elio/elio_chip.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool hasDropdown;

  /// When true, selected chips render a trailing ✓ icon next to the
  /// label. Default true to preserve legacy behaviour across Time /
  /// Style / Mood / dietary chips.
  ///
  /// Sprint 16.6 (Notion XX-2 B3, 12 May 2026): the meal-type chip row
  /// (Breakfast / Lunch / Dinner) sets this `false` because the extra
  /// ~24px from the check widened "Breakfast" enough to push "Dinner"
  /// onto a second line on standard phone widths. Solid terracotta fill
  /// is enough visual signal on a 3-chip row.
  final bool showCheck;

  final VoidCallback? onTap;

  const ElioChip({
    super.key,
    required this.label,
    required this.selected,
    this.hasDropdown = false,
    this.showCheck = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? ElioColors.terracotta : ElioColors.creamDeep;
    final fg = selected ? Colors.white : ElioColors.espresso;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ElioRadii.chip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ElioRadii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: ElioTextStyles.uiLabelStyle.copyWith(color: fg)),
            if (selected && showCheck) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check, color: Colors.white, size: 18),
            ] else if (!selected && hasDropdown) ...[
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down, color: fg, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
