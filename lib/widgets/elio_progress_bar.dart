import 'package:flutter/material.dart';
import '../theme/elio_theme.dart';

// ─────────────────────────────────────────────
// ElioProgressBar
// Shared segmented progress bar used across all
// onboarding screens.
// ─────────────────────────────────────────────

class ElioProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const ElioProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 4,
            decoration: BoxDecoration(
              color: i < currentStep ? ElioColors.amber : ElioColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
