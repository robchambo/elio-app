import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio_progress_bar.dart';
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
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // ── Progress bar ────────────────────────────────────
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: ElioProgressBar(currentStep: 8, totalSteps: 8),
              ),

              const Spacer(flex: 2),

              // ── Success checkmark ───────────────────────────────
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: ElioColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 56,
                  color: ElioColors.success,
                ),
              ),
              const SizedBox(height: 28),

              // ── Heading ─────────────────────────────────────────
              Text(
                "You're all set!",
                style: ElioText.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // ── Subtitle ────────────────────────────────────────
              Text(
                "Let's build your pantry and generate your first recipe.",
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: ElioColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // ── Summary bullets ─────────────────────────────────
              const _SummaryBullet(text: 'Your pantry is ready'),
              const SizedBox(height: 12),
              const _SummaryBullet(text: '7 free recipes per week'),
              const SizedBox(height: 12),
              const _SummaryBullet(text: 'Tap Generate to start cooking'),

              const Spacer(flex: 3),

              // ── Primary CTA ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => _goHome(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ElioColors.amber,
                    foregroundColor: ElioColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    elevation: 0,
                  ),
                  child: const Text("Let's Get Started"),
                ),
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
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: ElioColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
