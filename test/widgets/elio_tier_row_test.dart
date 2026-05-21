import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_tier_row.dart';

void main() {
  testWidgets('ElioTierRow renders cream-deep surface', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(
        body: ElioTierRow(label: 'Always have', count: 12),
      ),
    ));
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ElioTierRow), matching: find.byType(DecoratedBox)).first,
    );
    expect((box.decoration as BoxDecoration).color, ElioColors.creamDeep);
    expect(find.text('Always have (12)'), findsOneWidget);
  });
}
