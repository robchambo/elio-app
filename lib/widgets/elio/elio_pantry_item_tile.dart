import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';

/// Visual mapping for a tier string → (background, glyph colour, glyph icon).
///
/// Callers can override with [tierStyles] to adapt the tile to either the
/// 2-tier staples variant (`unselected → usually → always`) or the 3-tier
/// perishables variant (`unselected → fresh → thisWeek → today`).
class PantryTierStyle {
  final Color background;
  final Color glyphColor;
  final IconData? glyph;
  final Color? borderColor;

  const PantryTierStyle({
    required this.background,
    required this.glyphColor,
    this.glyph,
    this.borderColor,
  });
}

/// Grid tile used on onboarding screens 11 (staples) and 12 (perishables).
///
/// Tap cycles to the next tier in [tiers]. Long-press (300 ms via
/// [LongPressGestureRecognizer], wired through [RawGestureDetector] to
/// survive inside scrollables — see CLAUDE.md hard rule) fires
/// [onLongPress].
class ElioPantryItemTile extends StatelessWidget {
  final String label;
  final String tier;
  final List<String> tiers;
  final Map<String, PantryTierStyle>? tierStyles;
  final ValueChanged<String> onCycle;
  final VoidCallback onLongPress;

  const ElioPantryItemTile({
    super.key,
    required this.label,
    required this.tier,
    required this.tiers,
    required this.onCycle,
    required this.onLongPress,
    this.tierStyles,
  });

  String _nextTier() {
    final i = tiers.indexOf(tier);
    if (i < 0) return tiers.first;
    return tiers[(i + 1) % tiers.length];
  }

  PantryTierStyle _resolveStyle() {
    final map = tierStyles ?? _defaultStyles;
    return map[tier] ?? _defaultStyles['unselected']!;
  }

  static const Map<String, PantryTierStyle> _defaultStyles = {
    'unselected': PantryTierStyle(
      background: Color(0xFFFFFFFF),
      glyphColor: ElioColors.textMuted,
      borderColor: ElioColors.border,
    ),
    'usually': PantryTierStyle(
      background: Color(0x1FF08C14), // amber @ 12%
      glyphColor: ElioColors.amber,
      glyph: Icons.check,
      borderColor: ElioColors.amber,
    ),
    'always': PantryTierStyle(
      background: ElioColors.amber,
      glyphColor: Colors.white,
      glyph: Icons.star_rounded,
      borderColor: ElioColors.amber,
    ),
    'fresh': PantryTierStyle(
      background: Color(0x1F3D9970),
      glyphColor: ElioColors.freshGreen,
      glyph: Icons.eco,
      borderColor: ElioColors.freshGreen,
    ),
    'thisWeek': PantryTierStyle(
      background: Color(0x1FF08C14),
      glyphColor: ElioColors.perishThisWeek,
      glyph: Icons.schedule,
      borderColor: ElioColors.perishThisWeek,
    ),
    'today': PantryTierStyle(
      background: Color(0x1FE06C5E),
      glyphColor: ElioColors.perishToday,
      glyph: Icons.warning_amber_rounded,
      borderColor: ElioColors.perishToday,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle();

    final gestures = <Type, GestureRecognizerFactory>{
      TapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(),
        (recognizer) {
          recognizer.onTap = () => onCycle(_nextTier());
        },
      ),
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
        () => LongPressGestureRecognizer(
          duration: const Duration(milliseconds: 300),
        ),
        (recognizer) {
          recognizer.onLongPress = onLongPress;
        },
      ),
    };

    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: gestures,
      child: Container(
        padding: const EdgeInsets.all(ElioSpacing.sm + 2),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(ElioRadii.md),
          border: Border.all(
            color: style.borderColor ?? ElioColors.border,
            width: tier == 'unselected' ? 1.5 : 2.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (style.glyph != null)
              Icon(style.glyph, color: style.glyphColor, size: 22)
            else
              const SizedBox(height: 22),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ElioTextStyles.bodySmall.copyWith(
                color: ElioColors.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
