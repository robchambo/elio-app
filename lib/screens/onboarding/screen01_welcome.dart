import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../../services/analytics_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_onboarding_progress_bar.dart';
import '../../widgets/elio/elio_page_title.dart';
import '../auth/email_login_screen.dart';

// ─────────────────────────────────────────────
// Screen 01 — Welcome / Hook
//
// Sells the transformation outcome before asking for anything.
// See docs/onboarding/01-welcome.md for the authoritative spec.
//
// This screen receives an [OnboardingController] + an [onContinue]
// callback from the flow coordinator (Phase 7). It does not know
// about the next screen or navigation — the coordinator owns that.
//
// The "I already have an account" link (Q2 — confirmed YES) pushes
// [EmailLoginScreen]. [onSignInTap] is provided as a testing seam so
// widget tests can verify the intent without constructing a Firebase-
// backed auth screen.
// ─────────────────────────────────────────────

class Screen01Welcome extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;

  /// Optional override for the "I already have an account" tap handler.
  /// When null, pushes [EmailLoginScreen]. Exists purely as a testing seam.
  final VoidCallback? onSignInTap;

  const Screen01Welcome({
    super.key,
    required this.controller,
    required this.onContinue,
    this.onSignInTap,
  });

  void _handleSignInTap(BuildContext context) {
    if (onSignInTap != null) {
      onSignInTap!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ElioSpacing.screenEdge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ElioOnboardingProgressBar(value: 1 / 15),
              const SizedBox(height: ElioSpacing.xl),
              const ElioPageTitle('tonights dinner, from what you already have.'),
              const SizedBox(height: ElioSpacing.md),
              Text(
                "recipes built around you. tailored to you, tailored to your kitchen",
                style: ElioTextStyles.ledeStyle,
              ),
              const SizedBox(height: ElioSpacing.lg),
              // 18 May 2026: replaced the procedural PhoneMockupRecipeCard
              // widget (broken "Tomato & basil pasta" overflow demo) with
              // Kate's marketing hero image — three phone mockups
              // (Home / Recipe / Pantry) on a black backdrop.
              Expanded(
                child: Image.asset(
                  'assets/images/onboarding/welcome_hero.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: ElioSpacing.lg),
              ElioBigButton(
                label: 'Get started',
                onTap: () {
                  AnalyticsService.instance.logEvent(
                    'onboarding_step_completed',
                    const {'step_index': 1, 'step_name': 'welcome'},
                  );
                  onContinue();
                },
              ),
              const SizedBox(height: ElioSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: () => _handleSignInTap(context),
                  child: Text(
                    'i already have an account',
                    style: ElioTextStyles.bodyStyle.copyWith(
                      color: ElioColors.mocha,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
