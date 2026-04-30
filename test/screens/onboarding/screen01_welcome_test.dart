import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/screens/onboarding/screen01_welcome.dart';
import 'package:elio_app/widgets/elio/phone_mockup_recipe_card.dart';
import 'package:elio_app/widgets/elio/elio_page_title.dart';
import 'package:elio_app/widgets/elio/elio_big_button.dart';
import 'package:elio_app/widgets/elio/elio_onboarding_progress_bar.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('renders phone mockup, heading, CTA, and sign-in link',
      (t) async {
    await t.pumpWidget(wrap(Screen01Welcome(
      controller: OnboardingController(),
      onContinue: () {},
      onSignInTap: () {},
    )));
    expect(find.byType(PhoneMockupRecipeCard), findsOneWidget);
    expect(find.byType(ElioPageTitle), findsOneWidget);
    expect(find.byType(ElioBigButton), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('i already have an account'), findsOneWidget);
  });

  testWidgets('no back button on screen 01', (t) async {
    await t.pumpWidget(wrap(Screen01Welcome(
      controller: OnboardingController(),
      onContinue: () {},
      onSignInTap: () {},
    )));
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('Get started CTA fires onContinue', (t) async {
    var tapped = false;
    await t.pumpWidget(wrap(Screen01Welcome(
      controller: OnboardingController(),
      onContinue: () => tapped = true,
      onSignInTap: () {},
    )));
    await t.tap(find.text('Get started'));
    await t.pump();
    expect(tapped, isTrue);
  });

  testWidgets(
      '"I already have an account" tap triggers sign-in navigation intent',
      (t) async {
    // Using the onSignInTap seam (default pushes EmailLoginScreen; we verify
    // the tap hooks through rather than spinning up Firebase in the test).
    var signInTapped = 0;
    await t.pumpWidget(wrap(Screen01Welcome(
      controller: OnboardingController(),
      onContinue: () {},
      onSignInTap: () => signInTapped++,
    )));
    await t.tap(find.text('i already have an account'));
    await t.pump();
    expect(signInTapped, 1);
  });

  testWidgets('progress bar shows 1/15', (t) async {
    await t.pumpWidget(wrap(Screen01Welcome(
      controller: OnboardingController(),
      onContinue: () {},
      onSignInTap: () {},
    )));
    final bar = t.widget<ElioOnboardingProgressBar>(
        find.byType(ElioOnboardingProgressBar));
    expect(bar.value, closeTo(1 / 15, 0.0001));
  });
}
