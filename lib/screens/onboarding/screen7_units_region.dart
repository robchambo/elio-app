import 'package:flutter/material.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';
import '../../utils/region_utils.dart';
import '../../widgets/elio_progress_bar.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';

// ─────────────────────────────────────────────
// Screen 7 — Units & Region
// Lightweight final onboarding step: pick measurement
// system (metric/imperial) and region (US/UK).
// Pre-selected based on device locale.
// ─────────────────────────────────────────────

class UnitsRegionScreen extends StatefulWidget {
  final OnboardingState state;
  final void Function(OnboardingState updated) onComplete;
  final VoidCallback onBack;

  const UnitsRegionScreen({
    super.key,
    required this.state,
    required this.onComplete,
    required this.onBack,
  });

  @override
  State<UnitsRegionScreen> createState() => _UnitsRegionScreenState();
}

class _UnitsRegionScreenState extends State<UnitsRegionScreen> {
  late String _measurementUnits;
  late String _region;

  @override
  void initState() {
    super.initState();
    // Default region from device locale
    final detectedRegion = RegionUtils.region;
    _region = widget.state.region.isNotEmpty
        ? widget.state.region
        : (detectedRegion == AppRegion.uk ? 'UK' : 'US');
    // Default units based on region
    _measurementUnits = widget.state.measurementUnits.isNotEmpty
        ? widget.state.measurementUnits
        : (_region == 'UK' ? 'metric' : 'imperial');
  }

  void _complete() {
    widget.onComplete(
      widget.state.copyWith(
        measurementUnits: _measurementUnits,
        region: _region,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress bar ──────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: ElioProgressBar(currentStep: 7, totalSteps: 8),
            ),

            // ── Back button ───────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  color: ElioColors.navy,
                  onPressed: widget.onBack,
                ),
              ),
            ),

            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ElioEyebrow('step 7 of 8'),
                  const SizedBox(height: 12),
                  const ElioHeroHeading(
                    lines: ['units &', 'region'],
                    amberLastLine: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "we'll use these for recipes and cost estimates.",
                    style: ElioTextStyles.body,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Content ───────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Measurement Units section
                    const ElioEyebrow('measurement units'),
                    const SizedBox(height: 12),
                    _SelectionCard(
                      label: 'Metric (g, ml, \u00B0C)',
                      isSelected: _measurementUnits == 'metric',
                      onTap: () => setState(() => _measurementUnits = 'metric'),
                    ),
                    const SizedBox(height: 10),
                    _SelectionCard(
                      label: 'Imperial (oz, cups, \u00B0F)',
                      isSelected: _measurementUnits == 'imperial',
                      onTap: () => setState(() => _measurementUnits = 'imperial'),
                    ),

                    const SizedBox(height: 28),

                    // Region section
                    const ElioEyebrow('region'),
                    const SizedBox(height: 12),
                    _SelectionCard(
                      emoji: '\u{1F1FA}\u{1F1F8}',
                      label: 'United States',
                      isSelected: _region == 'US',
                      onTap: () => setState(() {
                        _region = 'US';
                        // Auto-switch units when region changes
                        _measurementUnits = 'imperial';
                      }),
                    ),
                    const SizedBox(height: 10),
                    _SelectionCard(
                      emoji: '\u{1F1EC}\u{1F1E7}',
                      label: 'United Kingdom',
                      isSelected: _region == 'UK',
                      onTap: () => setState(() {
                        _region = 'UK';
                        _measurementUnits = 'metric';
                      }),
                    ),
                  ],
                ),
              ),
            ),

            // ── Continue button ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: ElioBigButton(
                label: 'Continue',
                trailingIcon: Icons.chevron_right,
                onTap: _complete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tappable selection card ─────────────────────────────────────────────────

class _SelectionCard extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.label,
    this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? ElioColors.amber.withValues(alpha: 0.14) : ElioColors.cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? ElioColors.amber : Colors.transparent,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  label,
                  style: ElioTextStyles.body.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: ElioColors.amber, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
