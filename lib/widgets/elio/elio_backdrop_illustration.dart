import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Full-app brand backdrop. Single hardcoded variant (kale leaf) for now;
/// add a `Variant` enum when a second illustration ships (spec §7).
///
/// Place inside a [Stack] behind the page content. Designed to be inserted
/// by [ElioAppScaffold] but also usable directly.
///
/// Renders at 5% opacity with the SVG's natural multi-colour fills
/// (dark green outline, cream highlights, mid-greens) — matches Kate's
/// Figma comp.
class ElioBackdropIllustration extends StatelessWidget {
  const ElioBackdropIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      right: -120, // bleeds off the right edge by ~30%
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.05,
          child: SvgPicture.asset(
            'assets/illustrations/backdrop_kale.svg',
            // No colorFilter — the SVG has multi-colour painted detail
            // (dark green outline, cream highlights). At 5% opacity the
            // natural colours read as a soft tonal shape.
            fit: BoxFit.fitHeight,
          ),
        ),
      ),
    );
  }
}
