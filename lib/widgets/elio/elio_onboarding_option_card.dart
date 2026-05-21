import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';

/// Vertical selectable card used on onboarding screens 02, 03, 06, 07, 09.
///
/// Layout: leading icon (optional) + title + subtitle + amber-tick when
/// selected. Tapping fires [onTap] with [value] so callers can bind the
/// card to a controller setter (e.g. `setUserGoal`).
class ElioOnboardingOptionCard extends StatelessWidget {
  final String value;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final ValueChanged<String> onTap;

  const ElioOnboardingOptionCard({
    super.key,
    required this.value,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(ElioRadii.card),
      child: Container(
        padding: const EdgeInsets.all(ElioSpacing.md),
        decoration: BoxDecoration(
          color: ElioColors.creamDeep,
          borderRadius: BorderRadius.circular(ElioRadii.card),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: ElioColors.espresso, size: 28),
              const SizedBox(width: ElioSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ElioTextStyles.uiLabelStyle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: ElioTextStyles.bodySmallStyle),
                  ],
                ],
              ),
            ),
            const SizedBox(width: ElioSpacing.sm),
            _Tick(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  final bool selected;
  const _Tick({required this.selected});

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ElioColors.terracotta, width: 1.5),
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: ElioColors.terracotta,
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 16),
    );
  }
}
