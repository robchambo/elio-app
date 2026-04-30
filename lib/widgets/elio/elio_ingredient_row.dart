// lib/widgets/elio/elio_ingredient_row.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';

/// Circle checkbox + bold name + small detail underneath.
class ElioIngredientRow extends StatelessWidget {
  final String name;
  final String? detail;
  final bool checked;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;

  const ElioIngredientRow({
    super.key,
    required this.name,
    this.detail,
    this.checked = false,
    this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24, height: 24,
              margin: const EdgeInsets.only(right: 16, top: 2),
              decoration: BoxDecoration(
                color: checked ? ElioColors.terracotta : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: checked ? ElioColors.terracotta : ElioColors.border,
                  width: 2,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: ElioTextStyles.heading5),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail!, style: ElioTextStyles.bodySmall),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
