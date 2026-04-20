// lib/widgets/elio/elio_bento_card.dart
import 'package:flutter/material.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioBentoCard extends StatelessWidget {
  final IconData icon;
  final String kicker;
  final String title;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const ElioBentoCard({
    super.key,
    required this.icon,
    required this.kicker,
    required this.title,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: ElioRadii.card,
      child: Container(
        height: 150,
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: backgroundColor, borderRadius: ElioRadii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: ElioRadii.all(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kicker, style: ElioTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 4),
                Text(title, style: ElioTextStyles.heading4.copyWith(color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
