import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_ingredient_row.dart';

void main() {
  testWidgets('idle ElioIngredientRow shows outlined terracotta circle', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(body: ElioIngredientRow(name: 'Carrots')),
    ));
    final icon = tester.widget<Icon>(find.byIcon(Icons.circle_outlined));
    expect(icon.color, ElioColors.terracotta);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('checked ElioIngredientRow shows filled terracotta with white tick', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(body: ElioIngredientRow(name: 'Carrots', checked: true)),
    ));
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsNothing);
  });
}
