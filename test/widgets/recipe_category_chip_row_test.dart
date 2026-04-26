import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/widgets/recipe_category_chip_row.dart';

void main() {
  testWidgets(
      'RecipeCategoryChipRow renders All + categories and toggles selection',
      (tester) async {
    String? current;

    Widget build() => MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => RecipeCategoryChipRow(
                selected: current,
                onSelected: (v) => setState(() => current = v),
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Appetizer'), findsOneWidget);

    await tester.tap(find.text('Appetizer'));
    await tester.pumpAndSettle();
    expect(current, 'Appetizer');

    // Tapping the active chip clears back to All.
    await tester.tap(find.text('Appetizer'));
    await tester.pumpAndSettle();
    expect(current, isNull);
  });
}
