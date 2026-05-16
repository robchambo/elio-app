import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/utils/json_extractor.dart';

void main() {
  group('extractJsonObject — happy path', () {
    test('parses a clean JSON object', () {
      const raw = '{"title":"Stir-fry","servings":2}';
      final result = extractJsonObject(raw);
      expect(result['title'], 'Stir-fry');
      expect(result['servings'], 2);
    });

    test('parses JSON wrapped in markdown code fence', () {
      const raw = '''Here's your recipe:
```json
{"title":"Curry","servings":4}
```
Enjoy!''';
      final result = extractJsonObject(raw);
      expect(result['title'], 'Curry');
      expect(result['servings'], 4);
    });

    test('parses JSON with leading prose via brace extraction', () {
      const raw = 'Sure, here you go: {"title":"Pasta","servings":3} — bon appetit.';
      final result = extractJsonObject(raw);
      expect(result['title'], 'Pasta');
    });
  });

  group('extractJsonObject — truncation repair', () {
    test('repairs an SSE cut mid-string', () {
      // Stream ends partway through the description field.
      const raw = '{"title":"Roast","description":"A warm, comforting roast that ';
      final result = extractJsonObject(raw);
      expect(result['title'], 'Roast');
      expect(result['description'], isA<String>());
    });

    test('repairs an SSE cut mid-array with trailing comma', () {
      const raw = '{"title":"Salad","ingredients":["lettuce","tomato",';
      final result = extractJsonObject(raw);
      expect(result['title'], 'Salad');
      expect(result['ingredients'], ['lettuce', 'tomato']);
    });

    test('repairs an SSE cut at a partial key with colon', () {
      const raw = '{"title":"Soup","servings":2,"steps":';
      final result = extractJsonObject(raw);
      expect(result['title'], 'Soup');
      expect(result['servings'], 2);
      expect(result.containsKey('steps'), isFalse);
    });

    test('repairs nested object truncation', () {
      const raw = '{"title":"Stew","nutrition":{"calories":420,"proteinG":';
      final result = extractJsonObject(raw);
      expect(result['title'], 'Stew');
      expect(result['nutrition'], isA<Map>());
    });
  });

  group('extractJsonObject — failure modes', () {
    test('throws a meaningful Exception on irreparable corruption', () {
      // Regression: Gemini 2.5 Flash occasionally emits non-target-language
      // tokens in non-string positions (`がいったん停止` between an ingredient
      // and the closing `]`). The previous refactor turned this case into a
      // RangeError because of an unsafe `.substring(0, 80)` on the underlying
      // jsonDecode error message. This test pins the recovery: it must throw
      // an `Exception` with a useful message, never a RangeError.
      const raw =
          '{"title":"Stir-fry","ingredients":[{"name":"oil"}\n  がいったん停止\n  ],"servings":2}';
      expect(
        () => extractJsonObject(raw),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            isNot(contains('RangeError')),
          ),
        ),
      );
    });

    test('throws "No JSON object found" when input has no braces', () {
      expect(
        () => extractJsonObject('Sorry, I cannot help with that.'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No JSON object found'),
          ),
        ),
      );
    });
  });
}
