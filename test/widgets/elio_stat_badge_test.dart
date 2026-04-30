import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_stat_badge.dart';

void main() {
  testWidgets('ElioStatBadge renders cream-deep pill with terracotta icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(
        body: ElioStatBadge(icon: Icons.timer_outlined, value: '25 min'),
      ),
    ));
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ElioStatBadge), matching: find.byType(DecoratedBox)).first,
    );
    expect((box.decoration as BoxDecoration).color, ElioColors.creamDeep);

    final icon = tester.widget<Icon>(find.byIcon(Icons.timer_outlined));
    expect(icon.color, ElioColors.terracotta);
  });
}
