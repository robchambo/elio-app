import 'dart:async';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'entitlement_service.dart';
import 'error_service.dart';

// ──────────────────────────────────────────────
// PurchaseService
// Wraps RevenueCat for subscription management.
//
// Current state: sandbox mode only.
//   - Requires a RevenueCat API key to activate.
//   - If no key is configured, all purchase methods
//     return gracefully without crashing.
//   - Dev email accounts bypass purchases entirely
//     (handled by EntitlementService).
//
// To activate:
//   1. Create a RevenueCat project at app.revenuecat.com
//   2. Add your Google Play API key in RevenueCat dashboard
//   3. Set the RC API key in Firebase Remote Config as
//      'revenuecat_api_key', or in .env.local
//   4. Create products in Play Console:
//      - elio_pro_monthly (£4.49/mo)
//      - elio_pro_annual (£27.99/yr)
//   5. Create an "Entitlement" called "pro" in RevenueCat
//      and attach both products to it
// ──────────────────────────────────────────────

class PurchaseService {
  static final PurchaseService instance = PurchaseService._();
  PurchaseService._();

  bool _initialised = false;
  bool get isAvailable => _initialised;

  // Product identifiers — must match Play Console / App Store Connect
  static const String monthlyProductId = 'elio_pro_monthly';
  static const String annualProductId = 'elio_pro_annual';
  static const String entitlementId = 'pro';

  // RevenueCat API key — set via Remote Config or dart-define
  // Leave empty to run in "dry mode" (no purchases, no crashes)
  static const String _dartDefineRcKey = String.fromEnvironment('REVENUECAT_API_KEY');

  // ── Initialisation ───────────────────────────────────────
  Future<void> init({String? apiKey}) async {
    if (_initialised) return;

    final key = apiKey ?? _dartDefineRcKey;
    if (key.isEmpty) {
      // No API key — run in dry mode. Entitlements fall back to the
      // `config/proTesters` email allowlist inside EntitlementService.
      return;
    }

    try {
      await Purchases.configure(
        PurchasesConfiguration(key)
          ..appUserID = FirebaseAuth.instance.currentUser?.uid,
      );
      _initialised = true;

      // Refresh EntitlementService whenever RevenueCat reports a subscription change.
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    } catch (e) {
      ErrorService.log('purchase_init', e);
      // RevenueCat init failed — continue in dry mode
    }
  }

  // ── Lazy init ──────────────────────────────────────────
  /// Ensures RevenueCat is initialised before use. Safe to call repeatedly.
  Future<void> _ensureInitialised() async {
    if (!_initialised) await init();
  }

  // ── Fetch available packages ───────────────────────────────
  Future<List<Package>> getPackages() async {
    await _ensureInitialised();
    if (!_initialised) return [];

    try {
      final offerings = await Purchases.getOfferings();
      final pkgs = offerings.current?.availablePackages ?? [];
      _lastFetchedPackages = pkgs;
      return pkgs;
    } catch (e) {
      ErrorService.log('purchase_get_packages', e);
      return [];
    }
  }

  // ── Free trial helpers ─────────────────────────────────
  // RevenueCat exposes free-trial eligibility on the StoreProduct via
  // introductoryPrice. If introductoryPrice is non-null and the period
  // has units > 0, the user is eligible for a trial when subscribing
  // to that package. RevenueCat handles eligibility server-side; the
  // app must NOT track trial state itself.

  /// Returns true if the package has a free trial available for the
  /// current user (i.e. the StoreProduct exposes an introductoryPrice
  /// with a non-zero period).
  bool hasFreeTrial(Package package) {
    final intro = package.storeProduct.introductoryPrice;
    if (intro == null) return false;
    return intro.periodNumberOfUnits > 0;
  }

  /// Returns a short human label for the trial duration, e.g. "7-day".
  /// Returns an empty string if there is no trial.
  String trialDurationLabel(Package package) {
    final intro = package.storeProduct.introductoryPrice;
    if (intro == null || intro.periodNumberOfUnits <= 0) return '';
    final units = intro.periodNumberOfUnits;
    final unit = intro.periodUnit;
    // PeriodUnit values: day, week, month, year (lowercase from RC SDK)
    final unitName = unit.name.toLowerCase();
    switch (unitName) {
      case 'day':
        return '$units-day';
      case 'week':
        // Express weeks as days for the common 1-week trial case
        return '${units * 7}-day';
      case 'month':
        return units == 1 ? '1-month' : '$units-month';
      case 'year':
        return units == 1 ? '1-year' : '$units-year';
      default:
        return '$units-$unitName';
    }
  }

  /// Cached offerings result. Null until first checked.
  /// Used by [isAnyTrialAvailable] for a synchronous getter — it reads
  /// only what has already been fetched via [getPackages]. Call
  /// [getPackages] first to populate.
  List<Package> _lastFetchedPackages = const [];

  /// Returns true if at least one currently-loaded package has a trial.
  /// Note: this reads cached package data populated by [getPackages];
  /// callers that need accurate state should await [getPackages] first.
  bool get isAnyTrialAvailable {
    for (final p in _lastFetchedPackages) {
      if (hasFreeTrial(p)) return true;
    }
    return false;
  }

  // ── Purchase ─────────────────────────────────────────────
  Future<bool> purchasePackage(Package package) async {
    await _ensureInitialised();
    if (!_initialised) return false;

    try {
      final customerInfo = await Purchases.purchasePackage(package);
      return customerInfo.entitlements.all[entitlementId]?.isActive ?? false;
    } on PurchasesErrorCode catch (e) {
      ErrorService.log('purchase_package', e);
      return false;
    } catch (e) {
      ErrorService.log('purchase_package', e);
      return false;
    }
  }

  // ── Restore purchases ─────────────────────────────────
  Future<bool> restorePurchases() async {
    await _ensureInitialised();
    if (!_initialised) return false;

    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all[entitlementId]?.isActive ?? false;
    } catch (e) {
      ErrorService.log('purchase_restore', e);
      return false;
    }
  }

  // ── Check current entitlement ──────────────────────────────
  Future<bool> isPro() async {
    await _ensureInitialised();
    if (!_initialised) return false;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[entitlementId]?.isActive ?? false;
    } catch (e) {
      ErrorService.log('purchase_check_pro', e);
      return false;
    }
  }

  // ── React to subscription state changes ──────────────────────
  // We no longer mirror RevenueCat state into Firestore from the client —
  // `subscription.tier`, `subscription.source`, and `subscription.lastSyncedAt`
  // are locked by Firestore rules. RevenueCat is the single source of truth
  // for billing entitlement; EntitlementService reads it at runtime via
  // [isPro]. A future Cloud Function webhook can write the cached copy back
  // to Firestore with the Admin SDK if we ever need server-side reads.
  void _onCustomerInfoUpdated(CustomerInfo info) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await EntitlementService.instance.refresh();
    } catch (e) {
      ErrorService.log('purchase_sync_entitlement', e);
    }
  }

  // ── Identify user (call after sign-in) ───────────────────────
  Future<void> identify(String userId) async {
    await _ensureInitialised();
    if (!_initialised) return;
    try {
      await Purchases.logIn(userId);
    } catch (e) {
      ErrorService.log('purchase_identify', e);
    }
  }

  // ── Log out (call on sign-out) ────────────────────────────
  Future<void> logOut() async {
    if (!_initialised) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      ErrorService.log('purchase_logout', e);
    }
  }
}
