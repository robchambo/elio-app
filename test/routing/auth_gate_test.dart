import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elio_app/main.dart';

void main() {
  // Tests use lightweight stand-ins for AppShell / OnboardingFlow via the
  // AuthGate's builder overrides so we don't pull Firebase / AppShell's
  // initState chain into the widget tree.
  Widget stubShell(BuildContext _) =>
      const Scaffold(body: Center(child: Text('stub-shell')));
  Widget stubOnboarding(BuildContext _) =>
      const Scaffold(body: Center(child: Text('stub-onboarding')));

  testWidgets('AuthGate routes to OnboardingFlow when onboardingComplete false',
      (t) async {
    SharedPreferences.setMockInitialValues({'onboardingComplete': false});
    await t.pumpWidget(MaterialApp(
      home: AuthGate(
        appShellBuilder: stubShell,
        onboardingBuilder: stubOnboarding,
      ),
    ));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('onboardingFlowRoot')), findsOneWidget);
    expect(find.text('stub-onboarding'), findsOneWidget);
  });

  testWidgets('AuthGate routes to AppShell when onboardingComplete true',
      (t) async {
    SharedPreferences.setMockInitialValues({'onboardingComplete': true});
    await t.pumpWidget(MaterialApp(
      home: AuthGate(
        appShellBuilder: stubShell,
        onboardingBuilder: stubOnboarding,
      ),
    ));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('appShellRoot')), findsOneWidget);
    expect(find.text('stub-shell'), findsOneWidget);
  });
}
