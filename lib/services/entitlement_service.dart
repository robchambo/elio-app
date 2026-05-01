import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'purchase_service.dart';

// ──────────────────────────────────────────────
// EntitlementService
// Central source of truth for what the user can do.
//
// Free tier:  7 recipes/week, 20 history, owner-only household,
//             no meal planner generation, no shopping list.
// Pro tier:   Unlimited everything.
// ──────────────────────────────────────────────

class EntitlementService {
  static final EntitlementService instance = EntitlementService._();
  EntitlementService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Cached state (refreshed on each check) ─────────────────
  String _tier = 'free';
  int _weeklyGenerations = 0;
  DateTime? _weekStartedAt;

  // ── Constants ────────────────────────────────────────
  static const int freeWeeklyLimit = 7;
  static const int freeHistoryLimit = 20;
  static const int freeHouseholdLimit = 1; // owner only
  static const int proHouseholdLimit = 6;

  // ── Getters ──────────────────────────────────────────
  bool get isPro => _tier != 'free';
  bool get isFree => _tier == 'free';

  bool get canGenerate => isPro || _weeklyGenerations < freeWeeklyLimit;
  bool get canUseMealPlanner => isPro;
  bool get canUseShoppingList => isPro;
  bool get canAddHouseholdMembers => isPro;

  int get remainingGenerations =>
      isPro ? 999 : (freeWeeklyLimit - _weeklyGenerations).clamp(0, freeWeeklyLimit);

  /// Whole days remaining until the free-tier weekly counter resets.
  ///
  /// Returns 7 when the user has never generated (no week start recorded
  /// yet) and 0 once the 7-day window has elapsed. The auto-reset happens
  /// on the next [refresh()] call, so a value of 0 here means "the next
  /// generation will trigger a fresh week".
  int get daysUntilReset {
    if (_weekStartedAt == null) return 7;
    final elapsed = DateTime.now().toUtc().difference(_weekStartedAt!).inDays;
    return (7 - elapsed).clamp(0, 7);
  }

  int get maxHouseholdMembers => isPro ? proHouseholdLimit : freeHouseholdLimit;

  // ── Pro tester list (loaded from Firestore: config/proTesters) ────
  static Set<String> _proTesterEmails = {};
  static bool _proTestersLoaded = false;

  /// Fetches the pro tester email list from Firestore.
  /// Called once per session; cached after that.
  static Future<void> _loadProTesters() async {
    if (_proTestersLoaded) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('proTesters')
          .get();
      if (doc.exists) {
        final emails = (doc.data()?['emails'] as List?)?.cast<String>() ?? [];
        _proTesterEmails = emails.map((e) => e.toLowerCase().trim()).toSet();
      }
    } catch (_) {
      // Config doc may not exist yet — not an error
    }
    _proTestersLoaded = true;
  }

  // ── Refresh from Firestore ─────────────────────────────
  Future<void> refresh() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Load pro tester list (cached after first call)
    await _loadProTesters();

    // Pro testers are always Pro — no billing check needed
    if (_proTesterEmails.contains(user.email?.toLowerCase())) {
      _tier = 'pro';
      return;
    }

    // Tier is read from RevenueCat directly at runtime — not from Firestore.
    // The user doc's `subscription.tier` field is locked by Firestore rules;
    // RevenueCat is the single source of truth for billing entitlement.
    final isProFromRc = await PurchaseService.instance.isPro();
    _tier = isProFromRc ? 'pro' : 'free';

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final subscription = data['subscription'] as Map<String, dynamic>? ?? {};

    // Weekly generation tracking (still owner-writable under current rules).
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

  // ── Increment generation count ───────────────────────────
  Future<void> recordGeneration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _weeklyGenerations++;
    await _db.collection('users').doc(user.uid).update({
      'subscription.weeklyGenerations': FieldValue.increment(1),
    });
  }

  // ── Guest entitlements (device-local) ──────────────────────
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
