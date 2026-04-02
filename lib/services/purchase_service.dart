import 'dart:async';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'entitlement_service.dart';

// ─────────────────────────────────────────────
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
// ─────────────────────────────────────────────

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

  // ── Initialisation ─────────────────────────────────────────────────
  Future<void> init({String? apiKey}) async {
    if (_initialised) return;

    final key = apiKey ?? _dartDefineRcKey;
    if (key.isEmpty) {
      // No API key — run in dry mode. Entitlements are managed
      // locally via EntitlementService (dev bypass, Firestore proOverride).
      return;
    }

    try {
      await Purchases.configure(
        PurchasesConfiguration(key)
          ..appUserID = FirebaseAuth.instance.currentUser?.uid,
      );
      _initialised = true;

      // Listen for subscription changes and sync to Firestore + EntitlementService
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    } catch (_) {
      // RevenueCat init failed — continue in dry mode
    }
  }

  // ── Lazy init ──────────────────────────────────────────────────────
  /// Ensures RevenueCat is initialised before use. Safe to call repeatedly.
  Future<void> _ensureInitialised() async {
    if (!_initialised) await init();
  }

  // ── Fetch available packages ───────────────────────────────────────
  Future<List<Package>> getPackages() async {
    await _ensureInitialised();
    if (!_initialised) return [];

    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (_) {
      return [];
    }
  }

  // ── Purchase ───────────────────────────────────────────────────────
  Future<bool> purchasePackage(Package package) async {
    await _ensureInitialised();
    if (!_initialised) return false;

    try {
      final customerInfo = await Purchases.purchasePackage(package);
      return customerInfo.entitlements.all[entitlementId]?.isActive ?? false;
    } on PurchasesErrorCode catch (_) {
      // User cancelled, network error, etc.
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Restore purchases ─────────────────────────────────────────────
  Future<bool> restorePurchases() async {
    await _ensureInitialised();
    if (!_initialised) return false;

    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all[entitlementId]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Check current entitlement ──────────────────────────────────────
  Future<bool> isPro() async {
    await _ensureInitialised();
    if (!_initialised) return false;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[entitlementId]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Sync subscription state to Firestore ───────────────────────────
  void _onCustomerInfoUpdated(CustomerInfo info) async {
    final isActive = info.entitlements.all[entitlementId]?.isActive ?? false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'subscription.tier': isActive ? 'pro' : 'free',
        'subscription.source': 'revenuecat',
        'subscription.lastSyncedAt': FieldValue.serverTimestamp(),
      });

      // Refresh local entitlements
      await EntitlementService.instance.refresh();
    } catch (_) {
      // Firestore sync failed — will retry on next app launch
    }
  }

  // ── Identify user (call after sign-in) ─────────────────────────────
  Future<void> identify(String userId) async {
    await _ensureInitialised();
    if (!_initialised) return;
    try {
      await Purchases.logIn(userId);
    } catch (_) {}
  }

  // ── Log out (call on sign-out) ─────────────────────────────────────
  Future<void> logOut() async {
    if (!_initialised) return;
    try {
      await Purchases.logOut();
    } catch (_) {}
  }
}
