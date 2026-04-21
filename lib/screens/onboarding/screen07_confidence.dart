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
// Screen 07 — Cooking confidence
//
// Single-select of easy / mixed / challenge.
// Subhead softens when the user picked "15 minutes or less" on screen 06.
//
// See docs/onboarding/07-confidence.md for authoritative copy spec.
// ─────────────────────────────────────────────

class _ConfidenceOption {
  final String value;
  final String label;
  final String subtext;
  final IconData icon;
  const _ConfidenceOption(this.value, this.label, this.subtext, this.icon);
}

// Copy verbatim from docs/onboarding/07-confidence.md §Copy.
const List<_ConfidenceOption> _options = [
  _ConfidenceOption('easy', 'Keep it simple',
      'One pan, few ingredients, nothing fiddly', Icons.egg_outlined),
  _ConfidenceOption('mixed', 'A bit of both',
      'Easy most nights, happy to branch out', Icons.outdoor_grill),
  _ConfidenceOption('challenge', 'Challenge me',
      'Teach me something new — I like learning', Icons.local_fire_department),
];

// Subhead copy — default and softened variant (see §Personalisation).
const String _defaultSubhead = 'Tells us how adventurous to get with techniques.';
const String _softenedSubhead = "We'll lean easy — no fiddly bits.";

class Screen07Confidence extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const Screen07Confidence({
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
              final selected = controller.state.cookingConfidence;
              final subhead = controller.state.maxCookTime == 15
                  ? _softenedSubhead
                  : _defaultSubhead;
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
                        child: ElioOnboardingProgressBar(value: 7 / 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: ElioSpacing.lg),
                  const ElioHeroHeading(
                    lines: ['How do you feel', 'about cooking?'],
                    amberLastLine: true,
                  ),
                  const SizedBox(height: ElioSpacing.md),
                  Text(
                    subhead,
                    style: ElioTextStyles.body.copyWith(
                      color: ElioColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: ElioSpacing.lg),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (int i = 0; i < _options.length; i++) ...[
                          ElioOnboardingOptionCard(
                            value: _options[i].value,
                            title: _options[i].label,
                            subtitle: _options[i].subtext,
                            icon: _options[i].icon,
                            selected: selected == _options[i].value,
                            onTap: controller.setCookingConfidence,
                          ),
                          if (i != _options.length - 1)
                            const SizedBox(height: ElioSpacing.sm + 4),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: ElioSpacing.md),
                  ElioBigButton(
                    label: 'Continue',
                    onTap: selected == null
                        ? null
                        : () {
                            AnalyticsService.instance.logEvent(
                              'onboarding_step_completed',
                              const {
                                'step_index': 7,
                                'step_name': 'confidence',
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
