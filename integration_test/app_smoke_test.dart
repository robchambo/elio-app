import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:elio_app/main.dart' as app;

/// Smoke test: verifies the app launches without crashing.
///
/// This test handles Firebase initialization failure gracefully —
/// the app should still launch and show the WelcomeScreen in guest-compatible mode.
///
/// Run with: flutter test integration_test/app_smoke_test.dart --flavor prod -d [device-id]
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches without crashing', (tester) async {
    // Launch the app — Firebase.initializeApp() is wrapped in try/catch in main(),
    // so the app should start regardless of Firebase availability.
    app.main();

    // Give Firebase init + auth state stream time to resolve.
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Verify the MaterialApp rendered successfully.
    expect(
      find.byType(MaterialApp),
      findsOneWidget,
      reason: 'MaterialApp should be present after launch',
    );
  });

  testWidgets('App shows WelcomeScreen when not authenticated', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // The WelcomeScreen should be visible when no user is signed in.
    // Check for the tagline text which is unique to the welcome screen.
    expect(
      find.text('Already knows your kitchen.'),
      findsOneWidget,
      reason: 'WelcomeScreen tagline should be visible when not authenticated',
    );
  });

  testWidgets('WelcomeScreen contains essential UI elements', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Verify the Google Sign-In button text is present.
    expect(
      find.text('Continue with Google'),
      findsOneWidget,
      reason: 'Google Sign-In button should be visible on WelcomeScreen',
    );

    // Verify the guest mode link is present.
    expect(
      find.text('Try without an account'),
      findsOneWidget,
      reason: 'Guest mode link should be visible on WelcomeScreen',
    );

    // Verify the privacy note is present.
    expect(
      find.textContaining('Terms & Privacy Policy'),
      findsOneWidget,
      reason: 'Privacy note should be visible on WelcomeScreen',
    );
  });
}
