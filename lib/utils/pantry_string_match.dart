// Shared name-normalisation for pantry + shopping dedup.
//
// `nameLower`  → lowercase trim. Fallback lookup key.
// `matchKey`   → singularised lowercase. Primary dedup key. Collapses
//                "Carrot" and "Carrots" so they merge into one row.
//
// Sourced from ShoppingService._singularise (Sprint 16.3) — extracted
// here so the new InventoryWriter consumes the same logic without a
// second copy. Behaviour preserved.

class PantryStringMatch {
  PantryStringMatch._();

  /// Lowercase + trim. The fallback lookup key for legacy rows that
  /// pre-date `matchKey` and the `nameLower` indexing on shopping items.
  static String nameLower(String name) => name.trim().toLowerCase();

  /// Singularised lowercase. The primary dedup key.
  ///
  /// Crude English singulariser — sufficient for produce names. Returns
  /// the input unchanged when stripping a trailing 's'/'es'/'ies' would
  /// be wrong (words ending in "ss"/"us"/"is"/short words).
  static String matchKey(String name) {
    final s = nameLower(name);
    if (s.length < 4) return s;
    if (s.endsWith('ss') || s.endsWith('us') || s.endsWith('is')) return s;
    if (s.endsWith('ies')) return '${s.substring(0, s.length - 3)}y';
    if (s.endsWith('oes') || s.endsWith('xes') || s.endsWith('ches') ||
        s.endsWith('shes')) {
      return s.substring(0, s.length - 2);
    }
    if (s.endsWith('s')) return s.substring(0, s.length - 1);
    return s;
  }
}
