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

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  bool _initialised = false;

  /// Navigator observer for automatic screen tracking.
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Initialise analytics and set baseline user properties.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await _analytics.setAnalyticsCollectionEnabled(true);
    await _setUserProperties();
  }

  // ─── User properties ─────────────────────────────────────────────

  Future<void> _setUserProperties() async {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null || user.isAnonymous;

    await _analytics.setUserProperty(
      name: 'auth_method',
      value: isGuest ? 'guest' : 'google',
    );
    await _analytics.setUserProperty(
      name: 'subscription_tier',
      value: 'free',
    );
  }

  /// Update user properties after auth state changes.
  Future<void> updateAuthProperties() async => _setUserProperties();

  /// Set household size (call after onboarding or profile update).
  Future<void> setHouseholdSize(int size) async {
    await _analytics.setUserProperty(
      name: 'household_size',
      value: size.toString(),
    );
  }

  /// Set dietary profile summary (e.g. "vegetarian,gluten-free").
  Future<void> setDietaryProfile(List<String> requirements) async {
    await _analytics.setUserProperty(
      name: 'dietary_profile',
      value: requirements.isEmpty ? 'none' : requirements.join(','),
    );
  }

  // ─── Screen tracking ─────────────────────────────────────────────

  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  // ─── Generic event logging ───────────────────────────────────────

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    await _analytics.logEvent(name: name, parameters: params);
  }
}
