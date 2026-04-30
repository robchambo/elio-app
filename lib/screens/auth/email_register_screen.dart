import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/analytics_service.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../shell/app_shell.dart';
import 'email_login_screen.dart';

// ─────────────────────────────────────────────
// EmailRegisterScreen
// Email + password registration for Elio.
// ─────────────────────────────────────────────

class EmailRegisterScreen extends StatefulWidget {
  const EmailRegisterScreen({super.key});

  @override
  State<EmailRegisterScreen> createState() => _EmailRegisterScreenState();
}

class _EmailRegisterScreenState extends State<EmailRegisterScreen> {
  final AuthService _auth = AuthService();
  final AnalyticsService _analytics = AnalyticsService.instance;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    _analytics.logEvent('sign_in_method', {'method': 'email_register'});

    try {
      final credential = await _auth.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );

      final user = credential.user;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError('Registration failed. Please try again.');
        }
        return;
      }

      if (!mounted) return;

      // Sprint 16 rebuild: users who registered via the auth screens
      // (reached from screen 01 "I already have an account" or the
      // in-app sign-up) should land in the AppShell. The 15-screen
      // onboarding flow handles its own sign-up on screen 15.
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
        _showError('Registration failed. Check your connection and try again.');
      }
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
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email registration is not enabled.';
      default:
        return 'Registration failed. Please try again.';
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
                Text('Create your account', style: ElioText.displayMedium),
                const SizedBox(height: 6),
                Text(
                  'Get personalised recipes in seconds.',
                  style: ElioText.bodyLarge.copyWith(
                    color: ElioColors.mocha,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Name field ──────────────────────────────────
                Text('Name', style: ElioText.label),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  style: ElioText.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Your name',
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
                      return 'Please enter your name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

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
                  textInputAction: TextInputAction.next,
                  style: ElioText.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'At least 6 characters',
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
                      return 'Please enter a password.';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Confirm password field ──────────────────────
                Text('Confirm password', style: ElioText.label),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  style: ElioText.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Re-enter your password',
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
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: ElioColors.mocha,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password.';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleRegister(),
                ),
                const SizedBox(height: 32),

                // ── Create account button ───────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
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
                            'Create account',
                            style: ElioTextStyles.uiLabelStyle.copyWith(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Sign in link ────────────────────────────────
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: ElioText.bodyMedium.copyWith(
                          color: ElioColors.mocha,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const EmailLoginScreen(),
                            ),
                          );
                        },
                        // Sprint 16.2: 8-px pad so the hit-area clears
                        // the ~44-px accessibility minimum. Raw Text
                        // was ~20 px tall.
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Sign in',
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
