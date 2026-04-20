import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_segmented_toggle.dart';
import 'package:elio_app/theme/elio_theme.dart';

void main() {
  testWidgets('renders both option labels', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioSegmentedToggle(
          value: 'metric',
          optionA: (value: 'metric', label: 'Metric'),
          optionB: (value: 'imperial', label: 'Imperial'),
          onChanged: (_) {},
        ),
      ),
    ));
    expect(find.text('Metric'), findsOneWidget);
    expect(find.text('Imperial'), findsOneWidget);
  });

  testWidgets('tapping inactive segment fires onChanged', (tester) async {
    String? received;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioSegmentedToggle(
          value: 'metric',
          optionA: (value: 'metric', label: 'Metric'),
          optionB: (value: 'imperial', label: 'Imperial'),
          onChanged: (v) => received = v,
        ),
      ),
    ));
    await tester.tap(find.text('Imperial'));
    expect(received, 'imperial');
  });

  testWidgets('active segment has amber background', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioSegmentedToggle(
          value: 'imperial',
          optionA: (value: 'metric', label: 'Metric'),
          optionB: (value: 'imperial', label: 'Imperial'),
          onChanged: (_) {},
        ),
      ),
    ));

    // Find the Container that immediately wraps the "Imperial" Text.
    final imperialContainer = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Imperial'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = imperialContainer.decoration as BoxDecoration;
    expect(decoration.color, ElioColors.amber);
  });
}
