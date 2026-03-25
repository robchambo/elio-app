import 'package:flutter/material.dart';
import '../../models/elio_models.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio_progress_bar.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// DietaryScreen (Screen 1)
// Design: approachable utility.
// User selects dietary requirements for themselves.
// Step 1 of 5 in onboarding.
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

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.state.dietaryRequirements);
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
              Text('Any dietary needs?', style: ElioText.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Elio will never suggest something that doesn\'t work for you. Select all that apply.',
                style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
              ),
              const SizedBox(height: 24),

              // ── Dietary chips ─────────────────────────────────
              Expanded(
                child: Wrap(
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
                          style: GoogleFonts.outfit(fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : ElioColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Skip note ─────────────────────────────────────
              if (_selected.isEmpty)
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
