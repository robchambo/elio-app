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
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(ElioRadii.card),
      // Stack+Positioned.fill so the background tile always occupies the
      // full grid cell. Without Positioned.fill the Container shrank to
      // its content width, which made single-word tiles ("Oven",
      // "Air fryer", "Blender") visibly narrower than two-line ones
      // ("Hob / stove", "Slow cooker") in the same grid row. See
      // screen08_appliances_test "all appliance tiles render at
      // identical widths" for the regression guard.
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(ElioSpacing.sm),
              decoration: BoxDecoration(
                color: ElioColors.creamDeep,
                borderRadius: BorderRadius.circular(ElioRadii.card),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: ElioColors.espresso, size: 28),
                  const SizedBox(height: ElioSpacing.xs),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ElioTextStyles.uiLabelStyle,
                  ),
                ],
              ),
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
                  color: ElioColors.terracotta,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
