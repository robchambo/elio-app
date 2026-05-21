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

  group('UserSettingsService.canonicaliseApplianceToken', () {
    test('maps onboarding short IDs to Settings display labels', () {
      expect(UserSettingsService.canonicaliseApplianceToken('airfryer'),
          'Air fryer');
      expect(UserSettingsService.canonicaliseApplianceToken('slowcooker'),
          'Slow cooker');
      expect(UserSettingsService.canonicaliseApplianceToken('pressure'),
          'Instant Pot / Pressure cooker');
      expect(UserSettingsService.canonicaliseApplianceToken('blender'),
          'Blender');
      expect(UserSettingsService.canonicaliseApplianceToken('processor'),
          'Food processor');
      expect(UserSettingsService.canonicaliseApplianceToken('mixer'),
          'Stand mixer');
      expect(UserSettingsService.canonicaliseApplianceToken('ricecooker'),
          'Rice cooker');
      // Note: onboarding's label is "BBQ / grill" but Settings displays
      // "Grill / BBQ" — canonicalise to the Settings form so the chip
      // pre-selects.
      expect(UserSettingsService.canonicaliseApplianceToken('bbq'),
          'Grill / BBQ');
    });

    test('preserves base appliances not surfaced as chips in Settings', () {
      // Oven / Hob / Microwave aren't in the Kitchen Settings chip
      // list but Gemini still uses them — pass through cleanly.
      expect(UserSettingsService.canonicaliseApplianceToken('oven'), 'Oven');
      expect(UserSettingsService.canonicaliseApplianceToken('hob'),
          'Hob / stove');
      expect(UserSettingsService.canonicaliseApplianceToken('microwave'),
          'Microwave');
    });

    test('passes through Settings-form labels unchanged', () {
      expect(UserSettingsService.canonicaliseApplianceToken('Sous vide'),
          'Sous vide');
      expect(UserSettingsService.canonicaliseApplianceToken('Air fryer'),
          'Air fryer');
    });
  });

  group('UserSettingsService.canonicaliseApplianceList', () {
    test('canonicalises and de-dupes mixed-form lists', () {
      // Real-world Firestore state after re-toggling: onboarding form
      // alongside Settings form. Should collapse to a single
      // canonical entry.
      final out = UserSettingsService.canonicaliseApplianceList(
          ['airfryer', 'Air fryer', 'pressure']);
      expect(out, ['Air fryer', 'Instant Pot / Pressure cooker']);
    });
  });
}
