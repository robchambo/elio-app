import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/theme/elio_radii.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_big_button.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(theme: elioTheme(), home: Scaffold(body: child)));
}

// ─────────────────────────────────────────────
// ElioBigButton — keyboard-dismiss contract.
//
// Bug (Sprint 16.2 device smoke test): tapping Continue on an
// onboarding screen that owns a TextField leaves the keyboard open
// when the next screen appears — looks broken, blocks the new
// screen's tap targets.
//
// Fix: ElioBigButton unfocuses the primary focus before firing onTap.
// Everything in the onboarding flow uses ElioBigButton for forward
// nav, so a single intercept here covers the app globally.
// ─────────────────────────────────────────────

void main() {
  testWidgets('tapping ElioBigButton unfocuses any active TextField',
      (t) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    var tapped = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextField(focusNode: focusNode),
            ElioBigButton(
              label: 'Continue',
              onTap: () => tapped = true,
            ),
          ],
        ),
      ),
    ));

    focusNode.requestFocus();
    await t.pump();
    expect(focusNode.hasFocus, isTrue,
        reason: 'precondition: the field is focused before we tap');

    await t.tap(find.byType(ElioBigButton));
    await t.pump();

    expect(tapped, isTrue, reason: 'user onTap must still fire');
    expect(focusNode.hasFocus, isFalse,
        reason: 'tapping Continue should dismiss the keyboard globally');
  });

  testWidgets('null onTap does not crash on keyboard-dismiss attempt',
      (t) async {
    // Disabled state — tap is a no-op, but we still render a focused
    // field to prove the null-guard works when the button is inactive.
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextField(focusNode: focusNode),
            const ElioBigButton(label: 'Continue', onTap: null),
          ],
        ),
      ),
    ));

    focusNode.requestFocus();
    await t.pump();
    expect(focusNode.hasFocus, isTrue);

    await t.tap(find.byType(ElioBigButton));
    await t.pump();

    // Disabled button → no onTap → keyboard stays as the user left it.
    // The important assertion is "no crash".
    expect(find.byType(ElioBigButton), findsOneWidget);
  });

  // Sprint 16 rebrand — terracotta pill with white chevron.
  testWidgets('ElioBigButton uses terracotta background', (tester) async {
    await _pump(tester, ElioBigButton(label: 'Generate', onTap: () {}));
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ElioBigButton), matching: find.byType(DecoratedBox)).first,
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, ElioColors.terracotta);
  });

  testWidgets('ElioBigButton uses pill radius (ElioRadii.button)', (tester) async {
    await _pump(tester, ElioBigButton(label: 'Generate', onTap: () {}));
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ElioBigButton), matching: find.byType(DecoratedBox)).first,
    );
    final decoration = box.decoration as BoxDecoration;
    final radius = (decoration.borderRadius as BorderRadius).topLeft;
    expect(radius, Radius.circular(ElioRadii.button));
  });

  testWidgets('ElioBigButton renders trailing chevron icon by default', (tester) async {
    await _pump(tester, ElioBigButton(label: 'Generate', onTap: () {}));
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('ElioBigButton renders label text in white', (tester) async {
    await _pump(tester, ElioBigButton(label: 'Generate', onTap: () {}));
    final text = tester.widget<Text>(find.text('Generate'));
    expect(text.style?.color, Colors.white);
  });
}
