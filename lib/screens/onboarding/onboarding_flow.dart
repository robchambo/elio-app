import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/onboarding_state.dart';
import '../../services/firestore_service.dart';
import '../../services/guest_pantry_service.dart';
import '../../services/analytics_service.dart';
import '../home/home_screen.dart';
import '../paywall/paywall_screen.dart';
import 'screen1_dietary.dart';
import 'screen2_preset.dart';
import 'screen3_pantry.dart';
import 'screen4_household.dart';
import 'screen5_style.dart';
import 'screen6_appliances.dart';

// ─────────────────────────────────────────────
// OnboardingFlow
// Coordinator widget that manages the five-screen onboarding sequence.
// Uses a PageView for smooth horizontal transitions.
// Accumulates OnboardingState across screens.
// Writes to Firestore on completion (skipped in guest mode).
//
// Screen order:
//   1. Dietary requirements (mandatory)
//   2. Kitchen preset (mandatory)
//   3. Pantry review (mandatory)
//   4. Household members (optional)
//   5. Style preferences (optional)
//   6. Kitchen appliances (optional)
// ─────────────────────────────────────────────

class OnboardingFlow extends StatefulWidget {
  final String displayName;
  final VoidCallback onComplete;
  final bool isGuest;

  const OnboardingFlow({
    super.key,
    required this.displayName,
    required this.onComplete,
    this.isGuest = false,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  final FirestoreService _firestore = FirestoreService();
  final AnalyticsService _analytics = AnalyticsService.instance;
  OnboardingState _state = OnboardingState();
  bool _isSaving = false;

  static const List<String> _stepNames = [
    'dietary', 'kitchen_preset', 'pantry_review', 'household', 'style', 'appliances',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _onDietaryNext(OnboardingState updated) {
    setState(() => _state = updated);
    _analytics.logEvent('onboarding_step_completed', {'step': _stepNames[0]});
    _goToPage(1);
  }

  void _onPresetNext(OnboardingState updated) {
    setState(() => _state = updated);
    _analytics.logEvent('onboarding_step_completed', {'step': _stepNames[1]});
    _goToPage(2);
  }

  void _onPantryNext(OnboardingState updated) {
    setState(() => _state = updated);
    _analytics.logEvent('onboarding_step_completed', {'step': _stepNames[2]});
    _goToPage(3);
  }

  void _onHouseholdNext(OnboardingState updated) {
    setState(() => _state = updated);
    _analytics.logEvent('onboarding_step_completed', {'step': _stepNames[3]});
    _goToPage(4);
  }

  void _onStyleComplete(OnboardingState updated) {
    setState(() => _state = updated);
    _analytics.logEvent('onboarding_step_completed', {'step': _stepNames[4]});
    _goToPage(5);
  }

  Future<void> _onAppliancesComplete(OnboardingState updated) async {
    _analytics.logEvent('onboarding_step_completed', {'step': _stepNames[5]});
    setState(() { _state = updated; _isSaving = true; });

    // Guest mode: persist pantry data locally then navigate
    if (widget.isGuest) {
      await GuestPantryService.save(_state);
      _analytics.logEvent('onboarding_completed', {'auth_method': 'guest'});
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen(isGuest: true)),
          (route) => false,
        );
      }
      return;
    }

    // Signed-in mode: save to Firestore then navigate directly
    try {
      await _firestore.completeOnboarding(_state, widget.displayName);
      _analytics.logEvent('onboarding_completed', {'auth_method': 'google'});
      _analytics.setDietaryProfile(_state.dietaryRequirements.map((d) => d.label).toList());
      _analytics.setHouseholdSize(_state.additionalMembers.length + 1);
      if (mounted) {
        // Navigate to Home, then show paywall on top
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PaywallScreen(trigger: PaywallTrigger.onboarding),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaving) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFFF08C14)),
              const SizedBox(height: 20),
              Text(
                widget.isGuest ? 'Getting Elio ready...' : 'Setting up your kitchen...',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B6B6B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        DietaryScreen(
          state: _state,
          onNext: _onDietaryNext,
        ),
        KitchenPresetScreen(
          state: _state,
          onNext: _onPresetNext,
          onBack: () => _goToPage(0),
        ),
        PantryReviewScreen(
          state: _state,
          onNext: _onPantryNext,
          onBack: () => _goToPage(1),
        ),
        HouseholdScreen(
          state: _state,
          onComplete: _onHouseholdNext,
          onBack: () => _goToPage(2),
        ),
        StylePreferencesScreen(
          state: _state,
          onComplete: _onStyleComplete,
          onBack: () => _goToPage(3),
        ),
        KitchenAppliancesScreen(
          state: _state,
          onComplete: _onAppliancesComplete,
          onBack: () => _goToPage(4),
        ),
      ],
    );
  }
}
