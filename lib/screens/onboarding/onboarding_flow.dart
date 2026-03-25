import 'package:flutter/material.dart';
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
// Writes to Firestore on completion.
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

  const OnboardingFlow({
    super.key,
    required this.displayName,
    required this.onComplete,
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
    try {
      await _firestore.completeOnboarding(_state, widget.displayName);
      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaving) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFFFF),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFF08C14)),
              SizedBox(height: 20),
              Text(
                'Setting up your kitchen...',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B6B6B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(), // Navigation controlled programmatically
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
