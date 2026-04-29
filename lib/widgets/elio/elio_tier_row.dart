// lib/widgets/elio/elio_tier_row.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioTierRow extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback? onTap;
  final Widget? expandedBody;

  const ElioTierRow({
    super.key,
    required this.label,
    required this.count,
    this.onTap,
    this.expandedBody,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ElioRadii.card),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: ElioColors.cream,
          borderRadius: BorderRadius.circular(ElioRadii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('$label ($count)', style: ElioTextStyles.heading5),
                ),
                const Icon(Icons.chevron_right,
                    color: ElioColors.navy, size: 24),
              ],
            ),
            if (expandedBody != null) ...[
              const SizedBox(height: 12),
              expandedBody!,
            ],
          ],
        ),
      ),
    );
  }
}
