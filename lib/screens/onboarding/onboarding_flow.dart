import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../shell/app_shell.dart';

// ─────────────────────────────────────────────
// OnboardingFlow — Sprint 16 placeholder
//
// The legacy 8-screen flow has been deleted as part of the Sprint 16
// onboarding rebuild (Phase 0A). The new 15-screen coordinator will be
// implemented in Task 7.1. Until then this stub preserves the public
// constructor so existing callers (auth screens, screen0_welcome)
// continue to compile; it simply forwards to the AppShell.
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
    // During the rebuild, immediately replace with AppShell. Callers
    // will be rewired to route directly to AppShell / the new 15-screen
    // flow as Tasks 0.3 and 7.1 land.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (route) => false,
      );
    });
    return const Scaffold(
      backgroundColor: ElioColors.white,
      body: Center(
        child: CircularProgressIndicator(color: ElioColors.amber),
      ),
    );
  }
}
