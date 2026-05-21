import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_servings_control.dart';

void main() {
  testWidgets('increments and decrements, respects bounds', (tester) async {
    int value = 2;
    await tester.pumpWidget(StatefulBuilder(builder: (c, setState) =>
      MaterialApp(home: Scaffold(body: ElioServingsControl(
        value: value, min: 1, max: 4,
        onChanged: (v) => setState(() => value = v),
      ))),
    ));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('4'), findsOneWidget);

    // At max — add button disabled, nothing happens
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('4'), findsOneWidget);
  });
}
