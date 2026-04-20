// lib/widgets/elio/elio_chip.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool hasDropdown;
  final VoidCallback? onTap;

  const ElioChip({
    super.key,
    required this.label,
    required this.selected,
    this.hasDropdown = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? ElioColors.amber : Colors.white;
    final fg = selected ? Colors.white : ElioColors.navy;
    final borderColor = selected ? ElioColors.amber : ElioColors.border;
    return InkWell(
      onTap: onTap,
      borderRadius: ElioRadii.chip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: ElioRadii.chip,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: ElioTextStyles.body.copyWith(color: fg)),
            if (hasDropdown) ...[
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down, color: fg, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
