import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_plan_models.dart';

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

  // ── Add a single item ──────────────────────────────────────────────
  // Returns null (silently) when [name] is a common household staple.
  Future<PersistentShoppingItem?> addItem({
    required String name,
    String quantity = '',
    ShoppingSource source = ShoppingSource.manual,
  }) async {
    final normalised = name.trim().toLowerCase();

    // Silently drop universal staples — they're always in the kitchen.
    if (_isStaple(normalised)) return null;

    // Check for existing item with same name — update instead of duplicate
    final existing = await _collection
        .where('nameLower', isEqualTo: normalised)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      // If it was checked, uncheck it (user is re-adding)
      await doc.reference.update({
        'isChecked': false,
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
    await _collection.doc(itemId).update({
      'name': name.trim(),
      'nameLower': name.trim().toLowerCase(),
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

    // Aggregate ingredients from all meals
    final aggregated = <String, String>{};
    for (final day in plan.days) {
      for (final meal in day.meals.values) {
        if (meal == null) continue;
        for (final ingredient in meal.ingredients) {
          final key = ingredient.name.toLowerCase().trim();
          if (haveSet.any((h) => key.contains(h) || h.contains(key))) continue;
          if (_isStaple(key)) continue;
          final qtyStr = '${ingredient.quantity} ${ingredient.unit}'.trim();
          // Keep the first quantity we see (or accumulate — keeping simple for now)
          aggregated.putIfAbsent(key, () => qtyStr);
        }
      }
    }

    // Batch upsert
    final existing = await _collection.get();
    final existingByName = <String, DocumentReference>{};
    for (final doc in existing.docs) {
      final name = (doc.data()['nameLower'] as String?) ??
          (doc.data()['name'] as String? ?? '').toLowerCase().trim();
      existingByName[name] = doc.reference;
    }

    final batch = _db.batch();
    for (final entry in aggregated.entries) {
      if (existingByName.containsKey(entry.key)) {
        // Update quantity, uncheck if it was checked
        batch.update(existingByName[entry.key]!, {
          'quantity': entry.value,
          'source': ShoppingSource.mealPlan.name,
          'isChecked': false,
        });
      } else {
        final ref = _collection.doc();
        batch.set(ref, {
          'name': entry.key,
          'nameLower': entry.key,
          'quantity': entry.value,
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
