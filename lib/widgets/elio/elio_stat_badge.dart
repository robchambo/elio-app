// lib/widgets/elio/elio_stat_badge.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioStatBadge extends StatelessWidget {
  final IconData icon;
  final String value;

  const ElioStatBadge({super.key, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: ElioRadii.all(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: ElioColors.navy),
          const SizedBox(width: 8),
          Text(value, style: ElioTextStyles.statValue),
        ],
      ),
    );
  }
}
