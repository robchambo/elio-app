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
///
/// Visuals: tier is conveyed **purely by background fill + border
/// colour**. We used to render a glyph icon (tick / star / leaf /
/// clock / warning) above the label, but on-device testing for
/// Sprint 16.2 showed that longer labels ("Extra virgin olive oil",
/// "Mediterranean blend") collided with the glyph and clipped the
/// label with an ellipsis. Dropping the glyph gives the text the
/// whole tile height, and the colour-coded system is unambiguous
/// once paired with the screen-level swatch legend.
/// `PantryTierStyle.glyph` is retained for backwards compatibility
/// but is no longer rendered.
class ElioPantryItemTile extends StatelessWidget {
  final String label;
  final String tier;
  final List<String> tiers;
  final Map<String, PantryTierStyle>? tierStyles;
  final ValueChanged<String> onCycle;
  final VoidCallback onLongPress;

  /// When non-empty, the tile is rendered greyed-out + non-interactive
  /// and shows a small reason badge (e.g. "Vegan", "Gluten"). Used by
  /// onboarding screens 11/12 to filter conflicting items based on
  /// dietary/allergy selections from screens 04/05. See
  /// [DietaryFilter.blockReasons].
  final List<String> blockedReasons;

  const ElioPantryItemTile({
    super.key,
    required this.label,
    required this.tier,
    required this.tiers,
    required this.onCycle,
    required this.onLongPress,
    this.tierStyles,
    this.blockedReasons = const [],
  });

  bool get _isBlocked => blockedReasons.isNotEmpty;

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
      glyphColor: ElioColors.mocha,
      borderColor: ElioColors.rule,
    ),
    'usually': PantryTierStyle(
      background: Color(0x1FE37B53), // terracotta @ 12%
      glyphColor: ElioColors.terracotta,
      glyph: Icons.check,
      borderColor: ElioColors.terracotta,
    ),
    'always': PantryTierStyle(
      background: ElioColors.terracotta,
      glyphColor: Colors.white,
      glyph: Icons.star_rounded,
      borderColor: ElioColors.terracotta,
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
    if (_isBlocked) return _buildBlocked();

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
            color: style.borderColor ?? ElioColors.rule,
            width: tier == 'unselected' ? 1.5 : 2.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ElioTextStyles.bodySmall.copyWith(
              color: ElioColors.espresso,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// Greyed-out, non-interactive variant — used when the item conflicts
  /// with one or more dietary/allergy selections. Tap + long-press are
  /// suppressed; reason badge sits in the top-right of the tile.
  Widget _buildBlocked() {
    final reason = blockedReasons.first;
    return Semantics(
      label: '$label, unavailable: $reason',
      button: false,
      child: Container(
          padding: const EdgeInsets.all(ElioSpacing.sm + 2),
          decoration: BoxDecoration(
            color: ElioColors.cream,
            borderRadius: BorderRadius.circular(ElioRadii.md),
            border: Border.all(
              color: ElioColors.rule.withValues(alpha: 0.6),
              width: 1.0,
              style: BorderStyle.solid,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ElioTextStyles.bodySmall.copyWith(
                    color: ElioColors.mocha.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.lineThrough,
                    decorationColor:
                        ElioColors.mocha.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: ElioColors.espresso.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(ElioRadii.sm),
                  ),
                  child: Text(
                    reason,
                    style: ElioTextStyles.bodySmall.copyWith(
                      fontSize: 10,
                      color: ElioColors.mocha,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
