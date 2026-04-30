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
    this.trailingIcon = Icons.chevron_right,
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          color: onTap == null ? ElioColors.terracotta.withValues(alpha: 0.5) : ElioColors.terracotta,
          borderRadius: BorderRadius.circular(ElioRadii.button),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: ElioTextStyles.uiLabelStyle.copyWith(color: Colors.white),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else if (trailingIcon != null)
              Icon(trailingIcon, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }
}
