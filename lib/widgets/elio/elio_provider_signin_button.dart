import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';

/// Identifies which provider-flavoured sign-in button to render.
///
/// Visual treatment follows each provider's brand guidelines:
///   - [apple]  → black fill, white icon+label, white Apple glyph
///   - [google] → white fill with subtle border, multi-colour "G" glyph
///   - [email]  → off-white fill, navy label, mail glyph (Elio's own style)
enum ProviderButtonKind { apple, google, email }

/// Peer-style sign-in button used on onboarding screen 15.
///
/// All three variants render at the same size and weight — no primary /
/// secondary distinction. Apple accepts [visible] so the caller can gate
/// rendering by `Platform.isIOS`.
class ElioProviderSignInButton extends StatelessWidget {
  final ProviderButtonKind kind;
  final VoidCallback onPressed;
  final bool visible;

  const ElioProviderSignInButton({
    super.key,
    required this.kind,
    required this.onPressed,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final style = _style();

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: style.bg,
        borderRadius: BorderRadius.circular(ElioRadii.button),
        elevation: 0,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(ElioRadii.button),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ElioSpacing.lg,
              vertical: ElioSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ElioRadii.button),
              border: style.border,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                style.glyph,
                const SizedBox(width: ElioSpacing.sm + 4),
                Text(
                  style.label,
                  style: ElioTextStyles.uiLabelStyle.copyWith(color: style.fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({Color bg, Color fg, Widget glyph, String label, BoxBorder? border}) _style() {
    switch (kind) {
      case ProviderButtonKind.apple:
        return (
          bg: Colors.black,
          fg: Colors.white,
          // Apple brand: solid black button with white Apple logo glyph.
          glyph: const Icon(Icons.apple, color: Colors.white, size: 20),
          label: 'Continue with Apple',
          border: null,
        );
      case ProviderButtonKind.google:
        return (
          bg: Colors.white,
          fg: ElioColors.espresso,
          // Google brand requires the multi-colour "G" mark. The icon
          // here is a stand-in — screen 15 wires the real asset.
          glyph: const _GoogleG(),
          label: 'Continue with Google',
          border: Border.all(color: ElioColors.rule, width: 1.5),
        );
      case ProviderButtonKind.email:
        return (
          bg: Colors.white,
          fg: ElioColors.espresso,
          glyph: const Icon(Icons.mail_outline, color: ElioColors.espresso, size: 20),
          label: 'Continue with email',
          border: Border.all(color: ElioColors.rule, width: 1.5),
        );
    }
  }
}

/// Stand-in for Google's multi-colour "G" mark. Replace with the proper
/// brand asset when the real SVG lands in `assets/`.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF4285F4),
          fontSize: 16,
        ),
      ),
    );
  }
}
