import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'theme/elio_theme.dart';
import 'screens/onboarding/screen0_welcome.dart';
import 'screens/home/home_screen.dart';
import 'services/firestore_service.dart';
import 'services/analytics_service.dart';

// ─────────────────────────────────────────────
// Elio — AI Recipe Generator
// "Already knows your kitchen."
//
// Entry point: initialises Firebase + Crashlytics,
// then routes to WelcomeScreen or HomeScreen based
// on auth state. Guest mode bypasses Firebase.
// ─────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Pass all uncaught Flutter framework errors to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Initialise Analytics (sets user properties, enables collection)
    await AnalyticsService.instance.init();
  } catch (_) {
    // Firebase init may fail with placeholder credentials — app still
    // functions in guest mode.
  }

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
      navigatorObservers: [AnalyticsService.instance.observer],
      home: const _AuthGate(),
    );
  }
}

// ─── Auth gate ────────────────────────────────────────────────────────────────
// Listens to Firebase auth state and routes accordingly.
// Falls back to WelcomeScreen if Firebase is not available.

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _safeAuthStream(),
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

        // Not signed in (or Firebase unavailable)
        if (!snapshot.hasData || snapshot.data == null) {
          return const WelcomeScreen();
        }

        // Signed in — check onboarding
        return const _OnboardingGate();
      },
    );
  }

  Stream<User?> _safeAuthStream() {
    try {
      return FirebaseAuth.instance.authStateChanges();
    } catch (_) {
      // Firebase not available — emit null immediately so we show WelcomeScreen
      return Stream.value(null);
    }
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
