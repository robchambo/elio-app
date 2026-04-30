import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_bento_card.dart';

void main() {
  testWidgets('ElioBentoCard renders cream-deep surface with two-tone icon container', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(
        body: ElioBentoCard(
          icon: Icons.receipt_long_outlined,
          kicker: 'From a photo',
          title: 'Scan receipt',
        ),
      ),
    ));
    // Outer card: cream-deep surface.
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ElioBentoCard), matching: find.byType(DecoratedBox)).first,
    );
    expect((box.decoration as BoxDecoration).color, ElioColors.creamDeep);

    // Inner icon container: peach by default.
    final iconBoxes = tester.widgetList<DecoratedBox>(
      find.descendant(of: find.byType(ElioBentoCard), matching: find.byType(DecoratedBox)),
    ).toList();
    final innerColor = (iconBoxes[1].decoration as BoxDecoration).color;
    expect(innerColor, ElioColors.peach);

    // Icon glyph: espresso (default).
    final icon = tester.widget<Icon>(find.byIcon(Icons.receipt_long_outlined));
    expect(icon.color, ElioColors.espresso);
  });
}
