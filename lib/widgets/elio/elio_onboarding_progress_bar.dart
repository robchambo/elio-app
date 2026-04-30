import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';

/// Thin, proportional progress bar for the 15-screen onboarding flow.
///
/// Takes a [value] in the range 0.0..1.0 (clamped). Renders an amber fill
/// over an off-white / cream track. See plan Task 0.7.
class ElioOnboardingProgressBar extends StatelessWidget {
  final double value;

  const ElioOnboardingProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(ElioRadii.pill),
      child: LinearProgressIndicator(
        value: v,
        minHeight: 6,
        backgroundColor: ElioColors.cream,
        valueColor: const AlwaysStoppedAnimation<Color>(ElioColors.terracotta),
      ),
    );
  }
}
