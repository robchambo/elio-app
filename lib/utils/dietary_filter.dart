// ─────────────────────────────────────────────
// DietaryFilter
//
// Decides whether a pantry item should be greyed out on screens 11
// (staples) and 12 (perishables) based on the user's selections from
// screens 04 (dietary) and 05 (allergies).
//
// Design (signed off by Kate, 25 Apr 2026):
//   • Greyed-out treatment, not hidden — keeps the user reassured
//     that we know about the item, just not for them.
//   • Most blocking is derived from the canonical PantryCategory name
//     (whole categories grey out for vegan/vegetarian etc.).
//   • A small per-item override list handles cross-category cases —
//     gluten-free especially (soy sauce, sausages, naan etc. are
//     wheat-bearing items that don't live in the obvious category).
//
// Tokens used here MUST match the values written by:
//   • screen04_dietary.dart  → 'vegetarian', 'vegan', 'pescatarian',
//                              'halal', 'kosher', 'none'
//   • screen05_allergies.dart → 'peanut', 'treenut', 'dairy', 'egg',
//                               'fish', 'shellfish', 'soy', 'gluten',
//                               'sesame', plus user-typed strings.
// ─────────────────────────────────────────────

class DietaryFilter {
  DietaryFilter._();

  /// Reasons a single item is blocked, used to render the badge label
  /// on the tile (e.g. "Vegan", "Gluten").
  ///
  /// Returns an empty list when the item is allowed.
  static List<String> blockReasons({
    required String itemName,
    required List<String> dietary,
    required List<String> allergies,
    String? categoryName,
  }) {
    final reasons = <String>[];
    final nameKey = itemName.toLowerCase().trim();
    final dietSet = dietary.map((d) => d.toLowerCase()).toSet();
    final allergySet = allergies.map((a) => a.toLowerCase()).toSet();

    // ─── Category-level blocks ───────────────────────────────────
    if (categoryName != null) {
      final catBlocks = _categoryBlocks[categoryName] ?? const {};
      for (final flag in catBlocks) {
        if (_flagActive(flag, dietSet, allergySet)) {
          reasons.add(_flagLabel(flag));
        }
      }
    }

    // ─── Item-level overrides (cross-category) ───────────────────
    final itemFlags = _itemFlags[nameKey] ?? const <_BlockFlag>{};
    for (final flag in itemFlags) {
      if (!_flagActive(flag, dietSet, allergySet)) continue;
      final label = _flagLabel(flag);
      if (!reasons.contains(label)) reasons.add(label);
    }

    // ─── Custom (user-typed) "rather skip" / allergy strings ─────
    // Anything the user typed on screen 05 — if it appears in the
    // item name as a word, treat it as blocked. e.g. user types
    // "celery" → any item containing "celery" greys out.
    for (final raw in allergies) {
      final token = raw.toLowerCase().trim();
      if (token.isEmpty) continue;
      if (_isCustomToken(token) && _nameContainsWord(nameKey, token)) {
        if (!reasons.contains('Avoid')) reasons.add('Avoid');
      }
    }

    return reasons;
  }

  /// Convenience: is the item blocked at all?
  static bool isBlocked({
    required String itemName,
    required List<String> dietary,
    required List<String> allergies,
    String? categoryName,
  }) =>
      blockReasons(
        itemName: itemName,
        dietary: dietary,
        allergies: allergies,
        categoryName: categoryName,
      ).isNotEmpty;

  // ──────────────────────────────────────────────────────────────
  // Internal flag system
  // ──────────────────────────────────────────────────────────────

  /// Was this token NOT one of the named preset allergens / diets?
  static bool _isCustomToken(String token) {
    const presets = {
      // dietary
      'vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'none',
      // allergy presets
      'peanut', 'treenut', 'dairy', 'egg', 'fish', 'shellfish',
      'soy', 'gluten', 'sesame',
    };
    return !presets.contains(token);
  }

  static bool _nameContainsWord(String name, String word) {
    // Whole-word-ish: split on non-letters.
    final parts = name.split(RegExp(r'[^a-z]+'));
    return parts.any((p) => p == word);
  }

  static bool _flagActive(
    _BlockFlag flag,
    Set<String> diet,
    Set<String> allergies,
  ) {
    switch (flag) {
      case _BlockFlag.vegan:
        return diet.contains('vegan');
      case _BlockFlag.vegetarian:
        // Vegan is a stricter superset of vegetarian — block too.
        return diet.contains('vegetarian') || diet.contains('vegan');
      case _BlockFlag.meat:
        // Anyone who isn't a meat eater.
        return diet.contains('vegetarian') ||
            diet.contains('vegan') ||
            diet.contains('pescatarian');
      case _BlockFlag.fish:
        return diet.contains('vegetarian') ||
            diet.contains('vegan') ||
            allergies.contains('fish');
      case _BlockFlag.shellfish:
        return diet.contains('vegetarian') ||
            diet.contains('vegan') ||
            allergies.contains('shellfish');
      case _BlockFlag.dairy:
        return diet.contains('vegan') || allergies.contains('dairy');
      case _BlockFlag.egg:
        return diet.contains('vegan') || allergies.contains('egg');
      case _BlockFlag.gluten:
        return allergies.contains('gluten');
      case _BlockFlag.soy:
        return allergies.contains('soy');
      case _BlockFlag.peanut:
        return allergies.contains('peanut');
      case _BlockFlag.treenut:
        return allergies.contains('treenut');
      case _BlockFlag.sesame:
        return allergies.contains('sesame');
    }
  }

  static String _flagLabel(_BlockFlag flag) {
    switch (flag) {
      case _BlockFlag.vegan:
        return 'Vegan';
      case _BlockFlag.vegetarian:
        return 'Veggie';
      case _BlockFlag.meat:
        return 'Meat';
      case _BlockFlag.fish:
        return 'Fish';
      case _BlockFlag.shellfish:
        return 'Shellfish';
      case _BlockFlag.dairy:
        return 'Dairy';
      case _BlockFlag.egg:
        return 'Egg';
      case _BlockFlag.gluten:
        return 'Gluten';
      case _BlockFlag.soy:
        return 'Soy';
      case _BlockFlag.peanut:
        return 'Peanut';
      case _BlockFlag.treenut:
        return 'Tree nut';
      case _BlockFlag.sesame:
        return 'Sesame';
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Category → flags  (whole-category blocks)
  // ──────────────────────────────────────────────────────────────

  static const Map<String, Set<_BlockFlag>> _categoryBlocks = {
    'Dairy & Eggs': {_BlockFlag.dairy},
    // (eggs handled at item level so users with only an egg allergy
    // don't lose milk/butter; vegan/dairy still blocks the whole
    // category via the dairy flag.)

    // Note: 'Fresh meat & fish' is NOT category-blocked. Per-item
    // flags below distinguish meat (blocks pescatarian) from fish/
    // shellfish (allowed for pescatarian).
  };

  // ──────────────────────────────────────────────────────────────
  // Item-level overrides
  // ──────────────────────────────────────────────────────────────
  //
  // Use lowercase keys. Anything that needs to grey out across
  // categories — or that should grey out independently of its
  // category's bulk rule — lives here.

  static const Map<String, Set<_BlockFlag>> _itemFlags = {
    // ─── Eggs (egg allergy / vegan only — not dairy allergy) ─────
    'eggs': {_BlockFlag.egg, _BlockFlag.vegan},
    'noodles (egg)': {_BlockFlag.egg, _BlockFlag.gluten},
    'mayonnaise': {_BlockFlag.egg, _BlockFlag.vegan},

    // ─── Vegan-only blocks (animal-derived) ──────────────────────
    'honey': {_BlockFlag.vegan},
    'ghee': {_BlockFlag.vegan, _BlockFlag.dairy},
    // 2026-05-19 Kate flag pass: dropped the `vegetarian` block — paneer IS
    // vegetarian (animal-rennet-free; standard rennet used is vegetable or
    // microbial). Pre-fix it greyed out for vegetarians, which was wrong.
    'paneer': {_BlockFlag.vegan, _BlockFlag.dairy},
    'feta': {_BlockFlag.vegan, _BlockFlag.dairy},
    'halloumi': {_BlockFlag.vegan, _BlockFlag.dairy},
    'sour cream': {_BlockFlag.vegan, _BlockFlag.dairy},
    'pesto': {_BlockFlag.vegan, _BlockFlag.dairy, _BlockFlag.treenut},
    'ice cream': {_BlockFlag.vegan, _BlockFlag.dairy},

    // ─── Fish / shellfish (vegan + veggie + allergy) ─────────────
    'tuna': {_BlockFlag.fish},
    'anchovies': {_BlockFlag.fish},
    'fish sauce': {_BlockFlag.fish, _BlockFlag.vegan, _BlockFlag.vegetarian},
    'oyster sauce': {
      _BlockFlag.shellfish,
      _BlockFlag.vegan,
      _BlockFlag.vegetarian,
      _BlockFlag.gluten,
    },
    // 2026-05-19 Kate flag pass (in-cell comment, Sauces & Condiments):
    // "I think vegan and gluten free variants are easy to find. Allow
    // these. But are we able to label it as vegan or gluten free as the
    // soy sauce?" — dropping the vegan/vegetarian/gluten flags so the
    // user can add Worcestershire to their pantry; the GLUTEN-FREE SWAPS
    // prompt block in gemini_service.dart now also relabels it as
    // "gluten-free worcestershire sauce" for gluten-allergic users.
    // Vegan relabel deferred — would need a new VEGAN SWAPS prompt block
    // and Worcestershire is rare in vegan cooking; not worth the work.
    // 'worcestershire sauce': flags intentionally removed — see comment above.
    'frozen prawns': {_BlockFlag.shellfish, _BlockFlag.vegan, _BlockFlag.vegetarian},
    'frozen shrimp': {_BlockFlag.shellfish, _BlockFlag.vegan, _BlockFlag.vegetarian},
    'prawns': {_BlockFlag.shellfish}, // perishables
    'shrimp': {_BlockFlag.shellfish}, // US alias
    'salmon': {_BlockFlag.fish}, // pescatarian fine; veggie/vegan blocked via cat
    'white fish': {_BlockFlag.fish},

    // ─── Gluten (item-level wheat exceptions) ────────────────────
    'soy sauce': {_BlockFlag.gluten, _BlockFlag.soy},
    'hoisin sauce': {_BlockFlag.gluten, _BlockFlag.soy},
    'naan bread': {_BlockFlag.gluten},
    'bread': {_BlockFlag.gluten},
    'pasta (spaghetti)': {_BlockFlag.gluten},
    'pasta (penne)': {_BlockFlag.gluten},
    'pasta (fusilli)': {_BlockFlag.gluten},
    'orzo': {_BlockFlag.gluten},
    'couscous': {_BlockFlag.gluten},
    'bulgur wheat': {_BlockFlag.gluten},
    'tortillas (flour)': {_BlockFlag.gluten},
    'plain flour': {_BlockFlag.gluten},
    'all-purpose flour': {_BlockFlag.gluten}, // US alias
    'self-raising flour': {_BlockFlag.gluten},
    'self-rising flour': {_BlockFlag.gluten}, // US alias
    'strong bread flour': {_BlockFlag.gluten},
    'bread flour': {_BlockFlag.gluten}, // US alias
    // Note: 'sausages' carries gluten too — combined with meat in the
    // perishable meat block below to keep one entry per item.
    // 2026-05-19 Kate flag pass (in-cell comment, Frozen Staples):
    // "Can we re-label gluten free pastry? As with the other items, we
    // do not want to add complicated problems. Trying to keep it simple."
    // → drop flags; GF + dairy-free pastry variants exist; user trusted
    // to have the right one. Prompt swap relabels it at recipe time.
    // 'frozen pastry (puff)': flags intentionally removed — see above.
    // 'frozen pastry (shortcrust)': flags intentionally removed — see above.

    // ─── Soy (item-level) ────────────────────────────────────────
    'tofu': {_BlockFlag.soy},
    'miso paste': {_BlockFlag.soy},
    'frozen edamame': {_BlockFlag.soy},
    // 2026-05-19 Kate flag pass: gochujang is reliably fermented
    // soybean. Gluten content is brand-dependent (some brands use
    // barley malt, modern brands often rice-only) — per Kate's
    // Option-B don't-speculate call, omit `gluten` and rely on the
    // user-supplied custom-allergen exact-match for that path.
    'gochujang': {_BlockFlag.soy},

    // ─── Nuts ────────────────────────────────────────────────────
    'pine nuts': {_BlockFlag.treenut},
    'peanut butter': {_BlockFlag.peanut},

    // ─── Sesame ──────────────────────────────────────────────────
    'sesame oil': {_BlockFlag.sesame},
    'tahini': {_BlockFlag.sesame},
    // 2026-05-19 Kate flag pass: hummus always contains tahini.
    'hummus': {_BlockFlag.sesame},
    // 2026-05-19 Kate flag pass (in-cell comment, Baking Essentials):
    // "I think keep milk chocolate strict. dark is ok. Risk of mix up
    // acceptable." → strict default treats chocolate chips as milk
    // chocolate (most common shopping shape).
    'chocolate chips': {_BlockFlag.vegan, _BlockFlag.dairy},

    // ─── Perishable dairy & herbs (mixed category) ───────────────
    // 2026-05-19 Kate flag pass: filled in the rest of the Dairy &
    // Eggs items. The category block already greys these for
    // `dairy`-allergic users; the per-item `vegan` flag is the
    // missing piece. Parmesan deliberately NOT `vegetarian`-flagged
    // per Kate's Option-B don't-speculate call (animal rennet is
    // brand-dependent — most major brands now use vegetable rennet).
    'milk': {_BlockFlag.vegan, _BlockFlag.dairy},
    'yoghurt': {_BlockFlag.vegan, _BlockFlag.dairy},
    'yogurt': {_BlockFlag.vegan, _BlockFlag.dairy}, // US alias
    'double cream': {_BlockFlag.vegan, _BlockFlag.dairy},
    'heavy cream': {_BlockFlag.vegan, _BlockFlag.dairy}, // US alias
    'single cream': {_BlockFlag.vegan, _BlockFlag.dairy},
    'light cream': {_BlockFlag.vegan, _BlockFlag.dairy}, // US alias
    'cheddar cheese': {_BlockFlag.vegan, _BlockFlag.dairy},
    'parmesan': {_BlockFlag.vegan, _BlockFlag.dairy},
    'mozzarella': {_BlockFlag.vegan, _BlockFlag.dairy},
    'cream cheese': {_BlockFlag.vegan, _BlockFlag.dairy},
    'greek yoghurt': {_BlockFlag.vegan, _BlockFlag.dairy},
    'greek yogurt': {_BlockFlag.vegan, _BlockFlag.dairy}, // US alias
    'natural yoghurt': {_BlockFlag.vegan, _BlockFlag.dairy},
    'plain yogurt': {_BlockFlag.vegan, _BlockFlag.dairy}, // US alias

    // ─── Perishable meat (under Fresh meat & fish) ───────────────
    'chicken breast': {_BlockFlag.meat},
    'chicken thighs': {_BlockFlag.meat},
    'mince (beef)': {_BlockFlag.meat},
    'ground beef': {_BlockFlag.meat}, // US alias
    'mince (pork)': {_BlockFlag.meat},
    'ground pork': {_BlockFlag.meat}, // US alias
    'bacon': {_BlockFlag.meat},
    'sausages': {_BlockFlag.meat, _BlockFlag.gluten}, // overrides earlier entry
    'steak': {_BlockFlag.meat},

    // ─── Other animal items in non-obvious categories ────────────
    'butter': {_BlockFlag.vegan, _BlockFlag.dairy},
    // 2026-05-19 Kate flag pass: meat-based stock cubes block
    // vegan + vegetarian + the `meat` flag (which also catches
    // pescatarians). Vegetable stock stays un-flagged.
    'stock cubes (chicken)': {
      _BlockFlag.vegan,
      _BlockFlag.vegetarian,
      _BlockFlag.meat,
    },
    'bouillon cubes (chicken)': {
      _BlockFlag.vegan,
      _BlockFlag.vegetarian,
      _BlockFlag.meat,
    },
    'stock cubes (beef)': {
      _BlockFlag.vegan,
      _BlockFlag.vegetarian,
      _BlockFlag.meat,
    },
    'bouillon cubes (beef)': {
      _BlockFlag.vegan,
      _BlockFlag.vegetarian,
      _BlockFlag.meat,
    },
  };
}

enum _BlockFlag {
  vegan,
  vegetarian,
  meat,
  fish,
  shellfish,
  dairy,
  egg,
  gluten,
  soy,
  peanut,
  treenut,
  sesame,
}
