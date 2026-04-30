// lib/widgets/elio/elio_custom_field.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioCustomField extends StatelessWidget {
  final String placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;

  const ElioCustomField({
    super.key,
    required this.placeholder,
    this.controller,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(ElioRadii.card),
      ),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        style: ElioTextStyles.body,
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: ElioTextStyles.body.copyWith(color: ElioColors.mocha),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }
}
