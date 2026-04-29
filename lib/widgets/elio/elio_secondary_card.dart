// lib/widgets/elio/elio_secondary_card.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioSecondaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onAction;

  const ElioSecondaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(ElioRadii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ElioTextStyles.heading3),
                const SizedBox(height: 4),
                Text(subtitle, style: ElioTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: onAction,
            borderRadius: ElioRadii.all(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: ElioColors.amber,
                borderRadius: ElioRadii.all(24),
              ),
              child: Text(actionLabel,
                  style: ElioTextStyles.uiLabelStyle.copyWith(
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
