import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_pantry_tag_pill.dart';
import 'package:elio_app/theme/elio_theme.dart';

void main() {
  testWidgets('renders default label for inYourPantry', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ElioPantryTagPill(kind: PantryTagKind.inYourPantry),
      ),
    ));
    expect(find.text('In your pantry'), findsOneWidget);
  });

  testWidgets('useToday uses perishToday background', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ElioPantryTagPill(kind: PantryTagKind.useToday),
      ),
    ));
    final box = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((c) {
      final d = c.decoration;
      return d is BoxDecoration && d.color == ElioColors.perishToday;
    });
    expect((box.decoration as BoxDecoration).color, ElioColors.perishToday);
  });

  testWidgets('fresh uses freshGreen background', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ElioPantryTagPill(kind: PantryTagKind.fresh),
      ),
    ));
    expect(find.text('Fresh'), findsOneWidget);
  });

  testWidgets('overrideLabel overrides the default label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ElioPantryTagPill(
          kind: PantryTagKind.thisWeek,
          overrideLabel: 'Use within 3 days',
        ),
      ),
    ));
    expect(find.text('Use within 3 days'), findsOneWidget);
    expect(find.text('This week'), findsNothing);
  });
}
