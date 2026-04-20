import 'package:flutter/material.dart';
import '../../models/elio_models.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';
import '../../widgets/elio_progress_bar.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';

// ─────────────────────────────────────────────
// KitchenPresetScreen (Screen 2)
// Design: approachable utility.
// User selects a kitchen preset that pre-populates
// their pantry inventory.
// Step 2 of 5 in onboarding.
// ─────────────────────────────────────────────

class KitchenPresetScreen extends StatefulWidget {
  final OnboardingState state;
  final void Function(OnboardingState) onNext;
  final VoidCallback onBack;

  const KitchenPresetScreen({
    super.key,
    required this.state,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<KitchenPresetScreen> createState() => _KitchenPresetScreenState();
}

class _KitchenPresetScreenState extends State<KitchenPresetScreen> {
  KitchenPreset? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.state.kitchenPreset;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Progress ──────────────────────────────────────
              const ElioProgressBar(currentStep: 2, totalSteps: 8),
              const SizedBox(height: 20),

              // ── Header ────────────────────────────────────────
              GestureDetector(
                onTap: widget.onBack,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: ElioColors.navy),
                ),
              ),
              const SizedBox(height: 8),
              const ElioEyebrow('step 2 of 8'),
              const SizedBox(height: 12),
              const ElioHeroHeading(
                lines: ["what's your", 'kitchen like?'],
                amberLastLine: true,
              ),
              const SizedBox(height: 16),
              Text(
                'this sets up your pantry. you can tweak it on the next screen.',
                style: ElioTextStyles.body,
              ),
              const SizedBox(height: 24),

              // ── Preset cards ──────────────────────────────────
              Expanded(
                child: ListView(
                  children: KitchenPreset.values.map((preset) {
                    final isSelected = _selected == preset;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = preset),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isSelected ? ElioColors.navy.withValues(alpha: 0.04) : ElioColors.offWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? ElioColors.navy : ElioColors.border,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(preset.label, style: ElioText.headingMedium),
                                  const SizedBox(height: 4),
                                  Text(
                                    preset.description,
                                    style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${preset.alwaysHave.length + preset.almostAlwaysHave.length} pantry items',
                                    style: ElioText.label.copyWith(color: ElioColors.amber),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected ? ElioColors.navy : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? ElioColors.navy : ElioColors.border,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Continue button ───────────────────────────────
              ElioBigButton(
                label: 'Continue',
                trailingIcon: Icons.chevron_right,
                onTap: _selected == null
                    ? null
                    : () {
                        final preset = _selected!;
                        final inventory = [
                          ...preset.alwaysHave.map((name) => InventoryItem(name: name, tier: 'alwaysHave')),
                          ...preset.almostAlwaysHave.map((name) => InventoryItem(name: name, tier: 'almostAlwaysHave')),
                        ];
                        widget.onNext(widget.state.copyWith(
                          kitchenPreset: preset,
                          inventory: inventory,
                        ));
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
