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
      // Real message from Rob's 14 May screenshot — verbatim shape
      // includes the full URL + API key.
      const raw =
          "ClientException with SocketFailed host lookup: 'generativelanguage.googleapis.com' "
          "(OS Error: No address associated with hostname, errno = 7), "
          "uri=https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse&key=AIzaSyAWztc3-nC5m3da9PemH9vKs-xivfEOuh0";
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
          'Recipe generation failed for https://example.com?key=AIzaSyAWztc3-nC5m3da9');
      final result = friendlyError(e);
      expect(result, isNot(contains('AIzaSyAWztc3')));
      expect(result, contains('key=***'));
    });
  });

  group('scrubApiKey', () {
    test('strips key=... query parameter', () {
      const raw =
          'uri=https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse&key=AIzaSyAWztc3-nC5m3da9PemH9vKs-xivfEOuh0';
      final scrubbed = scrubApiKey(raw);
      expect(scrubbed, isNot(contains('AIzaSyAWztc3')));
      expect(scrubbed, contains('&key=***'));
    });

    test('strips ?key=... when first query param', () {
      const raw = 'https://example.com/path?key=AIzaSyABCDEF12345';
      final scrubbed = scrubApiKey(raw);
      expect(scrubbed, isNot(contains('AIzaSyABCDEF')));
      expect(scrubbed, contains('?key=***'));
    });

    test('strips bare AIzaSy tokens even without key= prefix', () {
      const raw = 'Auth failed for token AIzaSyAWztc3-nC5m3da';
      final scrubbed = scrubApiKey(raw);
      expect(scrubbed, isNot(contains('AIzaSyAWztc3')));
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
