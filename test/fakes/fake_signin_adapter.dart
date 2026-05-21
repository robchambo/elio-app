import 'package:flutter/material.dart';

import 'package:elio_app/screens/onboarding/screen15_account.dart';

// ─────────────────────────────────────────────
// FakeSignInAdapter — records provider taps and returns the configured
// UID per provider (null → failure path).
// ─────────────────────────────────────────────

class FakeSignInAdapter implements OnboardingSignInAdapter {
  String? appleUid;
  String? googleUid;
  String? emailUid;
  int appleCalls = 0;
  int googleCalls = 0;
  int emailCalls = 0;

  FakeSignInAdapter({this.appleUid, this.googleUid, this.emailUid});

  @override
  Future<String?> signInWithApple() async {
    appleCalls++;
    return appleUid;
  }

  @override
  Future<String?> signInWithGoogle() async {
    googleCalls++;
    return googleUid;
  }

  @override
  Future<String?> signInWithEmail(BuildContext context) async {
    emailCalls++;
    return emailUid;
  }
}
