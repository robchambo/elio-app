import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../../services/analytics_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../../widgets/elio/elio_household_stepper.dart';
import '../../widgets/elio/elio_onboarding_option_card.dart';
import '../../widgets/elio/elio_onboarding_progress_bar.dart';

// ─────────────────────────────────────────────
// Screen 03 — Household
//
// Single-select of the 5 household archetypes + count stepper.
// Tapping a type pre-fills the default count unless the user has
// manually edited the stepper (tracked on the controller).
//
// See docs/onboarding/03-household.md for authoritative copy spec.
// ─────────────────────────────────────────────

class _HouseholdOption {
  final String value;
  final String label;
  final String subtext;
  final int defaultCount;
  const _HouseholdOption(
      this.value, this.label, this.subtext, this.defaultCount);
}

// Copy verbatim from docs/onboarding/03-household.md §Copy.
const List<_HouseholdOption> _options = [
  _HouseholdOption('solo', 'Just me', 'Solo cooking, one plate to please', 1),
  _HouseholdOption('couple', 'Just the two of us', 'Two adults, one kitchen', 2),
  _HouseholdOption(
      'family', 'Family with kids', 'Little ones, teens, or a mix', 4),
  _HouseholdOption(
      'flat', 'Flatmates or housemates', 'Shared kitchen, shared shopping', 3),
  _HouseholdOption('other', 'Something else',
      "Tell us the headcount and we'll sort the rest", 2),
];

class Screen03Household extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const Screen03Household({
    super.key,
    required this.controller,
    required this.onContinue,
    required this.onBack,
  });

  void _selectType(String value) {
    controller.setHouseholdType(value);
    if (!controller.countManuallyEdited) {
      final opt = _options.firstWhere((o) => o.value == value);
      controller.setHouseholdCount(opt.defaultCount);
    }
  }

  void _onStepperChanged(int v) {
    controller.setHouseholdCount(v);
    if (!controller.countManuallyEdited) {
      controller.setCountManuallyEdited(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final selectedType = controller.state.householdType;
            final count = controller.state.householdCount;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // PINNED TOP.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ElioSpacing.screenEdge,
                    ElioSpacing.sm,
                    ElioSpacing.screenEdge,
                    0,
                  ),
                  child: Row(
                    children: [
                      BackButton(
                        color: ElioColors.espresso,
                        onPressed: onBack,
                      ),
                      const SizedBox(width: ElioSpacing.sm),
                      const Expanded(
                        child: ElioOnboardingProgressBar(value: 3 / 15),
                      ),
                    ],
                  ),
                ),
                // SCROLLABLE MIDDLE.
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      ElioSpacing.screenEdge,
                      ElioSpacing.lg,
                      ElioSpacing.screenEdge,
                      ElioSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ElioHeroHeading(
                          lines: ['Who are you', 'cooking for?'],
                          amberLastLine: true,
                        ),
                        const SizedBox(height: ElioSpacing.md),
                        Text(
                          // Goal-aware subhead: softer for users who picked
                          // "Feed the whole household" on screen 02.
                          // See docs/onboarding/03-household.md §Copy.
                          controller.state.userGoal == 'household'
                              ? "We'll make sure everyone's covered."
                              : "We'll size recipes and plan around your household.",
                          style: ElioTextStyles.body.copyWith(
                            color: ElioColors.mocha,
                          ),
                        ),
                        const SizedBox(height: ElioSpacing.lg),
                        for (int i = 0; i < _options.length; i++) ...[
                          if (i > 0)
                            const SizedBox(height: ElioSpacing.sm + 4),
                          ElioOnboardingOptionCard(
                            value: _options[i].value,
                            title: _options[i].label,
                            subtitle: _options[i].subtext,
                            selected: selectedType == _options[i].value,
                            onTap: _selectType,
                          ),
                        ],
                        if (selectedType != null) ...[
                          const SizedBox(height: ElioSpacing.lg),
                          Text(
                            'How many in total?',
                            style: ElioTextStyles.heading5,
                          ),
                          const SizedBox(height: ElioSpacing.sm),
                          Center(
                            child: ElioHouseholdStepper(
                              value: count,
                              onChanged: _onStepperChanged,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // PINNED BOTTOM.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ElioSpacing.screenEdge,
                    ElioSpacing.md,
                    ElioSpacing.screenEdge,
                    ElioSpacing.md,
                  ),
                  child: ElioBigButton(
                    label: 'Continue',
                    onTap: selectedType == null
                        ? null
                        : () {
                            AnalyticsService.instance.logEvent(
                              'onboarding_step_completed',
                              const {
                                'step_index': 3,
                                'step_name': 'household',
                              },
                            );
                            onContinue();
                          },
                    trailingIcon: Icons.arrow_forward,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
