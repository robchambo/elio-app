import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_onboarding_option_card.dart';

void main() {
  testWidgets('renders with title and subtitle', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioOnboardingOptionCard(
          value: 'pantryFirst',
          title: 'Use what I already have',
          subtitle: 'Recipes built around your pantry',
          selected: false,
          onTap: (_) {},
        ),
      ),
    ));
    expect(find.text('Use what I already have'), findsOneWidget);
    expect(find.text('Recipes built around your pantry'), findsOneWidget);
  });

  testWidgets('tap fires onTap with value', (tester) async {
    String? received;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioOnboardingOptionCard(
          value: 'pantryFirst',
          title: 'Use what I already have',
          selected: false,
          onTap: (v) => received = v,
        ),
      ),
    ));
    await tester.tap(find.byType(ElioOnboardingOptionCard));
    expect(received, 'pantryFirst');
  });

  testWidgets('selected state renders amber tick icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioOnboardingOptionCard(
          value: 'x',
          title: 'Foo',
          selected: true,
          onTap: (_) {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('unselected state does not render tick', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioOnboardingOptionCard(
          value: 'x',
          title: 'Foo',
          selected: false,
          onTap: (_) {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
