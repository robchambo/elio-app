import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_method_step.dart';

void main() {
  testWidgets('ElioMethodStep numeral is Bricolage 800 terracotta', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(
        body: ElioMethodStep(stepNumber: 1, title: '', body: 'Mix it all up.'),
      ),
    ));
    final numeral = tester.widget<Text>(find.text('01'));
    expect(numeral.style?.fontFamily, 'Bricolage Grotesque');
    expect(numeral.style?.fontWeight, FontWeight.w800);
    expect(numeral.style?.color, ElioColors.terracotta);
    expect(numeral.style?.fontSize, 56);
  });
}
