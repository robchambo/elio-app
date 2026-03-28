import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:elio_app/main.dart' as app;

/// Smoke test: verifies the app launches without crashing.
/// Run with: flutter test integration_test/ --flavor prod -d <device-id>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches without crashing', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // If we get here, the app launched successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
