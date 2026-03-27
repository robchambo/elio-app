import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/elio_models.dart';
import '../models/meal_plan_models.dart';
import '../models/onboarding_state.dart';
import '../models/recipe_models.dart';

// ─────────────────────────────────────────────
// FirestoreService
// Handles all Firestore reads and writes for Elio.
// All writes are scoped to the authenticated user's UID.
// ─────────────────────────────────────────────

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  Future<void> completeOnboarding(OnboardingState state, String displayName) async {
    final batch = _db.batch();
    final userRef = _db.collection('users').doc(_uid);
    final now = FieldValue.serverTimestamp();

    // 1. Create the user document
    batch.set(userRef, {
      'uid': _uid,
      'email': _auth.currentUser?.email ?? '',
      'displayName': displayName,
      'createdAt': now,
      'onboardingComplete': true,
      'stylePreferences': state.stylePreferences,
      'subscription': {
        'tier': 'free',
        'status': 'active',
        'trialEndsAt': null,
        'renewsAt': null,
        'dailyGenerations': 0,
        'dailyGenerationsResetAt': now,
      },
      'activeProfileIds': ['owner'],
    });

    // 2. Create the owner's household profile
    final ownerProfileRef = userRef.collection('profiles').doc('owner');
    final ownerProfileData = HouseholdProfile(
      name: displayName,
      dietaryRequirements: state.dietaryRequirements,
      isOwner: true,
    ).toFirestore();
    ownerProfileData['customAllergens'] = state.customAllergens;
    batch.set(ownerProfileRef, ownerProfileData);

    // 3. Write inventory items
    for (final item in state.inventory) {
      final itemRef = userRef.collection('inventory').doc();
      batch.set(itemRef, item.toFirestore());
    }

    // 4. Write additional household member profiles
    for (final member in state.additionalMembers) {
      final memberRef = userRef.collection('profiles').doc();
      batch.set(memberRef, member.toFirestore());
    }

    await batch.commit();
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
    // Each entry: { 'id': String, 'name': String, 'dietaryRequirements': List<String>, 'isOwner': bool }
    final householdProfiles = <Map<String, dynamic>>[];
    for (final doc in profilesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      householdProfiles.add({
        'id': doc.id,
        'name': data['name'] as String? ?? 'Member',
        'dietaryRequirements': (data['dietaryRequirements'] as List<dynamic>? ?? [])
            .map((d) => _decodeDietary(d.toString()))
            .toList(),
        'customAllergens': List<String>.from(data['customAllergens'] ?? []),
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
      inventoryWithIds.add({'id': doc.id, 'name': name, 'tier': tier, 'runningLow': isRunningLow});
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

  Future<void> updateInventoryItem(String itemId, {String? name, String? tier, bool? runningLow}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (tier != null) updates['tier'] = tier;
    if (runningLow != null) updates['runningLow'] = runningLow;
    if (updates.isEmpty) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('inventory')
        .doc(itemId)
        .update(updates);
  }

  // ─── Add a new inventory item ────────────────────────────────────

  Future<String> addInventoryItem(String name, String tier) async {
    final ref = _db.collection('users').doc(_uid).collection('inventory').doc();
    await ref.set({'name': name, 'tier': tier, 'runningLow': false});
    return ref.id;
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
  }

  Future<Map<String, List<String>>> getTasteProfile() async {
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return {'liked': [], 'disliked': []};
    final data = doc.data() ?? {};
    final profile = (data['tasteProfile'] as Map<String, dynamic>?) ?? {};
    return {
      'liked': List<String>.from(profile['likedTitles'] ?? []),
      'disliked': List<String>.from(profile['dislikedTitles'] ?? []),
    };
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
}
