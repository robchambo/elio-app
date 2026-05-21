import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/utils/pantry_staples.dart';

void main() {
  group('PantryStaples.isStaple', () {
    test('matches the four staple words as whole words', () {
      expect(PantryStaples.isStaple('salt'), isTrue);
      expect(PantryStaples.isStaple('sea salt'), isTrue);
      expect(PantryStaples.isStaple('table salt'), isTrue);
      expect(PantryStaples.isStaple('pepper'), isTrue);
      expect(PantryStaples.isStaple('black pepper'), isTrue);
      expect(PantryStaples.isStaple('water'), isTrue);
      expect(PantryStaples.isStaple('tap water'), isTrue);
      expect(PantryStaples.isStaple('sugar'), isTrue);
      expect(PantryStaples.isStaple('caster sugar'), isTrue);
      expect(PantryStaples.isStaple('brown sugar'), isTrue);
    });

    test('does NOT match compound words containing a staple as a substring', () {
      expect(PantryStaples.isStaple('salted butter'), isFalse);
      expect(PantryStaples.isStaple('peppercorns'), isFalse);
      expect(PantryStaples.isStaple('watermelon'), isFalse);
      expect(PantryStaples.isStaple('sugarsnap peas'), isFalse);
    });

    test('matches generic cooking oils exactly only', () {
      expect(PantryStaples.isStaple('oil'), isTrue);
      expect(PantryStaples.isStaple('cooking oil'), isTrue);
      expect(PantryStaples.isStaple('vegetable oil'), isTrue);
      expect(PantryStaples.isStaple('sunflower oil'), isTrue);
      expect(PantryStaples.isStaple('canola oil'), isTrue);
      expect(PantryStaples.isStaple('rapeseed oil'), isTrue);
      expect(PantryStaples.isStaple('neutral oil'), isTrue);
      expect(PantryStaples.isStaple('generic oil'), isTrue);
    });

    test('does NOT match specific flavour oils (recipe-defining)', () {
      expect(PantryStaples.isStaple('sesame oil'), isFalse);
      expect(PantryStaples.isStaple('olive oil'), isFalse);
      expect(PantryStaples.isStaple('chilli oil'), isFalse);
      expect(PantryStaples.isStaple('truffle oil'), isFalse);
    });

    test('input is normalised (lowercased + trimmed) before checking', () {
      expect(PantryStaples.isStaple('  Salt  '), isTrue);
      expect(PantryStaples.isStaple('SEA SALT'), isTrue);
    });
  });
}
