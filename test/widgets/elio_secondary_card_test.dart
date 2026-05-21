import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_secondary_card.dart';

void main() {
  testWidgets('ElioSecondaryCard renders cream-deep surface', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(
        body: ElioSecondaryCard(
          title: 'Subscription',
          subtitle: 'Free plan',
          actionLabel: 'View',
        ),
      ),
    ));
    final cardBox = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ElioSecondaryCard), matching: find.byType(DecoratedBox)).first,
    );
    expect((cardBox.decoration as BoxDecoration).color, ElioColors.creamDeep);
  });

  testWidgets('ElioSecondaryCard action pill is peach with espresso label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(
        body: ElioSecondaryCard(
          title: 'Subscription',
          subtitle: 'Free plan',
          actionLabel: 'View',
        ),
      ),
    ));
    final actionBox = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(InkWell), matching: find.byType(DecoratedBox)).first,
    );
    expect((actionBox.decoration as BoxDecoration).color, ElioColors.peach);

    final actionText = tester.widget<Text>(find.text('View'));
    expect(actionText.style?.color, ElioColors.espresso);
  });
}
