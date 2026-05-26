// Sprint 16.8 row 7 — smoke test for the Style A feature-tip bottom sheet.
//
// Pins that:
//   • title, body, and CTA label render
//   • tapping "Got it" pops with false and marks the tip seen
//   • tapping the CTA pops with true, marks the tip seen, and invokes onCta
//
// Uses SharedPreferences.setMockInitialValues so the persistence side-effects
// of `markSeen` resolve without a Firebase backend (the Firestore write is
// wrapped in try/catch and silently no-ops in the absence of FirebaseAuth).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elio_app/services/feature_tip_catalog.dart';
import 'package:elio_app/services/feature_tip_service.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_feature_tip_sheet.dart';

Future<void> _openSheet(
  WidgetTester tester,
  FeatureTip tip, {
  VoidCallback? onCta,
}) async {
  late BuildContext capturedContext;
  await tester.pumpWidget(MaterialApp(
    theme: elioTheme(),
    home: Scaffold(
      body: Builder(
        builder: (context) {
          capturedContext = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  ));
  // Fire-and-forget; the test inspects + interacts with the sheet directly.
  unawaited(ElioFeatureTipSheet.show(capturedContext, tip, onCta: onCta));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FeatureTipService.instance.resetForTesting();
    await FeatureTipService.instance.preload();
  });

  testWidgets('renders title, body, and CTA label', (tester) async {
    final tip = FeatureTipCatalog.recipeImport;
    await _openSheet(tester, tip);
    expect(find.text(tip.title), findsOneWidget);
    expect(find.text(tip.body), findsOneWidget);
    expect(find.text(tip.ctaLabel!), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets('tapping "Got it" dismisses and marks seen', (tester) async {
    final tip = FeatureTipCatalog.recipeImport;
    await _openSheet(tester, tip);
    expect(FeatureTipService.instance.hasSeen(tip.id), isFalse);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text(tip.title), findsNothing);
    expect(FeatureTipService.instance.hasSeen(tip.id), isTrue);
  });

  testWidgets('tapping CTA dismisses, marks seen, and invokes onCta',
      (tester) async {
    final tip = FeatureTipCatalog.recipeImport;
    var ctaFired = false;
    await _openSheet(tester, tip, onCta: () => ctaFired = true);
    await tester.tap(find.text(tip.ctaLabel!));
    await tester.pumpAndSettle();
    expect(ctaFired, isTrue);
    expect(FeatureTipService.instance.hasSeen(tip.id), isTrue);
  });
}
