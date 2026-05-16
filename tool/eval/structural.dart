import 'package:elio_app/utils/json_extractor.dart';

import 'fixtures.dart';

// ─────────────────────────────────────────────
// Structural checks — applied to every model output.
// Catches the hard failures (JSON broken, perishables ignored,
// dietary tags missing, cost field absent, UK unit violations).
// ─────────────────────────────────────────────

class CheckResult {
  final String name;
  final bool passed;
  final String? detail;
  const CheckResult(this.name, this.passed, [this.detail]);

  Map<String, dynamic> toJson() => {
    'name': name,
    'passed': passed,
    if (detail != null) 'detail': detail,
  };
}

class StructuralReport {
  final List<CheckResult> checks;
  final Map<String, dynamic>? parsedJson; // null if json_parses failed

  const StructuralReport(this.checks, this.parsedJson);

  int get passed => checks.where((c) => c.passed).length;
  int get total => checks.length;
  double get passRate => total == 0 ? 0 : passed / total;

  Map<String, dynamic> toJson() => {
    'checks': checks.map((c) => c.toJson()).toList(),
    'passed': passed,
    'total': total,
    'passRate': passRate,
  };
}

StructuralReport runStructuralChecks(String rawText, Fixture fixture) {
  final checks = <CheckResult>[];
  Map<String, dynamic>? parsed;

  // 1. json_parses
  try {
    parsed = extractJsonObject(rawText);
    checks.add(const CheckResult('json_parses', true));
  } catch (e) {
    checks.add(CheckResult('json_parses', false, e.toString()));
    return StructuralReport(checks, null);
  }

  // 2. all_required_perishables_used
  // Skip for leftover mode (no perishables field semantically)
  if (fixture.request.perishables.isNotEmpty) {
    final ingredients = (parsed['ingredients'] as List<dynamic>? ?? [])
        .map((i) => (i is Map<String, dynamic>) ? (i['name'] as String? ?? '').toLowerCase() : '')
        .toList();
    final steps = (parsed['steps'] as List<dynamic>? ?? []).map((s) => s.toString().toLowerCase()).join(' ');
    final missing = <String>[];
    for (final p in fixture.request.perishables) {
      final needle = p.toLowerCase();
      // Match the perishable against any ingredient name (substring) OR a step mention
      final inIngredients = ingredients.any((name) => _ingredientMatches(name, needle));
      final inSteps = steps.contains(needle.split(' ').last); // last word, e.g. "breast" → "chicken breast"
      if (!inIngredients && !inSteps) {
        missing.add(p);
      }
    }
    checks.add(CheckResult(
      'all_required_perishables_used',
      missing.isEmpty,
      missing.isEmpty ? null : 'Missing: ${missing.join(', ')}',
    ));
  }

  // 3. dietary_tags_present (only when dietary requirements exist)
  if (fixture.request.dietaryRequirements.isNotEmpty) {
    final tags = (parsed['dietaryTags'] as List<dynamic>? ?? []).map((t) => t.toString()).toList();
    checks.add(CheckResult(
      'dietary_tags_present',
      tags.isNotEmpty,
      tags.isEmpty ? 'dietaryTags array is empty despite ${fixture.request.dietaryRequirements.length} dietary constraints' : null,
    ));
  }

  // 4. cost_field_populated
  final costUSD = parsed['estimatedCostPerServingUSD'];
  final costGBP = parsed['estimatedCostPerServingGBP'];
  final hasCost = (costUSD is num && costUSD > 0) && (costGBP is num && costGBP > 0);
  checks.add(CheckResult(
    'cost_field_populated',
    hasCost,
    hasCost ? null : 'USD=$costUSD, GBP=$costGBP',
  ));

  // 5. region_units_correct — for UK fixtures, no imperial units should appear
  if (fixture.region == 'uk') {
    final ingredients = parsed['ingredients'] as List<dynamic>? ?? [];
    final imperialUnits = ['cup', 'cups', 'oz', 'ounce', 'ounces', 'lb', 'lbs', 'pound', 'pounds', 'fl oz', 'tsp.', 'tbsp.']; // tsp/tbsp alone are accepted
    final offenders = <String>[];
    for (final ing in ingredients) {
      if (ing is Map<String, dynamic>) {
        final unit = (ing['unit'] as String? ?? '').toLowerCase().trim();
        if (imperialUnits.contains(unit)) {
          offenders.add('${ing['name']} (${ing['unit']})');
        }
      }
    }
    checks.add(CheckResult(
      'region_units_correct',
      offenders.isEmpty,
      offenders.isEmpty ? null : 'Imperial units in UK recipe: ${offenders.join(', ')}',
    ));
  }

  return StructuralReport(checks, parsed);
}

bool _ingredientMatches(String ingredientName, String needle) {
  // Substring match in either direction — "chicken breast" needle should match
  // ingredient name "Chicken Breast" or just "chicken" or "chicken thighs".
  if (ingredientName.contains(needle)) return true;
  if (needle.contains(ingredientName) && ingredientName.length >= 3) return true;
  // Match on last word (e.g. "cherry tomatoes" → "tomatoes")
  final lastWord = needle.split(' ').last;
  if (lastWord.length >= 4 && ingredientName.contains(lastWord)) return true;
  return false;
}
