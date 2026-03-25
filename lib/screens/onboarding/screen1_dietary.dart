import 'package:flutter/material.dart';
import '../../models/elio_models.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio_progress_bar.dart';
import 'package:google_fonts/google_fonts.dart';

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
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Progress ──────────────────────────────────────
              const ElioProgressBar(currentStep: 1, totalSteps: 5),
              const SizedBox(height: 28),

              // ── Header ────────────────────────────────────────
              Text('Dietary requirements\n& Allergens', style: ElioText.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Elio will never suggest something that doesn\'t work for you. Select all that apply.',
                style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
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
                          return GestureDetector(
                            onTap: () => _toggle(req),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? ElioColors.navy : ElioColors.offWhite,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isSelected ? ElioColors.navy : ElioColors.border,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Text(
                                req.label,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : ElioColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // Custom allergen section
                      Text(
                        'Other allergies or intolerances',
                        style: ElioText.headingMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add anything not listed above — e.g. sesame, shellfish, mustard.',
                        style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                      ),
                      const SizedBox(height: 12),

                      // Custom allergen chips
                      if (_customAllergens.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _customAllergens.map((allergen) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: ElioColors.amber.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    allergen,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: ElioColors.navy,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _removeCustomAllergen(allergen),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: ElioColors.textSecondary,
                                    ),
                                  ),
                                ],
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
                            child: TextField(
                              controller: _customController,
                              focusNode: _customFocus,
                              textCapitalization: TextCapitalization.sentences,
                              style: ElioText.bodyMedium,
                              decoration: InputDecoration(
                                hintText: 'Add custom allergy...',
                                hintStyle: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
                                filled: true,
                                fillColor: ElioColors.offWhite,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: ElioColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: ElioColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: ElioColors.navy, width: 1.5),
                                ),
                              ),
                              onSubmitted: (_) => _addCustomAllergen(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _addCustomAllergen,
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: ElioColors.navy,
                                borderRadius: BorderRadius.circular(12),
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
                    'No restrictions? That\'s fine — just tap Next.',
                    style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
                  ),
                ),

              // ── Next button ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onNext(widget.state.copyWith(
                      dietaryRequirements: _selected.toList(),
                      customAllergens: _customAllergens,
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
