import 'package:flutter/material.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../utils/region_utils.dart';
import '../../widgets/elio_progress_bar.dart';

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
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress bar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: ElioProgressBar(currentStep: 7, totalSteps: 7),
            ),

            // ── Back button ───────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  color: ElioColors.navy,
                  onPressed: widget.onBack,
                ),
              ),
            ),

            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Units & Region', style: ElioText.displayMedium),
                  const SizedBox(height: 8),
                  Text(
                    "We'll use these for recipes and cost estimates",
                    style: ElioText.bodyLarge,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Content ───────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Measurement Units section
                    Text('Measurement Units', style: ElioText.headingMedium),
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
                    Text('Region', style: ElioText.headingMedium),
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
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _complete,
                  child: const Text('Continue'),
                ),
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
          color: isSelected ? ElioColors.amber.withValues(alpha: 0.12) : ElioColors.offWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? ElioColors.amber : ElioColors.border,
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
                  style: ElioText.bodyLarge.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? ElioColors.navy : ElioColors.textPrimary,
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
