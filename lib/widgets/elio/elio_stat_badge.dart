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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ElioColors.creamDeep,
        borderRadius: BorderRadius.circular(ElioRadii.panel),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: ElioColors.terracotta),
          const SizedBox(width: 8),
          Text(value, style: ElioTextStyles.uiLabelStyle),
        ],
      ),
    );
  }
}
