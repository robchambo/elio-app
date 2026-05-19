import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../../services/analytics_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../../widgets/elio/elio_onboarding_progress_bar.dart';

// ─────────────────────────────────────────────
// Screen 10 — Pantry intro (hook / interstitial)
//
// A breather between the question sequence (02–09) and the pantry
// build (11–12). No selection, no validation — just a goal-aware
// subhead that sets expectations for the pantry screens to come.
//
// Copy (headline, subhead variants, CTA) mirrored verbatim from
// docs/onboarding/10-pantry-intro.md §Copy & §Personalisation.
// ─────────────────────────────────────────────

const String _defaultSubhead =
    "This is the bit that makes Elio different — every recipe starts from what you've got. Takes about a minute, in two quick steps.";

String _subheadFor(String? goal) {
  switch (goal) {
    case 'wasteReduction':
      return "Let's see what's in your kitchen — especially anything that needs using soon. Takes about a minute, in two quick steps.";
    case 'decisionFatigue':
      return 'Quick tour of your kitchen — then dinner gets a lot faster. Takes about a minute, in two quick steps.';
    case 'household':
      return "Let's stock the kitchen for everyone. Takes about a minute, in two quick steps.";
    case 'takeawayEscape':
      return "Let's see what's in — so you've always got an answer to \"what's for dinner?\". Takes about a minute, in two quick steps.";
    case 'pantryFirst':
    default:
      return _defaultSubhead;
  }
}

class Screen10PantryIntro extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const Screen10PantryIntro({
    super.key,
    required this.controller,
    required this.onContinue,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ElioSpacing.screenEdge),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final subhead = _subheadFor(controller.state.userGoal);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      BackButton(
                        color: ElioColors.espresso,
                        onPressed: onBack,
                      ),
                      const SizedBox(width: ElioSpacing.sm),
                      const Expanded(
                        child: ElioOnboardingProgressBar(value: 10 / 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: ElioSpacing.lg),
                  const ElioHeroHeading(
                    lines: ["Now, what's already", 'in your kitchen?'],
                    amberLastLine: true,
                  ),
                  const SizedBox(height: ElioSpacing.md),
                  Text(
                    subhead,
                    style: ElioTextStyles.body.copyWith(
                      color: ElioColors.mocha,
                    ),
                  ),
                  const SizedBox(height: ElioSpacing.xl),
                  // Hero illustration — Kate-supplied 19 May 2026. Replaces
                  // the 🧊 placeholder. JPG (no transparency needed; the
                  // illustration ships with its own cream backdrop that
                  // sits cleanly on the screen's cream surface). 24 px
                  // ClipRRect mirrors the placeholder's rounded corners.
                  Expanded(
                    child: Center(
                      child: Semantics(
                        label:
                            'Illustrated pantry shelf — jars of grains, baskets of potatoes and onions, bottles of oil and vinegar',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/onboarding/pantry_intro_hero.jpg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ElioSpacing.md),
                  ElioBigButton(
                    label: "Let's have a look",
                    onTap: () {
                      AnalyticsService.instance.logEvent(
                        'onboarding_step_completed',
                        const {
                          'step_index': 10,
                          'step_name': 'pantry_intro',
                        },
                      );
                      onContinue();
                    },
                    trailingIcon: Icons.arrow_forward,
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
