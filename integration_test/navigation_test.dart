import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:elio_app/screens/home/home_screen.dart';

/// Integration tests for key navigation paths.
///
/// Verifies:
///   - Home -> Profile -> back to Home
///   - Home -> Meal Plan -> back to Home
///   - Home -> History -> back to Home
///
/// These tests launch HomeScreen directly in guest mode to avoid
/// needing to go through the full onboarding flow.
///
/// Run with: flutter test integration_test/navigation_test.dart --flavor prod -d [device-id]
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Helper to launch HomeScreen directly in guest mode.
  Future<void> launchHomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(isGuest: true),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  group('Navigation', () {
    testWidgets('Home -> Profile -> back to Home', (tester) async {
      await launchHomeScreen(tester);

      // Verify we are on HomeScreen by checking for the perishables header.
      expect(
        find.text("What's fresh today?"),
        findsOneWidget,
        reason: 'HomeScreen should be visible initially',
      );

      // The profile avatar is a circular Container in the header.
      // It is a GestureDetector wrapping a Container with BoxShape.circle.
      // In guest mode, the initials will be empty or default.
      // Find the profile avatar by looking for the circle-shaped container
      // in the header area. The avatar is a 36x36 navy circle.
      // We can find it by type — there should be a GestureDetector near the wordmark.

      // The profile avatar shows initials inside a navy circle.
      // In guest mode with no user data, the initials may be empty.
      // Find all GestureDetectors and tap the one in the header row.
      // A safer approach: the header has a Row with the wordmark and avatar.
      // The avatar Container is 36x36 with BoxShape.circle.

      // Tap the profile area (top-right of the header).
      // The profile avatar is inside a GestureDetector at the end of the header Row.
      // We look for it by finding the specific Container decoration.
      final avatarFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
            (widget.decoration as BoxDecoration).color != null,
      );

      // There may be multiple circular containers; tap the first one (the avatar).
      expect(avatarFinder, findsWidgets,
          reason: 'Profile avatar (circle container) should exist');
      await tester.tap(avatarFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify we navigated away from HomeScreen.
      expect(
        find.text("What's fresh today?"),
        findsNothing,
        reason: 'HomeScreen should not be visible after navigating to ProfileScreen',
      );

      // Navigate back using the system back button / Navigator pop.
      // ProfileScreen should have a back button in the AppBar or a gesture.
      // Try finding a back button icon.
      final backButton = find.byType(BackButton);
      final backIcon = find.byIcon(Icons.arrow_back);
      final backIconIos = find.byIcon(Icons.arrow_back_ios);
      final backIconNew = find.byIcon(Icons.arrow_back_ios_new);

      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
      } else if (backIcon.evaluate().isNotEmpty) {
        await tester.tap(backIcon.first);
      } else if (backIconIos.evaluate().isNotEmpty) {
        await tester.tap(backIconIos.first);
      } else if (backIconNew.evaluate().isNotEmpty) {
        await tester.tap(backIconNew.first);
      } else {
        // Fall back to Navigator.pop via the system back gesture.
        // Use the pageBack method from the binding.
        final dynamic binding = tester.binding;
        if (binding is IntegrationTestWidgetsFlutterBinding) {
          // Simulate system back.
          await tester.binding.handlePopRoute();
        }
      }

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify we are back on HomeScreen.
      expect(
        find.text("What's fresh today?"),
        findsOneWidget,
        reason: 'Should return to HomeScreen after navigating back from ProfileScreen',
      );
    });

    testWidgets('Home -> Meal Plan -> back to Home', (tester) async {
      await launchHomeScreen(tester);

      // Scroll to the meal planner banner.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      // Tap the meal planner banner.
      final bannerFinder = find.text('Plan your week');
      expect(bannerFinder, findsOneWidget,
          reason: 'Meal planner banner should be visible');

      await tester.tap(bannerFinder);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify we navigated away from HomeScreen.
      expect(
        find.text("What's fresh today?"),
        findsNothing,
        reason: 'HomeScreen should not be visible after navigating to MealPlanScreen',
      );

      // Navigate back.
      final backButton = find.byType(BackButton);
      final backIcon = find.byIcon(Icons.arrow_back);
      final backIconIos = find.byIcon(Icons.arrow_back_ios);
      final backIconNew = find.byIcon(Icons.arrow_back_ios_new);

      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
      } else if (backIcon.evaluate().isNotEmpty) {
        await tester.tap(backIcon.first);
      } else if (backIconIos.evaluate().isNotEmpty) {
        await tester.tap(backIconIos.first);
      } else if (backIconNew.evaluate().isNotEmpty) {
        await tester.tap(backIconNew.first);
      } else {
        await tester.binding.handlePopRoute();
      }

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify we are back on HomeScreen.
      expect(
        find.text("What's fresh today?"),
        findsOneWidget,
        reason: 'Should return to HomeScreen after navigating back from MealPlanScreen',
      );
    });

    testWidgets('Home -> History (via View all) -> back to Home',
        (tester) async {
      await launchHomeScreen(tester);

      // Scroll to the recent recipes section to find "View all" link.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      // Tap "View all" to navigate to HistoryScreen.
      final viewAllFinder = find.text('View all');
      expect(viewAllFinder, findsOneWidget,
          reason: '"View all" link should be visible in recent recipes section');

      await tester.tap(viewAllFinder);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify we navigated away from HomeScreen.
      expect(
        find.text("What's fresh today?"),
        findsNothing,
        reason: 'HomeScreen should not be visible after navigating to HistoryScreen',
      );

      // Navigate back.
      final backButton = find.byType(BackButton);
      final backIcon = find.byIcon(Icons.arrow_back);
      final backIconIos = find.byIcon(Icons.arrow_back_ios);
      final backIconNew = find.byIcon(Icons.arrow_back_ios_new);

      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
      } else if (backIcon.evaluate().isNotEmpty) {
        await tester.tap(backIcon.first);
      } else if (backIconIos.evaluate().isNotEmpty) {
        await tester.tap(backIconIos.first);
      } else if (backIconNew.evaluate().isNotEmpty) {
        await tester.tap(backIconNew.first);
      } else {
        await tester.binding.handlePopRoute();
      }

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify we are back on HomeScreen.
      expect(
        find.text("What's fresh today?"),
        findsOneWidget,
        reason: 'Should return to HomeScreen after navigating back from HistoryScreen',
      );
    });
  });
}
