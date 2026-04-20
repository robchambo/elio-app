import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';
import '../../widgets/elio_progress_bar.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../home/home_screen.dart';
import '../paywall/paywall_screen.dart';

// ─────────────────────────────────────────────
// Screen 8 — Onboarding Complete
// Final terminal step: confirms setup is done and
// hands the user off to HomeScreen. No back option.
// ─────────────────────────────────────────────

class OnboardingCompleteScreen extends StatelessWidget {
  final bool isGuest;

  const OnboardingCompleteScreen({super.key, this.isGuest = false});

  void _goHome(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(isGuest: isGuest)),
      (route) => false,
    );
    // Signed-in users see the onboarding paywall on top of Home
    if (!isGuest) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const PaywallScreen(trigger: PaywallTrigger.onboarding),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Progress bar ────────────────────────────────────
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: ElioProgressBar(currentStep: 8, totalSteps: 8),
              ),

              const Spacer(flex: 1),

              // ── Hero ────────────────────────────────────────────
              const ElioEyebrow('your kitchen is good to go'),
              const SizedBox(height: 16),
              const ElioHeroHeading(
                lines: ['elio is', 'ready'],
                amberLastLine: true,
              ),
              const SizedBox(height: 20),

              // ── Subtitle ────────────────────────────────────────
              Text(
                "let's build your pantry and generate your first recipe.",
                style: ElioTextStyles.body,
              ),

              const SizedBox(height: 32),

              // ── Summary bullets ─────────────────────────────────
              const _SummaryBullet(text: 'your pantry is ready'),
              const SizedBox(height: 12),
              const _SummaryBullet(text: '7 free recipes per week'),
              const SizedBox(height: 12),
              const _SummaryBullet(text: 'tap generate to start cooking'),

              const Spacer(flex: 2),

              // ── Primary CTA ─────────────────────────────────────
              ElioBigButton(
                label: 'Start cooking',
                trailingIcon: Icons.chevron_right,
                onTap: () => _goHome(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary bullet row ──────────────────────────────────────────────────────

class _SummaryBullet extends StatelessWidget {
  final String text;

  const _SummaryBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: ElioColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 16,
            color: ElioColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: ElioTextStyles.body,
          ),
        ),
      ],
    );
  }
}
