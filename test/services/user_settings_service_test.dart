// Sprint 16.1 — case-mismatch fix.
//
// Onboarding screen 4 writes lowercase dietary tokens
// ('vegetarian', 'vegan', etc.) while the Settings → Dietary
// screen uses TitleCase IDs ('Vegetarian', 'Vegan', etc.).
// `UserSettingsService.canonicaliseDietaryList` is the single source
// for normalising — these tests pin its contract so a regression
// can't silently re-break the "vegetarian set in onboarding doesn't
// pre-select in Settings" bug Rob reported.
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/services/user_settings_service.dart';

void main() {
  group('UserSettingsService.canonicaliseDietaryToken', () {
    test('maps lowercase onboarding tokens to TitleCase Settings IDs', () {
      expect(
          UserSettingsService.canonicaliseDietaryToken('vegetarian'), 'Vegetarian');
      expect(UserSettingsService.canonicaliseDietaryToken('vegan'), 'Vegan');
      expect(UserSettingsService.canonicaliseDietaryToken('pescatarian'),
          'Pescatarian');
      expect(UserSettingsService.canonicaliseDietaryToken('halal'), 'Halal');
      expect(UserSettingsService.canonicaliseDietaryToken('kosher'), 'Kosher');
    });

    test('passes through canonical TitleCase tokens unchanged', () {
      expect(UserSettingsService.canonicaliseDietaryToken('Vegetarian'),
          'Vegetarian');
      expect(UserSettingsService.canonicaliseDietaryToken('Nut-free'),
          'Nut-free');
      expect(UserSettingsService.canonicaliseDietaryToken('Gluten-free'),
          'Gluten-free');
    });

    test('passes through unknown tokens unchanged', () {
      // Custom user-typed values that don't match the preset map
      // shouldn't be silently reshaped.
      expect(UserSettingsService.canonicaliseDietaryToken('paleo'), 'paleo');
    });

    test('trims whitespace before lookup', () {
      expect(
          UserSettingsService.canonicaliseDietaryToken('  vegetarian  '),
          'Vegetarian');
    });
  });

  group('UserSettingsService.canonicaliseDietaryList', () {
    test('canonicalises every token and de-dupes after normalisation', () {
      final out = UserSettingsService.canonicaliseDietaryList(
          ['vegetarian', 'Vegetarian', 'vegan']);
      expect(out, ['Vegetarian', 'Vegan']);
    });

    test('preserves order of first occurrence', () {
      final out = UserSettingsService.canonicaliseDietaryList(
          ['kosher', 'vegetarian', 'halal']);
      expect(out, ['Kosher', 'Vegetarian', 'Halal']);
    });

    test('handles empty list', () {
      expect(UserSettingsService.canonicaliseDietaryList(const <String>[]),
          isEmpty);
    });
  });
}
