// test/screens/account/password_prompt_test.dart
//
// Sprint 17 — widget tests for the Email/password Delete Account reauth
// dialog. Pure UI helper, no Firebase wiring needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/screens/account/password_prompt.dart';

Future<Future<String?>> _showPrompt(WidgetTester tester, {String email = 'rob@example.com'}) async {
  late Future<String?> pending;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                pending = promptForPassword(context, email: email);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return pending;
}

void main() {
  group('promptForPassword', () {
    testWidgets('renders dialog with email + obscured password field', (tester) async {
      await _showPrompt(tester, email: 'kate@studioeyespy.com');

      expect(find.text('Confirm your password'), findsOneWidget);
      expect(
        find.textContaining('kate@studioeyespy.com'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
      expect(field.autofocus, isTrue);
    });

    testWidgets('Cancel returns null', (tester) async {
      final pending = await _showPrompt(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await pending, isNull);
    });

    testWidgets('Confirm returns the entered password', (tester) async {
      final pending = await _showPrompt(tester);

      await tester.enterText(find.byType(TextField), 'hunter2');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(await pending, 'hunter2');
    });

    testWidgets('keyboard submit returns the entered password', (tester) async {
      final pending = await _showPrompt(tester);

      await tester.enterText(find.byType(TextField), 'correcthorsebattery');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(await pending, 'correcthorsebattery');
    });

    testWidgets('Confirm with empty field returns empty string (caller treats as cancel)', (tester) async {
      final pending = await _showPrompt(tester);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(await pending, '');
    });

    testWidgets('barrier tap does not dismiss', (tester) async {
      final pending = await _showPrompt(tester);

      // Tap outside the dialog (top-left corner of the screen) — should be a no-op.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // Dialog still visible.
      expect(find.text('Confirm your password'), findsOneWidget);

      // Clean up so the future resolves before the test ends.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await pending, isNull);
    });
  });
}
