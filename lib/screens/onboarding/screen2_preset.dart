import 'package:flutter/material.dart';
import '../../models/elio_models.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio_progress_bar.dart';

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
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Progress ──────────────────────────────────────
              const ElioProgressBar(currentStep: 2, totalSteps: 5),
              const SizedBox(height: 28),

              // ── Header ────────────────────────────────────────
              GestureDetector(
                onTap: widget.onBack,
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: ElioColors.navy),
                    const SizedBox(width: 4),
                    Text('Back', style: ElioText.bodyMedium.copyWith(color: ElioColors.navy)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('What\'s your kitchen like?', style: ElioText.displayMedium),
              const SizedBox(height: 8),
              Text(
                'This sets up your pantry. You can tweak it on the next screen.',
                style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
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

              // ── Next button ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _selected == null
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
                  child: const Text('Next →'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
