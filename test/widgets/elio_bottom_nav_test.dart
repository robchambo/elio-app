import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_bottom_nav.dart';

void main() {
  testWidgets('tapping Pantry fires onTap with ElioNavTab.pantry', (tester) async {
    ElioNavTab? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: ElioBottomNav(
          active: ElioNavTab.home,
          onTap: (t) => captured = t,
        ),
      ),
    ));
    await tester.tap(find.text('PANTRY'));
    await tester.pump();
    expect(captured, ElioNavTab.pantry);
  });

  // Sprint 16 rebrand — labels HOME / PANTRY / RECIPES / SHOPPING LIST.
  testWidgets('shows HOME / PANTRY / RECIPES / SHOPPING LIST', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: Scaffold(
        bottomNavigationBar: ElioBottomNav(
          active: ElioNavTab.home,
          onTap: (_) {},
        ),
      ),
    ));
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('PANTRY'), findsOneWidget);
    expect(find.text('RECIPES'), findsOneWidget);
    expect(find.text('SHOPPING LIST'), findsOneWidget);
    expect(find.text('SHOPPING\nLIST'), findsNothing);
  });

  testWidgets('active tab uses espresso, idle tabs use mocha', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: Scaffold(
        bottomNavigationBar: ElioBottomNav(
          active: ElioNavTab.pantry,
          onTap: (_) {},
        ),
      ),
    ));
    final activeText = tester.widget<Text>(find.text('PANTRY'));
    expect(activeText.style?.color, ElioColors.espresso);

    final idleText = tester.widget<Text>(find.text('HOME'));
    expect(idleText.style?.color, ElioColors.mocha);
  });
}
