import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/elio_theme.dart';
import 'onboarding_flow.dart';
import '../home/home_screen.dart';

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

  Future<void> _handleGoogleSignIn() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final credential = await _auth.signInWithGoogle();
      if (credential == null) {
        setState(() => _isLoading = false);
        return;
      }

      final user = credential.user;
      if (user == null) {
        setState(() { _isLoading = false; _errorMessage = 'Sign-in failed. Please try again.'; });
        return;
      }

      // Check if user has completed onboarding
      final isComplete = await _firestore.isOnboardingComplete();

      if (!mounted) return;

      if (isComplete) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnboardingFlow(
              displayName: user.displayName ?? 'there',
              onComplete: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),

              // ── Wordmark ──────────────────────────────────────
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'EL',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: ElioColors.navy,
                        height: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: 'i',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: ElioColors.amber,
                        height: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: 'O',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: ElioColors.navy,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Tagline ───────────────────────────────────────
              Text(
                'Already knows your kitchen.',
                style: ElioText.headingLarge.copyWith(
                  color: ElioColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell Elio what\'s fresh today.\nGet a recipe in seconds.',
                style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
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
                    style: ElioText.bodyMedium.copyWith(color: ElioColors.error),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Google Sign-In button ─────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ElioColors.navy,
                    side: const BorderSide(color: ElioColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: ElioColors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: ElioColors.navy,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google G logo
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(shape: BoxShape.circle),
                              child: const Icon(Icons.g_mobiledata, size: 22, color: Colors.red),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ElioColors.navy,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Privacy note ──────────────────────────────────
              Center(
                child: Text(
                  'By continuing, you agree to our Terms & Privacy Policy.',
                  style: ElioText.label.copyWith(
                    color: ElioColors.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
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
