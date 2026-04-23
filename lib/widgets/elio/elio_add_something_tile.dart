import 'package:flutter/material.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';

/// Grid tile used on onboarding screens 11 (staples) and 12 (perishables)
/// to let a user add a custom item to the current category. Shares the
/// grid-cell footprint of [ElioPantryItemTile] (aspect ratio 2.4), so it
/// slots in as the last child of each category grid.
///
/// Visual: cream background, dashed amber border, "+" glyph and
/// "Add something" label. Single tap fires [onTap].
class ElioAddSomethingTile extends StatelessWidget {
  final VoidCallback onTap;

  const ElioAddSomethingTile({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ElioRadii.md),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: ElioColors.amber,
          radius: ElioRadii.md,
          strokeWidth: 1.5,
          dash: 5,
          gap: 3,
        ),
        child: Container(
          padding: const EdgeInsets.all(ElioSpacing.sm + 2),
          decoration: BoxDecoration(
            color: ElioColors.cream,
            borderRadius: BorderRadius.circular(ElioRadii.md),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, color: ElioColors.amber, size: 22),
              const SizedBox(height: 4),
              Text(
                'Add something',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ElioTextStyles.bodySmall.copyWith(
                  color: ElioColors.amber,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws a dashed rounded-rect border on top of a child. Cheap custom
/// painter — we avoid pulling in a new package just for this one tile.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}
