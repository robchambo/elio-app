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

  bool get _hasTrial => widget.controller.state.entitlement == 'pro';

  @override
  void initState() {
    super.initState();
    // Fire `onboarding_account_viewed` once per entry — drives the
    // top-of-funnel view count per-goal per-trial-state (spec §Analytics).
    _analytics.logEvent(
      'onboarding_account_viewed',
      {
        'goal': widget.controller.state.userGoal ?? 'unset',
        'has_trial': _hasTrial,
      },
    );
  }

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
    _analytics.logEvent(
      'onboarding_account_skipped',
      {'has_trial': _hasTrial},
    );
    _analytics.logEvent(
      'onboarding_complete',
      {'path': 'guest', 'has_trial': _hasTrial},
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: widget.destinationBuilder ?? (_) => const AppShell(),
      ),
    );
  }

  /// Handles a provider tap's completion.
  ///
  /// [comingSoonMessage] is used when the button is wired to a not-yet-
  /// implemented provider (Apple Sign-In lands Sprint 19; Email magic-link
  /// lands v1.1). For those, a null [uid] means "placeholder", not
  /// "failure" — we surface a coming-soon toast instead of the generic
  /// "Couldn't sign in" copy so we don't advertise a broken button.
  Future<void> _finishWithSignIn(
    String? uid,
    String provider, {
    String? comingSoonMessage,
  }) async {
    if (uid == null) {
      _analytics.logEvent(
        'onboarding_account_signin_failed',
        {
          'provider': provider,
          'reason': comingSoonMessage == null ? 'failure' : 'not_implemented',
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            comingSoonMessage ??
                'Couldn\'t sign in with $provider — try Email instead.',
          ),
        ),
      );
      return;
    }
    _analytics.logEvent(
      'onboarding_account_signin_success',
      {'provider': provider},
    );
    await _migration.migrateGuestToFirestore(uid, widget.controller.state);
    _analytics.logEvent(
      'onboarding_complete',
      {'path': 'account', 'has_trial': _hasTrial},
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: widget.destinationBuilder ?? (_) => const AppShell(),
      ),
    );
  }

  void _openLegal(String which) {
    _analytics.logEvent(
      'onboarding_legal_tapped',
      {'screen': 'account', 'which': which},
    );
    final label = which == 'terms' ? 'Terms of Service' : 'Privacy Policy';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — opens at elio.app/$which at launch.'),
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
              // NOTE (Sprint 16.2): the recipe-thumbnail anchor described
              // in docs/onboarding/15-account.md §Visual spec is deferred
              // pending Kate's hero imagery — sits in the Spacer above the
              // provider buttons when it lands. Flagged for Kate.
              if (isIOS) ...[
                ElioProviderSignInButton(
                  key: const Key('screen15AppleButton'),
                  kind: ProviderButtonKind.apple,
                  onPressed: _busy
                      ? () {}
                      : () => _withBusy(() async {
                            _analytics.logEvent(
                              'onboarding_account_signin_tapped',
                              const {'provider': 'apple'},
                            );
                            final uid = await _adapter.signInWithApple();
                            // Apple Sign-In proper lands Sprint 19; adapter
                            // returns null meantime — surface a honest
                            // "coming soon" toast rather than a generic
                            // failure so we don't advertise a broken button.
                            await _finishWithSignIn(
                              uid,
                              'apple',
                              comingSoonMessage:
                                  'Sign in with Apple is coming soon — use Google for now.',
                            );
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
                          _analytics.logEvent(
                            'onboarding_account_signin_tapped',
                            const {'provider': 'google'},
                          );
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
                          _analytics.logEvent(
                            'onboarding_account_signin_tapped',
                            const {'provider': 'email'},
                          );
                          final uid = await _adapter.signInWithEmail(context);
                          // Email magic-link lands v1.1 — adapter returns
                          // null in v1. Same "coming soon" treatment as
                          // Apple: honest, doesn't trap, keeps the tap
                          // as a signal users want this provider.
                          await _finishWithSignIn(
                            uid,
                            'email',
                            comingSoonMessage:
                                'Email sign-in is coming soon — use Google for now.',
                          );
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
              // Tappable Terms + Privacy — mirrors screen 14 paywall
              // footer. Real URLs land Sprint 17; v1 shows a placeholder
              // SnackBar so the links render and fire analytics.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'By continuing, you agree to our ',
                    style: ElioTextStyles.bodySmall.copyWith(
                      color: ElioColors.textMuted,
                    ),
                  ),
                  GestureDetector(
                    key: const Key('screen15TermsLink'),
                    onTap: () => _openLegal('terms'),
                    child: Text(
                      'Terms',
                      style: ElioTextStyles.bodySmall.copyWith(
                        color: ElioColors.textSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Text(
                    ' and ',
                    style: ElioTextStyles.bodySmall.copyWith(
                      color: ElioColors.textMuted,
                    ),
                  ),
                  GestureDetector(
                    key: const Key('screen15PrivacyLink'),
                    onTap: () => _openLegal('privacy'),
                    child: Text(
                      'Privacy Policy',
                      style: ElioTextStyles.bodySmall.copyWith(
                        color: ElioColors.textSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Text(
                    '.',
                    style: ElioTextStyles.bodySmall.copyWith(
                      color: ElioColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
