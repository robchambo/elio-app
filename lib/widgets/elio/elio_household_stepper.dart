import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';

/// −/count/+ control for household size on onboarding screen 03.
///
/// Clamps to [min]..[max] (defaults 1..10). Buttons disable at the bounds.
class ElioHouseholdStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const ElioHouseholdStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
  });

  @override
  Widget build(BuildContext context) {
    final canDec = value > min;
    final canInc = value < max;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ElioSpacing.sm,
        vertical: ElioSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: ElioColors.creamDeep,
        borderRadius: BorderRadius.circular(ElioRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            enabled: canDec,
            onTap: canDec ? () => onChanged(value - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ElioSpacing.lg),
            child: Text(
              '$value',
              style: ElioTextStyles.sectionHeadingStyle,
            ),
          ),
          _StepButton(
            icon: Icons.add,
            enabled: canInc,
            onTap: canInc ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? ElioColors.peach : ElioColors.peach.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: ElioColors.espresso, size: 20),
      ),
    );
  }
}
