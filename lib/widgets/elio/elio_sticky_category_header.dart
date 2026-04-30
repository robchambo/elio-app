import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';

/// Sticky category header used inside the pantry CustomScrollViews on
/// onboarding screens 11 and 12.
///
/// Renders as a [SliverPersistentHeaderDelegate] so category names stay
/// pinned while the user scrolls through the tiles in that category.
class ElioStickyCategoryHeader extends SliverPersistentHeaderDelegate {
  final String title;
  final int? count;
  final double height;

  ElioStickyCategoryHeader({
    required this.title,
    this.count,
    this.height = 44,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: ElioColors.cream,
      padding: const EdgeInsets.symmetric(
        horizontal: ElioSpacing.md,
        vertical: ElioSpacing.sm,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: ElioTextStyles.sectionHeadingStyle,
            ),
          ),
          if (count != null && count! > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ElioSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: ElioColors.terracotta.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: ElioTextStyles.bodySmallStyle.copyWith(
                  color: ElioColors.terracotta,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant ElioStickyCategoryHeader oldDelegate) =>
      oldDelegate.title != title ||
      oldDelegate.count != count ||
      oldDelegate.height != height;
}
