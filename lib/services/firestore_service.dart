import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/elio_models.dart';
import '../models/meal_plan_models.dart';
import '../models/onboarding_state.dart';
import '../models/recipe_models.dart';
import '../utils/pantry_utils.dart';
import 'error_service.dart';
import 'inventory_writer.dart';

// ─────────────────────────────────────────────
// FirestoreService
// Handles all Firestore reads and writes for Elio.
// All writes are scoped to the authenticated user's UID.
// ─────────────────────────────────────────────

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, List<String>>? _cachedTasteProfile;

  String get _uid => _auth.currentUser!.uid;

  /// Converts a stored enum name (e.g. "glutenFree") to its human-readable
  /// label (e.g. "Gluten-free") so Gemini can understand the constraint.
  static String _decodeDietary(String raw) {
    try {
      return DietaryRequirement.values
          .firstWhere((e) => e.name == raw)
          .label;
    } catch (_) {
      return raw; // already a label or unknown — pass through unchanged
    }
  }

  // ─── Onboarding: write all data in a single batch ───────────────

  /// Sprint 16.1: dietary requirements + custom allergens have ONE
  /// canonical home: `users/{uid}/profiles/{ownerId}.dietaryRequirements`
  /// and `.allergies`. Do NOT re-introduce user-doc copies — the
  /// in-app dietary screen only writes the owner-profile copy, so any
  /// user-doc value drifts the moment the user edits their settings.
  /// `state.toFirestoreMap()` still emits `dietary` and `allergies`
  /// keys; we strip them here to keep the user doc clean.
  Future<void> completeOnboarding(OnboardingState state, String displayName) async {
    final batch = _db.batch();
    final userRef = _db.collection('users').doc(_uid);
    final now = FieldValue.serverTimestamp();

    // 1. Create the user document. New Sprint 16 fields are written via
    //    state.toFirestoreMap(); subscription/metadata keys are layered on top.
    final userDocData = <String, dynamic>{
      ...state.toFirestoreMap(),
      'uid': _uid,
      'email': _auth.currentUser?.email ?? '',
      'displayName': displayName,
      'createdAt': now,
      'onboardingComplete': true,
      'subscription': {
        'tier': 'free',
        'status': 'active',
        'trialEndsAt': null,
        'renewsAt': null,
        'dailyGenerations': 0,
        'dailyGenerationsResetAt': now,
        'weeklyGenerations': 0,
        'weekStartedAt': now,
      },
      'activeProfileIds': ['owner'],
    };
    // Sprint 16.1: strip the dietary/allergen duplicates that
    // toFirestoreMap puts in the user doc. Canonical source is the
    // owner profile (see step 2 below).
    userDocData.remove('dietary');
    userDocData.remove('allergies');
    batch.set(userRef, userDocData);

    // 2. Create the owner's household profile. Allergies now live at the
    //    user-doc level (written above via toFirestoreMap) — no per-profile
    //    customAllergens anymore. Dietary requirements mirror state.dietary
    //    on the owner profile for backwards compatibility with profile
    //    screens that still read from /profiles/{ownerId}.
    final ownerProfileRef = userRef.collection('profiles').doc('owner');
    final ownerProfileData = HouseholdProfile(
      name: displayName,
      dietaryRequirements: const <DietaryRequirement>[],
      isOwner: true,
    ).toFirestore();
    // Overwrite the enum-encoded list with the new string-based dietary list.
    ownerProfileData['dietaryRequirements'] = state.dietary;
    // Sprint 15.9.3: also persist onboarding-set allergies onto the owner
    // profile so the in-app dietary screen can read them AND so recipe
    // generation can include them in the prompt. Previously only the user
    // doc held allergies; the owner profile was the source of truth for
    // the in-app screen, so allergies were effectively orphaned.
    ownerProfileData['allergies'] = state.allergies;
    batch.set(ownerProfileRef, ownerProfileData);

    // 3. Write inventory items — only if inventory is empty (guards against
    //    duplicate writes if completeOnboarding is somehow called more than once)
    final existingInventory = await userRef.collection('inventory').limit(1).get();
    if (existingInventory.docs.isEmpty) {
      for (final item in state.inventory) {
        final itemRef = userRef.collection('inventory').doc();
        // Sprint 15.9.3: InventoryItem.toFirestore now writes
        // expiryDate as Timestamp directly, so the previous defensive
        // String→Timestamp conversion here is redundant.
        batch.set(itemRef, item.toFirestore());
      }
    }

    // NOTE: additional household member profile writes removed in Sprint 16
    // rebuild — the new 15-screen flow does not capture per-member profiles
    // during onboarding. Task 6.4 (full MigrationService) will re-introduce
    // any required household writes.

    try {
      await batch.commit();
    } catch (e) {
      ErrorService.log('onboarding_complete', e);
      rethrow; // Onboarding failure is critical — caller should handle
    }
  }

  // ─── Check if onboarding is complete ────────────────────────────

  Future<bool> isOnboardingComplete() async {
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return false;
    return doc.data()?['onboardingComplete'] == true;
  }

  // ─── Get user data for home screen ──────────────────────────────
  // Returns a map with:
  //   stylePreferences: List<String>
  //   dietaryRequirements: List<String>
  //   alwaysHave: List<String>
  //   almostAlwaysHave: List<String>
  //   subscription: Map

  Future<Map<String, dynamic>> getUserData() async {
    // Run one-time deduplication if needed (fire-and-forget, non-blocking)
    deduplicateInventory();

    // Fetch user doc, all profiles, and inventory in parallel
    final userDocFuture = _db.collection('users').doc(_uid).get();
    final profilesFuture = _db.collection('users').doc(_uid).collection('profiles').get();
    final inventoryFuture = _db.collection('users').doc(_uid).collection('inventory').get();

    final results = await Future.wait([userDocFuture, profilesFuture, inventoryFuture]);

    final userDoc = results[0] as DocumentSnapshot;
    final profilesSnapshot = results[1] as QuerySnapshot;
    final inventorySnapshot = results[2] as QuerySnapshot;

    final userData = userDoc.data() as Map<String, dynamic>? ?? {};

    // Build list of all household profiles with their dietary requirements
    // and allergens. Each entry shape: { id, name, dietaryRequirements,
    // allergens, isOwner }.
    //
    // Sprint 15.9.3 SAFETY FIX: this used to read `customAllergens` from
    // profile docs, but the dietary_screen writes to `allergies`. Field
    // name mismatch meant a user typing "peanuts" in the dietary screen
    // saved the value but it was never read back — recipe generation
    // ignored it and could suggest peanut butter to a peanut-allergy user.
    // Now reads `allergies` (canonical field) with a `customAllergens`
    // fallback for any docs written by the buggy old read path's mirror.
    //
    // TODO(sprint-17): remove the customAllergens fallback once
    // telemetry confirms no reads in the wild. With Sprint 16.1's
    // single-source-of-truth (UserSettingsService + canonical owner
    // profile), no writer produces customAllergens any more — this
    // is purely a back-compat read for users with stale data.
    final householdProfiles = <Map<String, dynamic>>[];
    for (final doc in profilesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final allergens = List<String>.from(
        (data['allergies'] as List<dynamic>? ??
                data['customAllergens'] as List<dynamic>? ??
                const <dynamic>[]),
      );
      householdProfiles.add({
        'id': doc.id,
        'name': data['name'] as String? ?? 'Member',
        'dietaryRequirements': (data['dietaryRequirements'] as List<dynamic>? ?? [])
            .map((d) => _decodeDietary(d.toString()))
            .toList(),
        'allergens': allergens,
        // Keep the legacy key in the returned map too so any older
        // caller still finds something — both point at the same list.
        'customAllergens': allergens,
        'isOwner': data['isOwner'] as bool? ?? false,
      });
    }

    // Owner's dietary requirements (for backwards compatibility)
    final ownerProfile = householdProfiles.firstWhere(
      (p) => p['isOwner'] == true,
      orElse: () => householdProfiles.isNotEmpty ? householdProfiles.first : {'dietaryRequirements': <String>[]},
    );
    final dietaryRequirements = List<String>.from(ownerProfile['dietaryRequirements'] ?? []);

    // Separate inventory by tier, tracking running low items
    final alwaysHave = <String>[];
    final almostAlwaysHave = <String>[];
    final runningLowItems = <String>[]; // items flagged as running low
    // Also store inventory with doc IDs for profile screen editing
    final inventoryWithIds = <Map<String, dynamic>>[];

    for (final doc in inventorySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['name'] as String? ?? '';
      final tier = data['tier'] as String? ?? '';
      final isRunningLow = data['runningLow'] as bool? ?? false;

      // Parse expiryDate — may be a Timestamp or ISO string
      DateTime? expiryDate;
      final rawExpiry = data['expiryDate'];
      if (rawExpiry is Timestamp) {
        expiryDate = rawExpiry.toDate();
      } else if (rawExpiry is String) {
        expiryDate = DateTime.tryParse(rawExpiry);
      }

      inventoryWithIds.add({
        'id': doc.id,
        'name': name,
        'tier': tier,
        'runningLow': isRunningLow,
        if (expiryDate != null) 'expiryDate': expiryDate.toIso8601String(),
      });
      if (tier == 'alwaysHave') {
        alwaysHave.add(name);
      } else if (tier == 'almostAlwaysHave') {
        almostAlwaysHave.add(name);
      }
      if (isRunningLow) runningLowItems.add(name);
    }

    // Owner's custom allergens
    final customAllergens = List<String>.from(ownerProfile['customAllergens'] ?? []);

    return {
      'stylePreferences': List<String>.from(userData['stylePreferences'] ?? []),
      'appliances': List<String>.from(userData['appliances'] ?? []),
      'dietaryRequirements': dietaryRequirements,
      'customAllergens': customAllergens,
      'householdProfiles': householdProfiles,
      'alwaysHave': alwaysHave,
      'almostAlwaysHave': almostAlwaysHave,
      'runningLowItems': runningLowItems,
      'inventoryWithIds': inventoryWithIds,
      'subscription': userData['subscription'] as Map<String, dynamic>? ?? {},
    };
  }

  // ─── Save appliances ────────────────────────────────────────────────

  Future<void> saveAppliances(List<String> appliances) async {
    await _db.collection('users').doc(_uid).update({'appliances': appliances});
  }

  // ─── Settings: get and update measurement units + region ─────────

  Future<Map<String, dynamic>> getSettings() async {
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) {
      return {
        'measurementUnits': 'metric',
        'region': 'US',
        'saverModeDefault': false,
      };
    }
    final data = doc.data() as Map<String, dynamic>;
    return {
      'measurementUnits': data['measurementUnits'] as String? ?? 'metric',
      'region': data['region'] as String? ?? 'US',
      // Sprint 16.1: global saver-mode default. Read by
      // RecipePreferencesScreen on init so the toggle starts in the
      // user's preferred state; per-recipe overrides still work.
      'saverModeDefault': data['saverModeDefault'] as bool? ?? false,
    };
  }

  Future<void> updateSettings({
    String? measurementUnits,
    String? region,
    bool? saverModeDefault,
  }) async {
    final updates = <String, dynamic>{};
    if (measurementUnits != null) updates['measurementUnits'] = measurementUnits;
    if (region != null) updates['region'] = region;
    if (saverModeDefault != null) updates['saverModeDefault'] = saverModeDefault;
    if (updates.isEmpty) return;
    await _db.collection('users').doc(_uid).update(updates);
  }

  // ─── Sprint 16.7c: per-user shopping aisle ordering ──────────────

  /// Reads the user's preferred aisle ordering. Returns null if the user
  /// has never reordered (the shopping list falls back to the default
  /// enum order in that case via [AisleUtils.orderedFor]).
  Future<List<String>?> getAisleOrder() async {
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    final raw = data['aisleOrder'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return null;
  }

  /// Persists the user's preferred aisle ordering. Stored as a list of
  /// [GroceryAisle.name] strings on the user doc.
  Future<void> saveAisleOrder(List<String> order) async {
    await _db.collection('users').doc(_uid).update({'aisleOrder': order});
  }

  // ─── Free tier: check if user can generate a recipe ─────────────
  // Free tier: 3 recipes/day. Resets at midnight UTC.
  // Pro tier: unlimited.

  Future<bool> canGenerateRecipe() async {
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return true;

    final data = doc.data() as Map<String, dynamic>;
    final subscription = data['subscription'] as Map<String, dynamic>? ?? {};

    // Pro users have unlimited generations
    final tier = subscription['tier'] as String? ?? 'free';
    if (tier != 'free') return true;

    // Check daily count
    final dailyGenerations = (subscription['dailyGenerations'] as num?)?.toInt() ?? 0;
    final resetAt = subscription['dailyGenerationsResetAt'] as Timestamp?;

    // If reset timestamp is from a previous day, reset the counter
    if (resetAt != null) {
      final resetDate = resetAt.toDate();
      final now = DateTime.now().toUtc();
      final isSameDay = resetDate.year == now.year &&
          resetDate.month == now.month &&
          resetDate.day == now.day;

      if (!isSameDay) {
        // Reset the counter — it's a new day
        await _db.collection('users').doc(_uid).update({
          'subscription.dailyGenerations': 0,
          'subscription.dailyGenerationsResetAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
    }

    return dailyGenerations < 3;
  }

  // ─── Increment daily generation count ───────────────────────────

  Future<void> incrementDailyGenerations() async {
    await _db.collection('users').doc(_uid).update({
      'subscription.dailyGenerations': FieldValue.increment(1),
    });
  }

  // ─── Save generated recipe ───────────────────────────────────────

  Future<String> saveRecipe(GeneratedRecipe recipe) async {
    final recipeRef = _db.collection('users').doc(_uid).collection('recipes').doc();
    await recipeRef.set(recipe.toFirestore());
    return recipeRef.id;
  }

  // ─── Toggle running low flag on an inventory item ─────────────────

  Future<void> toggleRunningLow(String itemId, bool isRunningLow) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('inventory')
        .doc(itemId)
        .update({'runningLow': isRunningLow});
  }

  // ─── Update an inventory item ────────────────────────────────────

  Future<void> updateInventoryItem(String itemId, {String? name, String? tier, bool? runningLow, DateTime? expiryDate, bool clearExpiry = false}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (tier != null) updates['tier'] = tier;
    if (runningLow != null) updates['runningLow'] = runningLow;
    if (expiryDate != null) updates['expiryDate'] = Timestamp.fromDate(expiryDate);
    if (clearExpiry) updates['expiryDate'] = FieldValue.delete();
    if (updates.isEmpty) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('inventory')
        .doc(itemId)
        .update(updates);
  }

  // ─── Add a new inventory item ────────────────────────────────────

  Future<String> addInventoryItem(
    String name,
    String tier, {
    DateTime? expiryDate,
    String? category,
    String? price,
  }) async {
    // Sprint 15.9.1: dedup-aware add lives in InventoryWriter. The
    // signature here is unchanged so callers (pantry tab, scanner,
    // builder sheet) don't need to update.
    return InventoryWriter.instance.addItem(
      name: name,
      tier: tier,
      expiryDate: expiryDate,
      category: category,
      price: price,
    );
  }

  // ─── Delete an inventory item ────────────────────────────────────

  Future<void> deleteInventoryItem(String itemId) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('inventory')
        .doc(itemId)
        .delete();
  }

  // ─── Rate a recipe (thumbs up / thumbs down) ──────────────────────────────────────────────

  Future<void> rateRecipe({
    required String recipeTitle,
    required bool liked,
    required List<String> cuisineTags,
    required List<String> dietaryTags,
  }) async {
    final batch = _db.batch();
    final userRef = _db.collection('users').doc(_uid);
    final ratingRef = userRef.collection('ratings').doc();
    batch.set(ratingRef, {
      'recipeTitle': recipeTitle,
      'liked': liked,
      'cuisineTags': cuisineTags,
      'dietaryTags': dietaryTags,
      'ratedAt': FieldValue.serverTimestamp(),
    });
    if (liked) {
      batch.update(userRef, {
        'tasteProfile.likedTitles': FieldValue.arrayUnion([recipeTitle]),
        'tasteProfile.dislikedTitles': FieldValue.arrayRemove([recipeTitle]),
      });
    } else {
      batch.update(userRef, {
        'tasteProfile.dislikedTitles': FieldValue.arrayUnion([recipeTitle]),
        'tasteProfile.likedTitles': FieldValue.arrayRemove([recipeTitle]),
      });
    }
    await batch.commit();
    _cachedTasteProfile = null; // invalidate cache after rating change
  }

  Future<Map<String, List<String>>> getTasteProfile() async {
    if (_cachedTasteProfile != null) return _cachedTasteProfile!;

    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return {'liked': [], 'disliked': []};
    final data = doc.data() ?? {};
    final profile = (data['tasteProfile'] as Map<String, dynamic>?) ?? {};
    final result = {
      'liked': List<String>.from(profile['likedTitles'] ?? []),
      'disliked': List<String>.from(profile['dislikedTitles'] ?? []),
    };
    _cachedTasteProfile = result;
    return result;
  }

  // ─── Meal plan persistence ───────────────────────────────────────

  Future<void> saveMealPlan(MealPlan plan) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('mealPlan')
        .doc('current')
        .set(plan.toJson());
  }

  Future<MealPlan?> loadMealPlan() async {
    final doc = await _db
        .collection('users')
        .doc(_uid)
        .collection('mealPlan')
        .doc('current')
        .get();
    if (!doc.exists) return null;
    return MealPlan.fromJson(doc.data()!);
  }

  Future<void> deleteMealPlan() async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('mealPlan')
        .doc('current')
        .delete();
  }

  // ─── Daily generation count ──────────────────────────────────────

  Future<int> getRemainingGenerations() async {
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return 3;

    final data = doc.data() as Map<String, dynamic>;
    final subscription = data['subscription'] as Map<String, dynamic>? ?? {};

    final tier = subscription['tier'] as String? ?? 'free';
    if (tier != 'free') return 999; // Unlimited for pro

    final dailyGenerations = (subscription['dailyGenerations'] as num?)?.toInt() ?? 0;
    final resetAt = subscription['dailyGenerationsResetAt'] as Timestamp?;

    if (resetAt != null) {
      final resetDate = resetAt.toDate();
      final now = DateTime.now().toUtc();
      final isSameDay = resetDate.year == now.year &&
          resetDate.month == now.month &&
          resetDate.day == now.day;
      if (!isSameDay) return 3;
    }

    return (3 - dailyGenerations).clamp(0, 3);
  }

  // ─── Pro override (dev/test accounts only) ────────────────────────

  Future<void> grantProAccess() async {
    await _db.collection('users').doc(_uid).update({
      'subscription.proOverride': true,
    });
  }

  Future<void> revokeProAccess() async {
    await _db.collection('users').doc(_uid).update({
      'subscription.proOverride': false,
    });
  }

  // ─── Get all inventory item names ─────────────────────────────────

  Future<List<String>> getInventoryNames() async {
    final snapshot = await _db
        .collection('users')
        .doc(_uid)
        .collection('inventory')
        .get();
    return snapshot.docs
        .map((doc) => (doc.data()['name'] as String?) ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  // ─── One-time deduplication of inventory ──────────────────────────
  // Removes exact-duplicate inventory items (same normalised name + same tier).
  // Keeps the first occurrence, deletes the rest.

  Future<int> deduplicateInventory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('inventory_deduped_v1') == true) return 0;

      final snapshot = await _db
          .collection('users')
          .doc(_uid)
          .collection('inventory')
          .get();

      // Track seen items by normalised name + tier
      final seen = <String>{};
      final toDelete = <String>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? '';
        final tier = data['tier'] as String? ?? '';
        final key = '${PantryUtils.normalise(name)}|$tier';

        if (seen.contains(key)) {
          toDelete.add(doc.id);
        } else {
          seen.add(key);
        }
      }

      // Delete duplicates in batches of 500 (Firestore batch limit)
      for (var i = 0; i < toDelete.length; i += 500) {
        final batch = _db.batch();
        final end = (i + 500).clamp(0, toDelete.length);
        for (var j = i; j < end; j++) {
          batch.delete(_db
              .collection('users')
              .doc(_uid)
              .collection('inventory')
              .doc(toDelete[j]));
        }
        await batch.commit();
      }

      await prefs.setBool('inventory_deduped_v1', true);
      return toDelete.length;
    } catch (e) {
      ErrorService.log('inventory_deduplication', e);
      // Migration must not block the user — silently fail
      return 0;
    }
  }
}
