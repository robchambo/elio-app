import 'package:flutter/material.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';

// ─────────────────────────────────────────────
// ElioPantryTierLegend — colour-coded legend for screens 11/12.
//
// Replaces the older emoji legends (◐ Usually ✅ Always, 🟢🟡🔴) which
// didn't actually match the tile appearance. Each entry renders as a
// small rounded swatch with the *exact* fill + border used by the
// corresponding pantry tile tier, so legend and tiles visually agree.
//
// Kept as its own widget so screen 11 and screen 12 share the same
// swatch construction. See ElioPantryItemTile for the matching tile
// styles.
// ─────────────────────────────────────────────

class ElioPantryTierLegend extends StatelessWidget {
  final List<ElioPantryTierLegendEntry> entries;

  const ElioPantryTierLegend({super.key, required this.entries});

  /// Screen 11 (staples) — usually / always.
  factory ElioPantryTierLegend.staples({Key? key}) {
    return ElioPantryTierLegend(
      key: key,
      entries: const [
        ElioPantryTierLegendEntry(
          label: 'Usually in',
          background: Color(0x1FF08C14), // amber @ 12% — matches tile
          borderColor: ElioColors.amber,
        ),
        ElioPantryTierLegendEntry(
          label: 'Always in',
          background: ElioColors.amber,
          borderColor: ElioColors.amber,
        ),
      ],
    );
  }

  /// Screen 12 (perishables) — fresh / this week / today.
  factory ElioPantryTierLegend.perishables({Key? key}) {
    return ElioPantryTierLegend(
      key: key,
      entries: const [
        ElioPantryTierLegendEntry(
          label: 'Fresh',
          background: Color(0x1F3D9970),
          borderColor: ElioColors.freshGreen,
        ),
        ElioPantryTierLegendEntry(
          label: 'This week',
          background: Color(0x1FF08C14),
          borderColor: ElioColors.perishThisWeek,
        ),
        ElioPantryTierLegendEntry(
          label: 'Today',
          background: Color(0x1FE06C5E),
          borderColor: ElioColors.perishToday,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ElioSpacing.md,
      runSpacing: ElioSpacing.xs,
      children: entries.map(_swatchEntry).toList(),
    );
  }

  Widget _swatchEntry(ElioPantryTierLegendEntry e) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: e.background,
            borderRadius: BorderRadius.circular(ElioRadii.sm),
            border: Border.all(color: e.borderColor, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          e.label,
          style: ElioTextStyles.bodySmall.copyWith(
            color: ElioColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class ElioPantryTierLegendEntry {
  final String label;
  final Color background;
  final Color borderColor;
  const ElioPantryTierLegendEntry({
    required this.label,
    required this.background,
    required this.borderColor,
  });
}
