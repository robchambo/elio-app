import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../services/analytics_service.dart';
import '../../services/purchase_service.dart';
import '../../services/entitlement_service.dart';

// ─────────────────────────────────────────────
// PaywallScreen — Sprint 16 editorial restyle.
//
// Lead with a 7-day free trial when the user is eligible.
// RevenueCat manages trial eligibility server-side via the
// StoreProduct introductoryPrice — the app does not track trial state.
//
// Two visual states:
//   1. Trial-eligible:    "Start your 7-day free trial"
//   2. Already used trial: "Upgrade to Pro" (direct purchase)
//
// IMPORTANT: The _showTrialState getter is load-bearing for dry mode.
// When REVENUECAT_API_KEY isn't configured, getPackages() returns []
// and _showTrialState returns true (we optimistically lead with trial).
// It only returns false when packages have loaded AND none have an
// introductory price. Do NOT refactor that getter.
// ─────────────────────────────────────────────

/// Legacy trigger enum — retained for backward compatibility with existing
/// callers and integration tests. New callers should prefer [triggerContext].
///
/// `first_recipe` is the onboarding screen-14 entry point added in Sprint
/// 16; it drives per-goal headlines via [PaywallScreen.onboarding] and
/// optionally renders a [PaywallScreen.recipeThumbnailUrl] above the hero.
// ignore: constant_identifier_names
enum PaywallTrigger { onboarding, capReached, lockedFeature, first_recipe }

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

  /// Onboarding state — required when [trigger] is
  /// [PaywallTrigger.first_recipe] so per-goal headlines can resolve.
  /// Null for all other triggers.
  final OnboardingState? onboarding;

  /// Optional recipe thumbnail rendered above the hero heading. Only
  /// used by the first-recipe trigger; ignored otherwise.
  final String? recipeThumbnailUrl;

  /// Test-only injection point for the PurchaseService. Production
  /// callers leave null and the singleton is used.
  final PurchaseService? purchaseService;

  /// Optional callback invoked when the user taps "Continue with Free".
  /// When null (legacy callers), this UI element is not rendered. When
  /// non-null (onboarding screen 14), the link is shown and this is
  /// fired in place of Navigator.pop.
  final VoidCallback? onContinueWithFree;

  /// Optional callback invoked on a successful trial/subscription start.
  /// Legacy callers leave null — PaywallScreen falls back to
  /// `Navigator.pop(true)` as before. Onboarding screen 14 uses this to
  /// advance without popping the route.
  final VoidCallback? onTrialStarted;

  /// Optional override of the close (✕) handler. When null, defaults to
  /// `Navigator.pop()`. Onboarding screen 14 injects this to return to
  /// screen 13 non-destructively.
  final VoidCallback? onClose;

  /// Optional override for the primary "Start free trial / Subscribe"
  /// CTA. When set, replaces the internal `_onSubscribe` flow — screen
  /// 14 uses this to drive the purchase via an injected service and
  /// advance the onboarding controller on success.
  final VoidCallback? onStartTrial;

  const PaywallScreen({
    super.key,
    this.triggerContext,
    this.trigger = PaywallTrigger.lockedFeature,
    this.lockedFeatureName,
    this.onboarding,
    this.recipeThumbnailUrl,
    this.purchaseService,
    this.onContinueWithFree,
    this.onTrialStarted,
    this.onClose,
    this.onStartTrial,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final AnalyticsService _analytics = AnalyticsService.instance;
  late final PurchaseService _purchases =
      widget.purchaseService ?? PurchaseService.instance;

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
      case PaywallTrigger.first_recipe:
        return 'first_recipe';
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

  /// Headline for [PaywallTrigger.first_recipe] — varies by the user's
  /// onboarding goal. Falls back to a neutral trial CTA when the goal
  /// is unset. Returned as a single-entry list so it composes with
  /// [ElioHeroHeading] (the underline + amber-last-line treatment still
  /// renders cleanly on one line).
  List<String> get _firstRecipeHeadline {
    // Per-goal headlines for the onboarding first-recipe paywall entry.
    // Copy signed off Sprint 16.2 (docs/onboarding/14-paywall.md §Copy).
    switch (widget.onboarding?.userGoal) {
      case 'pantryFirst':
        // Two-line editorial treatment — Rob's call for extra weight on
        // the dominant pantry-first goal.
        return ['Cook from your pantry.', 'Every night.'];
      case 'wasteReduction':
        return ['Cut your food waste from week one.'];
      case 'decisionFatigue':
        return ['No more 6pm panic.'];
      case 'household':
        return ['One plan for the whole house.'];
      case 'takeawayEscape':
        // US-leaning spelling ("takeout") per Rob's Sprint 16.2 decision —
        // US is the primary launch market.
        return ['Skip the takeout.'];
      default:
        return ['Unlimited Elio. Start with 7 days free.'];
    }
  }

  /// Context-specific hero lines. Returns up to 3 lines for ElioHeroHeading.
  List<String> get _heroLines {
    switch (_resolvedContext) {
      case 'first_recipe':
        return _firstRecipeHeadline;
      case 'weekly_limit':
        return ["you've used", 'your free', 'recipes'];
      case 'meal_planner':
        return ['plan your', 'week with', 'pro'];
      case 'shopping_list':
        return ['unlock', 'smart', 'shopping'];
      case 'household':
        return ['cook for', 'everyone'];
      default:
        return ['go pro', 'with elio'];
    }
  }

  String get _contextEyebrow {
    switch (_resolvedContext) {
      case 'first_recipe':
        return 'unlock more like this';
      case 'weekly_limit':
        return 'unlock unlimited recipes';
      case 'meal_planner':
        return 'plan your whole week';
      case 'shopping_list':
        return 'shop smarter with one list';
      case 'household':
        return 'cook for your household';
      default:
        return 'upgrade to elio pro';
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

  String? get _annualPriceString {
    for (final p in _packages) {
      if (p.storeProduct.identifier == PurchaseService.annualProductId) {
        return p.storeProduct.priceString;
      }
    }
    return null;
  }

  String? get _monthlyPriceString {
    for (final p in _packages) {
      if (p.storeProduct.identifier == PurchaseService.monthlyProductId) {
        return p.storeProduct.priceString;
      }
    }
    return null;
  }

  // ── Build ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final trial = _showTrialState;
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: ElioColors.navy),
          onPressed: () {
            _analytics.logEvent('paywall_dismissed', {
              'trigger_context': _resolvedContext ?? 'none',
            });
            if (widget.onClose != null) {
              widget.onClose!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Recipe thumbnail (first_recipe trigger only) ──
              if (widget.recipeThumbnailUrl != null &&
                  widget.recipeThumbnailUrl!.isNotEmpty) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: ElioRadii.card,
                    child: Image.network(
                      widget.recipeThumbnailUrl!,
                      key: const Key('paywallRecipeThumbnail'),
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Eyebrow ──────────────────────────────────────
              ElioEyebrow(_contextEyebrow),
              const SizedBox(height: 12),

              // ── Hero heading ─────────────────────────────────
              ElioHeroHeading(
                lines: _heroLines,
                amberLastLine: true,
                showUnderline: true,
              ),
              const SizedBox(height: 20),

              if (trial) ...[
                ElioEyebrow(
                  '$_trialDurationLabel free trial · cancel anytime',
                ),
                const SizedBox(height: 24),
              ] else ...[
                const SizedBox(height: 8),
              ],

              // ── Feature cards ─────────────────────────────────
              ..._buildFeatureCards(),
              const SizedBox(height: 28),

              // ── Pricing pills ────────────────────────────────
              _buildPricingRow(),
              const SizedBox(height: 28),

              // ── Primary CTA ──────────────────────────────────
              ElioBigButton(
                key: const Key('paywallPrimaryCta'),
                label: trial
                    ? 'Start my $_trialDurationLabel free trial'
                    : 'Subscribe — $_selectedPriceString/$_selectedPeriodString',
                trailingIcon: Icons.chevron_right,
                loading: _isLoading,
                onTap: widget.onStartTrial ?? _onSubscribe,
              ),
              const SizedBox(height: 14),

              // ── Continue with Free (onboarding screen 14 only) ───
              if (widget.onContinueWithFree != null) ...[
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _analytics.logEvent(
                              'onboarding_paywall_free_continued',
                            );
                            widget.onContinueWithFree!();
                          },
                    child: Text(
                      'Continue with Free',
                      style: ElioTextStyles.bodySmall.copyWith(
                        color: ElioColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],

              // ── Restore purchases ─────────────────────────────
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _onRestore,
                  child: Text(
                    'Restore purchases',
                    style: ElioTextStyles.bodySmall.copyWith(
                      color: ElioColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // ── Legal ────────────────────────────────────────
              Text(
                trial
                    ? '7 days free, then $_selectedPriceString/$_selectedPeriodString. Cancel anytime in Google Play.'
                    : '$_selectedPriceString billed every $_selectedPeriodString. Cancel anytime in Google Play.',
                style: GoogleFonts.quicksand(
                  fontSize: 11,
                  height: 1.4,
                  color: ElioColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Feature cards ────────────────────────────────────────────────────
  // Informational cream cards — no action button (so we build inline,
  // not via ElioSecondaryCard which always renders a CTA).
  List<Widget> _buildFeatureCards() {
    const features = <Map<String, String>>[
      {
        'title': 'Unlimited recipes',
        'subtitle': 'Generate as many meals as you like, every week.',
      },
      {
        'title': 'Weekly meal planner',
        'subtitle': 'Plan breakfast, lunch and dinner seven days ahead.',
      },
      {
        'title': 'Smart shopping list',
        'subtitle': 'Missing ingredients organised by grocery aisle.',
      },
      {
        'title': 'Household of 6',
        'subtitle': 'Share preferences with your whole household.',
      },
      {
        'title': '50-recipe history',
        'subtitle': 'Keep your favourites — revisit any time.',
      },
    ];

    return [
      for (final f in features) ...[
        _FeatureInfoCard(
          title: f['title']!,
          subtitle: f['subtitle']!,
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  // ── Pricing pills ────────────────────────────────────────────────────
  Widget _buildPricingRow() {
    final annualLabel = _annualPriceString ?? '£27.99/yr';
    final monthlyLabel = _monthlyPriceString ?? '£4.49/mo';

    return Row(
      children: [
        Expanded(
          child: _PricingPill(
            label: 'Yearly',
            price: annualLabel,
            badge: 'Best value',
            isSelected: _isAnnual,
            onTap: () => setState(() => _isAnnual = true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PricingPill(
            label: 'Monthly',
            price: monthlyLabel,
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
      if (!mounted) return;
      if (widget.onTrialStarted != null) {
        widget.onTrialStarted!();
      } else {
        Navigator.of(context).pop(true);
      }
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

// ─── Feature info card (inline cream container) ───────────────────────
class _FeatureInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _FeatureInfoCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: ElioRadii.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ElioColors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: ElioColors.amber,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ElioTextStyles.heading5),
                const SizedBox(height: 2),
                Text(subtitle, style: ElioTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pricing pill ──────────────────────────────────────────────────────
class _PricingPill extends StatelessWidget {
  final String label;
  final String price;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PricingPill({
    required this.label,
    required this.price,
    required this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: ElioRadii.card,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        decoration: BoxDecoration(
          color: isSelected ? ElioColors.amber.withValues(alpha: 0.12) : Colors.white,
          borderRadius: ElioRadii.card,
          border: Border.all(
            color: isSelected ? ElioColors.amber : ElioColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: ElioColors.amber,
                  borderRadius: ElioRadii.chip,
                ),
                child: Text(
                  badge!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              const SizedBox(height: 19),
            ],
            Text(
              label,
              style: ElioTextStyles.bodySmall.copyWith(
                color: isSelected ? ElioColors.navy : ElioColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: ElioTextStyles.heading4.copyWith(
                color: isSelected ? ElioColors.navy : ElioColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
