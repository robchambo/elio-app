// lib/utils/friendly_error.dart
//
// Sprint 16.6 (deliberation-bleed follow-up, 14 May 2026).
//
// Centralised user-facing error formatter for Gemini network failures
// and other recoverable exceptions. Replaces ad-hoc `e.toString()
// .replaceFirst('Exception: ', '')` patterns scattered across screens.
//
// Two responsibilities:
//
// 1. Map network-shaped exceptions to a friendly "you're offline"
//    message. Triggers were observed in production via:
//      - Rob 13 May (bulk cook offline) → SocketException / Failed
//        host lookup / Network is unreachable / Connection refused.
//      - Kate 14 May (main recipe gen, after app switch) → same
//        ClientException shape: app backgrounded → SSE stream
//        cancelled → on return, raw exception surfaced.
//
// 2. SCRUB the Gemini API key from any exception text before it
//    reaches the user UI OR Crashlytics. The streaming endpoint URL
//    embeds `?key=AIzaSy...` and that URL appears verbatim in
//    `ClientException` messages on network failure. The screenshot
//    Rob captured 14 May showed the API key plainly visible in the
//    in-app error toast — a real security issue regardless of how
//    friendly the message reads.
//
// Use sites: every screen that surfaces a Gemini exception via
// snackbar / toast / state. See callers via `grep friendlyError`.

/// Convert [e] to a user-facing message. Network-shaped exceptions
/// are mapped to "You're offline. Reconnect and try again." The
/// returned string never contains the Gemini API key — both
/// `key=AIzaSy...` query params and bare AIzaSy tokens are scrubbed.
///
/// For non-network exceptions, returns the trimmed exception text
/// with the `Exception: ` prefix stripped, with API key scrubbing
/// applied as a final defensive layer.
String friendlyError(Object e) {
  final raw = e.toString();
  final lower = raw.toLowerCase();
  final isOffline = lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('no address associated with hostname') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection failed') ||
      lower.contains('software caused connection abort') ||
      lower.contains('clientexception with socketfailed');
  if (isOffline) {
    return "You're offline. Reconnect and try again.";
  }
  // Sprint 17 — never leak Dart's raw null-check / type-cast / range /
  // NoSuchMethod toStrings to the user. Two motivating bugs (both 26
  // May 2026):
  //   (a) Kate guest regen surfaced "Null check operator used on a
  //       null value" in a snackbar after the regen path hit its
  //       limit (PR #14 gated that path properly).
  //   (b) Rob meal-plan recipe-tap surfaced "type 'String' is not a
  //       subtype of type 'num?' in type cast" when Gemini emitted a
  //       String for a numeric meal-slot field (PR #19 added a
  //       defensive asNum() coercion).
  // Anything else that bubbles a TypeError / RangeError / NoSuchMethod
  // up to a toast should degrade to a generic friendly message rather
  // than raw `_TypeError` text. The underlying error is still logged
  // via the caller's ErrorService.log — only the user-visible string
  // is sanitised.
  final isDartTypeError = lower.contains('null check operator') ||
      lower.contains('_typeerror') ||
      lower.contains('is not a subtype of') ||
      lower.contains('in type cast') ||
      lower.contains('rangeerror') ||
      lower.contains('nosuchmethoderror');
  if (isDartTypeError) {
    return 'Something went wrong. Please try again.';
  }
  return scrubApiKey(raw.replaceFirst('Exception: ', ''));
}

/// Remove the Gemini API key from any string before display or
/// logging. Two patterns covered:
///   - Query-param shape: `?key=AIzaSy...` / `&key=AIzaSy...`
///   - Bare token: `AIzaSy` + alphanumerics (Google API keys always
///     start with `AIzaSy`)
/// Returns the input with both shapes replaced by `***` markers.
///
/// Use this anywhere a raw URL or exception message could leak into
/// user UI, Crashlytics, or logs. Defensive — assume the source is
/// untrusted.
String scrubApiKey(String input) {
  return input
      .replaceAllMapped(
        RegExp(r'(\?|&)key=[^&\s]+'),
        (m) => '${m.group(1)}key=***',
      )
      .replaceAll(RegExp(r'AIzaSy[A-Za-z0-9_-]+'), '***');
}
