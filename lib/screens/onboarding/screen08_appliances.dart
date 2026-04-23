import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../../services/analytics_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_appliance_tile.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../../widgets/elio/elio_onboarding_progress_bar.dart';

// ─────────────────────────────────────────────
// Screen 08 — Appliances
//
// Multi-select of 11 appliances in a 2-column grid. Oven / hob /
// microwave are pre-selected on first render (spec §Copy). Continue
// is always enabled — an empty array is a valid answer.
//
// See docs/onboarding/08-appliances.md for authoritative copy spec.
// ─────────────────────────────────────────────

class _Appliance {
  final String value;
  final String label;
  final IconData icon;
  const _Appliance(this.value, this.label, this.icon);
}

// Copy + order verbatim from docs/onboarding/08-appliances.md §Options.
const List<_Appliance> _appliances = [
  _Appliance('oven', 'Oven', Icons.microwave_outlined),
  _Appliance('hob', 'Hob / stove', Icons.local_fire_department_outlined),
  _Appliance('microwave', 'Microwave', Icons.settings_input_component),
  _Appliance('airfryer', 'Air fryer', Icons.air),
  _Appliance('slowcooker', 'Slow cooker', Icons.soup_kitchen),
  _Appliance('pressure', 'Pressure cooker / Instant Pot', Icons.compress),
  _Appliance('blender', 'Blender', Icons.blender),
  _Appliance('processor', 'Food processor', Icons.kitchen),
  _Appliance('mixer', 'Stand mixer', Icons.cyclone),
  _Appliance('ricecooker', 'Rice cooker', Icons.rice_bowl),
  _Appliance('bbq', 'BBQ / grill', Icons.outdoor_grill),
];

const List<String> _defaultSelected = ['oven', 'hob', 'microwave'];

class Screen08Appliances extends StatefulWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const Screen08Appliances({
    super.key,
    required this.controller,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<Screen08Appliances> createState() => _Screen08AppliancesState();
}

class _Screen08AppliancesState extends State<Screen08Appliances> {
  @override
  void initState() {
    super.initState();
    // Pre-select the three default appliances on first render if the user
    // hasn't made any selection yet (appliances list is still empty).
    if (widget.controller.state.appliances.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.controller.state.appliances.isEmpty) {
          widget.controller.setAppliances(List<String>.from(_defaultSelected));
        }
      });
    }
  }

  void _toggle(String value) {
    final current = List<String>.from(widget.controller.state.appliances);
    if (current.contains(value)) {
      current.remove(value);
    } else {
      current.add(value);
    }
    widget.controller.setAppliances(current);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final selected = widget.controller.state.appliances;
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
                        color: ElioColors.navy,
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(width: ElioSpacing.sm),
                      const Expanded(
                        child: ElioOnboardingProgressBar(value: 8 / 15),
                      ),
                    ],
                  ),
                ),
                // SCROLLABLE MIDDLE — heading/subhead + grid of appliance tiles.
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
                          lines: ["What's in", 'your kitchen?'],
                          amberLastLine: true,
                        ),
                        const SizedBox(height: ElioSpacing.md),
                        Text(
                          "Tick what you've got. We'll only suggest recipes that fit.",
                          style: ElioTextStyles.body.copyWith(
                            color: ElioColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: ElioSpacing.sm),
                        Text(
                          "We've ticked the usuals — untick if you don't have one.",
                          style: ElioTextStyles.bodySmall.copyWith(
                            color: ElioColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: ElioSpacing.lg),
                        GridView.count(
                          crossAxisCount: 3,
                          mainAxisSpacing: ElioSpacing.sm,
                          crossAxisSpacing: ElioSpacing.sm,
                          childAspectRatio: 0.9,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          children: [
                            for (final a in _appliances)
                              ElioApplianceTile(
                                value: a.value,
                                label: a.label,
                                icon: a.icon,
                                selected: selected.contains(a.value),
                                onTap: _toggle,
                              ),
                          ],
                        ),
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
                    onTap: () {
                      AnalyticsService.instance.logEvent(
                        'onboarding_step_completed',
                        const {
                          'step_index': 8,
                          'step_name': 'appliances',
                        },
                      );
                      widget.onContinue();
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
