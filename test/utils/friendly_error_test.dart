// test/utils/friendly_error_test.dart
//
// Sprint 16.6 (deliberation-bleed follow-up, 14 May 2026).
// Covers the centralised friendly-error formatter + API key scrubber.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/utils/friendly_error.dart';

void main() {
  group('friendlyError — network-shaped exceptions', () {
    test('maps SocketException to friendly offline copy', () {
      final e = const SocketException('Failed host lookup: ...');
      expect(friendlyError(e), "You're offline. Reconnect and try again.");
    });

    test('matches the ClientException shape Kate captured 14 May', () {
      // Verbatim shape of Rob's 14 May screenshot.
      // SYNTHETIC KEY ONLY — never paste real secrets into test fixtures
      // (GitGuardian alerted on a real key here on 14 May 2026).
      const raw =
          "ClientException with SocketFailed host lookup: 'generativelanguage.googleapis.com' "
          "(OS Error: No address associated with hostname, errno = 7), "
          "uri=https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse&key=AIzaSyFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKE000";
      final e = Exception(raw);
      expect(friendlyError(e), "You're offline. Reconnect and try again.");
    });

    test('matches "Failed host lookup" alone', () {
      final e = Exception('Failed host lookup: generativelanguage.googleapis.com');
      expect(friendlyError(e), "You're offline. Reconnect and try again.");
    });

    test('matches "Connection refused"', () {
      final e = Exception('Connection refused by peer');
      expect(friendlyError(e), "You're offline. Reconnect and try again.");
    });

    test('matches "Network is unreachable"', () {
      final e = Exception('Network is unreachable');
      expect(friendlyError(e), "You're offline. Reconnect and try again.");
    });
  });

  group('friendlyError — non-network exceptions', () {
    test('falls through with Exception: prefix stripped', () {
      final e = Exception('That recipe included peanuts, retrying…');
      expect(friendlyError(e),
          'That recipe included peanuts, retrying…');
    });

    test('scrubs API key from non-network exception text (defence in depth)',
        () {
      // Even if a non-network exception somehow embeds the URL,
      // the scrubber should strip the key before display.
      final e = Exception(
          'Recipe generation failed for https://example.com?key=AIzaSyFAKEFAKEFAKE');
      final result = friendlyError(e);
      expect(result, isNot(contains('AIzaSyFAKE')));
      expect(result, contains('key=***'));
    });
  });

  group('friendlyError — Dart type-error sanitisation (Sprint 17)', () {
    // Two motivating bugs (both 26 May 2026):
    //   (a) Kate guest regen → "Null check operator used on a null value"
    //       snackbar (PR #14 gated the path; friendlyError is last-line).
    //   (b) Rob meal-plan recipe-tap → "type 'String' is not a subtype
    //       of type 'num?' in type cast" (PR #19 added asNum() helper;
    //       friendlyError covers anything else still bubbling).

    test('null check operator → generic friendly copy', () {
      final e = Exception('Null check operator used on a null value');
      expect(friendlyError(e), 'Something went wrong. Please try again.');
    });

    test('TypeError null cast → generic friendly copy', () {
      final e = Exception("type 'Null' is not a subtype of type 'String'");
      expect(friendlyError(e), 'Something went wrong. Please try again.');
    });

    test('TypeError String→num cast → generic friendly copy (meal-plan shape)', () {
      // Verbatim shape from Rob's 26may-b meal-plan recipe-tap bug.
      final e = Exception("type 'String' is not a subtype of type 'num?' in type cast");
      expect(friendlyError(e), 'Something went wrong. Please try again.');
    });

    test('cast failure thrown from real Dart cast → friendly fallback', () {
      try {
        final dynamic v = '5 min';
        // ignore: unused_local_variable, unnecessary_cast
        final n = v as num?;
        fail('expected cast to throw');
      } catch (e) {
        expect(friendlyError(e),
            'Something went wrong. Please try again.');
      }
    });

    test('real null-check operator error → friendly fallback', () {
      try {
        // ignore: dead_null_aware_expression
        final int x = (null as int?)!;
        fail('expected null check to throw: $x');
      } catch (e) {
        expect(friendlyError(e),
            'Something went wrong. Please try again.');
      }
    });

    test('RangeError → generic friendly copy', () {
      final e = Exception('RangeError (index): Index out of range: no indices for empty list');
      expect(friendlyError(e), 'Something went wrong. Please try again.');
    });

    test('NoSuchMethodError → generic friendly copy', () {
      final e = Exception("NoSuchMethodError: The method 'foo' was called on null.");
      expect(friendlyError(e), 'Something went wrong. Please try again.');
    });

    test('StateError "Bad state: FirestoreService…" → generic friendly copy', () {
      // Rob 30 May — non-Pro-at-cap regen surfaced this raw StateError.
      final e = StateError(
          'Bad state: FirestoreService called without a signed-in user. '
          'Guard `FirebaseAuth.instance.currentUser` upstream.');
      expect(friendlyError(e), 'Something went wrong. Please try again.');
    });

    test('still falls through clean for non-error Exception text', () {
      final e = Exception('Some other domain message');
      expect(friendlyError(e), 'Some other domain message');
    });
  });

  group('scrubApiKey', () {
    test('strips key=... query parameter', () {
      // SYNTHETIC KEY ONLY — see note in earlier test.
      const raw =
          'uri=https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse&key=AIzaSyFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKE000';
      final scrubbed = scrubApiKey(raw);
      expect(scrubbed, isNot(contains('AIzaSyFAKE')));
      expect(scrubbed, contains('&key=***'));
    });

    test('strips ?key=... when first query param', () {
      const raw = 'https://example.com/path?key=AIzaSyABCDEF12345';
      final scrubbed = scrubApiKey(raw);
      expect(scrubbed, isNot(contains('AIzaSyABCDEF')));
      expect(scrubbed, contains('?key=***'));
    });

    test('strips bare AIzaSy tokens even without key= prefix', () {
      // SYNTHETIC KEY ONLY — see note in earlier test.
      const raw = 'Auth failed for token AIzaSyFAKEFAKEFAKEFAKE';
      final scrubbed = scrubApiKey(raw);
      expect(scrubbed, isNot(contains('AIzaSyFAKE')));
      expect(scrubbed, contains('***'));
    });

    test('leaves clean strings untouched', () {
      const raw = 'Recipe generation timed out. Please try again.';
      expect(scrubApiKey(raw), raw);
    });

    test('scrubs multiple occurrences', () {
      const raw =
          'Tried key=AIzaSyAAAA then fell back to AIzaSyBBBB, both failed';
      final scrubbed = scrubApiKey(raw);
      expect(scrubbed, isNot(contains('AIzaSyAAAA')));
      expect(scrubbed, isNot(contains('AIzaSyBBBB')));
    });
  });
}
