// test/widgets/elio_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_chip.dart';

void main() {
  testWidgets('tapping chip fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: ElioChip(label: 'Vegetarian', selected: false, onTap: () => tapped = true),
    ))));
    await tester.tap(find.text('Vegetarian'));
    expect(tapped, true);
  });

  // Sprint 16 rebrand — terracotta-selected with check, creamDeep idle.
  testWidgets('selected chip uses terracotta fill and shows check icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: Scaffold(body: ElioChip(label: 'Vegetarian', selected: true, onTap: () {})),
    ));
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ElioChip), matching: find.byType(DecoratedBox)).first,
    );
    expect((box.decoration as BoxDecoration).color, ElioColors.terracotta);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('idle chip uses creamDeep fill and shows no check icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: Scaffold(body: ElioChip(label: 'Vegetarian', selected: false, onTap: () {})),
    ));
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ElioChip), matching: find.byType(DecoratedBox)).first,
    );
    expect((box.decoration as BoxDecoration).color, ElioColors.creamDeep);
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
