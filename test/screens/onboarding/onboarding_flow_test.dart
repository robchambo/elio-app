import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/screens/onboarding/onboarding_flow.dart';
import 'package:elio_app/screens/onboarding/screen01_welcome.dart';
import 'package:elio_app/screens/onboarding/screen02_goal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingFlow coordinator', () {
    void sizeViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('renders screen 01 initially', (tester) async {
      sizeViewport(tester);
      await tester.pumpWidget(MaterialApp(
        home: OnboardingFlow(controller: OnboardingController()),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(Screen01Welcome), findsOneWidget);
      expect(find.byType(Screen02Goal), findsNothing);
    });

    testWidgets('tapping Get started advances to screen 02', (tester) async {
      sizeViewport(tester);
      await tester.pumpWidget(MaterialApp(
        home: OnboardingFlow(controller: OnboardingController()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.byType(Screen02Goal), findsOneWidget);
    });

    testWidgets('back from screen 02 returns to screen 01', (tester) async {
      sizeViewport(tester);
      await tester.pumpWidget(MaterialApp(
        home: OnboardingFlow(controller: OnboardingController()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      // Back button is an IconButton rendered by the AppBar BackButton.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(Screen01Welcome), findsOneWidget);
      expect(find.byType(Screen02Goal), findsNothing);
    });
  });
}
