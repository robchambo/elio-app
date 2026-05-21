import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────
// AnalyticsService
// Centralised wrapper for Firebase Analytics.
// All event logging goes through this service.
//
// Usage: call AnalyticsService.init() once at startup,
// then use AnalyticsService.instance anywhere.
// ─────────────────────────────────────────────

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  // Lazy — resolving FirebaseAnalytics.instance at field-init time throws
  // "No Firebase App [DEFAULT] has been created" in widget tests that
  // don't call Firebase.initializeApp(). Resolving it on demand + guarding
  // every caller keeps tests green without a test harness.
  FirebaseAnalytics? _analyticsOrNull;
  FirebaseAnalytics? get _analytics {
    try {
      return _analyticsOrNull ??= FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  bool _initialised = false;

  /// Navigator observer for automatic screen tracking. Returns null when
  /// Firebase is not initialised (e.g. in widget tests).
  FirebaseAnalyticsObserver? get observer {
    final a = _analytics;
    return a == null ? null : FirebaseAnalyticsObserver(analytics: a);
  }

  /// Initialise analytics and set baseline user properties.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    final a = _analytics;
    if (a == null) return;
    try {
      await a.setAnalyticsCollectionEnabled(true);
      await _setUserProperties();
    } catch (_) {
      // Firebase not initialised in test env — no-op.
    }
  }

  // ─── User properties ─────────────────────────────────────────────

  Future<void> _setUserProperties() async {
    final a = _analytics;
    if (a == null) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final isGuest = user == null || user.isAnonymous;

      await a.setUserProperty(
        name: 'auth_method',
        value: isGuest ? 'guest' : 'google',
      );
      await a.setUserProperty(
        name: 'subscription_tier',
        value: 'free',
      );
    } catch (_) {
      // Firebase not initialised — silent no-op in tests.
    }
  }

  /// Update user properties after auth state changes.
  Future<void> updateAuthProperties() async => _setUserProperties();

  /// Set household size (call after onboarding or profile update).
  Future<void> setHouseholdSize(int size) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.setUserProperty(
        name: 'household_size',
        value: size.toString(),
      );
    } catch (_) {}
  }

  /// Set dietary profile summary (e.g. "vegetarian,gluten-free").
  Future<void> setDietaryProfile(List<String> requirements) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.setUserProperty(
        name: 'dietary_profile',
        value: requirements.isEmpty ? 'none' : requirements.join(','),
      );
    } catch (_) {}
  }

  // ─── Screen tracking ─────────────────────────────────────────────

  Future<void> logScreenView(String screenName) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logScreenView(screenName: screenName);
    } catch (_) {}
  }

  // ─── Generic event logging ───────────────────────────────────────

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(name: name, parameters: params);
    } catch (_) {
      // Swallow analytics failures — typically Firebase not initialised
      // in widget tests. Never fail real user flows on telemetry.
    }
  }
}
