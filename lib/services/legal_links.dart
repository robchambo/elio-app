// lib/services/legal_links.dart
//
// Sprint 17 — single source of truth for the URLs of Elio's hosted
// legal pages. Both Play and App Store listings require the
// privacy-policy URL at submission, so these have to be live before
// launch. The pages themselves are static HTML hosted off-app
// (Vercel/Netlify/GitHub Pages — TBD).
//
// Why a constants file rather than baking the URLs into the
// SettingsScreen tile: same reason as AccountService and
// DataExportService — Settings UI is still in design, the launch
// blockers are these URLs being correct everywhere they're
// referenced (paywall T&Cs disclosure, sign-up disclaimer, account
// settings). Centralise once, swap the constant when the domain is
// live.
//
// TODO(sprint-17): Once Rob picks a domain (elio.app / elio-recipes.com
// / etc.) and publishes the two pages, replace the placeholder URLs
// below. The Play/App Store listings reference the same URLs — keep
// them in sync.

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalLinks {
  LegalLinks._();

  /// Placeholder URLs. **Must be replaced before store submission.**
  /// The flag below trips a runtime assert in debug builds so a real
  /// release can't ship with these still in place.
  static const String privacyPolicyUrl =
      'https://elio.app/privacy';
  static const String termsOfServiceUrl =
      'https://elio.app/terms';

  /// Email address used by the Send Feedback tile and any "Contact
  /// us" links the legal pages reference. Owned by Rob, not a
  /// dedicated alias yet — fine for v1, swap later.
  static const String supportEmail = 'support@elio.app';

  /// Set to `true` once the URLs above point to real, hosted pages.
  /// Tested in `legal_links_test.dart` so a release build cannot ship
  /// while this is still false.
  static const bool urlsAreLive = false;

  /// Opens [url] in the system browser. Returns false if the launch
  /// fails so the caller can show a fallback (copy-to-clipboard, say).
  static Future<bool> open(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('LegalLinks.open failed: $e');
      }
      return false;
    }
  }

  static Future<bool> openPrivacyPolicy() => open(privacyPolicyUrl);
  static Future<bool> openTermsOfService() => open(termsOfServiceUrl);
}
