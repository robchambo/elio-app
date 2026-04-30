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
// Screen 04 — Dietary (Option B union-capture)
//
// Multi-select with silent mutual-exclusion. When householdCount > 1
// and the "does anyone eat differently?" toggle is flipped ON, a
// second multi-select captures the union of dietary needs across the
// whole household (seeded from the user's own selections).
//
// Exclusion rules (applied to both primary AND union lists):
//   - "No restrictions" vs any: mutually exclusive (tapping one clears
//     the other camp).
//   - Vegan vs Vegetarian: additive (vegan is a subset — keep both).
//   - Pescatarian vs Vegetarian/Vegan: replaces (remove the conflict,
//     add pescatarian).
//
// See docs/onboarding/04-dietary.md for authoritative spec.
// ─────────────────────────────────────────────

class _DietOption {
  final String value;
  final String label;
  const _DietOption(this.value, this.label);
}

const List<_DietOption> _options = [
  _DietOption('none', 'Happy with anything.'),
  _DietOption('vegetarian', 'Vegetarian'),
  _DietOption('vegan', 'Vegan'),
  _DietOption('pescatarian', 'Pescatarian'),
  _DietOption('halal', 'Halal'),
  _DietOption('kosher', 'Kosher'),
];

/// Apply the silent mutual-exclusion rules. Called when the user taps
/// a dietary card: takes the existing list + the tapped value, returns
/// the new list.
List<String> applyDietaryExclusion(List<String> current, String tapped) {
  final isSelected = current.contains(tapped);

  // Tapping an already-selected card toggles it off (no exclusion work).
  if (isSelected) {
    return current.where((v) => v != tapped).toList();
  }

  // Tapping "No restrictions" clears everything else.
  if (tapped == 'none') {
    return ['none'];
  }

  // Tapping any other option while "No restrictions" is selected clears it.
  final next = current.where((v) => v != 'none').toList();

  // Pescatarian is mutually exclusive with Vegetarian and Vegan.
  if (tapped == 'pescatarian') {
    next.removeWhere((v) => v == 'vegetarian' || v == 'vegan');
  }
  // Vegetarian is mutually exclusive with Pescatarian (vegan stays — subset).
  if (tapped == 'vegetarian') {
    next.removeWhere((v) => v == 'pescatarian');
  }
  // Vegan is mutually exclusive with Pescatarian (vegetarian stays — subset).
  if (tapped == 'vegan') {
    next.removeWhere((v) => v == 'pescatarian');
  }

  next.add(tapped);
  return next;
}

class Screen04Dietary extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const Screen04Dietary({
    super.key,
    required this.controller,
    required this.onContinue,
    required this.onBack,
  });

  void _tapPrimary(String value) {
    final next = applyDietaryExclusion(controller.state.dietary, value);
    controller.setDietary(next);
  }

  void _tapUnion(String value) {
    final next = applyDietaryExclusion(
        controller.state.householdCombinedDietary, value);
    controller.setHouseholdCombinedDietary(next);
  }

  void _toggleHousehold(bool v) {
    if (v) {
      // Seed the union with a copy of the user's own selections BEFORE
      // flipping the flag — setHouseholdDiffering preserves whatever's
      // currently in householdCombinedDietary when going true.
      controller.setHouseholdCombinedDietary(
          List<String>.from(controller.state.dietary));
      controller.setHouseholdDiffering(true);
    } else {
      // setHouseholdDiffering(false) also clears householdCombinedDietary.
      controller.setHouseholdDiffering(false);
    }
  }

  bool get _continueEnabled {
    final s = controller.state;
    if (s.householdCount > 1 && s.householdHasDifferingDiet) {
      return s.householdCombinedDietary.isNotEmpty;
    }
    // Spec allows Continue whenever not blocked by the union-empty case.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final s = controller.state;
            final showHouseholdToggle = s.householdCount > 1;
            final showUnion =
                showHouseholdToggle && s.householdHasDifferingDiet;

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
                        child: ElioOnboardingProgressBar(value: 4 / 15),
                      ),
                    ],
                  ),
                ),
                // SCROLLABLE MIDDLE — heading + subhead + options +
                // conditional household-union section all scroll together.
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
                          lines: ['Any dietary rules', 'we should follow?'],
                          amberLastLine: true,
                        ),
                        const SizedBox(height: ElioSpacing.md),
                        Text(
                          'Pick all that apply. Allergies come next.',
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
                            selected: s.dietary.contains(_options[i].value),
                            onTap: _tapPrimary,
                          ),
                        ],
                        if (showHouseholdToggle) ...[
                          const SizedBox(height: ElioSpacing.lg),
                          const Divider(
                              height: 1, color: ElioColors.rule),
                          const SizedBox(height: ElioSpacing.sm),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: s.householdHasDifferingDiet,
                            onChanged: _toggleHousehold,
                            activeTrackColor: ElioColors.terracotta,
                            title: Text(
                              'Does anyone else in your household eat differently?',
                              style: ElioTextStyles.body,
                            ),
                          ),
                        ],
                        if (showUnion) ...[
                          const SizedBox(height: ElioSpacing.md),
                          Text(
                            "Cover everyone's needs",
                            style: ElioTextStyles.heading5,
                          ),
                          const SizedBox(height: ElioSpacing.xs),
                          Text(
                            "Pick everything that applies to anyone — including you. We'll make sure no one gets left out.",
                            style: ElioTextStyles.bodySmall.copyWith(
                              color: ElioColors.mocha,
                            ),
                          ),
                          const SizedBox(height: ElioSpacing.md),
                          for (int i = 0; i < _options.length; i++) ...[
                            if (i > 0)
                              const SizedBox(height: ElioSpacing.sm + 4),
                            ElioOnboardingOptionCard(
                              value: _options[i].value,
                              title: _options[i].label,
                              selected: s.householdCombinedDietary
                                  .contains(_options[i].value),
                              onTap: _tapUnion,
                            ),
                          ],
                          if (s.householdCombinedDietary.isEmpty) ...[
                            const SizedBox(height: ElioSpacing.sm),
                            Text(
                              "Pick at least one — or turn the toggle off if everyone's the same.",
                              style: ElioTextStyles.bodySmall.copyWith(
                                color: ElioColors.mocha,
                              ),
                            ),
                          ],
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
                    onTap: _continueEnabled
                        ? () {
                            AnalyticsService.instance.logEvent(
                              'onboarding_step_completed',
                              const {
                                'step_index': 4,
                                'step_name': 'dietary',
                              },
                            );
                            onContinue();
                          }
                        : null,
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
