import 'dart:convert';

// ─────────────────────────────────────────────
// JsonExtractor
// Robust JSON object extraction from raw LLM responses
// (handles markdown fences, leading prose, truncated SSE payloads).
//
// Lifted out of GeminiService so the eval harness can use the
// same logic when parsing model outputs for structural checks.
// ─────────────────────────────────────────────

/// Extract a JSON object from a string that may contain markdown fences,
/// leading/trailing prose, or a truncated tail. Throws if no usable
/// object can be recovered.
Map<String, dynamic> extractJsonObject(String text) {
  text = text.trim();

  // 1. If responseMimeType worked, the whole body IS the JSON.
  if (text.startsWith('{')) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      // Fall through to fence stripping.
    }
  }

  // 2. Strip markdown code fences (```json ... ``` or ``` ... ```).
  final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
  final fenceMatch = fencePattern.firstMatch(text);
  if (fenceMatch != null) {
    final inner = fenceMatch.group(1)?.trim() ?? '';
    if (inner.isNotEmpty) {
      try {
        return jsonDecode(inner) as Map<String, dynamic>;
      } catch (_) {
        // Fall through to brace extraction.
      }
    }
  }

  // 3. Find outermost { ... } braces.
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end != -1 && end > start) {
    final candidate = text.substring(start, end + 1);
    try {
      return jsonDecode(candidate) as Map<String, dynamic>;
    } catch (_) {
      // Fall through to truncation repair.
    }
  }

  // 4. Truncation repair — common when SSE is cut mid-payload before
  // the MAX_TOKENS finish-reason chunk arrives. Walk forward tracking
  // string state + container nesting, then close any unfinished
  // string / array / object so the result is at least syntactically
  // valid. Recipe model fields are nullable / list-defaulting so a
  // partial recipe usually still renders something.
  if (start != -1) {
    final repaired = _tryRepairTruncatedJson(text.substring(start));
    if (repaired != null) {
      try {
        return jsonDecode(repaired) as Map<String, dynamic>;
      } catch (_) {
        // Repair didn't help — fall through to the throw below.
      }
    }
  }

  if (start != -1 && end != -1 && end > start) {
    throw Exception('Could not parse recipe JSON (response was truncated).');
  }
  throw Exception('No JSON object found in AI response. Please try again.');
}

/// Best-effort repair of a truncated JSON object. Walks the string
/// once, tracking string-literal state + container depth, then
/// appends the closing characters needed to balance the structure.
/// Returns null if there is no `{` to anchor to.
///
/// Deliberately permissive: a truncated string at the tail is closed
/// with `"`, an unfinished array with `]`, etc. The resulting JSON
/// may have an empty/short final field, but the rest of the recipe
/// (title, ingredients up to the cut, partial steps) renders, which
/// is far better than the user seeing a parse error.
String? _tryRepairTruncatedJson(String text) {
  if (!text.contains('{')) return null;
  final stack = <String>[]; // '}' or ']' to append, in reverse open order
  bool inString = false;
  bool escape = false;
  int lastSafeEnd = -1; // index just past the last well-formed value boundary

  for (int i = 0; i < text.length; i++) {
    final ch = text[i];
    if (escape) {
      escape = false;
      continue;
    }
    if (inString) {
      if (ch == '\\') {
        escape = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    switch (ch) {
      case '"':
        inString = true;
        break;
      case '{':
        stack.add('}');
        break;
      case '[':
        stack.add(']');
        break;
      case '}':
      case ']':
        if (stack.isNotEmpty) stack.removeLast();
        if (stack.isEmpty) lastSafeEnd = i + 1;
        break;
    }
  }

  // If the stream landed exactly at a complete top-level object, no
  // repair needed — caller should have parsed it already, but return
  // anyway for safety.
  if (stack.isEmpty && lastSafeEnd > 0) {
    return text.substring(0, lastSafeEnd);
  }

  final buf = StringBuffer(text);
  // Close any unfinished string first.
  if (inString) buf.write('"');
  // Trim a trailing comma before closing — `[1, 2,` → `[1, 2]`.
  var tail = buf.toString();
  final trimmed = tail.replaceFirst(RegExp(r'[,\s]+$'), '');
  if (trimmed.length != tail.length) {
    buf
      ..clear()
      ..write(trimmed);
  }
  // Likewise drop a trailing colon / partial key — `"steps":` → drop.
  final tail2 = buf.toString();
  final trimmed2 = tail2.replaceFirst(RegExp(r',\s*"[^"]*"\s*:\s*$'), '');
  if (trimmed2.length != tail2.length) {
    buf
      ..clear()
      ..write(trimmed2);
  }
  // Append closing chars in reverse order of opens.
  for (var i = stack.length - 1; i >= 0; i--) {
    buf.write(stack[i]);
  }
  return buf.toString();
}
