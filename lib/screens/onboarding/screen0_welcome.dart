import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/analytics_service.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import 'onboarding_flow.dart';
import '../shell/app_shell.dart';
import '../auth/email_login_screen.dart';

// ─────────────────────────────────────────────
// WelcomeScreen (Screen 0)
// Design: approachable utility.
// First impression of Elio — warm, confident, simple.
//
// Layout:
//   • Large ELiO wordmark
//   • Tagline
//   • Three value props
//   • Google Sign-In button
//   • "Explore without an account" guest bypass
//   • Privacy note
// ─────────────────────────────────────────────

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final AuthService _auth = AuthService();
  final FirestoreService _firestore = FirestoreService();
  bool _isLoading = false;
  String? _errorMessage;

  final AnalyticsService _analytics = AnalyticsService.instance;

  Future<void> _handleGoogleSignIn() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    _analytics.logEvent('sign_in_method', {'method': 'google'});

    try {
      final credential = await _auth.signInWithGoogle();
      if (credential == null) {
        setState(() => _isLoading = false);
        return;
      }

      final user = credential.user;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sign-in failed. Please try again.';
        });
        return;
      }

      final isComplete = await _firestore.isOnboardingComplete();
      if (!mounted) return;

      if (isComplete) {
        // Already onboarded — go straight to the 4-tab shell
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
        );
      } else {
        // New user — start onboarding
        _analytics.logEvent('onboarding_started');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => OnboardingFlow(
              displayName: user.displayName ?? 'there',
              onComplete: () {}, // unused — OnboardingFlow navigates directly
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sign-in failed. Check your connection and try again.';
        });
      }
    }
  }

  void _handleGuestMode() {
    _analytics.logEvent('sign_in_method', {'method': 'guest'});
    _analytics.logEvent('onboarding_started');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnboardingFlow(
          displayName: 'there',
          isGuest: true,
          onComplete: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),

              // ── Eyebrow ──────────────────────────────────────
              const ElioEyebrow('meet elio'),
              const SizedBox(height: 16),

              // ── Hero heading ──────────────────────────────────
              const ElioHeroHeading(
                lines: ['already knows', 'your kitchen'],
                amberLastLine: true,
              ),

              const SizedBox(height: 20),

              // ── Tagline ───────────────────────────────────────
              Text(
                "tell elio what's fresh today.\nget a recipe in seconds.",
                style: ElioTextStyles.body,
              ),

              const Spacer(flex: 1),

              // ── Value props ───────────────────────────────────
              _ValueProp(
                icon: Icons.kitchen_outlined,
                title: 'Knows your pantry',
                subtitle: 'Set it once. Elio remembers your staples forever.',
              ),
              const SizedBox(height: 16),
              _ValueProp(
                icon: Icons.auto_awesome_outlined,
                title: 'AI that actually cooks',
                subtitle: 'Gemini 2.0 Flash generates real, practical recipes.',
              ),
              const SizedBox(height: 16),
              _ValueProp(
                icon: Icons.people_outline,
                title: 'Built for your household',
                subtitle: 'Dietary needs for everyone, always respected.',
              ),

              const Spacer(flex: 2),

              // ── Error message ─────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: ElioColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: ElioTextStyles.bodySmall.copyWith(color: ElioColors.error),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Google Sign-In button ─────────────────────────
              ElioBigButton(
                label: 'Continue with Google',
                trailingIcon: Icons.chevron_right,
                loading: _isLoading,
                onTap: _isLoading ? null : _handleGoogleSignIn,
              ),
              const SizedBox(height: 12),

              // ── Email sign-in button ─────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EmailLoginScreen(),
                            ),
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ElioColors.navy,
                    side: const BorderSide(color: ElioColors.navy, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    backgroundColor: Colors.transparent,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.email_outlined, size: 20, color: ElioColors.navy),
                      const SizedBox(width: 10),
                      Text(
                        'Sign in with email',
                        style: ElioTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: ElioColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Guest bypass (de-emphasised) ───────────────────
              Center(
                child: TextButton(
                  onPressed: _handleGuestMode,
                  style: TextButton.styleFrom(
                    foregroundColor: ElioColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Try without an account',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: ElioColors.textMuted,
                      decoration: TextDecoration.underline,
                      decorationColor: ElioColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Privacy note ──────────────────────────────────
              Center(
                child: Text(
                  'by continuing, you agree to our terms & privacy policy.',
                  style: ElioTextStyles.bodySmall.copyWith(color: ElioColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueProp extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ValueProp({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ElioColors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: ElioColors.amber, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ElioText.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
