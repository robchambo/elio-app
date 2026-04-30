import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

/// Visual category for [ElioPantryTagPill]. Maps to a colour + copy.
enum PantryTagKind {
  inYourPantry,
  useToday,
  alwaysHave,
  usuallyHave,
  fresh,
  thisWeek,
  needToBuy,
}

/// Small coloured pill surfacing pantry state on recipe cards.
///
/// Used on screen 01's demo phone-mockup card and on screen 13's generated
/// recipe ingredient rows to call out items already in the pantry.
class ElioPantryTagPill extends StatelessWidget {
  final PantryTagKind kind;
  final String? overrideLabel;

  const ElioPantryTagPill({
    super.key,
    required this.kind,
    this.overrideLabel,
  });

  ({Color fg, Color bg, String label}) _style() {
    switch (kind) {
      case PantryTagKind.inYourPantry:
        return (
          fg: ElioColors.espresso,
          bg: ElioColors.terracotta.withValues(alpha: 0.15),
          label: 'In your pantry',
        );
      case PantryTagKind.useToday:
        return (
          fg: Colors.white,
          bg: ElioColors.perishToday,
          label: 'Use today',
        );
      case PantryTagKind.alwaysHave:
        return (
          fg: Colors.white,
          bg: ElioColors.terracotta,
          label: 'Always in',
        );
      case PantryTagKind.usuallyHave:
        return (
          fg: ElioColors.terracotta,
          bg: ElioColors.terracotta.withValues(alpha: 0.12),
          label: 'Usually in',
        );
      case PantryTagKind.fresh:
        return (
          fg: Colors.white,
          bg: ElioColors.freshGreen,
          label: 'Fresh',
        );
      case PantryTagKind.thisWeek:
        return (
          fg: Colors.white,
          bg: ElioColors.perishThisWeek,
          label: 'This week',
        );
      case PantryTagKind.needToBuy:
        return (
          fg: ElioColors.textSecondary,
          bg: ElioColors.textSecondary.withValues(alpha: 0.10),
          label: 'Shopping list',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(ElioRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: s.fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            overrideLabel ?? s.label,
            style: ElioTextStyles.bodySmall.copyWith(
              color: s.fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
