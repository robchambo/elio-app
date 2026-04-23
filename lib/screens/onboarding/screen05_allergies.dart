import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../../services/analytics_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_chip.dart';
import '../../widgets/elio/elio_chip_text_input.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../../widgets/elio/elio_onboarding_progress_bar.dart';

// ─────────────────────────────────────────────
// Screen 05 — Allergies & dislikes
//
// Section 1: 9 preset allergen chips + "Other" (reveals a chip text
// input on tap). All selections — preset or typed — are stored in the
// single controller.state.allergies array (Q3 decision: no separate
// customAllergens field).
//
// Section 2: free-text chip input writing to controller.state.dislikes.
//
// Skip link at the bottom persists [] to both and advances.
//
// See docs/onboarding/05-allergies.md for authoritative spec.
// ─────────────────────────────────────────────

class _PresetAllergen {
  final String value;
  final String label;
  const _PresetAllergen(this.value, this.label);
}

const List<_PresetAllergen> _presets = [
  _PresetAllergen('peanut', 'Peanuts'),
  _PresetAllergen('treenut', 'Tree nuts'),
  _PresetAllergen('dairy', 'Milk / dairy'),
  _PresetAllergen('egg', 'Eggs'),
  _PresetAllergen('fish', 'Fish'),
  _PresetAllergen('shellfish', 'Shellfish'),
  _PresetAllergen('soy', 'Soy'),
  _PresetAllergen('gluten', 'Wheat / gluten'),
  _PresetAllergen('sesame', 'Sesame'),
];

const Set<String> _presetValues = {
  'peanut',
  'treenut',
  'dairy',
  'egg',
  'fish',
  'shellfish',
  'soy',
  'gluten',
  'sesame',
};

class Screen05Allergies extends StatefulWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const Screen05Allergies({
    super.key,
    required this.controller,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<Screen05Allergies> createState() => _Screen05AllergiesState();
}

class _Screen05AllergiesState extends State<Screen05Allergies> {
  bool _otherExpanded = false;

  void _togglePreset(String value) {
    final current = widget.controller.state.allergies;
    if (current.contains(value)) {
      widget.controller
          .setAllergies(current.where((v) => v != value).toList());
    } else {
      widget.controller.setAllergies([...current, value]);
    }
  }

  /// Returns only the non-preset (custom) allergy entries, used as the
  /// chip-input's values so preset taps and typed entries don't fight.
  List<String> _customAllergies() => widget.controller.state.allergies
      .where((v) => !_presetValues.contains(v))
      .toList();

  void _onCustomAllergiesChanged(List<String> next) {
    // Preserve the preset selections and replace just the custom set.
    final presets = widget.controller.state.allergies
        .where(_presetValues.contains)
        .toList();
    widget.controller.setAllergies([...presets, ...next]);
  }

  void _onDislikesChanged(List<String> next) {
    widget.controller.setDislikes(next);
  }

  void _skip() {
    widget.controller.setAllergies(<String>[]);
    widget.controller.setDislikes(<String>[]);
    _logStep();
    widget.onContinue();
  }

  void _logStep() {
    AnalyticsService.instance.logEvent(
      'onboarding_step_completed',
      const {'step_index': 5, 'step_name': 'allergies'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final s = widget.controller.state;
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
                        child: ElioOnboardingProgressBar(value: 5 / 15),
                      ),
                    ],
                  ),
                ),
                // SCROLLABLE MIDDLE.
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
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
                          lines: ['And anything', 'to avoid?'],
                          amberLastLine: true,
                        ),
                        const SizedBox(height: ElioSpacing.md),
                        Text(
                          "Allergies first, then anything you just don't fancy.",
                          style: ElioTextStyles.body.copyWith(
                            color: ElioColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: ElioSpacing.lg),
                        Text('Any allergies?',
                            style: ElioTextStyles.heading5),
                        const SizedBox(height: ElioSpacing.sm),
                        Wrap(
                          spacing: ElioSpacing.sm,
                          runSpacing: ElioSpacing.sm,
                          children: [
                            for (final p in _presets)
                              ElioChip(
                                label: p.label,
                                selected: s.allergies.contains(p.value),
                                onTap: () => _togglePreset(p.value),
                              ),
                            ElioChip(
                              label: '+ Other',
                              selected: _otherExpanded,
                              onTap: () => setState(
                                  () => _otherExpanded = !_otherExpanded),
                            ),
                          ],
                        ),
                        if (_otherExpanded) ...[
                          const SizedBox(height: ElioSpacing.md),
                          ElioChipTextInput(
                            values: _customAllergies(),
                            onChanged: _onCustomAllergiesChanged,
                            hintText:
                                'Add custom allergy and press enter',
                          ),
                        ],
                        const SizedBox(height: ElioSpacing.lg),
                        const Divider(height: 1, color: ElioColors.border),
                        const SizedBox(height: ElioSpacing.lg),
                        Text("Anything you just don't fancy?",
                            style: ElioTextStyles.heading5),
                        const SizedBox(height: ElioSpacing.sm),
                        ElioChipTextInput(
                          values: s.dislikes,
                          onChanged: _onDislikesChanged,
                          hintText: 'Start typing… e.g. mushrooms, olives',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElioBigButton(
                        label: 'Continue',
                        onTap: () {
                          _logStep();
                          widget.onContinue();
                        },
                        trailingIcon: Icons.arrow_forward,
                      ),
                      const SizedBox(height: ElioSpacing.sm),
                      Center(
                        child: TextButton(
                          onPressed: _skip,
                          child: Text(
                            'Skip — no allergies or dislikes',
                            style: ElioTextStyles.bodySmall.copyWith(
                              color: ElioColors.textMuted,
                            ),
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
