import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_appliance_tile.dart';

void main() {
  testWidgets('renders label and icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 120,
          child: ElioApplianceTile(
            value: 'oven',
            label: 'Oven',
            icon: Icons.kitchen,
            selected: false,
            onTap: (_) {},
          ),
        ),
      ),
    ));
    expect(find.text('Oven'), findsOneWidget);
    expect(find.byIcon(Icons.kitchen), findsOneWidget);
  });

  testWidgets('tap fires onTap with value', (tester) async {
    String? received;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 120,
          child: ElioApplianceTile(
            value: 'oven',
            label: 'Oven',
            icon: Icons.kitchen,
            selected: false,
            onTap: (v) => received = v,
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(ElioApplianceTile));
    expect(received, 'oven');
  });

  testWidgets('selected overlays amber check icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 120,
          child: ElioApplianceTile(
            value: 'oven',
            label: 'Oven',
            icon: Icons.kitchen,
            selected: true,
            onTap: (_) {},
          ),
        ),
      ),
    ));
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('unselected does not render check', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 120,
          child: ElioApplianceTile(
            value: 'oven',
            label: 'Oven',
            icon: Icons.kitchen,
            selected: false,
            onTap: (_) {},
          ),
        ),
      ),
    ));
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
