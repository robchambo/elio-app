import 'package:flutter/material.dart';
import '../../theme/elio_text_styles.dart';

/// Section heading — Bricolage Grotesque Bold (700), sentence case as authored,
/// espresso colour, no period treatment.
///
/// Used for in-page section labels: "Ingredients", "Pantry Builder",
/// "Custom allergens or dietary requirements", etc.
class ElioSectionHeading extends StatelessWidget {
  const ElioSectionHeading(this.text, {super.key, this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: ElioTextStyles.sectionHeadingStyle,
      textAlign: textAlign,
    );
  }
}
