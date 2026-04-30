import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'theme/elio_theme.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/shell/app_shell.dart';
import 'services/analytics_service.dart';
import 'services/remote_config_service.dart';
import 'services/notification_service.dart';

// ─────────────────────────────────────────────
// Elio — AI Recipe Generator
// "Already knows your kitchen."
//
// Entry point: initialises Firebase + Crashlytics, then routes via
// AuthGate which keys off the `onboardingComplete` SharedPreferences
// flag (Sprint 16 rebuild) rather than Firebase auth state. The
// onboarding flow itself is guest-first — sign-in is deferred to
// screen 15.
// ─────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Pass all uncaught Flutter framework errors to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Catch async errors not handled by Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Parallelise Analytics + Remote Config (both independent after Firebase)
    await Future.wait([
      AnalyticsService.instance.init(),
      RemoteConfigService.instance.init(),
    ]);

    // Lightweight notification init (register background handler + listeners only)
    // Permission request is deferred to HomeScreen first load.
    await NotificationService.instance.init();

    // PurchaseService is deferred to first use (lazy init) to reduce cold-start time.
  } catch (_) {
    // Firebase init may fail with placeholder credentials — app still
    // functions in guest mode.
  }

  runApp(const ElioApp());
}

class ElioApp extends StatelessWidget {
  const ElioApp({super.key});

  static final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    // Give the notification service access to scaffold messenger for snackbars
    NotificationService.instance.scaffoldMessengerKey = _scaffoldMessengerKey;

    return MaterialApp(
      title: 'Elio',
      theme: elioTheme(),
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      navigatorObservers: [
        if (AnalyticsService.instance.observer != null)
          AnalyticsService.instance.observer!,
      ],
      home: const AuthGate(),
    );
  }
}

// ─── Auth gate ────────────────────────────────────────────────────────────────
// Sprint 16 rebuild: routes based on the `onboardingComplete` flag in
// SharedPreferences (set at the end of the new 15-screen flow) rather
// than Firebase auth state. This supports the deferred-sign-in model
// where users can complete onboarding fully in guest mode.

class AuthGate extends StatelessWidget {
  /// Optional override of the post-onboarding root. Production leaves this
  /// null and we render [AppShell]. Tests can inject a lightweight stand-in
  /// to avoid pulling Firebase into the widget tree.
  final WidgetBuilder? appShellBuilder;

  /// Optional override of the pre-onboarding root. Production renders the
  /// [OnboardingFlow] stub; tests can inject a stand-in.
  final WidgetBuilder? onboardingBuilder;

  const AuthGate({
    super.key,
    this.appShellBuilder,
    this.onboardingBuilder,
  });

  Future<bool> _isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboardingComplete') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isOnboardingComplete(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: ElioColors.cream,
            body: Center(
              child: CircularProgressIndicator(color: ElioColors.terracotta),
            ),
          );
        }
        if (snapshot.data == true) {
          return KeyedSubtree(
            key: const Key('appShellRoot'),
            child: appShellBuilder?.call(context) ?? const AppShell(),
          );
        }
        return KeyedSubtree(
          key: const Key('onboardingFlowRoot'),
          child: onboardingBuilder?.call(context) ??
              const OnboardingFlow(
                displayName: 'there',
                onComplete: _noop,
              ),
        );
      },
    );
  }
}

void _noop() {}
