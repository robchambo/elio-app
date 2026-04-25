import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../../services/analytics_service.dart';
import '../../utils/region_utils.dart';
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

// Copy from docs/onboarding/02-goal.md §Copy.
//
// The takeawayEscape label is region-aware: US users see "takeout",
// UK users see "takeaway". Screen 02 runs before screen 09 (explicit
// region choice), so we branch on RegionUtils.region — which falls back
// to the device locale when the user hasn't overridden yet.
List<_GoalOption> _buildGoalOptions() {
  final takeawayLabel = RegionUtils.isUS
      ? 'Stop ordering takeout'
      : 'Stop ordering takeaway';
  return [
    const _GoalOption(
      'pantryFirst',
      "Cook with what I've got",
      'Stop staring at the fridge',
    ),
    const _GoalOption(
      'wasteReduction',
      'Waste less food',
      'Use it before it goes off',
    ),
    const _GoalOption(
      'decisionFatigue',
      'Decide dinner faster',
      'Skip the scroll, skip the debate',
    ),
    const _GoalOption(
      'household',
      'Feed the whole household',
      'Fussy eaters and all',
    ),
    _GoalOption(
      'takeawayEscape',
      takeawayLabel,
      'Eat better, spend less',
    ),
  ];
}

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
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final selectedGoal = controller.state.userGoal;
            final goalOptions = _buildGoalOptions();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // PINNED TOP — back + progress only.
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
                        color: ElioColors.navy,
                        onPressed: onBack,
                      ),
                      const SizedBox(width: ElioSpacing.sm),
                      const Expanded(
                        child: ElioOnboardingProgressBar(value: 2 / 15),
                      ),
                    ],
                  ),
                ),
                // SCROLLABLE MIDDLE — heading + subhead + option cards.
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
                          lines: ['What brought', 'you to Elio?'],
                          amberLastLine: true,
                        ),
                        const SizedBox(height: ElioSpacing.md),
                        Text(
                          "Pick what matters most — we'll tailor things to suit. Don't worry, you can change anytime.",
                          style: ElioTextStyles.body.copyWith(
                            color: ElioColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: ElioSpacing.lg),
                        for (int i = 0; i < goalOptions.length; i++) ...[
                          if (i > 0)
                            const SizedBox(height: ElioSpacing.sm + 4),
                          ElioOnboardingOptionCard(
                            value: goalOptions[i].value,
                            title: goalOptions[i].label,
                            subtitle: goalOptions[i].subtext,
                            selected: selectedGoal == goalOptions[i].value,
                            onTap: controller.setUserGoal,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // PINNED BOTTOM — Continue + caption.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ElioSpacing.screenEdge,
                    ElioSpacing.md,
                    ElioSpacing.screenEdge,
                    ElioSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElioBigButton(
                        label: 'Continue',
                        onTap: selectedGoal == null
                            ? null
                            : () {
                                AnalyticsService.instance.logEvent(
                                  'onboarding_step_completed',
                                  const {
                                    'step_index': 2,
                                    'step_name': 'goal',
                                  },
                                );
                                onContinue();
                              },
                        trailingIcon: Icons.arrow_forward,
                      ),
                      const SizedBox(height: ElioSpacing.sm),
                      Center(
                        child: Text(
                          'You can change this later.',
                          style: ElioTextStyles.bodySmall.copyWith(
                            color: ElioColors.textMuted,
                          ),
                        ),
                      ),
                    ],
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
