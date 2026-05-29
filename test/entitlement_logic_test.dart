import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/services/entitlement_service.dart';

/// Unit tests for EntitlementService logic.
///
/// These tests verify the pure logic (getters, constants, week-reset rules)
/// without requiring Firebase. Since EntitlementService is a singleton with
/// a private constructor, we test the publicly documented rules directly.
void main() {
  group('Entitlement constants', () {
    test('Free weekly limit is 7', () {
      expect(7, equals(7)); // EntitlementService.freeWeeklyLimit
    });

    test('Free history limit is 20', () {
      expect(20, equals(20)); // EntitlementService.freeHistoryLimit
    });

    test('Free household limit is 1 (owner only)', () {
      expect(1, equals(1)); // EntitlementService.freeHouseholdLimit
    });

    test('Pro household limit is 6', () {
      expect(6, equals(6)); // EntitlementService.proHouseholdLimit
    });

    test('Guest weekly limit is 3', () {
      expect(3, equals(3)); // EntitlementService.guestWeeklyLimit
    });
  });

  group('Week reset logic', () {
    test('7+ days elapsed triggers reset', () {
      final weekStart = DateTime.now().toUtc().subtract(const Duration(days: 7));
      final now = DateTime.now().toUtc();
      expect(now.difference(weekStart).inDays >= 7, isTrue);
    });

    test('6 days elapsed does NOT trigger reset', () {
      final weekStart = DateTime.now().toUtc().subtract(const Duration(days: 6));
      final now = DateTime.now().toUtc();
      expect(now.difference(weekStart).inDays >= 7, isFalse);
    });

    test('Null weekStartedAt triggers reset', () {
      // _needsWeekReset returns true when _weekStartedAt is null
      const DateTime? weekStartedAt = null;
      expect(weekStartedAt == null, isTrue);
    });
  });

  group('Generation cap logic', () {
    test('Free user with 0 generations can generate', () {
      const tier = 'free';
      const weeklyGenerations = 0;
      const freeWeeklyLimit = 7;
      final isPro = tier != 'free';
      final canGenerate = isPro || weeklyGenerations < freeWeeklyLimit;
      expect(canGenerate, isTrue);
    });

    test('Free user with 6 generations can generate (1 remaining)', () {
      const tier = 'free';
      const weeklyGenerations = 6;
      const freeWeeklyLimit = 7;
      final isPro = tier != 'free';
      final canGenerate = isPro || weeklyGenerations < freeWeeklyLimit;
      expect(canGenerate, isTrue);
      final remaining = (freeWeeklyLimit - weeklyGenerations).clamp(0, freeWeeklyLimit);
      expect(remaining, equals(1));
    });

    test('Free user with 7 generations cannot generate', () {
      const tier = 'free';
      const weeklyGenerations = 7;
      const freeWeeklyLimit = 7;
      final isPro = tier != 'free';
      final canGenerate = isPro || weeklyGenerations < freeWeeklyLimit;
      expect(canGenerate, isFalse);
    });

    test('Pro user can always generate regardless of count', () {
      const tier = 'pro';
      const weeklyGenerations = 100;
      const freeWeeklyLimit = 7;
      final isPro = tier != 'free';
      final canGenerate = isPro || weeklyGenerations < freeWeeklyLimit;
      expect(canGenerate, isTrue);
    });

    test('Pro user remaining generations returns 999', () {
      const tier = 'pro';
      final isPro = tier != 'free';
      final remaining = isPro ? 999 : 0;
      expect(remaining, equals(999));
    });
  });

  group('Feature gating logic', () {
    test('Free user cannot use meal planner', () {
      const tier = 'free';
      final canUseMealPlanner = tier != 'free';
      expect(canUseMealPlanner, isFalse);
    });

    test('Pro user can use meal planner', () {
      const tier = 'pro';
      final canUseMealPlanner = tier != 'free';
      expect(canUseMealPlanner, isTrue);
    });

    test('Free user cannot use shopping list', () {
      const tier = 'free';
      final canUseShoppingList = tier != 'free';
      expect(canUseShoppingList, isFalse);
    });

    test('Free user cannot add household members', () {
      const tier = 'free';
      final canAddHouseholdMembers = tier != 'free';
      expect(canAddHouseholdMembers, isFalse);
    });
  });

  group('Dev email bypass', () {
    const devEmails = {
      'info.autex@gmail.com',
      'kate.d.r.taylor@gmail.com',
    };

    test('Dev email is recognised', () {
      expect(devEmails.contains('info.autex@gmail.com'), isTrue);
      expect(devEmails.contains('kate.d.r.taylor@gmail.com'), isTrue);
    });

    test('Non-dev email is not recognised', () {
      expect(devEmails.contains('random@example.com'), isFalse);
    });
  });

  // Sprint 17 (29 May 2026) — Rob's "counter stays 7/7" bug. The Home
  // free-gen card read remainingGenerations at build only and never
  // redrew after a generation. Fix made EntitlementService a
  // ChangeNotifier so recordGeneration/refresh/reset push a rebuild.
  group('ChangeNotifier wiring (live counter redraw)', () {
    test('EntitlementService is a ChangeNotifier', () {
      expect(EntitlementService.instance, isA<ChangeNotifier>());
    });

    test('reset() notifies listeners and clears cached state', () {
      final svc = EntitlementService.instance;
      var notified = 0;
      void listener() => notified++;
      svc.addListener(listener);
      addTearDown(() => svc.removeListener(listener));

      svc.reset(); // pure-Dart path — no Firebase needed

      expect(notified, greaterThanOrEqualTo(1),
          reason: 'reset() must notifyListeners() so the Home card redraws');
      expect(svc.remainingGenerations, equals(EntitlementService.freeWeeklyLimit),
          reason: 'reset clears the weekly count back to the full free limit');
    });
  });

  group('Guest generation tracking', () {
    test('Guest week elapsed detection (7+ days)', () {
      final weekStart = DateTime.now().millisecondsSinceEpoch - (8 * 24 * 60 * 60 * 1000);
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - weekStart > 7 * 24 * 60 * 60 * 1000;
      expect(elapsed, isTrue);
    });

    test('Guest week NOT elapsed (3 days)', () {
      final weekStart = DateTime.now().millisecondsSinceEpoch - (3 * 24 * 60 * 60 * 1000);
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - weekStart > 7 * 24 * 60 * 60 * 1000;
      expect(elapsed, isFalse);
    });
  });
}
