// Sprint 17 — AccountService GDPR delete coverage.
//
// The destructive flow (Firestore wipe + Auth delete) needs an emulator
// or on-device verification — Firebase Auth and Firestore both refuse
// to mock cleanly without `firebase_auth_mocks` / `fake_cloud_firestore`,
// neither of which are pulled in here yet. Sprint 17's emulator-rule
// task will pick that up.
//
// What we DO cover with unit tests is the part that's most likely to
// silently rot: the `userSubcollections` and `fcmTopics` constants. If
// a future commit adds a new `users/{uid}/foo` subcollection (or a new
// FCM topic) and forgets to update AccountService, this test fails and
// the dev sees exactly which list is out of date — far better than
// shipping a delete-account that quietly leaves orphaned user data.

import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/services/account_service.dart';
import 'package:elio_app/services/notification_service.dart';

void main() {
  group('AccountService.userSubcollections', () {
    test('matches the Firestore schema documented in CLAUDE.md', () {
      // Authoritative list copied from CLAUDE.md "Firestore Schema".
      // Update both at the same time when the schema changes.
      const schema = <String>{
        'profiles',
        'inventory',
        'recipes',
        'ratings',
        'mealPlan',
        'shoppingItems',
        'tierMemory',
        'fcmTokens',
      };
      expect(
        AccountService.userSubcollections.toSet(),
        equals(schema),
        reason:
            'AccountService.userSubcollections must match CLAUDE.md '
            'Firestore Schema. If you added a new subcollection, append '
            'it to AccountService.userSubcollections AND update '
            'CLAUDE.md so the next person sees the canonical list.',
      );
    });

    test('contains no duplicates', () {
      final list = AccountService.userSubcollections;
      expect(list.toSet().length, list.length);
    });
  });

  group('AccountService.fcmTopics', () {
    test('matches NotificationService topic constants', () {
      // NotificationService is the source of truth for topic names —
      // AccountService duplicates them so the delete flow doesn't have
      // to import the full notification stack. This test enforces they
      // stay in sync.
      const topicsFromService = <String>{
        NotificationService.topicWeeklyReminder,
        NotificationService.topicRestockReminder,
        NotificationService.topicTipsAndUpdates,
      };
      expect(
        AccountService.fcmTopics.toSet(),
        equals(topicsFromService),
        reason:
            'AccountService.fcmTopics drifted from NotificationService. '
            'Pushes will continue to a deleted account if the lists '
            'disagree.',
      );
    });
  });

  group('DeleteAccountResult', () {
    test('Cancelled carries a reason', () {
      const r = DeleteAccountCancelled('reauth cancelled');
      expect(r.reason, 'reauth cancelled');
    });

    test('Failed carries stage and message', () {
      const r = DeleteAccountFailed(stage: 'auth', message: 'boom');
      expect(r.stage, 'auth');
      expect(r.message, 'boom');
    });
  });
}
