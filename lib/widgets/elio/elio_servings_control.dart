// lib/widgets/elio/elio_servings_control.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioServingsControl extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const ElioServingsControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(icon: Icons.remove,
            onTap: value > min ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 48,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: ElioTextStyles.sectionHeadingStyle),
        ),
        _RoundButton(icon: Icons.add,
            onTap: value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundButton({required this.icon, this.onTap});
  @override
  Widget build(BuildContext c) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: ElioRadii.all(999),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: enabled ? ElioColors.peach : ElioColors.peach.withValues(alpha: 0.4),
          borderRadius: ElioRadii.all(999),
        ),
        child: Icon(icon, color: ElioColors.espresso, size: 20),
      ),
    );
  }
}
