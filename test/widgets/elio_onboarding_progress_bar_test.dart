import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_onboarding_progress_bar.dart';

void main() {
  testWidgets('renders with value in range', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ElioOnboardingProgressBar(value: 0.4)),
    ));
    final lpi = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(lpi.value, closeTo(0.4, 0.0001));
  });

  testWidgets('clamps value above 1.0 to 1.0', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ElioOnboardingProgressBar(value: 2.0)),
    ));
    final lpi = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(lpi.value, 1.0);
  });

  testWidgets('clamps value below 0.0 to 0.0', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ElioOnboardingProgressBar(value: -0.5)),
    ));
    final lpi = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(lpi.value, 0.0);
  });
}
