// test/utils/time_parser_test.dart
//
// Sprint 16.6 — cooking timer.
//
// Pure-function tests for the regex parser that extracts cookable
// durations from recipe step text. The Paprika-style inline tappable
// pills depend on `findMatches(text)` returning every match with its
// span position so the step renderer can split text into plain +
// tappable segments. `firstDuration(text)` is the convenience helper
// for the case where we just want a pre-fill for the duration picker.

import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/utils/time_parser.dart';

void main() {
  group('TimeParser.firstDuration', () {
    test('returns null when there are no durations in the text', () {
      expect(TimeParser.firstDuration('Mix everything together.'), isNull);
    });

    test('parses "30 minutes"', () {
      expect(
        TimeParser.firstDuration('Bake for 30 minutes until golden.'),
        const Duration(minutes: 30),
      );
    });

    test('parses the short form "30 min"', () {
      expect(
        TimeParser.firstDuration('Simmer for 30 min.'),
        const Duration(minutes: 30),
      );
    });

    test('parses "30 mins" (plural short form)', () {
      expect(
        TimeParser.firstDuration('Rest for 30 mins.'),
        const Duration(minutes: 30),
      );
    });

    test('parses "1 hour"', () {
      expect(
        TimeParser.firstDuration('Marinate for 1 hour.'),
        const Duration(hours: 1),
      );
    });

    test('parses "2 hours"', () {
      expect(
        TimeParser.firstDuration('Roast for 2 hours.'),
        const Duration(hours: 2),
      );
    });

    test('parses "1 hr"', () {
      expect(
        TimeParser.firstDuration('Cook for 1 hr.'),
        const Duration(hours: 1),
      );
    });

    test('parses composite "1 hour 30 minutes"', () {
      expect(
        TimeParser.firstDuration('Slow cook for 1 hour 30 minutes.'),
        const Duration(hours: 1, minutes: 30),
      );
    });

    test('parses composite "1 hr 30 min" (mixed short forms)', () {
      expect(
        TimeParser.firstDuration('Slow cook for 1 hr 30 min.'),
        const Duration(hours: 1, minutes: 30),
      );
    });

    test('parses "45 seconds"', () {
      expect(
        TimeParser.firstDuration('Toast for 45 seconds.'),
        const Duration(seconds: 45),
      );
    });

    test('parses short form "30 secs"', () {
      expect(
        TimeParser.firstDuration('Pulse for 30 secs.'),
        const Duration(seconds: 30),
      );
    });

    test('returns first match when multiple times present', () {
      // "Bake for 30 minutes then rest for 5 minutes"
      expect(
        TimeParser.firstDuration(
            'Bake for 30 minutes then rest for 5 minutes.'),
        const Duration(minutes: 30),
      );
    });

    test('ignores ambiguous ranges like "5-10 minutes"', () {
      // v1: conservative — skip ranges to avoid guessing the user's intent.
      // "5-10 minutes" could mean "5 to 10" — Paprika just uses the
      // longer in that case but Elio's recipes are AI-generated so we
      // can't trust ranges to be conservative. Skip entirely.
      expect(
        TimeParser.firstDuration('Bake for 5-10 minutes until done.'),
        isNull,
      );
    });

    test('case insensitive', () {
      expect(
        TimeParser.firstDuration('SIMMER FOR 20 MINUTES.'),
        const Duration(minutes: 20),
      );
    });

    test('rejects decimals like "1.5 hours" in v1', () {
      // v1: integer durations only. AI-generated recipes use "1 hour
      // 30 minutes" not "1.5 hours" the majority of the time. Reassess
      // if real recipes need this.
      expect(
        TimeParser.firstDuration('Brine for 1.5 hours.'),
        isNull,
      );
    });

    test('rejects "0 minutes"', () {
      // A zero-duration timer is never useful — bail rather than match.
      expect(
        TimeParser.firstDuration('Wait for 0 minutes.'),
        isNull,
      );
    });

    test('does not match standalone numbers without unit', () {
      expect(
        TimeParser.firstDuration('Add 30 g of butter.'),
        isNull,
      );
    });

    test('does not match "minute" as part of "miniature"', () {
      // Word-boundary check guards against substring false matches.
      expect(
        TimeParser.firstDuration('Garnish with miniature herbs.'),
        isNull,
      );
    });
  });

  group('TimeParser.findMatches', () {
    test('returns empty list when no durations', () {
      expect(TimeParser.findMatches('Mix everything.'), isEmpty);
    });

    test('returns one match for a single duration', () {
      final matches = TimeParser.findMatches('Bake for 30 minutes.');
      expect(matches, hasLength(1));
      expect(matches.first.duration, const Duration(minutes: 30));
      expect(matches.first.start, 9);
      expect(matches.first.end, 19); // "30 minutes" is 10 chars at position 9
      expect(matches.first.matchedText, '30 minutes');
    });

    test('returns multiple matches in order, with non-overlapping spans', () {
      final matches = TimeParser.findMatches(
        'Bake for 30 minutes then rest for 5 mins.',
      );
      expect(matches, hasLength(2));
      expect(matches[0].duration, const Duration(minutes: 30));
      expect(matches[1].duration, const Duration(minutes: 5));
      expect(matches[0].end <= matches[1].start, isTrue);
    });

    test('composite "1 hour 30 minutes" is a single match span', () {
      final matches = TimeParser.findMatches('Slow cook for 1 hour 30 minutes.');
      expect(matches, hasLength(1));
      expect(matches.first.duration, const Duration(hours: 1, minutes: 30));
      expect(matches.first.matchedText, '1 hour 30 minutes');
    });

    test('composite "1 hr 30 min" is a single match span', () {
      final matches = TimeParser.findMatches('Cook for 1 hr 30 min.');
      expect(matches, hasLength(1));
      expect(matches.first.duration, const Duration(hours: 1, minutes: 30));
      expect(matches.first.matchedText, '1 hr 30 min');
    });

    test('skips range expressions like "5-10 minutes"', () {
      final matches = TimeParser.findMatches('Bake for 5-10 minutes.');
      expect(matches, isEmpty);
    });

    test('preserves case of matched text', () {
      final matches = TimeParser.findMatches('SIMMER FOR 20 MINUTES.');
      expect(matches.first.matchedText, '20 MINUTES');
    });
  });
}
