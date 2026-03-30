import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../theme/elio_theme.dart';
import '../../services/analytics_service.dart';
import '../../services/purchase_service.dart';
import '../../services/entitlement_service.dart';

// ─────────────────────────────────────────────
// PaywallScreen
// Design: approachable utility.
//
// Annual plan pre-selected, monthly shown as secondary.
// 7-day opt-in trial (no card required).
// Can be shown post-onboarding, on cap hit, or from locked features.
// ─────────────────────────────────────────────

enum PaywallTrigger { onboarding, capReached, lockedFeature }

class PaywallScreen extends StatefulWidget {
  final PaywallTrigger trigger;
  final String? lockedFeatureName;

  const PaywallScreen({
    super.key,
    this.trigger = PaywallTrigger.lockedFeature,
    this.lockedFeatureName,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final AnalyticsService _analytics = AnalyticsService.instance;
  final PurchaseService _purchases = PurchaseService.instance;
  bool _isAnnual = true; // Annual pre-selected
  bool _isLoading = false;
  List<Package> _packages = [];

  @override
  void initState() {
    super.initState();
    _analytics.logEvent('paywall_viewed', {
      'trigger': widget.trigger.name,
      'locked_feature': widget.lockedFeatureName ?? 'none',
    });
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    if (!_purchases.isAvailable) return;
    final packages = await _purchases.getPackages();
    if (mounted) setState(() => _packages = packages);
  }

  String get _headline {
    switch (widget.trigger) {
      case PaywallTrigger.onboarding:
        return 'Unlock the full kitchen';
      case PaywallTrigger.capReached:
        return "You've used all 7 this week";
      case PaywallTrigger.lockedFeature:
        return '${widget.lockedFeatureName ?? 'This feature'} is Pro';
    }
  }

  String get _subtitle {
    switch (widget.trigger) {
      case PaywallTrigger.onboarding:
        return 'Start your 7-day free trial — no card required.';
      case PaywallTrigger.capReached:
        return 'Go Pro for unlimited recipes, meal plans, and more.';
      case PaywallTrigger.lockedFeature:
        return 'Upgrade to unlock ${widget.lockedFeatureName?.toLowerCase() ?? 'this feature'} and everything else.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Close button ─────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 16),
                child: GestureDetector(
                  onTap: () {
                    _analytics.logEvent('paywall_dismissed', {
                      'trigger': widget.trigger.name,
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
                    child: const Icon(Icons.close, size: 18, color: ElioColors.textSecondary),
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    // ── Icon ─────────────────────────────────
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: ElioColors.amber.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, color: ElioColors.amber, size: 36),
                    ),
                    const SizedBox(height: 20),

                    // ── Headline ─────────────────────────────
                    Text(
                      _headline,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: ElioColors.navy,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subtitle,
                      style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // ── Feature list ─────────────────────────
                    ..._buildFeatureList(),
                    const SizedBox(height: 32),

                    // ── Plan toggle ──────────────────────────
                    _buildPlanCards(),
                    const SizedBox(height: 24),

                    // ── CTA ──────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onSubscribe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ElioColors.amber,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: ElioColors.amber.withValues(alpha: 0.5),
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
                                widget.trigger == PaywallTrigger.onboarding
                                    ? 'Start Free Trial'
                                    : _isAnnual
                                        ? 'Go Pro — £27.99/year'
                                        : 'Go Pro — £4.49/month',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Secondary CTAs ───────────────────────
                    if (widget.trigger == PaywallTrigger.onboarding)
                      TextButton(
                        onPressed: _isLoading ? null : () {
                          _analytics.logEvent('paywall_skip_trial');
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Continue with free plan',
                          style: ElioText.bodyMedium.copyWith(
                            color: ElioColors.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                    // ── Restore purchases ────────────────────
                    TextButton(
                      onPressed: _isLoading ? null : _onRestore,
                      child: Text(
                        'Restore purchases',
                        style: ElioText.bodyMedium.copyWith(
                          color: ElioColors.textSecondary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),
                    Text(
                      'Cancel anytime. No commitment.',
                      style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
                      textAlign: TextAlign.center,
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

  // ── Feature list ─────────────────────────────────────────────────────
  List<Widget> _buildFeatureList() {
    const features = [
      ('Unlimited recipe generations', 'No weekly cap'),
      ('Weekly meal planner', 'Auto-generated plans for your household'),
      ('Shopping lists', 'Aggregated from your meal plan'),
      ('Up to 6 household members', 'Everyone\'s diet covered'),
      ('Unlimited recipe history', 'Never lose a favourite'),
    ];

    return features
        .map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: ElioColors.amber.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 14, color: ElioColors.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.$1,
                          style: ElioText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          f.$2,
                          style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }

  // ── Plan cards ───────────────────────────────────────────────────────
  Widget _buildPlanCards() {
    return Row(
      children: [
        // Annual
        Expanded(
          child: _PlanCard(
            label: 'Annual',
            price: '£27.99/yr',
            perMonth: '£2.33/mo',
            badge: 'Save 48%',
            isSelected: _isAnnual,
            onTap: () => setState(() => _isAnnual = true),
          ),
        ),
        const SizedBox(width: 12),
        // Monthly
        Expanded(
          child: _PlanCard(
            label: 'Monthly',
            price: '£4.49/mo',
            perMonth: null,
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
      'trigger': widget.trigger.name,
    });

    if (!_purchases.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscriptions coming soon!')),
        );
      }
      return;
    }

    // Find the right package
    final targetId = _isAnnual
        ? PurchaseService.annualProductId
        : PurchaseService.monthlyProductId;
    final package = _packages.cast<Package?>().firstWhere(
      (p) => p!.storeProduct.identifier == targetId,
      orElse: () => _packages.isNotEmpty ? _packages.first : null,
    );

    if (package == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No plans available. Please try again later.')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    final success = await _purchases.purchasePackage(package);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      await EntitlementService.instance.refresh();
      _analytics.logEvent('purchase_completed', {
        'plan': _isAnnual ? 'annual' : 'monthly',
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
  final String? perMonth;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.label,
    required this.price,
    required this.perMonth,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? ElioColors.amber.withValues(alpha: 0.08) : ElioColors.offWhite,
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
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? ElioColors.navy : ElioColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isSelected ? ElioColors.navy : ElioColors.textPrimary,
              ),
            ),
            if (perMonth != null) ...[
              const SizedBox(height: 2),
              Text(
                perMonth!,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? ElioColors.amber : ElioColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
