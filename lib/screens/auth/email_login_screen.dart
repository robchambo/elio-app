import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/analytics_service.dart';
import '../../services/error_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_provider_signin_button.dart';
import '../shell/app_shell.dart';
import 'email_register_screen.dart';

// ─────────────────────────────────────────────
// EmailLoginScreen
//
// "I already have an account" landing surface. Despite the class name,
// this is the multi-provider sign-in screen — Google primary, Apple on
// iOS (coming-soon toast until Sprint 19), and the email + password form
// below an "or sign in with email" divider.
//
// Pre-19 May 2026 this was email-only. Rob's on-device feedback was
// that real users tap "I already have an account" expecting Google
// because that's what they used to create the account on screen 15.
// File / class name kept to avoid churn at the screen 01 call site.
// ─────────────────────────────────────────────

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final AuthService _auth = AuthService();
  final AnalyticsService _analytics = AnalyticsService.instance;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Provider sign-in: Google ────────────────────────────────────
  //
  // Mirrors screen 15's Google path. On success we land in AppShell —
  // existing-user flow, no onboarding migration.
  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    _analytics.logEvent('sign_in_method', {'method': 'google'});

    try {
      final credential = await _auth.signInWithGoogle();
      if (credential?.user == null) {
        // User cancelled the Google account picker — silent return.
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (route) => false,
      );
    } catch (e) {
      ErrorService.log('signin_google', e);
      if (mounted) {
        setState(() => _isLoading = false);
        _showError("Couldn't sign in with Google. Check your connection and try again.");
      }
    }
  }

  // Apple Sign-In proper lands Sprint 19 (matches screen 15's "coming
  // soon" treatment — keeps the tap as a demand signal but doesn't
  // advertise a broken button).
  void _handleAppleSignIn() {
    _analytics.logEvent('sign_in_method', {'method': 'apple'});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sign in with Apple is coming soon — use Google for now.',
          style: ElioTextStyles.uiLabelStyle.copyWith(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: ElioColors.espresso,
      ),
    );
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    _analytics.logEvent('sign_in_method', {'method': 'email'});

    try {
      final credential = await _auth.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final user = credential.user;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError('Sign-in failed. Please try again.');
        }
        return;
      }

      // Sprint 16 rebuild: sign-in from AuthGate's login path is reserved
      // for existing users. If a user reaches the login flow, we treat them
      // as onboarded and land them in the AppShell. First-time users are
      // routed through the new 15-screen onboarding flow which terminates
      // at its own account screen.
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(_mapFirebaseError(e.code));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Sign-in failed. Check your connection and try again.');
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email address first.');
      return;
    }

    try {
      await _auth.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Password reset email sent to $email',
              style: ElioTextStyles.uiLabelStyle.copyWith(color: Colors.white, fontSize: 14),
            ),
            backgroundColor: ElioColors.success,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_mapFirebaseError(e.code));
    } catch (e) {
      if (mounted) _showError('Could not send reset email. Try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: ElioTextStyles.uiLabelStyle.copyWith(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: ElioColors.error,
      ),
    );
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      appBar: AppBar(
        backgroundColor: ElioColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ElioColors.espresso),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────
                Text('Welcome back', style: ElioText.displayMedium),
                const SizedBox(height: 6),
                Text(
                  'Sign in to your Elio account.',
                  style: ElioText.bodyLarge.copyWith(
                    color: ElioColors.mocha,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Provider sign-in ────────────────────────────
                // Google first — it's what most existing users created
                // their account with on screen 15.
                if (Platform.isIOS) ...[
                  ElioProviderSignInButton(
                    kind: ProviderButtonKind.apple,
                    onPressed: _isLoading ? () {} : _handleAppleSignIn,
                  ),
                  const SizedBox(height: ElioSpacing.sm + 2),
                ],
                ElioProviderSignInButton(
                  kind: ProviderButtonKind.google,
                  onPressed: _isLoading ? () {} : _handleGoogleSignIn,
                ),
                const SizedBox(height: 24),

                // ── Divider ─────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: ElioColors.rule,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or sign in with email',
                        style: ElioTextStyles.bodySmallStyle.copyWith(
                          color: ElioColors.mocha,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: ElioColors.rule,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Email field ─────────────────────────────────
                Text('Email', style: ElioText.label),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  style: ElioText.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    filled: true,
                    fillColor: ElioColors.cream,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: ElioColors.terracotta,
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email.';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Password field ──────────────────────────────
                Text('Password', style: ElioText.label),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  style: ElioText.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Your password',
                    filled: true,
                    fillColor: ElioColors.cream,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: ElioColors.terracotta,
                        width: 1.5,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: ElioColors.mocha,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleSignIn(),
                ),
                const SizedBox(height: 8),

                // ── Forgot password ─────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _handleForgotPassword,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot password?',
                      style: ElioTextStyles.uiLabelStyle.copyWith(
                        fontSize: 13,
                        color: ElioColors.terracotta,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Sign in button ──────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ElioColors.terracotta,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          ElioColors.terracotta.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Sign in',
                            style: ElioTextStyles.uiLabelStyle.copyWith(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Register link ───────────────────────────────
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: ElioText.bodyMedium.copyWith(
                          color: ElioColors.mocha,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const EmailRegisterScreen(),
                            ),
                          );
                        },
                        // Sprint 16.2: 8-px pad so the hit-area clears
                        // the ~44-px accessibility minimum. Raw Text
                        // was ~20 px tall.
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Register',
                            style: ElioTextStyles.uiLabelStyle.copyWith(
                              fontSize: 14,
                              color: ElioColors.terracotta,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
