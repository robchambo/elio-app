// lib/widgets/elio/elio_duration_picker_sheet.dart
//
// Sprint 16.6 — cooking timer.
//
// Bottom-sheet picker for choosing a timer duration. Quick chips for
// common values + a "custom…" option that opens a Material time
// picker for arbitrary durations. Returns the picked Duration via
// `Navigator.pop`, or null on dismiss.
//
// Pre-fills the selected chip when a detected duration is passed in
// (the inline-pill tap path), or starts with 10 min selected when
// the user is creating a timer from scratch (the clock-fallback icon
// path).

import 'package:flutter/material.dart';

import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';

class ElioDurationPickerSheet extends StatefulWidget {
  /// Initial selection. Pre-fills the matching chip when provided
  /// (or selects "custom" when no chip matches). Defaults to 10 min
  /// when null.
  final Duration? initialDuration;

  /// Step label, shown as the sheet's sub-title context (e.g.
  /// "Step 3 · we detected 25 minutes in the instruction").
  final String? contextLabel;

  const ElioDurationPickerSheet({
    super.key,
    this.initialDuration,
    this.contextLabel,
  });

  /// Helper to show the sheet and await the picked duration.
  static Future<Duration?> show(
    BuildContext context, {
    Duration? initialDuration,
    String? contextLabel,
  }) {
    return showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: ElioColors.cream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ElioDurationPickerSheet(
        initialDuration: initialDuration,
        contextLabel: contextLabel,
      ),
    );
  }

  @override
  State<ElioDurationPickerSheet> createState() =>
      _ElioDurationPickerSheetState();
}

class _ElioDurationPickerSheetState extends State<ElioDurationPickerSheet> {
  // Quick-chip options. Same set as the mockup.
  static const List<Duration> _quickOptions = [
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 20),
    Duration(minutes: 25),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(hours: 1),
  ];

  late Duration _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDuration ?? const Duration(minutes: 10);
  }

  String _formatChipLabel(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return m == 0 ? '$h h' : '${h}h ${m}m';
    }
    return '${d.inMinutes} min';
  }

  Future<void> _pickCustom() async {
    // Use Material's TimePicker in 24h mode as a duration picker —
    // good enough for v1 without pulling in another package.
    final initial = TimeOfDay(
      hour: _selected.inHours,
      minute: _selected.inMinutes.remainder(60),
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Custom timer length',
      builder: (ctx, child) => MediaQuery(
        // Force 24-hour mode so AM/PM doesn't appear for duration entry.
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      final d = Duration(hours: picked.hour, minutes: picked.minute);
      if (d.inSeconds > 0) setState(() => _selected = d);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ElioColors.rule,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'start a timer.',
            style: ElioTextStyles.pageTitleStyle.copyWith(fontSize: 22),
          ),
          if (widget.contextLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.contextLabel!,
              style: ElioTextStyles.bodySmallStyle.copyWith(
                color: ElioColors.mocha,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _quickOptions)
                _Chip(
                  label: _formatChipLabel(d),
                  selected: _selected == d,
                  onTap: () => setState(() => _selected = d),
                ),
              _Chip(
                label: 'custom…',
                selected: !_quickOptions.contains(_selected),
                onTap: _pickCustom,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: ElioColors.terracotta,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                elevation: 0,
              ),
              child: Text(
                'Start ${_formatChipLabel(_selected)} timer',
                style: ElioTextStyles.uiLabelStyle.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ElioColors.terracotta : ElioColors.creamDeep,
          borderRadius: BorderRadius.circular(ElioRadii.chip),
          border: Border.all(
            color: selected ? ElioColors.terracotta : ElioColors.rule,
          ),
        ),
        child: Text(
          label,
          style: ElioTextStyles.bodySmallStyle.copyWith(
            color: selected ? Colors.white : ElioColors.espresso,
            fontFamily: 'DM Mono',
          ),
        ),
      ),
    );
  }
}
