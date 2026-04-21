import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import 'screen01_welcome.dart';
import 'screen02_goal.dart';
import 'screen03_household.dart';
import 'screen04_dietary.dart';
import 'screen05_allergies.dart';
import 'screen06_time.dart';
import 'screen07_confidence.dart';
import 'screen08_appliances.dart';
import 'screen09_region.dart';
import 'screen10_pantry_intro.dart';
import 'screen11_pantry_staples.dart';
import 'screen12_pantry_perishables.dart';
import 'screen13_first_recipe.dart';
import 'screen14_paywall.dart';
import 'screen15_account.dart';

// ─────────────────────────────────────────────
// OnboardingFlow — 15-screen coordinator (Sprint 16)
//
// Owns a single [OnboardingController] and a [PageController]. Each child
// screen receives `onContinue` / `onBack` callbacks wired to page
// navigation. Screens 02–14 advance via `nextPage`; screen 15 replaces
// the route with the post-onboarding destination after flipping the
// `onboardingComplete` pref (screen 15 owns that logic already).
//
// The legacy `{displayName, onComplete, isGuest}` constructor is kept
// for backwards-compatibility with `AuthGate` in `lib/main.dart`, but
// those fields are no longer read — onboarding completion is now signalled
// via SharedPreferences and `AuthGate` re-resolves on app restart.
// ─────────────────────────────────────────────

class OnboardingFlow extends StatefulWidget {
  final String displayName;
  final VoidCallback onComplete;
  final bool isGuest;

  /// Optional injected controller — tests pass a pre-configured instance
  /// to seed state. Production callers let the coordinator construct a
  /// fresh one per flow.
  final OnboardingController? controller;

  const OnboardingFlow({
    super.key,
    this.displayName = 'there',
    this.onComplete = _noop,
    this.isGuest = false,
    this.controller,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

void _noop() {}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final PageController _pageController;
  late final OnboardingController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = OnboardingController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _back() async {
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Screen01Welcome(controller: _controller, onContinue: _next),
          Screen02Goal(
            controller: _controller,
            onContinue: _next,
            onBack: _back,
          ),
          Screen03Household(
            controller: _controller,
            onContinue: _next,
            onBack: _back,
          ),
          Screen04Dietary(
            controller: _controller,
            onContinue: _next,
            onBack: _back,
          ),
          Screen05Allergies(
            controller: _controller,
            onContinue: _next,
            onBack: _back,
          ),
          Screen06Time(
            controller: _controller,
            onContinue: _next,
            onBack: _back,
          ),
          Screen07Confidence(
            controller: _controller,
            onContinue: _next,
            onBack: _back,
          ),
          Screen08Appliances(
            controller: _controller,
            onContinue: _next,
            onBack: _back,
          ),
          Screen09Region(
            controller: _controller,
            onContinue: _next,
            onBack: _back,
          ),
          Screen10PantryIntro(
            controller: _controller,
            onContinue: _next,
            onBack: _back,
          ),
          Screen11PantryStaples(
            controller: _controller,
            onContinue: _next,
            onBack: _back,
          ),
          Screen12PantryPerishables(
            controller: _controller,
            onContinue: _next,
            onBack: _back,
          ),
          Screen13FirstRecipe(
            controller: _controller,
            onContinue: _next,
          ),
          Screen14Paywall(
            controller: _controller,
            onContinue: _next,
            onBack: _back,
          ),
          Screen15Account(
            controller: _controller,
            onBack: _back,
          ),
        ],
      ),
    );
  }
}
