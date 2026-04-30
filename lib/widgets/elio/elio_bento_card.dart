// lib/widgets/elio/elio_bento_card.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioBentoCard extends StatelessWidget {
  final IconData icon;
  final String kicker;
  final String title;
  final VoidCallback? onTap;

  const ElioBentoCard({
    super.key,
    required this.icon,
    required this.kicker,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ElioRadii.card),
      child: Container(
        // Width is determined by parent (commonly Expanded inside a Row).
        // Fixed height keeps both tiles in a pair visually aligned.
        height: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ElioColors.creamDeep,
          borderRadius: BorderRadius.circular(ElioRadii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: ElioColors.terracotta, size: 28),
            // Clamp wrap behaviour so the title can't bleed outside the
            // rounded background (Sprint 16.3 — was overflowing on the
            // pantry "Scan receipt" tile when content wrapped to 2 lines).
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kicker,
                  style: ElioTextStyles.eyebrowStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: ElioTextStyles.uiLabelStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
