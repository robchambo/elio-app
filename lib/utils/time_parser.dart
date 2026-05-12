// lib/utils/time_parser.dart
//
// Sprint 16.6 — cooking timer.
//
// Regex parser that extracts cookable durations from recipe step
// text. Powers two needs:
//
//   1. `firstDuration(text)` — pre-fill the duration picker when the
//      user taps an inline pill or the per-step clock-fallback icon.
//   2. `findMatches(text)` — return every match with its span position
//      so the ElioMethodStep renderer can split the prose into plain
//      and tappable segments (Paprika-style inline pills).
//
// Patterns covered (case insensitive):
//
//   - "30 minutes", "30 minute", "30 mins", "30 min"
//   - "5 seconds", "5 second", "5 secs", "5 sec"
//   - "1 hour", "1 hours", "1 hr", "1 hrs"
//   - composite "1 hour 30 minutes" (in any short/long combination)
//
// Patterns deliberately NOT covered in v1:
//
//   - Ranges ("5-10 minutes") — ambiguous; AI may write either
//     "to-be-cautious" or "until-this-happens" so we don't guess.
//   - Decimals ("1.5 hours") — AI rarely writes this; "1 hour 30
//     minutes" is the canonical AI output.
//   - "Half an hour", "a couple of minutes" — natural language; not
//     worth the false-match risk in v1. Add later if real recipes
//     need it.
//   - Standalone numbers ("30") with no unit — must have a unit.
//   - Zero durations ("0 minutes") — never a useful timer.
//
// Word-boundary anchors guard against substring matches like "minute"
// inside "miniature".

/// A parsed time match in source text. Spans are character offsets so
/// the renderer can substring around them for plain/tappable splits.
class TimeMatch {
  /// Inclusive start offset (characters) into the source text.
  final int start;

  /// Exclusive end offset (characters) into the source text.
  final int end;

  /// The matched text exactly as it appeared in the source (preserves
  /// case so the rendered pill text matches what the AI wrote).
  final String matchedText;

  /// The duration this match represents.
  final Duration duration;

  const TimeMatch({
    required this.start,
    required this.end,
    required this.matchedText,
    required this.duration,
  });

  @override
  String toString() =>
      'TimeMatch($start..$end "$matchedText" → ${duration.inMinutes}m '
      '${duration.inSeconds % 60}s)';
}

abstract class TimeParser {
  // Reject ranges like "5-10 minutes" / "5 to 10 minutes".
  // The lookbehind anchor "(?<![\d.-])" ensures we don't match a number
  // that immediately follows a "-" or "to" (range markers).
  // We approximate by detecting a "<number>(-|–|—)<number>" pattern
  // immediately before the unit and rejecting the whole match.
  static final _rangePattern = RegExp(
    r'\d+\s*[-–—]\s*\d+\s*(?:hour|hours|hr|hrs|minute|minutes|min|mins|second|seconds|sec|secs)\b',
    caseSensitive: false,
  );

  // The core composite pattern — captures optional hours + optional
  // minutes + optional seconds, requiring at least one component.
  // Examples it matches (case insensitive):
  //   30 minutes / 30 min / 30 mins / 30 minute
  //   5 seconds / 5 sec / 5 secs / 5 second
  //   1 hour / 1 hr / 2 hours / 2 hrs
  //   1 hour 30 minutes
  //   1 hr 30 min
  //   1 hour 30 minutes 15 seconds
  //
  // Each component requires word boundaries to prevent substring matches
  // (e.g. "miniature" doesn't contain "min" as a word).
  //
  // `\b\d+\b` for the number; the unit is `\b(...)\b`.
  //
  // We separate the three units into named subpatterns so the parsing
  // helper can extract each independently.
  static const String _hourUnit = r'(?:hours?|hrs?)';
  static const String _minUnit = r'(?:minutes?|mins?)';
  static const String _secUnit = r'(?:seconds?|secs?)';

  // Negative lookbehind to reject numbers preceded by a digit or a
  // decimal point. Stops "1.5 hours" from matching as "5 hours" and
  // "300 grams" from matching as a duration after some other digit.
  static const String _numStart = r'(?<![\d.])(\d+)';

  // Composite: optional hours [optional separator] optional minutes
  // [optional separator] optional seconds. Must have at least one
  // component. Components must appear in order (h, m, s).
  static final _compositePattern = RegExp(
    // hours component (optional)
    '(?:\\b$_numStart\\s*$_hourUnit\\b)'
    // optional minutes component (with optional comma/and/space separator)
    '(?:[\\s,]*(?:and\\s+)?(\\d+)\\s*$_minUnit\\b)?'
    // optional seconds component
    '(?:[\\s,]*(?:and\\s+)?(\\d+)\\s*$_secUnit\\b)?'
    '|'
    // OR: minutes-only (no preceding hours)
    '\\b$_numStart\\s*$_minUnit\\b'
    // optional seconds after minutes-only
    '(?:[\\s,]*(?:and\\s+)?(\\d+)\\s*$_secUnit\\b)?'
    '|'
    // OR: seconds-only
    '\\b$_numStart\\s*$_secUnit\\b',
    caseSensitive: false,
  );

  /// Find every parseable duration in [text], in source order, with
  /// non-overlapping spans. Returns an empty list when nothing matches.
  static List<TimeMatch> findMatches(String text) {
    final result = <TimeMatch>[];

    // First pass: collect range expressions so we can exclude any
    // composite match whose span overlaps with a range.
    final rangeSpans = _rangePattern
        .allMatches(text)
        .map((m) => (start: m.start, end: m.end))
        .toList();

    bool overlapsRange(int start, int end) {
      for (final r in rangeSpans) {
        // Overlap if not strictly before nor strictly after.
        if (!(end <= r.start || start >= r.end)) return true;
      }
      return false;
    }

    for (final m in _compositePattern.allMatches(text)) {
      if (overlapsRange(m.start, m.end)) continue;

      // Groups (1-indexed):
      //   Composite path:    1=hours, 2=minutes (opt), 3=seconds (opt)
      //   Minutes-only path: 4=minutes,             5=seconds (opt)
      //   Seconds-only path: 6=seconds
      final hours = int.tryParse(m.group(1) ?? '');
      final minsAfterHours = int.tryParse(m.group(2) ?? '');
      final secsAfterHours = int.tryParse(m.group(3) ?? '');
      final minsOnly = int.tryParse(m.group(4) ?? '');
      final secsAfterMins = int.tryParse(m.group(5) ?? '');
      final secsOnly = int.tryParse(m.group(6) ?? '');

      Duration? d;
      if (hours != null) {
        d = Duration(
          hours: hours,
          minutes: minsAfterHours ?? 0,
          seconds: secsAfterHours ?? 0,
        );
      } else if (minsOnly != null) {
        d = Duration(minutes: minsOnly, seconds: secsAfterMins ?? 0);
      } else if (secsOnly != null) {
        d = Duration(seconds: secsOnly);
      }
      if (d == null || d.inSeconds == 0) continue;

      result.add(TimeMatch(
        start: m.start,
        end: m.end,
        matchedText: text.substring(m.start, m.end),
        duration: d,
      ));
    }

    return result;
  }

  /// Returns the first parseable duration in [text], or null if there
  /// is none. Convenience helper for pre-filling the duration picker.
  static Duration? firstDuration(String text) {
    final matches = findMatches(text);
    return matches.isEmpty ? null : matches.first.duration;
  }
}
