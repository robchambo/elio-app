// ─────────────────────────────────────────────
// QuantityUtils
// Parsing, normalisation, and consolidation of
// ingredient quantities for shopping lists.
// ─────────────────────────────────────────────

/// A parsed numeric quantity with its normalised unit.
class ParsedQuantity {
  final double amount;
  final String unit;

  const ParsedQuantity(this.amount, this.unit);

  @override
  String toString() => 'ParsedQuantity($amount, "$unit")';
}

/// Utility helpers for ingredient quantity consolidation.
///
/// Parses free-text quantity strings, normalises units, and combines
/// multiple quantities of the same ingredient into a single display string.
class QuantityUtils {
  QuantityUtils._();

  // ── Unit alias map ──────────────────────────

  static const Map<String, String> _unitAliases = {
    // Volume
    'cup': 'cup',
    'cups': 'cup',
    'tablespoon': 'tbsp',
    'tablespoons': 'tbsp',
    'tbsp': 'tbsp',
    'tbs': 'tbsp',
    'teaspoon': 'tsp',
    'teaspoons': 'tsp',
    'tsp': 'tsp',
    'ml': 'ml',
    'millilitre': 'ml',
    'millilitres': 'ml',
    'milliliter': 'ml',
    'milliliters': 'ml',
    'litre': 'l',
    'litres': 'l',
    'liter': 'l',
    'liters': 'l',
    'l': 'l',

    // Weight
    'gram': 'g',
    'grams': 'g',
    'g': 'g',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'kg': 'kg',
    'ounce': 'oz',
    'ounces': 'oz',
    'oz': 'oz',
    'pound': 'lb',
    'pounds': 'lb',
    'lb': 'lb',
    'lbs': 'lb',

    // Countable
    'piece': 'piece',
    'pieces': 'piece',
    'pcs': 'piece',
    'clove': 'clove',
    'cloves': 'clove',
    'slice': 'slice',
    'slices': 'slice',
    'bunch': 'bunch',
    'bunches': 'bunch',
    'can': 'can',
    'cans': 'can',
    'tin': 'can',
    'tins': 'can',
    'head': 'head',
    'heads': 'head',
    'sprig': 'sprig',
    'sprigs': 'sprig',
  };

  // ── Plural display forms ────────────────────

  static const Map<String, String> _pluralForms = {
    'cup': 'cups',
    'tbsp': 'tbsp',
    'tsp': 'tsp',
    'ml': 'ml',
    'l': 'l',
    'g': 'g',
    'kg': 'kg',
    'oz': 'oz',
    'lb': 'lbs',
    'piece': 'pieces',
    'clove': 'cloves',
    'slice': 'slices',
    'bunch': 'bunches',
    'can': 'cans',
    'head': 'heads',
    'sprig': 'sprigs',
  };

  // ── Public API ──────────────────────────────

  /// Parse a quantity string and unit into a [ParsedQuantity].
  ///
  /// Handles integers, decimals, fractions ("1/2"), mixed fractions ("1 1/2"),
  /// and descriptive words ("large", "pinch"). Unit strings are normalised
  /// to a canonical form via an alias table.
  static ParsedQuantity parse(String quantity, String unit) {
    final q = quantity.trim();
    final u = unit.trim().toLowerCase();

    final normUnit = _unitAliases[u] ?? '';
    final amount = _parseAmount(q);

    // Descriptive quantity — no numeric value and no recognised unit
    if (amount == 0 && q.isNotEmpty && normUnit.isEmpty && u.isEmpty) {
      // Treat the raw quantity text as a descriptive unit
      return ParsedQuantity(0, q.toLowerCase());
    }

    // Descriptive unit that isn't in our alias table
    if (amount == 0 && q.isEmpty && u.isNotEmpty && normUnit.isEmpty) {
      return ParsedQuantity(0, u);
    }

    return ParsedQuantity(amount, normUnit.isNotEmpty ? normUnit : u);
  }

  /// Combine a list of [ParsedQuantity] values into a single display string.
  ///
  /// Quantities sharing the same unit are summed. Different units are joined
  /// with " + ". Descriptive (zero-amount) entries are appended as-is.
  static String combine(List<ParsedQuantity> quantities) {
    if (quantities.isEmpty) return '';

    // Separate numeric from descriptive
    final numeric = <String, double>{};
    final descriptive = <String>{};

    for (final pq in quantities) {
      if (pq.amount == 0) {
        // Descriptive — keep unique labels
        if (pq.unit.isNotEmpty) descriptive.add(pq.unit);
      } else {
        numeric[pq.unit] = (numeric[pq.unit] ?? 0) + pq.amount;
      }
    }

    final parts = <String>[];

    // Format numeric groups
    for (final entry in numeric.entries) {
      final amount = entry.value;
      final unit = entry.key;
      final display = _formatAmount(amount);

      if (unit.isEmpty) {
        parts.add(display);
      } else {
        final unitDisplay = displayUnit(unit, amount);
        // Compact for short symbol units (g, ml, kg, etc.)
        if (_isSymbolUnit(unit)) {
          parts.add('$display$unitDisplay');
        } else {
          parts.add('$display $unitDisplay');
        }
      }
    }

    // Append descriptive entries
    for (final d in descriptive) {
      parts.add(d);
    }

    return parts.join(' + ');
  }

  /// Return the display form of a normalised unit, pluralised when [amount] > 1.
  static String displayUnit(String normalisedUnit, double amount) {
    if (normalisedUnit.isEmpty) return '';

    // Check if it's a known unit with plural forms
    if (_pluralForms.containsKey(normalisedUnit)) {
      return amount > 1 ? _pluralForms[normalisedUnit]! : normalisedUnit;
    }

    // Unknown unit — return as-is
    return normalisedUnit;
  }

  // ── Private helpers ─────────────────────────

  /// Parse a string into a double, handling fractions and mixed numbers.
  static double _parseAmount(String text) {
    if (text.isEmpty) return 0;

    // Replace Unicode fraction characters
    var t = text
        .replaceAll('\u00BC', '1/4')   // ¼
        .replaceAll('\u00BD', '1/2')   // ½
        .replaceAll('\u00BE', '3/4')   // ¾
        .replaceAll('\u2153', '1/3')   // ⅓
        .replaceAll('\u2154', '2/3');  // ⅔
    // Handle combined forms like "1½" → "1 1/2"
    t = t.replaceAllMapped(
      RegExp(r'(\d)(\d/\d)'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    // Try simple double parse first
    final simple = double.tryParse(t);
    if (simple != null) return simple;

    // Mixed fraction: "1 1/2"
    final mixedMatch = RegExp(r'^(\d+)\s+(\d+)/(\d+)$').firstMatch(t);
    if (mixedMatch != null) {
      final whole = int.parse(mixedMatch.group(1)!);
      final num = int.parse(mixedMatch.group(2)!);
      final den = int.parse(mixedMatch.group(3)!);
      return den != 0 ? whole + num / den : 0;
    }

    // Simple fraction: "1/2"
    final fracMatch = RegExp(r'^(\d+)/(\d+)$').firstMatch(t);
    if (fracMatch != null) {
      final num = int.parse(fracMatch.group(1)!);
      final den = int.parse(fracMatch.group(2)!);
      return den != 0 ? num / den : 0;
    }

    // Unparsable — descriptive text like "large", "handful"
    return 0;
  }

  /// Format a double for display: whole numbers without decimal, otherwise 1-2
  /// decimal places with trailing zeros stripped.
  static String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    // Up to 2 decimal places, strip trailing zeros
    var s = value.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  /// Whether a unit is a short symbol that should be rendered without a space
  /// (e.g. "200g" rather than "200 g").
  static bool _isSymbolUnit(String unit) {
    return const {'g', 'kg', 'ml', 'l', 'oz', 'lb', 'lbs'}.contains(unit);
  }
}
