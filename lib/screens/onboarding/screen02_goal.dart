import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../../services/analytics_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../../widgets/elio/elio_onboarding_option_card.dart';
import '../../widgets/elio/elio_onboarding_progress_bar.dart';

// ─────────────────────────────────────────────
// Screen 02 — Goal
//
// Single-select. Captures the user's primary benefit priority into
// controller.state.userGoal — downstream screens (10, 13, 14) use
// this as a copy hook only (not a prompt input).
//
// See docs/onboarding/02-goal.md for the authoritative copy spec.
//
// Back button fires [onBack] (coordinator pops to screen 01 and
// preserves selection per spec). Continue is disabled until a goal
// is picked; once picked, firing [onContinue] advances to screen 03.
// ─────────────────────────────────────────────

class _GoalOption {
  final String value;
  final String label;
  final String subtext;
  const _GoalOption(this.value, this.label, this.subtext);
}

// Copy verbatim from docs/onboarding/02-goal.md §Copy.
const List<_GoalOption> _goalOptions = [
  _GoalOption(
    'pantryFirst',
    "Cook with what I've got",
    'Stop staring at the fridge',
  ),
  _GoalOption(
    'wasteReduction',
    'Waste less food',
    'Use it before it goes off',
  ),
  _GoalOption(
    'decisionFatigue',
    'Decide dinner faster',
    'Skip the scroll, skip the debate',
  ),
  _GoalOption(
    'household',
    'Feed the whole household',
    'Fussy eaters and all',
  ),
  _GoalOption(
    'takeawayEscape',
    'Stop ordering takeaway',
    'Eat better, spend less',
  ),
];

class Screen02Goal extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const Screen02Goal({
    super.key,
    required this.controller,
    required this.onContinue,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ElioSpacing.screenEdge),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final selectedGoal = controller.state.userGoal;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      BackButton(
                        color: ElioColors.navy,
                        onPressed: onBack,
                      ),
                      const SizedBox(width: ElioSpacing.sm),
                      const Expanded(
                        child: ElioOnboardingProgressBar(value: 2 / 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: ElioSpacing.lg),
                  const ElioHeroHeading(
                    lines: ['What brought', 'you to Elio?'],
                    amberLastLine: true,
                  ),
                  const SizedBox(height: ElioSpacing.md),
                  Text(
                    "Pick what matters most — we'll tailor things to suit.",
                    style: ElioTextStyles.body.copyWith(
                      color: ElioColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: ElioSpacing.lg),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _goalOptions.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: ElioSpacing.sm + 4),
                      itemBuilder: (_, i) {
                        final o = _goalOptions[i];
                        return ElioOnboardingOptionCard(
                          value: o.value,
                          title: o.label,
                          subtitle: o.subtext,
                          selected: selectedGoal == o.value,
                          onTap: controller.setUserGoal,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: ElioSpacing.md),
                  ElioBigButton(
                    label: 'Continue',
                    onTap: selectedGoal == null
                        ? null
                        : () {
                            AnalyticsService.instance.logEvent(
                              'onboarding_step_completed',
                              const {'step_index': 2, 'step_name': 'goal'},
                            );
                            onContinue();
                          },
                    trailingIcon: Icons.arrow_forward,
                  ),
                  const SizedBox(height: ElioSpacing.sm),
                  Center(
                    child: Text(
                      'You can change this later in Settings.',
                      style: ElioTextStyles.bodySmall.copyWith(
                        color: ElioColors.textMuted,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
