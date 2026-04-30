// lib/widgets/elio/elio_bento_card.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

/// Two-tile action card used on Pantry + Recipes import rows.
///
/// Card surface: cream-deep. Inner icon container is the two-tone pop —
/// callers pass an [iconBackgroundColor] (defaults to peach) and an
/// [iconColor] (defaults to espresso) so the same shell can render the
/// "Scan receipt" / "Scan barcode" / "Take photo" / "Manual entry" tiles
/// with distinct accent backgrounds while the card frame stays uniform.
class ElioBentoCard extends StatelessWidget {
  final IconData icon;
  final String kicker;
  final String title;
  final Color iconBackgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const ElioBentoCard({
    super.key,
    required this.icon,
    required this.kicker,
    required this.title,
    this.iconBackgroundColor = ElioColors.peach,
    this.iconColor = ElioColors.espresso,
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(ElioRadii.panel),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
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
