import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../../services/analytics_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_page_title.dart';
import '../../widgets/elio/elio_onboarding_option_card.dart';
import '../../widgets/elio/elio_onboarding_progress_bar.dart';

// ─────────────────────────────────────────────
// Screen 06 — Time on weeknights
//
// Single-select of 4 max-cook-time buckets (15/30/45/75 minutes).
// Feeds the Gemini prompt's time budget so recipes stay inside it.
//
// See docs/onboarding/06-time.md for authoritative copy spec.
// ─────────────────────────────────────────────

class _TimeOption {
  final int minutes;
  final String label;
  final String subtext;
  final IconData icon;
  const _TimeOption(this.minutes, this.label, this.subtext, this.icon);
}

// Copy verbatim from docs/onboarding/06-time.md §Copy.
const List<_TimeOption> _options = [
  _TimeOption(
      15, '15 minutes or less', 'Quick fixes, one pan, done', Icons.bolt),
  _TimeOption(
      30, 'About 30 minutes', 'The weeknight sweet spot', Icons.timer_outlined),
  _TimeOption(
      45, 'Up to 45 minutes', 'Room for something proper', Icons.restaurant),
  _TimeOption(
      75, 'An hour or more', 'I enjoy the cooking bit', Icons.soup_kitchen),
];

class Screen06Time extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const Screen06Time({
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
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final selected = controller.state.maxCookTime;
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
                        child: ElioOnboardingProgressBar(value: 6 / 15),
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
                        const ElioPageTitle('how long have you got on a weeknight.'),
                        const SizedBox(height: ElioSpacing.md),
                        Text(
                          "We'll match recipes to you.",
                          style: ElioTextStyles.body.copyWith(
                            color: ElioColors.mocha,
                          ),
                        ),
                        const SizedBox(height: ElioSpacing.lg),
                        for (int i = 0; i < _options.length; i++) ...[
                          if (i > 0)
                            const SizedBox(height: ElioSpacing.sm + 4),
                          ElioOnboardingOptionCard(
                            value: '${_options[i].minutes}',
                            title: _options[i].label,
                            subtitle: _options[i].subtext,
                            icon: _options[i].icon,
                            selected: selected == _options[i].minutes,
                            onTap: (_) => controller
                                .setMaxCookTime(_options[i].minutes),
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
                    onTap: selected == null
                        ? null
                        : () {
                            AnalyticsService.instance.logEvent(
                              'onboarding_step_completed',
                              const {
                                'step_index': 6,
                                'step_name': 'time',
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
