// test/utils/json_num_test.dart
//
// Hotfix (27 May 2026) — defensive num coercion for Gemini-fed JSON.

import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/utils/json_num.dart';

void main() {
  group('asNum', () {
    test('passes num through unchanged', () {
      expect(asNum(5), 5);
      expect(asNum(5.5), 5.5);
      expect(asNum(0), 0);
      expect(asNum(-3), -3);
    });

    test('null → null', () {
      expect(asNum(null), isNull);
    });

    test('plain numeric strings parse', () {
      expect(asNum('5'), 5);
      expect(asNum('5.5'), 5.5);
      expect(asNum('-3'), -3);
      expect(asNum(' 5 '), 5); // whitespace trimmed
    });

    test('unit-suffixed strings extract the leading number', () {
      expect(asNum('5 min'), 5);
      expect(asNum('5 minutes'), 5);
      expect(asNum('350 kcal'), 350);
      expect(asNum('2.5g'), 2.5);
    });

    test('currency-prefixed strings extract the number', () {
      expect(asNum('\$3.50'), 3.50);
      expect(asNum('£2.99'), 2.99);
      expect(asNum('\$0'), 0);
    });

    test('"about N" prose extracts the number', () {
      expect(asNum('about 5'), 5);
      expect(asNum('approximately 350 calories'), 350);
    });

    test('garbage returns null', () {
      expect(asNum('not a number'), isNull);
      expect(asNum(''), isNull);
      expect(asNum('---'), isNull);
      expect(asNum([1, 2, 3]), isNull);
      expect(asNum({'k': 'v'}), isNull);
    });

    test('caller chain to int / double with fallback works', () {
      expect(asNum('5 min')?.toInt() ?? 99, 5);
      expect(asNum('garbage')?.toInt() ?? 99, 99);
      expect(asNum(null)?.toDouble() ?? 0.0, 0.0);
      expect(asNum('\$3.50')?.toDouble() ?? 0.0, 3.50);
    });
  });
}
