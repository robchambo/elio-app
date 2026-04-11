import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../theme/elio_theme.dart';
import '../../services/analytics_service.dart';
import '../../services/purchase_service.dart';
import '../../services/entitlement_service.dart';

// ─────────────────────────────────────────────
// PaywallScreen
// Lead with a 7-day free trial when the user is eligible.
// RevenueCat manages trial eligibility server-side via the
// StoreProduct introductoryPrice — the app does not track trial state.
//
// Two visual states:
//   1. Trial-eligible:    "Start Your 7-Day Free Trial"
//   2. Already used trial: "Upgrade to Pro" (direct purchase)
//
// Both states share the same feature checklist and plan toggle.
// ─────────────────────────────────────────────

/// Legacy trigger enum — retained for backward compatibility with existing
/// callers and integration tests. New callers should prefer [triggerContext].
enum PaywallTrigger { onboarding, capReached, lockedFeature }

class PaywallScreen extends StatefulWidget {
  /// Optional context describing where the paywall was opened from.
  /// Recognised values: 'weekly_limit', 'meal_planner', 'shopping_list',
  /// 'household'. Any other value (or null) shows the default headline.
  final String? triggerContext;

  /// Legacy trigger — kept for backward compatibility. Maps onto
  /// [triggerContext] when [triggerContext] is null.
  final PaywallTrigger trigger;

  /// Legacy locked-feature name — kept so older callers still compile.
  final String? lockedFeatureName;

  const PaywallScreen({
    super.key,
    this.triggerContext,
    this.trigger = PaywallTrigger.lockedFeature,
    this.lockedFeatureName,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final AnalyticsService _analytics = AnalyticsService.instance;
  final PurchaseService _purchases = PurchaseService.instance;

  bool _isAnnual = true; // Annual pre-selected (best value)
  bool _isLoading = false;
  List<Package> _packages = [];

  @override
  void initState() {
    super.initState();
    _analytics.logEvent('paywall_viewed', {
      'trigger_context': _resolvedContext ?? 'none',
      'legacy_trigger': widget.trigger.name,
    });
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    if (!_purchases.isAvailable) return;
    final packages = await _purchases.getPackages();
    if (mounted) setState(() => _packages = packages);
  }

  /// Resolves the effective context string. If [triggerContext] is set,
  /// use it directly. Otherwise map the legacy [trigger] enum onto a
  /// reasonable context value.
  String? get _resolvedContext {
    if (widget.triggerContext != null) return widget.triggerContext;
    switch (widget.trigger) {
      case PaywallTrigger.capReached:
        return 'weekly_limit';
      case PaywallTrigger.onboarding:
        return null;
      case PaywallTrigger.lockedFeature:
        final name = widget.lockedFeatureName?.toLowerCase() ?? '';
        if (name.contains('meal')) return 'meal_planner';
        if (name.contains('shop')) return 'shopping_list';
        if (name.contains('household')) return 'household';
        return null;
    }
  }

  String get _contextHeadline {
    switch (_resolvedContext) {
      case 'weekly_limit':
        return 'Unlock unlimited recipes';
      case 'meal_planner':
        return 'Plan your whole week';
      case 'shopping_list':
        return 'Shop smarter with one list';
      case 'household':
        return 'Cook for your whole household';
      default:
        return 'Go Pro with Elio';
    }
  }

  // ── Trial / package helpers ─────────────────────────────────────────
  Package? get _selectedPackage {
    if (_packages.isEmpty) return null;
    final targetId = _isAnnual
        ? PurchaseService.annualProductId
        : PurchaseService.monthlyProductId;
    for (final p in _packages) {
      if (p.storeProduct.identifier == targetId) return p;
    }
    return _packages.first;
  }

  /// Trial state is "lead with trial" in two cases:
  ///   1. Packages are loaded AND at least one has a trial configured
  ///      (live RevenueCat with trial-enabled Play Store SKUs).
  ///   2. Packages are empty — either still loading or running in
  ///      "dry mode" (no RC key). In that case we optimistically show
  ///      the trial copy so pre-launch and testing match the intended
  ///      live experience. RevenueCat remains the source of truth at
  ///      purchase time — if the user isn't eligible, it won't grant one.
  bool get _showTrialState {
    if (_packages.isEmpty) return true;
    for (final p in _packages) {
      if (_purchases.hasFreeTrial(p)) return true;
    }
    return false;
  }

  String get _trialDurationLabel {
    final pkg = _selectedPackage;
    if (pkg == null) return '7-day';
    final label = _purchases.trialDurationLabel(pkg);
    return label.isEmpty ? '7-day' : label;
  }

  String get _selectedPriceString {
    final pkg = _selectedPackage;
    if (pkg == null) {
      return _isAnnual ? '£27.99' : '£4.49';
    }
    return pkg.storeProduct.priceString;
  }

  String get _selectedPeriodString => _isAnnual ? 'year' : 'month';

  // ── Build ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Close button (top-LEFT per spec)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, left: 16),
                child: GestureDetector(
                  onTap: () {
                    _analytics.logEvent('paywall_dismissed', {
                      'trigger_context': _resolvedContext ?? 'none',
                    });
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ElioColors.offWhite,
                      shape: BoxShape.circle,
                      border: Border.all(color: ElioColors.border),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: ElioColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Context headline ────────────────────────
                    Text(
                      _contextHeadline,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ElioColors.amber,
                        letterSpacing: 0.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // ── Hero ────────────────────────────────────
                    Text(
                      _showTrialState
                          ? 'Start Your $_trialDurationLabel Free Trial'
                          : 'Upgrade to Pro',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: ElioColors.navy,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _showTrialState
                          ? 'All Pro features. Cancel anytime. No charge for 7 days.'
                          : 'All Pro features. Cancel anytime in Google Play.',
                      style: ElioText.bodyLarge.copyWith(
                        color: ElioColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // ── Feature checklist ───────────────────────
                    ..._buildFeatureList(),
                    const SizedBox(height: 24),

                    // ── Plan toggle ─────────────────────────────
                    _buildPlanCards(),
                    const SizedBox(height: 20),

                    // ── Primary CTA ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onSubscribe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ElioColors.amber,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              ElioColors.amber.withValues(alpha: 0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _showTrialState
                                    ? 'Start Free Trial'
                                    : 'Subscribe — $_selectedPriceString/$_selectedPeriodString',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Fine print ──────────────────────────────
                    Text(
                      _showTrialState
                          ? '7 days free, then $_selectedPriceString/$_selectedPeriodString. Cancel anytime in Google Play.'
                          : '$_selectedPriceString billed every $_selectedPeriodString. Cancel anytime in Google Play.',
                      style: ElioText.bodyMedium.copyWith(
                        color: ElioColors.textMuted,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // ── Restore purchases ───────────────────────
                    TextButton(
                      onPressed: _isLoading ? null : _onRestore,
                      child: Text(
                        'Restore purchases',
                        style: ElioText.bodyMedium.copyWith(
                          color: ElioColors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Feature checklist ────────────────────────────────────────────────
  List<Widget> _buildFeatureList() {
    const features = [
      'Unlimited AI recipe generation',
      'Weekly meal planner',
      'Smart shopping list',
      'Household sharing (up to 6 members)',
      'Unlimited recipe history',
      'Priority recipe regeneration',
    ];

    return features
        .map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 22,
                  color: ElioColors.success,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    f,
                    style: ElioText.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ElioColors.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  // ── Plan cards ───────────────────────────────────────────────────────
  Widget _buildPlanCards() {
    // Pull live prices from packages when available; fall back to defaults.
    String? annualPrice;
    String? monthlyPrice;
    for (final p in _packages) {
      if (p.storeProduct.identifier == PurchaseService.annualProductId) {
        annualPrice = p.storeProduct.priceString;
      } else if (p.storeProduct.identifier == PurchaseService.monthlyProductId) {
        monthlyPrice = p.storeProduct.priceString;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _PlanCard(
            label: 'Annual',
            price: annualPrice ?? '£27.99/yr',
            badge: 'Best value — save ~30%',
            isSelected: _isAnnual,
            onTap: () => setState(() => _isAnnual = true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlanCard(
            label: 'Monthly',
            price: monthlyPrice ?? '£4.49/mo',
            badge: null,
            isSelected: !_isAnnual,
            onTap: () => setState(() => _isAnnual = false),
          ),
        ),
      ],
    );
  }

  Future<void> _onSubscribe() async {
    _analytics.logEvent('paywall_subscribe_tapped', {
      'plan': _isAnnual ? 'annual' : 'monthly',
      'trigger_context': _resolvedContext ?? 'none',
      'is_trial': _showTrialState,
    });

    if (!_purchases.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscriptions coming soon!')),
        );
      }
      return;
    }

    final package = _selectedPackage;
    if (package == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No plans available. Please try again later.')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    // RevenueCat auto-applies the configured Play Store free trial when
    // the user is eligible — no manual trial flag needed.
    final success = await _purchases.purchasePackage(package);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      await EntitlementService.instance.refresh();
      _analytics.logEvent('purchase_completed', {
        'plan': _isAnnual ? 'annual' : 'monthly',
        'is_trial': _showTrialState,
      });
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _onRestore() async {
    setState(() => _isLoading = true);
    final success = await _purchases.restorePurchases();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      await EntitlementService.instance.refresh();
      _analytics.logEvent('purchase_restored');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pro access restored!')),
        );
        Navigator.of(context).pop(true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No previous subscription found.')),
        );
      }
    }
  }
}

// ─── Plan card widget ──────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final String label;
  final String price;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.label,
    required this.price,
    required this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        decoration: BoxDecoration(
          color: isSelected
              ? ElioColors.amber.withValues(alpha: 0.08)
              : ElioColors.offWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? ElioColors.amber : ElioColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ElioColors.amber,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              const SizedBox(height: 19),
            ],
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? ElioColors.navy : ElioColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected ? ElioColors.navy : ElioColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
