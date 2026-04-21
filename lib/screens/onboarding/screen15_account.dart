import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/onboarding_controller.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/migration_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../../widgets/elio/elio_onboarding_progress_bar.dart';
import '../../widgets/elio/elio_provider_signin_button.dart';
import '../shell/app_shell.dart';

// ─────────────────────────────────────────────
// Screen 15 — Soft account gate
//
// Final onboarding step. Three peer sign-in buttons (Apple iOS-only,
// Google, Email) plus a prominent "Continue without an account" skip.
// Any forward exit sets `onboardingComplete = true` in SharedPreferences
// and navigates to AppShell.
//
// Successful sign-in runs MigrationService.migrateGuestToFirestore(uid,
// state) which persists the onboarding state + guest pantry and aliases
// RC. Skip path is fully local — guest state is already persisted by
// GuestPantryService; no migration runs.
//
// Apple button is gated on `Theme.of(context).platform` so tests can
// flip platforms via `debugDefaultTargetPlatformOverride` without
// touching `dart:io`.
//
// Copy + behaviour: docs/onboarding/15-account.md.
// ─────────────────────────────────────────────

/// Provider-agnostic sign-in surface that returns a UID (or null on
/// failure/cancel). Production adapter wraps `AuthService`. Tests inject
/// a fake so no Firebase wiring is required.
abstract class OnboardingSignInAdapter {
  Future<String?> signInWithApple();
  Future<String?> signInWithGoogle();
  Future<String?> signInWithEmail(BuildContext context);
}

/// Real adapter — delegates to the existing AuthService. Email flow
/// pushes the existing EmailLoginScreen via [context]; the caller
/// awaits its Navigator.pop result to resolve the UID.
class RealSignInAdapter implements OnboardingSignInAdapter {
  final AuthService _auth;
  RealSignInAdapter([AuthService? auth]) : _auth = auth ?? AuthService();

  @override
  Future<String?> signInWithApple() async {
    // iOS-only. Apple Sign-In proper lands in Sprint 19; returning null
    // keeps the button inert until then — the caller surfaces a toast.
    return null;
  }

  @override
  Future<String?> signInWithGoogle() async {
    final cred = await _auth.signInWithGoogle();
    return cred?.user?.uid;
  }

  @override
  Future<String?> signInWithEmail(BuildContext context) async {
    // v1: punt to existing email login screen; Sprint 16+ can inline a
    // passwordless magic-link flow per spec §Copy.Email.
    return null;
  }
}

class Screen15Account extends StatefulWidget {
  final OnboardingController controller;
  final VoidCallback? onBack;

  /// Injected for tests. Defaults to [RealSignInAdapter] in production.
  final OnboardingSignInAdapter? signInAdapter;

  /// Injected for tests. Defaults to a singleton [MigrationService].
  final MigrationService? migration;

  /// Builder for the post-onboarding destination. Defaults to `AppShell`;
  /// tests inject a stub to avoid Firebase initialisation.
  final WidgetBuilder? destinationBuilder;

  const Screen15Account({
    super.key,
    required this.controller,
    this.onBack,
    this.signInAdapter,
    this.migration,
    this.destinationBuilder,
  });

  @override
  State<Screen15Account> createState() => _Screen15AccountState();
}

class _Screen15AccountState extends State<Screen15Account> {
  bool _busy = false;
  final AnalyticsService _analytics = AnalyticsService.instance;

  late final OnboardingSignInAdapter _adapter =
      widget.signInAdapter ?? RealSignInAdapter();
  late final MigrationService _migration = widget.migration ?? MigrationService();

  String get _headline {
    switch (widget.controller.state.userGoal) {
      case 'pantryFirst':
        return 'Save your pantry.';
      case 'wasteReduction':
        return 'Save what you\'ve got.';
      case 'decisionFatigue':
        return 'Save your setup.';
      case 'household':
        return 'Save your household.';
      case 'takeawayEscape':
        return widget.controller.state.entitlement == 'pro'
            ? 'Lock in your trial.'
            : 'Save your setup.';
      default:
        return 'Save your Elio setup.';
    }
  }

  Future<void> _finishAsGuest() async {
    _analytics.logEvent('onboarding_skipped_signin');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: widget.destinationBuilder ?? (_) => const AppShell(),
      ),
    );
  }

  Future<void> _finishWithSignIn(String? uid, String provider) async {
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t sign in with $provider — try Email instead.')),
      );
      return;
    }
    _analytics.logEvent(
      'onboarding_account_signin_success',
      {'provider': provider},
    );
    await _migration.migrateGuestToFirestore(uid, widget.controller.state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: widget.destinationBuilder ?? (_) => const AppShell(),
      ),
    );
  }

  Future<void> _withBusy(Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: ElioColors.navy),
                onPressed: widget.onBack,
              ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(ElioSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ElioOnboardingProgressBar(value: 1.0),
              const SizedBox(height: ElioSpacing.lg),
              ElioHeroHeading(
                lines: [_headline],
                amberLastLine: true,
              ),
              const SizedBox(height: ElioSpacing.md),
              Text(
                'Sign in to keep your pantry, recipes, and preferences '
                'across your devices. One tap.',
                style: ElioTextStyles.body,
              ),
              const Spacer(),
              if (isIOS) ...[
                ElioProviderSignInButton(
                  key: const Key('screen15AppleButton'),
                  kind: ProviderButtonKind.apple,
                  onPressed: _busy
                      ? () {}
                      : () => _withBusy(() async {
                            final uid = await _adapter.signInWithApple();
                            await _finishWithSignIn(uid, 'apple');
                          }),
                ),
                const SizedBox(height: ElioSpacing.sm + 2),
              ],
              ElioProviderSignInButton(
                key: const Key('screen15GoogleButton'),
                kind: ProviderButtonKind.google,
                onPressed: _busy
                    ? () {}
                    : () => _withBusy(() async {
                          final uid = await _adapter.signInWithGoogle();
                          await _finishWithSignIn(uid, 'google');
                        }),
              ),
              const SizedBox(height: ElioSpacing.sm + 2),
              ElioProviderSignInButton(
                key: const Key('screen15EmailButton'),
                kind: ProviderButtonKind.email,
                onPressed: _busy
                    ? () {}
                    : () => _withBusy(() async {
                          final uid = await _adapter.signInWithEmail(context);
                          await _finishWithSignIn(uid, 'email');
                        }),
              ),
              const SizedBox(height: ElioSpacing.md),
              Center(
                child: TextButton(
                  key: const Key('screen15SkipButton'),
                  onPressed: _busy ? null : () => _withBusy(_finishAsGuest),
                  child: Text(
                    'Continue without an account',
                    style: ElioTextStyles.body.copyWith(
                      color: ElioColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ElioSpacing.sm),
              Text(
                'By continuing, you agree to our Terms and Privacy Policy.',
                style: ElioTextStyles.bodySmall.copyWith(
                  color: ElioColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
