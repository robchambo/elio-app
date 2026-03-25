import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/onboarding_state.dart';
import '../../services/firestore_service.dart';
import 'screen1_dietary.dart';
import 'screen2_preset.dart';
import 'screen3_pantry.dart';
import 'screen4_household.dart';
import 'screen5_style.dart';

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
  OnboardingState _state = OnboardingState();
  bool _isSaving = false;

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
    _goToPage(1);
  }

  void _onPresetNext(OnboardingState updated) {
    setState(() => _state = updated);
    _goToPage(2);
  }

  void _onPantryNext(OnboardingState updated) {
    setState(() => _state = updated);
    _goToPage(3);
  }

  void _onHouseholdNext(OnboardingState updated) {
    setState(() => _state = updated);
    _goToPage(4);
  }

  Future<void> _onStyleComplete(OnboardingState updated) async {
    setState(() { _state = updated; _isSaving = true; });

    // Guest mode: skip Firestore, navigate immediately
    if (widget.isGuest) {
      widget.onComplete();
      return;
    }

    // Signed-in mode: save to Firestore then navigate
    try {
      await _firestore.completeOnboarding(_state, widget.displayName);
      if (mounted) widget.onComplete();
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
      ],
    );
  }
}
