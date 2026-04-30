import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';

/// Two-option segmented control used on onboarding screen 09 (region/units).
///
/// Renders a pill track with two segments. The active segment uses the
/// amber fill; inactive renders transparent with navy text.
class ElioSegmentedToggle extends StatelessWidget {
  final String value;
  final ({String value, String label}) optionA;
  final ({String value, String label}) optionB;
  final ValueChanged<String> onChanged;

  const ElioSegmentedToggle({
    super.key,
    required this.value,
    required this.optionA,
    required this.optionB,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(ElioRadii.pill),
        border: Border.all(color: ElioColors.rule),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: optionA.label,
              active: value == optionA.value,
              onTap: () => onChanged(optionA.value),
            ),
          ),
          Expanded(
            child: _Segment(
              label: optionB.label,
              active: value == optionB.value,
              onTap: () => onChanged(optionB.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ElioRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: ElioSpacing.sm + 2),
        decoration: BoxDecoration(
          color: active ? ElioColors.terracotta : Colors.transparent,
          borderRadius: BorderRadius.circular(ElioRadii.pill),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: ElioTextStyles.body.copyWith(
            color: active ? Colors.white : ElioColors.espresso,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
