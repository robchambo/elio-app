import 'dart:convert';

// ─────────────────────────────────────────────
// JsonExtractor
// Robust JSON object extraction from raw LLM responses
// (handles markdown fences, leading prose, etc.).
//
// Lifted out of GeminiService so the eval harness can use the
// same logic when parsing model outputs for structural checks.
// ─────────────────────────────────────────────

/// Extract a JSON object from a string that may contain markdown fences,
/// leading/trailing prose, or other noise. Throws if no valid object found.
Map<String, dynamic> extractJsonObject(String text) {
  text = text.trim();

  // 1. If responseMimeType worked, the whole body IS the JSON
  if (text.startsWith('{')) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      // Fall through to fence stripping
    }
  }

  // 2. Strip markdown code fences (```json ... ``` or ``` ... ```)
  final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
  final fenceMatch = fencePattern.firstMatch(text);
  if (fenceMatch != null) {
    final inner = fenceMatch.group(1)?.trim() ?? '';
    if (inner.isNotEmpty) {
      try {
        return jsonDecode(inner) as Map<String, dynamic>;
      } catch (_) {
        // Fall through to brace extraction
      }
    }
  }

  // 3. Find outermost { ... } braces
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end != -1 && end > start) {
    final candidate = text.substring(start, end + 1);
    try {
      return jsonDecode(candidate) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Could not parse recipe JSON: ${e.toString().substring(0, 80)}');
    }
  }

  throw Exception('No JSON object found in AI response. Please try again.');
}
