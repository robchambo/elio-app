// lib/widgets/elio/elio_big_button.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioBigButton extends StatelessWidget {
  final String label;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final bool loading;

  const ElioBigButton({
    super.key,
    required this.label,
    this.trailingIcon,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: ElioRadii.button,
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: onTap == null ? ElioColors.amber.withValues(alpha: 0.5) : ElioColors.amber,
          borderRadius: ElioRadii.button,
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: ElioTextStyles.heading3.copyWith(color: ElioColors.navy),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: ElioColors.navy),
              )
            else if (trailingIcon != null)
              Icon(trailingIcon, color: ElioColors.navy, size: 28),
          ],
        ),
      ),
    );
  }
}
