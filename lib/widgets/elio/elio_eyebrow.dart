// lib/widgets/elio/elio_eyebrow.dart
import 'package:flutter/material.dart';
import '../../theme/elio_text_styles.dart';

/// Small all-caps label ("YOUR KITCHEN IS READY FOR ELIO", "YOU CAN PICK MULTIPLE").
class ElioEyebrow extends StatelessWidget {
  final String text;
  final TextAlign textAlign;

  const ElioEyebrow(this.text, {super.key, this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: ElioTextStyles.eyebrow,
      textAlign: textAlign,
    );
  }
}
