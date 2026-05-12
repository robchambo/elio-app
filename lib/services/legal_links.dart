// lib/services/legal_links.dart
//
// Sprint 17 — single source of truth for the URLs of Elio's hosted
// legal pages. Both Play and App Store listings require the
// privacy-policy URL at submission, so these have to be live before
// launch. The pages themselves are static HTML hosted off-app
// (Vercel/Netlify/GitHub Pages — TBD).
//
// Sprint 16.1 (Settings redesign): trimmed to URL constants only.
// The previous version exposed an `open()` helper backed by
// `url_launcher`, which isn't in pubspec yet. Rather than pull in
// url_launcher just for the legal links (also wanted for support
// email, app-store rate link, etc.), we render Privacy/ToS as
// in-app markdown viewers loaded from `assets/legal/`. When
// url_launcher lands (Sprint 17 launch prep), the open() helpers
// can be reinstated and the in-app viewer can become a fallback.
//
// TODO(sprint-17): Once Rob picks a domain (elio.app /
// elio-recipes.com / etc.) and publishes the two pages, replace the
// placeholder URLs below. The Play/App Store listings reference the
// same URLs — keep them in sync.

class LegalLinks {
  LegalLinks._();

  /// Placeholder URLs. **Must be replaced before store submission.**
  /// The flag below trips a runtime assert in debug builds so a real
  /// release can't ship with these still in place.
  static const String privacyPolicyUrl = 'https://elio.app/privacy';
  static const String termsOfServiceUrl = 'https://elio.app/terms';

  /// Email address used by the Send Feedback tile and any "Contact
  /// us" links the legal pages reference. Owned by Rob, not a
  /// dedicated alias yet — fine for v1, swap later.
  static const String supportEmail = 'support@elio.app';

  /// Set to `true` once the URLs above point to real, hosted pages.
  /// Tested in `legal_links_test.dart` so a release build cannot ship
  /// while this is still false.
  static const bool urlsAreLive = false;
}
