import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/analytics_service.dart';
import '../../theme/elio_theme.dart';
import '../shell/app_shell.dart';
import 'email_register_screen.dart';

// ─────────────────────────────────────────────
// EmailLoginScreen
// Email + password sign-in for Elio.
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
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
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
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
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
      backgroundColor: ElioColors.white,
      appBar: AppBar(
        backgroundColor: ElioColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ElioColors.navy),
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
                    color: ElioColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

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
                    fillColor: ElioColors.offWhite,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: ElioColors.amber,
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
                    fillColor: ElioColors.offWhite,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: ElioColors.amber,
                        width: 1.5,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: ElioColors.textMuted,
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
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ElioColors.amber,
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
                      backgroundColor: ElioColors.amber,
                      foregroundColor: ElioColors.white,
                      disabledBackgroundColor:
                          ElioColors.amber.withValues(alpha: 0.5),
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
                              color: ElioColors.white,
                            ),
                          )
                        : Text(
                            'Sign in',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ElioColors.white,
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
                          color: ElioColors.textSecondary,
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
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ElioColors.amber,
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
