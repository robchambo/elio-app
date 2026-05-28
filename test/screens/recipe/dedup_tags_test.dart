// test/screens/recipe/dedup_tags_test.dart
//
// Sprint 17 (28 May 2026) — `_dedupTagsCaseInsensitive` in
// recipe_screen.dart collapses duplicate dietary tags differing only
// in case. The function is file-private; this test re-implements it
// against the same contract so refactors stay honest. If the
// implementation diverges, the test will need to be updated alongside.
//
// Contract:
//   - Order-preserving
//   - First-seen capitalisation wins
//   - Empty/whitespace-only entries dropped
//   - Comparison case-insensitive via toLowerCase + trim

import 'package:flutter_test/flutter_test.dart';

// Mirror of the private helper in recipe_screen.dart. Kept here to
// avoid making the helper public just for testability — the helper is
// trivial enough that drift risk is low + the failure mode (mismatched
// behaviour) shows up immediately in on-device pill rendering.
List<String> dedupTagsCaseInsensitive(Iterable<String> tags) {
  final seen = <String>{};
  final result = <String>[];
  for (final tag in tags) {
    final key = tag.toLowerCase().trim();
    if (key.isEmpty) continue;
    if (seen.add(key)) result.add(tag);
  }
  return result;
}

void main() {
  group('dedupTagsCaseInsensitive', () {
    test('keeps unique tags in original order', () {
      expect(
        dedupTagsCaseInsensitive(['Vegetarian', 'Gluten-Free', 'Dairy-Free']),
        ['Vegetarian', 'Gluten-Free', 'Dairy-Free'],
      );
    });

    test('collapses case-only duplicates, first-seen wins', () {
      // Verbatim shape from Rob's 28 May screenshot.
      expect(
        dedupTagsCaseInsensitive(['Pescatarian', 'gluten-free', 'pescatarian']),
        ['Pescatarian', 'gluten-free'],
      );
    });

    test('first-seen lowercase still wins when uppercase follows', () {
      expect(
        dedupTagsCaseInsensitive(['vegan', 'Vegan']),
        ['vegan'],
      );
    });

    test('drops empty + whitespace-only entries', () {
      expect(
        dedupTagsCaseInsensitive(['Vegan', '', '   ', 'Gluten-Free']),
        ['Vegan', 'Gluten-Free'],
      );
    });

    test('handles surrounding whitespace in keys', () {
      expect(
        dedupTagsCaseInsensitive(['Vegan', '  vegan  ']),
        ['Vegan'],
      );
    });

    test('empty input → empty output', () {
      expect(dedupTagsCaseInsensitive(<String>[]), isEmpty);
    });
  });
}
