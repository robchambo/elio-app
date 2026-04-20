import 'package:flutter/material.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';
import '../../widgets/elio_progress_bar.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';

// ─────────────────────────────────────────────
// Screen 6 — Kitchen Appliances (Optional)
// Design philosophy: approachable utility.
// Multi-select chip grid of appliances the user owns.
// Stored in Firestore and used to enhance recipe suggestions.
// Fully skippable.
// ─────────────────────────────────────────────

class KitchenAppliancesScreen extends StatefulWidget {
  final OnboardingState state;
  final void Function(OnboardingState updated) onComplete;
  final VoidCallback onBack;

  const KitchenAppliancesScreen({
    super.key,
    required this.state,
    required this.onComplete,
    required this.onBack,
  });

  @override
  State<KitchenAppliancesScreen> createState() => _KitchenAppliancesScreenState();
}

class _KitchenAppliancesScreenState extends State<KitchenAppliancesScreen> {
  late Set<String> _selected;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollHint = true;

  static const List<_ApplianceOption> _options = [
    _ApplianceOption('Air fryer', '🌬️'),
    _ApplianceOption('Slow cooker', '🍲'),
    _ApplianceOption('Rice cooker', '🍚'),
    _ApplianceOption('Instant Pot / Pressure cooker', '⚡'),
    _ApplianceOption('Stand mixer', '🎂'),
    _ApplianceOption('Food processor', '🔪'),
    _ApplianceOption('Blender', '🥤'),
    _ApplianceOption('Sous vide', '🌡️'),
    _ApplianceOption('Bread maker', '🍞'),
    _ApplianceOption('Waffle iron', '🧇'),
    _ApplianceOption('Spiralizer', '🥗'),
    _ApplianceOption('Grill / BBQ', '🔥'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.state.appliances);
    _scrollController.addListener(() {
      final atBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 40;
      if (atBottom && _showScrollHint) {
        setState(() => _showScrollHint = false);
      } else if (!atBottom && !_showScrollHint) {
        setState(() => _showScrollHint = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggle(String appliance) {
    setState(() {
      if (_selected.contains(appliance)) {
        _selected.remove(appliance);
      } else {
        _selected.add(appliance);
      }
    });
  }

  void _complete() {
    widget.onComplete(
      widget.state.copyWith(appliances: _selected.toList()),
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
              child: ElioProgressBar(currentStep: 6, totalSteps: 8),
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
                  const ElioEyebrow('step 6 of 8'),
                  const SizedBox(height: 12),
                  const ElioHeroHeading(
                    lines: ['which', 'appliances?'],
                    amberLastLine: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "we'll suggest recipes that make the most of your gear.",
                    style: ElioTextStyles.body,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "optional — tap skip if you're not sure yet.",
                    style: ElioTextStyles.bodySmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Appliances grid with scroll indicator ──────────────
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.builder(
                      controller: _scrollController,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.6,
                      ),
                      itemCount: _options.length,
                      itemBuilder: (context, i) {
                        final opt = _options[i];
                        final isSelected = _selected.contains(opt.label);
                        return _ApplianceChip(
                          option: opt,
                          isSelected: isSelected,
                          onTap: () => _toggle(opt.label),
                        );
                      },
                    ),
                  ),
                  // Fade gradient + scroll hint at bottom
                  AnimatedOpacity(
                    opacity: _showScrollHint ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: IgnorePointer(
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                ElioColors.offWhite.withValues(alpha: 0.0),
                                ElioColors.offWhite.withValues(alpha: 0.95),
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  color: ElioColors.textSecondary, size: 22),
                              const SizedBox(height: 6),
                              Text(
                                'Scroll for more',
                                style: ElioText.bodyMedium.copyWith(
                                  color: ElioColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Actions ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  ElioBigButton(
                    label: _selected.isEmpty ? 'Continue' : 'Save appliances',
                    trailingIcon: Icons.chevron_right,
                    onTap: _complete,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _complete, // skip = complete with empty list
                    child: Text(
                      'skip for now',
                      style: ElioTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Appliance chip tile ──────────────────────────────────────────────────────

class _ApplianceChip extends StatelessWidget {
  final _ApplianceOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _ApplianceChip({
    required this.option,
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
        decoration: BoxDecoration(
          color: isSelected ? ElioColors.amber.withValues(alpha: 0.12) : ElioColors.offWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ElioColors.amber : ElioColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(option.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.label,
                  style: ElioText.bodyMedium.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? ElioColors.navy : ElioColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: ElioColors.amber, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _ApplianceOption {
  final String label;
  final String emoji;
  const _ApplianceOption(this.label, this.emoji);
}
