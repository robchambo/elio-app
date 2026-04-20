import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';

// ─────────────────────────────────────────────
// OnboardingFlow — Sprint 16 placeholder
//
// The legacy 8-screen flow has been deleted as part of the Sprint 16
// onboarding rebuild (Phase 0A). The new 15-screen coordinator will be
// implemented in Task 7.1. Until then this stub preserves the public
// constructor so the AuthGate can route new users here; it renders a
// simple placeholder and is replaced wholesale in later tasks.
// ─────────────────────────────────────────────

class OnboardingFlow extends StatelessWidget {
  final String displayName;
  final VoidCallback onComplete;
  final bool isGuest;

  const OnboardingFlow({
    super.key,
    required this.displayName,
    required this.onComplete,
    this.isGuest = false,
  });

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ElioColors.white,
      body: Center(
        child: Text(
          'Onboarding — Sprint 16 rebuild in progress',
          style: TextStyle(color: ElioColors.navy),
        ),
      ),
    );
  }
}
