import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'entitlement_service.dart';
import 'history_service.dart';

// ─────────────────────────────────────────────
// AuthService
// Handles Firebase Authentication for Elio.
// Uses google_sign_in v6 API.
// ─────────────────────────────────────────────

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign in with Google using v6 API
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Set the display name on the Firebase user profile
      await credential.user?.updateDisplayName(displayName);

      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Send password reset email
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    // 21 May 2026 — defensive in-memory cache clear so a sign-out
    // followed by sign-in (different account or same) doesn't show
    // the previous user's local-only recipe history. Touches no disk
    // state; safe to call on every sign-out. (Sprint 17: history is now
    // uid-scoped on disk too, so the cache also auto-invalidates on the
    // uid change — this stays as belt-and-braces.)
    HistoryService.clearCache();
    // Sprint 17 (28 May 2026) — clear cached entitlement state so a
    // stale signed-in tier / weekly-generation count doesn't bleed into
    // the guest session or the next account on this device.
    EntitlementService.instance.reset();
  }
}
