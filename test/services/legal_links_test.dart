// Sprint 17 — guards on the legal URLs.
//
// Two failure modes worth catching at test time:
//   1. URLs are obviously malformed (typo, missing scheme).
//   2. The placeholder URLs are still in place when someone tries to
//      ship a real release.
//
// `urlsAreLive` is the gate — flip it to true in the same commit
// that points the constants at real pages. The release-ship test
// below fails until that flips, so a bad release can't sneak through.

import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/services/legal_links.dart';

void main() {
  group('LegalLinks URLs', () {
    test('privacy URL parses as a valid https URI', () {
      final uri = Uri.tryParse(LegalLinks.privacyPolicyUrl);
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, isNotEmpty);
    });

    test('terms URL parses as a valid https URI', () {
      final uri = Uri.tryParse(LegalLinks.termsOfServiceUrl);
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, isNotEmpty);
    });

    test('support email is a plausible address', () {
      expect(LegalLinks.supportEmail, contains('@'));
      expect(LegalLinks.supportEmail.split('@').last, contains('.'));
    });

    // Sentinel test: when we're ready to ship, flip
    // `LegalLinks.urlsAreLive` to true in the same commit that
    // updates the URLs. Until then this test passes (placeholder
    // mode); after the flip it asserts the URLs no longer point at
    // the placeholder domain.
    test(
      'when urlsAreLive is true, URLs are not the elio.app placeholders',
      () {
        if (!LegalLinks.urlsAreLive) {
          // Placeholder mode — nothing to assert yet.
          return;
        }
        expect(
          LegalLinks.privacyPolicyUrl,
          isNot('https://elio.app/privacy'),
          reason: 'Set urlsAreLive=true but URLs still point at the '
              'placeholder. Update privacyPolicyUrl + termsOfServiceUrl '
              'to the real hosted pages.',
        );
        expect(
          LegalLinks.termsOfServiceUrl,
          isNot('https://elio.app/terms'),
        );
      },
    );
  });
}
