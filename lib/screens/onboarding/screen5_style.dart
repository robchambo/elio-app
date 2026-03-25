import 'package:flutter/material.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio_progress_bar.dart';

// ─────────────────────────────────────────────
// Screen 5 — Food Style Preferences (Optional)
// Design philosophy: approachable utility.
// Multi-select grid of cooking styles that pre-populate
// the Style chips on the home screen. Fully skippable.
// ─────────────────────────────────────────────

class StylePreferencesScreen extends StatefulWidget {
  final OnboardingState state;
  final void Function(OnboardingState updated) onComplete;
  final VoidCallback onBack;

  const StylePreferencesScreen({
    super.key,
    required this.state,
    required this.onComplete,
    required this.onBack,
  });

  @override
  State<StylePreferencesScreen> createState() => _StylePreferencesScreenState();
}

class _StylePreferencesScreenState extends State<StylePreferencesScreen> {
  late Set<String> _selected;

  static const List<_StyleOption> _options = [
    _StyleOption('Asian', '🍜'),
    _StyleOption('Mediterranean', '🫒'),
    _StyleOption('Indian', '🍛'),
    _StyleOption('Mexican', '🌮'),
    _StyleOption('Italian', '🍝'),
    _StyleOption('Middle Eastern', '🧆'),
    _StyleOption('Japanese', '🍱'),
    _StyleOption('Thai', '🌶️'),
    _StyleOption('American', '🍔'),
    _StyleOption('French', '🥐'),
    _StyleOption('Comfort food', '🥘'),
    _StyleOption('Light & healthy', '🥗'),
    _StyleOption('Quick & easy', '⚡'),
    _StyleOption('Vegetable-forward', '🥦'),
    _StyleOption('High protein', '💪'),
    _StyleOption('Budget-friendly', '💰'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.state.stylePreferences);
  }

  void _toggle(String style) {
    setState(() {
      if (_selected.contains(style)) {
        _selected.remove(style);
      } else {
        _selected.add(style);
      }
    });
  }

  void _complete() {
    widget.onComplete(
      widget.state.copyWith(stylePreferences: _selected.toList()),
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
              child: ElioProgressBar(currentStep: 5, totalSteps: 5),
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
                  Text('What do you like to cook?', style: ElioText.displayMedium),
                  const SizedBox(height: 8),
                  Text(
                    'We\'ll use this to personalise your recipe suggestions. You can change this any time.',
                    style: ElioText.bodyLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Optional — tap Skip if you\'re not sure yet.',
                    style: ElioText.bodyLarge.copyWith(
                      color: ElioColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Style grid ────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
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
                    return _StyleChip(
                      option: opt,
                      isSelected: isSelected,
                      onTap: () => _toggle(opt.label),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Actions ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _complete,
                      child: Text(
                        _selected.isEmpty ? 'Continue' : 'Save preferences',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _complete, // skip = complete with empty list
                    child: Text(
                      'Skip for now',
                      style: ElioText.bodyMedium.copyWith(
                        color: ElioColors.textSecondary,
                      ),
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

// ─── Style chip tile ─────────────────────────────────────────────────────────

class _StyleChip extends StatelessWidget {
  final _StyleOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyleChip({
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

class _StyleOption {
  final String label;
  final String emoji;
  const _StyleOption(this.label, this.emoji);
}
