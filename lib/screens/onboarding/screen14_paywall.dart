import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../../screens/paywall/paywall_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/purchase_service.dart';

/// Minimal interface screen 14 depends on — a single method that
/// attempts to start the default (annual) 7-day trial. Returns true
/// on success, false otherwise. The production adapter wraps
/// PurchaseService; tests inject a fake.
abstract class TrialStarter {
  Future<bool> startDefaultTrial();
}

class _RealTrialStarter implements TrialStarter {
  final PurchaseService _svc;
  _RealTrialStarter(this._svc);
  @override
  Future<bool> startDefaultTrial() async {
    final packages = await _svc.getPackages();
    if (packages.isEmpty) return false;
    return _svc.purchasePackage(packages.first);
  }
}

// ─────────────────────────────────────────────
// Screen 14 — Onboarding paywall
//
// Thin wrapper around the shared PaywallScreen with the first_recipe
// trigger. The paywall component itself handles headline selection,
// feature cards, pricing pills, and RC purchase flow. Screen 14 wires
// three controller-aware callbacks:
//
//   onClose            → returns to screen 13 (non-destructive)
//   onContinueWithFree → controller.setEntitlement('free') + advance
//   onStartTrial       → runs purchaseService.purchasePackage(...) with
//                        the first available package; on success sets
//                        entitlement='pro' and advances
//
// Copy + behaviour: docs/onboarding/14-paywall.md.
// ─────────────────────────────────────────────

class Screen14Paywall extends StatefulWidget {
  final OnboardingController controller;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final String? recipeThumbnailUrl;

  /// Optional trial starter override — tests inject a fake. Production
  /// callers pass null and the real PurchaseService is used.
  final TrialStarter? trialStarter;

  const Screen14Paywall({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onContinue,
    this.recipeThumbnailUrl,
    this.trialStarter,
  });

  @override
  State<Screen14Paywall> createState() => _Screen14PaywallState();
}

class _Screen14PaywallState extends State<Screen14Paywall> {
  bool _purchasing = false;

  late final TrialStarter _starter =
      widget.trialStarter ?? _RealTrialStarter(PurchaseService.instance);

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logEvent('onboarding_paywall_viewed');
  }

  Future<void> _startTrial() async {
    if (_purchasing) return;
    setState(() => _purchasing = true);
    try {
      final success = await _starter.startDefaultTrial();
      if (!mounted) return;
      if (success) {
        widget.controller.setEntitlement('pro');
        AnalyticsService.instance.logEvent(
          'onboarding_step_completed',
          const {'step_index': 14, 'step_name': 'paywall_trial'},
        );
        widget.onContinue();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't start the trial. Try again, or Continue with Free.",
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  void _continueWithFree() {
    widget.controller.setEntitlement('free');
    AnalyticsService.instance.logEvent(
      'onboarding_step_completed',
      const {'step_index': 14, 'step_name': 'paywall_free'},
    );
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return PaywallScreen(
      trigger: PaywallTrigger.first_recipe,
      onboarding: widget.controller.state,
      recipeThumbnailUrl: widget.recipeThumbnailUrl,
      onClose: widget.onBack,
      onContinueWithFree: _continueWithFree,
      onStartTrial: _startTrial,
    );
  }
}
