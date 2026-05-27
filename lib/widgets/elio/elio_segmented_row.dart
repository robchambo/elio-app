// lib/widgets/elio/elio_segmented_row.dart
//
// Inline segmented control — label on the left, terracotta-filled pill
// segments on the right. Cream pill rail with a single rule-coloured
// border; the selected segment animates between positions.
//
// Originally defined privately in `account_screen.dart` as `_SegmentedRow`
// for the Units + Region rows in Settings (Sprint 16.1). Extracted to
// `lib/widgets/elio/` (Sprint 17 prep, 26 May 2026) so the recipe-
// generation screen can reuse the same control for the new Pantry / Go
// Wild mode picker without copy-paste drift.
//
// Visuals are deliberately identical to the Settings version — see the
// `Units` row + `Region` row in `account_screen.dart` for the live
// reference.

import 'package:flutter/material.dart';

import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';

class ElioSegmentedRow extends StatelessWidget {
  final String label;

  /// `(value, displayLabel)` tuples. Two-segment is the most common shape
  /// (Metric / Imperial, Pantry / Go Wild) but the widget accepts any
  /// count so the same control works for three- or four-segment pickers.
  final List<(String, String)> options;

  final String value;
  final ValueChanged<String> onChanged;

  const ElioSegmentedRow({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: ElioTextStyles.uiLabelStyle)),
          Container(
            decoration: BoxDecoration(
              color: ElioColors.cream,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ElioColors.rule, width: 1),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (val, display) in options)
                  GestureDetector(
                    onTap: () {
                      if (val != value) onChanged(val);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: val == value
                            ? ElioColors.terracotta
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        display,
                        style: ElioTextStyles.uiLabelStyle.copyWith(
                          color: val == value
                              ? Colors.white
                              : ElioColors.espresso,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
