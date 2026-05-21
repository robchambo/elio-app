import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_radii.dart';

void main() {
  group('ElioRadii rebrand values', () {
    test('chip is 999 (full pill)', () {
      expect(ElioRadii.chip, 999.0);
    });
    test('button is 20', () {
      expect(ElioRadii.button, 20.0);
    });
    test('card is 16', () {
      expect(ElioRadii.card, 16.0);
    });
    test('panel is 14', () {
      expect(ElioRadii.panel, 14.0);
    });
    test('input is 14', () {
      expect(ElioRadii.input, 14.0);
    });
  });
}
