// Sprint 16.8 row 7 — pins the shouldShow eligibility matrix and the
// session-threshold behaviour. Catches regressions where a tip would
// either re-fire after being seen, fire after the user has used the
// feature, or skip the "viewed N times without using" gate.
//
// The service singleton survives across tests, so each test starts with
// `resetForTesting()` + a clean `SharedPreferences.setMockInitialValues({})`.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elio_app/services/feature_tip_catalog.dart';
import 'package:elio_app/services/feature_tip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FeatureTipService.instance.resetForTesting();
    await FeatureTipService.instance.preload();
  });

  group('FeatureTipService.shouldShow', () {
    test('returns null until the session threshold is hit', () {
      final tip = FeatureTipCatalog.recipeImport;
      // recipeImport.sessionThreshold = 3 → null, null, then the tip.
      for (var i = 1; i < tip.sessionThreshold; i++) {
        expect(FeatureTipService.instance.shouldShow(tip.id), isNull,
            reason: 'view $i should not fire');
      }
      final shown = FeatureTipService.instance.shouldShow(tip.id);
      expect(shown, isNotNull);
      expect(shown!.id, tip.id);
    });

    test('returns null after the tip has been marked seen', () async {
      final tip = FeatureTipCatalog.recipeImport;
      await FeatureTipService.instance.markSeen(tip.id);
      // Even after hitting threshold, a seen tip never fires again.
      for (var i = 0; i < tip.sessionThreshold + 2; i++) {
        expect(FeatureTipService.instance.shouldShow(tip.id), isNull);
      }
    });

    test('returns null once the targeted feature has been used', () async {
      final tip = FeatureTipCatalog.recipeImport;
      await FeatureTipService.instance.markFeatureUsed(tip.requiredFeatureEvent);
      for (var i = 0; i < tip.sessionThreshold + 2; i++) {
        expect(FeatureTipService.instance.shouldShow(tip.id), isNull);
      }
    });

    test('returns null for an unknown tip id', () {
      expect(FeatureTipService.instance.shouldShow('not_a_real_tip'), isNull);
    });
  });

  group('FeatureTipService.markFeatureUsed', () {
    test('also auto-marks the matching catalogue tip as seen', () async {
      final tip = FeatureTipCatalog.mealPlanToShopping;
      expect(FeatureTipService.instance.hasSeen(tip.id), isFalse);
      await FeatureTipService.instance.markFeatureUsed(tip.requiredFeatureEvent);
      expect(FeatureTipService.instance.hasSeen(tip.id), isTrue);
    });
  });

  group('FeatureTipService.preload', () {
    test('rehydrates seen-state from SharedPreferences', () async {
      final tip = FeatureTipCatalog.recipeImport;
      SharedPreferences.setMockInitialValues({
        'seen_tip_${tip.id}': true,
      });
      FeatureTipService.instance.resetForTesting();
      await FeatureTipService.instance.preload();
      expect(FeatureTipService.instance.hasSeen(tip.id), isTrue);
      // Threshold no longer matters — seen wins.
      for (var i = 0; i < tip.sessionThreshold + 2; i++) {
        expect(FeatureTipService.instance.shouldShow(tip.id), isNull);
      }
    });

    test('rehydrates feature-used state from SharedPreferences', () async {
      final tip = FeatureTipCatalog.mealPlanToShopping;
      SharedPreferences.setMockInitialValues({
        'feature_used_${tip.requiredFeatureEvent}': true,
      });
      FeatureTipService.instance.resetForTesting();
      await FeatureTipService.instance.preload();
      for (var i = 0; i < tip.sessionThreshold + 2; i++) {
        expect(FeatureTipService.instance.shouldShow(tip.id), isNull);
      }
    });
  });

  group('FeatureTipCatalog', () {
    test('byId resolves every registered tip', () {
      for (final tip in FeatureTipCatalog.all) {
        expect(FeatureTipCatalog.byId(tip.id), same(tip));
      }
    });

    test('byId returns null for unknown ids', () {
      expect(FeatureTipCatalog.byId('not_a_real_tip'), isNull);
    });

    test('every tip has a non-empty title, body, and feature event', () {
      for (final tip in FeatureTipCatalog.all) {
        expect(tip.title.trim().isNotEmpty, isTrue, reason: 'title ${tip.id}');
        expect(tip.body.trim().isNotEmpty, isTrue, reason: 'body ${tip.id}');
        expect(tip.requiredFeatureEvent.trim().isNotEmpty, isTrue,
            reason: 'event ${tip.id}');
        expect(tip.sessionThreshold, greaterThanOrEqualTo(1));
      }
    });
  });
}
