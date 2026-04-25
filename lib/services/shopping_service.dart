import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_plan_models.dart';
import '../utils/quantity_utils.dart';

// ─────────────────────────────────────────────
// ShoppingService
// Persistent shopping list backed by Firestore.
//
// Items come from three sources:
//   1. Manual — user types in an item
//   2. Meal plan — auto-populated when a plan is generated
//   3. Restock — auto-added when an item is flagged Running Low
//
// Firestore path: users/{uid}/shoppingItems/{docId}
// ─────────────────────────────────────────────

class ShoppingService {
  static final ShoppingService instance = ShoppingService._();
  ShoppingService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Staple exclusions ──────────────────────────────────────────────
  // Each entry is matched as a WHOLE WORD inside the normalised name
  // (e.g. "salt" matches "sea salt" and "table salt" but NOT "salted butter").
  // This avoids false positives on compound words while still catching variants.
  static const _stapleWords = <String>{
    'water',  // cold water, warm water, tap water, …
    'salt',   // sea salt, table salt, kosher salt, … but NOT salted butter
    'pepper', // black pepper, ground pepper, white pepper, …
    'sugar',  // caster sugar, granulated sugar, brown sugar, …
  };

  // Generic cooking oils — exact match only so sesame oil / chilli oil / truffle
  // oil / olive oil are NOT excluded (they are specific, flavour-defining
  // ingredients).  Only truly neutral / interchangeable oils are excluded.
  static const _genericOilsExact = <String>{
    'oil',
    'cooking oil',
    'vegetable oil',
    'sunflower oil',
    'canola oil',
    'rapeseed oil',
    'neutral oil',
    'generic oil',
  };

  /// Returns true when [normalisedName] is a common household staple that
  /// should never be added to a shopping list automatically.
  /// Public accessor for use in UI filtering (e.g. meal plan shopping dialog).
  bool isStaplePublic(String normalisedName) => _isStaple(normalisedName);

  bool _isStaple(String normalisedName) {
    // Exact-match generic oils first.
    if (_genericOilsExact.contains(normalisedName)) return true;
    // Word-boundary check: the staple term must appear as a complete word so
    // "salt" matches "sea salt" but not "salted butter".
    return _stapleWords.any((term) => _containsWord(normalisedName, term));
  }

  /// True when [word] appears as a whole word inside [text].
  /// Treats space as the only word separator (consistent with ingredient names).
  static bool _containsWord(String text, String word) {
    if (text == word) return true;
    return text.startsWith('$word ') ||
        text.endsWith(' $word') ||
        text.contains(' $word ');
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('users').doc(_uid!).collection('shoppingItems');

  // ── Purge residual staples from Firestore ────────────────────────────
  // One-time cleanup for items that were added before staple filtering
  // existed. Safe to call multiple times — only deletes matching docs.
  Future<void> purgeStaples() async {
    if (_uid == null) return;
    final snapshot = await _collection.get();
    final batch = _db.batch();
    int purged = 0;
    for (final doc in snapshot.docs) {
      final name = (doc.data()['nameLower'] as String?) ??
          (doc.data()['name'] as String? ?? '').toLowerCase().trim();
      if (_isStaple(name)) {
        batch.delete(doc.reference);
        purged++;
      }
    }
    if (purged > 0) await batch.commit();
  }

  // ── Load all items ─────────────────────────────────────────────────
  Future<List<PersistentShoppingItem>> loadItems() async {
    if (_uid == null) return [];
    final snapshot = await _collection.orderBy('addedAt').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return PersistentShoppingItem(
        id: doc.id,
        name: data['name'] as String? ?? '',
        quantity: data['quantity'] as String? ?? '',
        source: _parseSource(data['source'] as String?),
        isChecked: data['isChecked'] as bool? ?? false,
        addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }).toList();
  }

  // ── Match-key normalisation ─────────────────────────────────────────
  // Storage `nameLower` is the lowercase trimmed name (kept for backwards
  // compatibility + readability). Lookups go through [_matchKey] which also
  // strips simple English plurals so "Carrots" and "Carrot" resolve to the
  // same item. Without this, recipes that use "Carrot" + "Carrots" produce
  // two separate rows (Sprint 16.3 bug from Rob's screenshot).
  /// Crude English singulariser — sufficient for produce names. Returns
  /// the input unchanged when stripping a trailing 's'/'es'/'ies' would
  /// be wrong (words ending in "ss"/"us"/"is"/short words).
  static String _singularise(String s) {
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

  // ── Add a single item ──────────────────────────────────────────────
  // Returns null (silently) when [name] is a common household staple.
  Future<PersistentShoppingItem?> addItem({
    required String name,
    String quantity = '',
    ShoppingSource source = ShoppingSource.manual,
  }) async {
    final normalised = name.trim().toLowerCase();
    final matchKey = _singularise(normalised);

    // Silently drop universal staples — they're always in the kitchen.
    if (_isStaple(normalised)) return null;

    // Check for existing item with same singularised key — update instead of
    // duplicating ("Carrot" + "Carrots" should merge into one row). Fall back
    // to nameLower for items written before matchKey existed.
    var existing = await _collection
        .where('matchKey', isEqualTo: matchKey)
        .limit(1)
        .get();
    if (existing.docs.isEmpty) {
      existing = await _collection
          .where('nameLower', isEqualTo: normalised)
          .limit(1)
          .get();
    }

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      // If it was checked, uncheck it (user is re-adding)
      await doc.reference.update({
        'isChecked': false,
        'matchKey': matchKey, // backfill for legacy rows
        if (quantity.isNotEmpty) 'quantity': quantity,
      });
      final data = doc.data();
      return PersistentShoppingItem(
        id: doc.id,
        name: data['name'] as String? ?? name.trim(),
        quantity: quantity.isNotEmpty ? quantity : (data['quantity'] as String? ?? ''),
        source: _parseSource(data['source'] as String?),
        isChecked: false,
        addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }

    final ref = _collection.doc();
    final now = DateTime.now();
    await ref.set({
      'name': name.trim(),
      'nameLower': normalised,
      'matchKey': matchKey,
      'quantity': quantity,
      'source': source.name,
      'isChecked': false,
      'addedAt': Timestamp.fromDate(now),
    });

    return PersistentShoppingItem(
      id: ref.id,
      name: name.trim(),
      quantity: quantity,
      source: source,
      isChecked: false,
      addedAt: now,
    );
  }

  // ── Toggle checked state ───────────────────────────────────────────
  Future<void> toggleChecked(String itemId, bool isChecked) async {
    if (_uid == null) return;
    await _collection.doc(itemId).update({'isChecked': isChecked});
  }

  // ── Update name and quantity ────────────────────────────────────────
  Future<void> updateItem(String itemId, {required String name, required String quantity}) async {
    if (_uid == null) return;
    final lower = name.trim().toLowerCase();
    await _collection.doc(itemId).update({
      'name': name.trim(),
      'nameLower': lower,
      'matchKey': _singularise(lower),
      'quantity': quantity.trim(),
    });
  }

  // ── Remove an item ─────────────────────────────────────────────────
  Future<void> removeItem(String itemId) async {
    if (_uid == null) return;
    await _collection.doc(itemId).delete();
  }

  // ── Clear all checked items ────────────────────────────────────────
  Future<void> clearChecked() async {
    if (_uid == null) return;
    final checked = await _collection.where('isChecked', isEqualTo: true).get();
    final batch = _db.batch();
    for (final doc in checked.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Merge meal plan ingredients ────────────────────────────────────
  // Smart merge: adds new items, updates quantities for existing ones.
  // Does NOT remove old meal plan items (user may have checked some off).
  Future<void> mergeFromMealPlan(
    MealPlan plan, {
    List<String> alreadyHave = const [],
  }) async {
    if (_uid == null) return;

    final haveSet = alreadyHave.map((s) => s.toLowerCase().trim()).toSet();

    // Aggregate ingredients from all meals, consolidating quantities per
    // ingredient. The grouping key is the singularised lowercase name so that
    // "Carrot" + "Carrots" merge into one entry.
    final quantities = <String, List<ParsedQuantity>>{};
    final displayNames = <String, String>{}; // first display name wins
    final lowerNames = <String, String>{}; // first lower name wins (for nameLower)
    for (final day in plan.days) {
      for (final meal in day.meals.values) {
        if (meal == null) continue;
        for (final ingredient in meal.ingredients) {
          final cleanName = cleanForShopping(ingredient.name);
          final lower = cleanName.toLowerCase().trim();
          final key = _singularise(lower);
          if (haveSet.any((h) => key.contains(h) || h.contains(key))) continue;
          if (_isStaple(lower)) continue;
          displayNames.putIfAbsent(key, () => cleanName);
          lowerNames.putIfAbsent(key, () => lower);
          final parsed = QuantityUtils.parse(ingredient.quantity, ingredient.unit);
          quantities.putIfAbsent(key, () => []).add(parsed);
        }
      }
    }

    // Batch upsert — look up by match key, falling back to nameLower for any
    // legacy items written before [matchKey] existed.
    final existing = await _collection.get();
    final existingByKey = <String, DocumentReference>{};
    for (final doc in existing.docs) {
      final data = doc.data();
      final stored = (data['matchKey'] as String?) ??
          _singularise(((data['nameLower'] as String?) ??
                  (data['name'] as String? ?? '').toLowerCase())
              .trim());
      existingByKey[stored] = doc.reference;
    }

    final batch = _db.batch();
    for (final key in quantities.keys) {
      final combinedQty = QuantityUtils.combine(quantities[key]!);
      final displayName = displayNames[key] ?? key;
      final lower = lowerNames[key] ?? key;
      if (existingByKey.containsKey(key)) {
        batch.update(existingByKey[key]!, {
          'quantity': combinedQty,
          'source': ShoppingSource.mealPlan.name,
          'isChecked': false,
          'matchKey': key, // backfill for legacy rows
        });
      } else {
        final ref = _collection.doc();
        batch.set(ref, {
          'name': displayName,
          'nameLower': lower,
          'matchKey': key,
          'quantity': combinedQty,
          'source': ShoppingSource.mealPlan.name,
          'isChecked': false,
          'addedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    }
    await batch.commit();
  }

  // ── Add/remove restock item ────────────────────────────────────────
  Future<void> addRestockItem(String name) async {
    await addItem(
      name: name,
      quantity: 'Restock',
      source: ShoppingSource.restock,
    );
  }

  Future<void> removeRestockItem(String name) async {
    if (_uid == null) return;
    final normalised = name.trim().toLowerCase();
    final snapshot = await _collection
        .where('nameLower', isEqualTo: normalised)
        .where('source', isEqualTo: ShoppingSource.restock.name)
        .get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Ingredient name cleaning ────────────────────────────────────────
  // Recipe ingredients carry preparation details ("Ham, cut into cubes",
  // "Shrimp (raw, peeled and deveined)", "Butter, melted") that are useful
  // for cooking but clutter the shopping list. This strips them down to
  // just the item you need to buy.

  /// Prep-related words found in parentheses or after commas — if a
  /// parenthetical or comma-clause contains any of these, strip it.
  static const _prepWords = <String>{
    'chopped', 'diced', 'sliced', 'minced', 'grated', 'shredded',
    'crushed', 'melted', 'softened', 'cubed', 'julienned', 'peeled',
    'deveined', 'trimmed', 'deboned', 'halved', 'quartered', 'torn',
    'cut', 'beaten', 'whisked', 'sifted', 'toasted', 'roasted',
    'grilled', 'blanched', 'drained', 'rinsed', 'soaked', 'thawed',
    'frozen', 'raw', 'cooked', 'boiled', 'steamed', 'fried',
    'thinly', 'finely', 'roughly', 'freshly', 'lightly',
    'at room temperature', 'room temperature', 'to taste',
    'for garnish', 'for serving', 'optional', 'divided',
  };

  /// Size adjectives to strip from the start of a name.
  static const _sizeAdjectives = <String>{
    'large', 'small', 'medium', 'extra-large', 'extra large',
    'big', 'thin', 'thick',
  };

  /// Clean a recipe ingredient name for the shopping list.
  /// "Ham, cut into cubes or thin strips" → "Ham"
  /// "Shrimp (raw, peeled and deveined)" → "Shrimp"
  /// "Large Eggs" → "Eggs"
  /// "Butter, melted" → "Butter"
  static String cleanForShopping(String name) {
    var cleaned = name.trim();

    // 1. Strip comma-clauses that contain prep words
    //    "Ham, cut into cubes" → "Ham"
    //    "Butter, melted" → "Butter"
    //    But keep "Rice, white" style commas that are product descriptors
    final commaIdx = cleaned.indexOf(',');
    if (commaIdx > 0) {
      final afterComma = cleaned.substring(commaIdx + 1).toLowerCase().trim();
      if (_prepWords.any((w) => afterComma.contains(w))) {
        cleaned = cleaned.substring(0, commaIdx).trim();
      }
    }

    // 2. Strip parentheticals that contain prep words
    //    "Shrimp (raw, peeled and deveined)" → "Shrimp"
    //    But keep "(white)", "(brown)", "(basmati)" — product variants
    final parenMatch = RegExp(r'\s*\([^)]+\)\s*$').firstMatch(cleaned);
    if (parenMatch != null) {
      final parenContent = parenMatch.group(0)!.toLowerCase();
      if (_prepWords.any((w) => parenContent.contains(w))) {
        cleaned = cleaned.substring(0, parenMatch.start).trim();
      }
    }

    // 3. Strip leading size adjectives
    //    "Large Eggs" → "Eggs", "Small eggs" → "eggs"
    final lower = cleaned.toLowerCase();
    for (final adj in _sizeAdjectives) {
      if (lower.startsWith('$adj ')) {
        cleaned = cleaned.substring(adj.length).trim();
        break;
      }
    }

    // 4. Capitalise first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    return cleaned;
  }

  // ── Helpers ────────────────────────────────────────────────────────
  static ShoppingSource _parseSource(String? source) {
    switch (source) {
      case 'mealPlan':
        return ShoppingSource.mealPlan;
      case 'restock':
        return ShoppingSource.restock;
      default:
        return ShoppingSource.manual;
    }
  }
}

// ─── Models ──────────────────────────────────────────────────────────────────

enum ShoppingSource { manual, mealPlan, restock, recipe }

class PersistentShoppingItem {
  final String id;
  final String name;
  final String quantity;
  final ShoppingSource source;
  bool isChecked;
  final DateTime addedAt;

  PersistentShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.source,
    required this.isChecked,
    required this.addedAt,
  });

  bool get isRestock => source == ShoppingSource.restock;
  bool get isMealPlan => source == ShoppingSource.mealPlan;
  bool get isManual => source == ShoppingSource.manual;
}
