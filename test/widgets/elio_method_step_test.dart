import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/utils/time_parser.dart';
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

  testWidgets(
      'Sprint 16.6: without onTimeTap, body renders as plain Text (back-compat)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(
        body: ElioMethodStep(
          stepNumber: 1,
          title: '',
          body: 'Bake for 25 minutes until golden.',
        ),
      ),
    ));
    // The whole body string is present as a single plain-Text widget,
    // not split into spans.
    expect(find.text('Bake for 25 minutes until golden.'), findsOneWidget);
  });

  testWidgets(
      'Sprint 16.6: with onTimeTap and a parseable time, renders a tappable pill that fires the callback',
      (tester) async {
    final taps = <TimeMatch>[];
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: Scaffold(
        body: ElioMethodStep(
          stepNumber: 1,
          title: '',
          body: 'Bake for 25 minutes until golden.',
          onTimeTap: taps.add,
        ),
      ),
    ));
    // The "25 minutes" pill renders as its own Text (the matched text)
    // inside a tappable. Find it by exact label.
    expect(find.text('25 minutes'), findsOneWidget);
    await tester.tap(find.text('25 minutes'));
    expect(taps, hasLength(1));
    expect(taps.first.duration, const Duration(minutes: 25));
    expect(taps.first.matchedText, '25 minutes');
  });

  testWidgets(
      'Sprint 16.6: with onTimeTap but no parseable time, renders the body as plain Text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: Scaffold(
        body: ElioMethodStep(
          stepNumber: 2,
          title: '',
          body: 'Mix everything together until smooth.',
          onTimeTap: (_) {},
        ),
      ),
    ));
    expect(
      find.text('Mix everything together until smooth.'),
      findsOneWidget,
    );
  });
}
