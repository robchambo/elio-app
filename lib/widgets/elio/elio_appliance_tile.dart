import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';

/// Square-ish grid tile used on onboarding screen 08 (appliances).
///
/// Icon above label; amber border + tick overlay when selected.
class ElioApplianceTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<String> onTap;

  const ElioApplianceTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? ElioColors.amber : ElioColors.border;
    final bg = selected
        ? ElioColors.amber.withValues(alpha: 0.08)
        : ElioColors.white;

    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(ElioRadii.lg),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(ElioSpacing.md),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(ElioRadii.lg),
              border: Border.all(
                color: borderColor,
                width: selected ? 2.0 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: ElioColors.navy, size: 32),
                const SizedBox(height: ElioSpacing.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: ElioTextStyles.bodySmall.copyWith(
                    color: ElioColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ElioColors.amber,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
