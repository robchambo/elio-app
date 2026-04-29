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
    // Global keyboard-dismiss contract (Sprint 16.2): every forward-nav
    // button in onboarding is an ElioBigButton, so unfocusing here drops
    // the soft keyboard before the next screen renders. Without this,
    // the keyboard from e.g. screen 05 (allergies free-text) persists
    // into screen 06 and blocks its tap targets. Null-safe — disabled
    // button (onTap == null) is a no-op.
    final void Function()? handler = (loading || onTap == null)
        ? null
        : () {
            FocusManager.instance.primaryFocus?.unfocus();
            onTap!();
          };
    return InkWell(
      onTap: handler,
      borderRadius: BorderRadius.circular(ElioRadii.button),
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: onTap == null ? ElioColors.amber.withValues(alpha: 0.5) : ElioColors.amber,
          borderRadius: BorderRadius.circular(ElioRadii.button),
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
