import 'package:flutter/material.dart';
import '../../models/elio_models.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';
import '../../widgets/elio_progress_bar.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_chip.dart';
import '../../widgets/elio/elio_custom_field.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';

// ─────────────────────────────────────────────
// DietaryScreen (Screen 1)
// Renamed to "Dietary requirements & Allergens"
// Supports standard DietaryRequirement enum chips
// plus a free-text custom allergen input.
// ─────────────────────────────────────────────

class DietaryScreen extends StatefulWidget {
  final OnboardingState state;
  final void Function(OnboardingState) onNext;

  const DietaryScreen({super.key, required this.state, required this.onNext});

  @override
  State<DietaryScreen> createState() => _DietaryScreenState();
}

class _DietaryScreenState extends State<DietaryScreen> {
  late Set<DietaryRequirement> _selected;
  late List<String> _customAllergens;
  final TextEditingController _customController = TextEditingController();
  final FocusNode _customFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.state.dietaryRequirements);
    _customAllergens = List.from(widget.state.customAllergens);
  }

  @override
  void dispose() {
    _customController.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  void _toggle(DietaryRequirement req) {
    setState(() {
      if (_selected.contains(req)) {
        _selected.remove(req);
      } else {
        _selected.add(req);
      }
    });
  }

  void _addCustomAllergen() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    if (_customAllergens.contains(text)) {
      _customController.clear();
      return;
    }
    setState(() {
      _customAllergens.add(text);
      _customController.clear();
    });
    _customFocus.requestFocus();
  }

  void _removeCustomAllergen(String allergen) {
    setState(() => _customAllergens.remove(allergen));
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
              const ElioProgressBar(currentStep: 1, totalSteps: 8),
              const SizedBox(height: 28),

              // ── Header ────────────────────────────────────────
              const ElioEyebrow('step 1 of 8'),
              const SizedBox(height: 12),
              const ElioHeroHeading(
                lines: ["what's your", 'diet?'],
                amberLastLine: true,
              ),
              const SizedBox(height: 16),
              Text(
                "elio will never suggest something that doesn't work for you. pick all that apply.",
                style: ElioTextStyles.body,
              ),
              const SizedBox(height: 24),

              // ── Dietary chips + custom allergens ──────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Standard dietary chips
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: DietaryRequirement.values.map((req) {
                          final isSelected = _selected.contains(req);
                          return ElioChip(
                            label: req.label,
                            selected: isSelected,
                            onTap: () => _toggle(req),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 28),

                      // Custom allergen section
                      const ElioEyebrow('custom allergens'),
                      const SizedBox(height: 10),
                      Text(
                        'add anything not covered above — e.g. sesame, shellfish, no red meat.',
                        style: ElioTextStyles.bodySmall,
                      ),
                      const SizedBox(height: 14),

                      // Custom allergen chips
                      if (_customAllergens.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _customAllergens.map((allergen) {
                            return GestureDetector(
                              onTap: () => _removeCustomAllergen(allergen),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: ElioColors.amber,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      allergen,
                                      style: ElioTextStyles.body.copyWith(color: Colors.white),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Custom allergen text input
                      Row(
                        children: [
                          Expanded(
                            child: ElioCustomField(
                              placeholder: 'add custom allergy...',
                              controller: _customController,
                              onSubmitted: (_) => _addCustomAllergen(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _addCustomAllergen,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: ElioColors.navy,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Skip note ─────────────────────────────────────
              if (_selected.isEmpty && _customAllergens.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    "no restrictions? that's fine — just tap continue.",
                    style: ElioTextStyles.bodySmall,
                  ),
                ),

              // ── Continue button ───────────────────────────────
              ElioBigButton(
                label: 'Continue',
                trailingIcon: Icons.chevron_right,
                onTap: () {
                  widget.onNext(widget.state.copyWith(
                    dietaryRequirements: _selected.toList(),
                    customAllergens: _customAllergens,
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
