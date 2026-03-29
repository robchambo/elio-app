import 'package:flutter/material.dart';
import '../theme/elio_theme.dart';

// ─────────────────────────────────────────────
// PantryUtils
// Normalisation, fuzzy matching, and duplicate
// detection for pantry inventory items.
// ─────────────────────────────────────────────

class PantryUtils {
  PantryUtils._();

  /// Common variant map — maps known synonyms to a canonical name.
  static const Map<String, String> _variantMap = {
    'extra virgin olive oil': 'olive oil',
    'evoo': 'olive oil',
    'greek yoghurt': 'yogurt',
    'greek yogurt': 'yogurt',
    'yoghurt': 'yogurt',
    'caster sugar': 'sugar',
    'granulated sugar': 'sugar',
    'brown sugar': 'sugar',
  };

  /// Normalise an item name for comparison: lowercase, trim, strip trailing
  /// 's'/'es' for basic plural handling, apply variant map.
  static String normalise(String name) {
    var n = name.toLowerCase().trim();

    // Apply variant map first (before plural stripping)
    if (_variantMap.containsKey(n)) {
      return _variantMap[n]!;
    }

    // Strip trailing plurals
    // "tomatoes" → strip 'es' when ending in 'oes' → "tomato"
    if (n.endsWith('oes')) {
      n = n.substring(0, n.length - 2);
    }
    // "dishes" → "dish", "batches" → "batch", "boxes" → "box"
    else if (n.endsWith('shes') || n.endsWith('ches') || n.endsWith('xes')) {
      n = n.substring(0, n.length - 2);
    }
    // General trailing 's' — "eggs" → "egg", "onions" → "onion"
    else if (n.endsWith('s') && !n.endsWith('ss')) {
      n = n.substring(0, n.length - 1);
    }

    return n;
  }

  /// Compute the Levenshtein (edit) distance between two strings.
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Use two-row optimisation to save memory
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          curr[j - 1] + 1, // insertion
          prev[j] + 1, // deletion
          prev[j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[b.length];
  }

  /// Check if two normalised names are a fuzzy match.
  /// Returns true if: exact match, one contains the other (shorter >= 3 chars),
  /// or Levenshtein distance is within threshold.
  static bool isFuzzyMatch(String a, String b) {
    final na = normalise(a);
    final nb = normalise(b);

    // Exact match after normalisation
    if (na == nb) return true;

    // Containment check — shorter string must be >= 3 chars
    final shorter = na.length <= nb.length ? na : nb;
    final longer = na.length <= nb.length ? nb : na;
    if (shorter.length >= 3 && longer.contains(shorter)) return true;

    // Levenshtein distance check
    final maxLen = longer.length;
    final threshold = maxLen <= 8 ? 1 : 2;
    return _levenshtein(na, nb) <= threshold;
  }

  /// Find potential duplicates for a new item name against existing items.
  /// Returns list of existing item names that fuzzy-match.
  static List<String> findDuplicates(String newItem, List<String> existing) {
    final matches = <String>[];
    for (final item in existing) {
      if (isFuzzyMatch(newItem, item)) {
        matches.add(item);
      }
    }
    return matches;
  }

  /// Shows a dialog warning the user about potential duplicates.
  /// Returns true if user wants to add anyway, false to cancel.
  static Future<bool> showDuplicateWarning(
    BuildContext context,
    String newItem,
    List<String> matches,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final matchText = matches.length == 1
            ? 'You already have "${matches.first}" in your pantry. Add "$newItem" anyway?'
            : 'You already have similar items in your pantry:\n${matches.map((m) => '  \u2022 $m').join('\n')}\n\nAdd "$newItem" anyway?';

        return AlertDialog(
          backgroundColor: ElioColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Similar item found', style: ElioText.headingMedium),
          content: Text(matchText, style: ElioText.bodyMedium),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ElioColors.amber, width: 1.5),
                foregroundColor: ElioColors.amber,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Add anyway',
                style: ElioText.bodyMedium.copyWith(
                  color: ElioColors.amber,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
