import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/utils/pantry_string_match.dart';

void main() {
  group('PantryStringMatch.nameLower', () {
    test('lowercases and trims', () {
      expect(PantryStringMatch.nameLower('  Carrots  '), 'carrots');
      expect(PantryStringMatch.nameLower('Sea Salt'), 'sea salt');
      expect(PantryStringMatch.nameLower(''), '');
    });
  });

  group('PantryStringMatch.matchKey', () {
    test('strips trailing s for plural words', () {
      expect(PantryStringMatch.matchKey('carrots'), 'carrot');
      expect(PantryStringMatch.matchKey('Onions'), 'onion');
    });

    test('handles ies → y', () {
      expect(PantryStringMatch.matchKey('berries'), 'berry');
      expect(PantryStringMatch.matchKey('cherries'), 'cherry');
    });

    test('drops es from oes/xes/ches/shes endings', () {
      expect(PantryStringMatch.matchKey('tomatoes'), 'tomato');
      expect(PantryStringMatch.matchKey('boxes'), 'box');
      expect(PantryStringMatch.matchKey('peaches'), 'peach');
      expect(PantryStringMatch.matchKey('dishes'), 'dish');
    });

    test('does not strip trailing s when ending is ss/us/is', () {
      expect(PantryStringMatch.matchKey('hummus'), 'hummus');
      expect(PantryStringMatch.matchKey('cress'), 'cress');
      expect(PantryStringMatch.matchKey('basis'), 'basis');
    });

    test('skips short words (<4 chars)', () {
      expect(PantryStringMatch.matchKey('os'), 'os');
      expect(PantryStringMatch.matchKey('cup'), 'cup');
    });

    test('lowercases and trims before matching', () {
      expect(PantryStringMatch.matchKey('  CARROTS  '), 'carrot');
      expect(PantryStringMatch.matchKey('Tomatoes'), 'tomato');
    });

    test('non-plural words pass through unchanged', () {
      expect(PantryStringMatch.matchKey('pasta'), 'pasta');
      expect(PantryStringMatch.matchKey('rice'), 'rice');
    });
  });
}
