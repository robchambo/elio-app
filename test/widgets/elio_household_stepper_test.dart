import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_household_stepper.dart';

void main() {
  testWidgets('renders the current value', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioHouseholdStepper(value: 3, onChanged: (_) {}),
      ),
    ));
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('+ fires onChanged with value+1', (tester) async {
    int? received;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioHouseholdStepper(
          value: 3,
          onChanged: (v) => received = v,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.add));
    expect(received, 4);
  });

  testWidgets('- fires onChanged with value-1', (tester) async {
    int? received;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioHouseholdStepper(
          value: 3,
          onChanged: (v) => received = v,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.remove));
    expect(received, 2);
  });

  testWidgets('clamps at min=1 (decrement disabled)', (tester) async {
    int? received;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioHouseholdStepper(
          value: 1,
          onChanged: (v) => received = v,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.remove));
    expect(received, isNull);
  });

  testWidgets('clamps at max=10 (increment disabled)', (tester) async {
    int? received;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioHouseholdStepper(
          value: 10,
          onChanged: (v) => received = v,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.add));
    expect(received, isNull);
  });
}
