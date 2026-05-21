import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';

/// Small pantry-status icon for ingredient rows.
///
/// Green when the ingredient is in stock; red when it isn't.
/// Uses the same `Icons.kitchen_outlined` glyph as the bottom-nav PANTRY tab.
class ElioPantryIcon extends StatelessWidget {
  final bool inStock;
  final double size;

  const ElioPantryIcon({
    super.key,
    required this.inStock,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final color = inStock ? ElioColors.espresso : ElioColors.terracotta;
    return Semantics(
      label: inStock ? 'In your pantry' : 'Not in your pantry',
      child: Icon(Icons.kitchen_outlined, size: size, color: color),
    );
  }
}
