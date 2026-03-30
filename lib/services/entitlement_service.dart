import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
// EntitlementService
// Central source of truth for what the user can do.
//
// Free tier:  7 recipes/week, 20 history, owner-only household,
//             no meal planner generation, no shopping list.
// Pro tier:   Unlimited everything.
// ─────────────────────────────────────────────

class EntitlementService {
  static final EntitlementService instance = EntitlementService._();
  EntitlementService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Cached state (refreshed on each check) ─────────────────────────
  String _tier = 'free';
  int _weeklyGenerations = 0;
  DateTime? _weekStartedAt;

  // ── Constants ──────────────────────────────────────────────────────
  static const int freeWeeklyLimit = 7;
  static const int freeHistoryLimit = 20;
  static const int freeHouseholdLimit = 1; // owner only
  static const int proHouseholdLimit = 6;

  // ── Getters ────────────────────────────────────────────────────────
  bool get isPro => _tier != 'free';
  bool get isFree => _tier == 'free';

  bool get canGenerate => isPro || _weeklyGenerations < freeWeeklyLimit;
  bool get canUseMealPlanner => isPro;
  bool get canUseShoppingList => isPro;
  bool get canAddHouseholdMembers => isPro;

  int get remainingGenerations =>
      isPro ? 999 : (freeWeeklyLimit - _weeklyGenerations).clamp(0, freeWeeklyLimit);

  int get maxHouseholdMembers => isPro ? proHouseholdLimit : freeHouseholdLimit;

  // ── Dev accounts: always Pro regardless of Firestore tier ─────────
  static const Set<String> _devEmails = {
    'info.autex@gmail.com',
    'kate.d.r.taylor@gmail.com',
  };

  // ── Refresh from Firestore ─────────────────────────────────────────
  Future<void> refresh() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Dev accounts are always Pro — no Firestore check needed
    if (_devEmails.contains(user.email)) {
      _tier = 'pro';
      return;
    }

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final subscription = data['subscription'] as Map<String, dynamic>? ?? {};

    // proOverride bypasses billing — set directly in Firestore for dev/test accounts
    final proOverride = subscription['proOverride'] as bool? ?? false;
    _tier = proOverride ? 'pro' : (subscription['tier'] as String? ?? 'free');

    // Weekly generation tracking
    _weeklyGenerations = (subscription['weeklyGenerations'] as num?)?.toInt() ?? 0;
    final weekStartTs = subscription['weekStartedAt'] as Timestamp?;
    _weekStartedAt = weekStartTs?.toDate();

    // Auto-reset if week has elapsed
    if (_needsWeekReset()) {
      _weeklyGenerations = 0;
      _weekStartedAt = DateTime.now().toUtc();
      await _db.collection('users').doc(user.uid).update({
        'subscription.weeklyGenerations': 0,
        'subscription.weekStartedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  bool _needsWeekReset() {
    if (_weekStartedAt == null) return true;
    final now = DateTime.now().toUtc();
    return now.difference(_weekStartedAt!).inDays >= 7;
  }

  // ── Increment generation count ─────────────────────────────────────
  Future<void> recordGeneration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _weeklyGenerations++;
    await _db.collection('users').doc(user.uid).update({
      'subscription.weeklyGenerations': FieldValue.increment(1),
    });
  }

  // ── Guest entitlements (device-local) ──────────────────────────────
  static const int guestWeeklyLimit = 3;

  static Future<bool> canGuestGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('guest_weekly_generations') ?? 0;
    final weekStart = prefs.getInt('guest_week_started_at') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Reset if 7 days have passed
    if (now - weekStart > 7 * 24 * 60 * 60 * 1000) {
      await prefs.setInt('guest_weekly_generations', 0);
      await prefs.setInt('guest_week_started_at', now);
      return true;
    }

    return count < guestWeeklyLimit;
  }

  static Future<void> recordGuestGeneration() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('guest_weekly_generations') ?? 0;
    final weekStart = prefs.getInt('guest_week_started_at') ?? 0;

    if (weekStart == 0) {
      await prefs.setInt('guest_week_started_at', DateTime.now().millisecondsSinceEpoch);
    }
    await prefs.setInt('guest_weekly_generations', count + 1);
  }

  static Future<int> guestRemainingGenerations() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('guest_weekly_generations') ?? 0;
    final weekStart = prefs.getInt('guest_week_started_at') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - weekStart > 7 * 24 * 60 * 60 * 1000) return guestWeeklyLimit;
    return (guestWeeklyLimit - count).clamp(0, guestWeeklyLimit);
  }
}
