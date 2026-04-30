import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';

/// Chip-token input used for custom allergies + dislikes on screen 05.
///
/// User types free text; tokens commit on Enter or comma. Each token
/// renders as a chip with a remove (×) affordance. Duplicates (case
/// insensitive) are ignored.
class ElioChipTextInput extends StatefulWidget {
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String hintText;

  const ElioChipTextInput({
    super.key,
    required this.values,
    required this.onChanged,
    this.hintText = 'Add and press enter',
  });

  @override
  State<ElioChipTextInput> createState() => _ElioChipTextInputState();
}

class _ElioChipTextInputState extends State<ElioChipTextInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final token = raw.trim();
    if (token.isEmpty) return;
    final lower = token.toLowerCase();
    if (widget.values.any((v) => v.toLowerCase() == lower)) {
      _controller.clear();
      return;
    }
    widget.onChanged([...widget.values, token]);
    _controller.clear();
  }

  void _remove(String token) {
    widget.onChanged(widget.values.where((v) => v != token).toList());
  }

  void _onTextChanged(String v) {
    // Allow comma-delimited commit without requiring Enter.
    if (v.endsWith(',')) {
      _commit(v.substring(0, v.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.values.isNotEmpty) ...[
          Wrap(
            spacing: ElioSpacing.sm,
            runSpacing: ElioSpacing.sm,
            children:
                widget.values.map((t) => _TokenChip(label: t, onRemove: () => _remove(t))).toList(),
          ),
          const SizedBox(height: ElioSpacing.sm),
        ],
        TextField(
          controller: _controller,
          onChanged: _onTextChanged,
          onSubmitted: _commit,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: ElioTextStyles.bodySmallStyle,
            filled: true,
            fillColor: ElioColors.creamDeep,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: ElioSpacing.md,
              vertical: ElioSpacing.sm + 2,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ElioRadii.input),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ElioRadii.input),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _TokenChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _TokenChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: ElioSpacing.md,
        right: ElioSpacing.sm,
        top: 6,
        bottom: 6,
      ),
      decoration: BoxDecoration(
        color: ElioColors.terracotta.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ElioRadii.pill),
        border: Border.all(color: ElioColors.terracotta.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: ElioTextStyles.bodySmallStyle.copyWith(color: ElioColors.espresso)),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: ElioColors.espresso),
            ),
          ),
        ],
      ),
    );
  }
}
