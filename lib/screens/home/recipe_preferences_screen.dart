// lib/screens/home/recipe_preferences_screen.dart
//
// Sprint 16 Phase 6 — Recipe Preferences screen sits between Home's Generate
// CTA and the Recipe Screen. User picks Mood / Style / Time (chips) and taps
// "Generate", which pops the screen with a [RecipePreferences] result. The
// screen itself does NOT call GeminiService — Home receives the prefs and
// runs its existing generation flow.
import 'package:flutter/material.dart';
import '../../models/recipe_preferences.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_spacing.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_chip.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';

class RecipePreferencesScreen extends StatefulWidget {
  const RecipePreferencesScreen({super.key});

  @override
  State<RecipePreferencesScreen> createState() =>
      _RecipePreferencesScreenState();
}

class _RecipePreferencesScreenState extends State<RecipePreferencesScreen> {
  static const _timeOptions = <String>[
    'Quick (< 15 min)',
    'Standard (< 30 min)',
    'Slow (< 60 min)',
    'Any',
  ];
  static const _styleOptions = <String>[
    'Comfort',
    'Healthy',
    'Light',
    'Hearty',
    'Spicy',
    'Fresh',
    'Any',
  ];
  static const _moodOptions = <String>[
    'Easy',
    'Impressive',
    'Kid-friendly',
    'Date night',
    'Meal prep',
    'Any',
  ];

  String _time = 'Any';
  String _style = 'Any';
  String _mood = 'Any';

  void _generate() {
    final prefs = RecipePreferences(
      time: _time == 'Any' ? null : _time,
      style: _style == 'Any' ? null : _style,
      mood: _mood == 'Any' ? null : _mood,
    );
    Navigator.of(context).pop(prefs);
  }

  Widget _section({
    required String eyebrow,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElioEyebrow(eyebrow),
        const SizedBox(height: ElioSpacing.md),
        Wrap(
          spacing: ElioSpacing.sm,
          runSpacing: ElioSpacing.sm,
          children: [
            for (final opt in options)
              ElioChip(
                label: opt,
                selected: selected == opt,
                onTap: () => onSelect(opt),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ElioColors.navy),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ElioSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ElioHeroHeading(
              lines: ['set the', 'mood'],
              amberLastLine: true,
              showUnderline: true,
            ),
            const SizedBox(height: ElioSpacing.xl),
            _section(
              eyebrow: 'time',
              options: _timeOptions,
              selected: _time,
              onSelect: (v) => setState(() => _time = v),
            ),
            const SizedBox(height: ElioSpacing.xl),
            _section(
              eyebrow: 'style',
              options: _styleOptions,
              selected: _style,
              onSelect: (v) => setState(() => _style = v),
            ),
            const SizedBox(height: ElioSpacing.xl),
            _section(
              eyebrow: 'mood',
              options: _moodOptions,
              selected: _mood,
              onSelect: (v) => setState(() => _mood = v),
            ),
            const SizedBox(height: ElioSpacing.xxl),
            ElioBigButton(
              label: 'Generate',
              trailingIcon: Icons.auto_awesome,
              onTap: _generate,
            ),
            const SizedBox(height: ElioSpacing.md),
          ],
        ),
      ),
    );
  }
}
