import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/elio_theme.dart';
import 'screens/onboarding/screen0_welcome.dart';
import 'screens/home/home_screen.dart';
import 'services/firestore_service.dart';

// ─────────────────────────────────────────────
// Elio — AI Recipe Generator
// "Already knows your kitchen."
//
// Entry point: initialises Firebase, then routes
// to WelcomeScreen or HomeScreen based on auth state.
// ─────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ElioApp());
}

class ElioApp extends StatelessWidget {
  const ElioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elio',
      theme: elioTheme(),
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}

// ─── Auth gate ────────────────────────────────────────────────────────────────
// Listens to Firebase auth state and routes accordingly.

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: ElioColors.white,
            body: Center(
              child: CircularProgressIndicator(color: ElioColors.amber),
            ),
          );
        }

        // Not signed in
        if (!snapshot.hasData || snapshot.data == null) {
          return const WelcomeScreen();
        }

        // Signed in — check onboarding
        return const _OnboardingGate();
      },
    );
  }
}

// ─── Onboarding gate ──────────────────────────────────────────────────────────
// Checks Firestore to see if onboarding is complete.

class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate();

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  final FirestoreService _firestore = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _firestore.isOnboardingComplete(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: ElioColors.white,
            body: Center(
              child: CircularProgressIndicator(color: ElioColors.amber),
            ),
          );
        }

        if (snapshot.data == true) {
          return const HomeScreen();
        }

        // Onboarding not complete — go back to welcome
        return const WelcomeScreen();
      },
    );
  }
}
