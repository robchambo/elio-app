// lib/utils/json_num.dart
//
// Defensive numeric-field parser for Gemini-produced JSON.
//
// Gemini occasionally emits String values where a number is expected
// (e.g. `"5"` for a count, `"5 min"` for a duration, `"$3.50"` for a
// cost). The previous pattern `(json['x'] as num?)?.toInt()` throws
// `_TypeError: type 'String' is not a subtype of type 'num?' in type
// cast` BEFORE the `?.toInt()` runs, which broke the meal-plan recipe-
// tap flow on the 26may-b APK.
//
// This helper accepts:
//   - `null` → `null`
//   - `num` → as-is
//   - `String` → `num.tryParse`, then leading-numeric extraction for
//     unit-suffixed values like `"5 min"` / `"$3.50"`
//   - anything else → `null`
//
// Callers chain `.toInt()` / `.toDouble()` with a fallback default the
// same way they did against `as num?`.

/// Coerce a dynamic JSON value to `num?` defensively.
///
/// Examples:
///   asNum(5)        → 5
///   asNum(5.5)      → 5.5
///   asNum('5')      → 5
///   asNum('5.5')    → 5.5
///   asNum('5 min')  → 5
///   asNum('\$3.50') → 3.50
///   asNum(null)     → null
///   asNum([1,2])    → null
num? asNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) {
    final trimmed = value.trim();
    final direct = num.tryParse(trimmed);
    if (direct != null) return direct;
    // Extract first signed numeric (handles "5 min", "$3.50", "about 5").
    final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(trimmed);
    if (match != null) return num.tryParse(match.group(0)!);
    return null;
  }
  return null;
}
