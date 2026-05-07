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
import '../../widgets/elio/elio_segmented_toggle.dart';

// ─────────────────────────────────────────────
// Screen 09 — Region & units
//
// Single-select of uk|us|other plus a metric/imperial toggle.
// Region is pre-selected from device locale on first render.
// Units auto-flip on region change unless the user has manually
// overridden the toggle (tracked via controller.unitsManuallyEdited).
//
// See docs/onboarding/09-region.md for authoritative copy spec.
// ─────────────────────────────────────────────

class _RegionOption {
  final String value;
  final String label;
  final IconData icon;
  const _RegionOption(this.value, this.label, this.icon);
}

// Copy verbatim from docs/onboarding/09-region.md §Copy.
const List<_RegionOption> _regionOptions = [
  _RegionOption('uk', 'United Kingdom', Icons.flag_outlined),
  _RegionOption('us', 'United States', Icons.flag),
  _RegionOption('other', 'Elsewhere', Icons.public),
];

/// Default measurement-units for a given region.
String _defaultUnitsFor(String region) =>
    region == 'us' ? 'imperial' : 'metric';

/// Map a locale country code to the region value.
String regionFromCountryCode(String? code) {
  switch (code) {
    case 'GB':
      return 'uk';
    case 'US':
      return 'us';
    default:
      return 'other';
  }
}

class Screen09Region extends StatefulWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const Screen09Region({
    super.key,
    required this.controller,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<Screen09Region> createState() => _Screen09RegionState();
}

class _Screen09RegionState extends State<Screen09Region> {
  bool _didInitLocale = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitLocale) return;
    _didInitLocale = true;
    // Pre-select region from device locale; only on first render, and only
    // when the user hasn't already picked (region defaults to 'uk' so we
    // guard via a one-shot flag).
    final code = Localizations.localeOf(context).countryCode;
    final region = regionFromCountryCode(code);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.setRegion(region);
      if (!widget.controller.unitsManuallyEdited) {
        widget.controller.setMeasurementUnits(_defaultUnitsFor(region));
      }
    });
  }

  void _selectRegion(String region) {
    widget.controller.setRegion(region);
    // Units auto-flip unless the user has manually overridden.
    if (!widget.controller.unitsManuallyEdited) {
      widget.controller.setMeasurementUnits(_defaultUnitsFor(region));
    }
  }

  void _selectUnits(String units) {
    widget.controller.setMeasurementUnits(units);
    if (!widget.controller.unitsManuallyEdited) {
      widget.controller.setUnitsManuallyEdited(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final region = widget.controller.state.region;
            final units = widget.controller.state.measurementUnits;
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
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(width: ElioSpacing.sm),
                      const Expanded(
                        child: ElioOnboardingProgressBar(value: 9 / 15),
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
                        const ElioPageTitle('where are you cooking.'),
                        const SizedBox(height: ElioSpacing.md),
                        Text(
                          'So we get the names and measurements right.',
                          style: ElioTextStyles.body.copyWith(
                            color: ElioColors.mocha,
                          ),
                        ),
                        const SizedBox(height: ElioSpacing.lg),
                        for (int i = 0; i < _regionOptions.length; i++) ...[
                          if (i > 0)
                            const SizedBox(height: ElioSpacing.sm + 4),
                          ElioOnboardingOptionCard(
                            value: _regionOptions[i].value,
                            title: _regionOptions[i].label,
                            icon: _regionOptions[i].icon,
                            selected: region == _regionOptions[i].value,
                            onTap: _selectRegion,
                          ),
                        ],
                        const SizedBox(height: ElioSpacing.lg),
                        Text(
                          'Measurements',
                          style: ElioTextStyles.heading5,
                        ),
                        const SizedBox(height: ElioSpacing.sm),
                        ElioSegmentedToggle(
                          value: units,
                          optionA: (value: 'metric', label: 'Metric'),
                          optionB: (value: 'imperial', label: 'Imperial'),
                          onChanged: _selectUnits,
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
                          'step_index': 9,
                          'step_name': 'region',
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
