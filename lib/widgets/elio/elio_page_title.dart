import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';

/// Hero / page-title heading.
///
/// Renders [text] in Bricolage Grotesque ExtraBold (800), espresso, with
/// every `.` glyph rendered in terracotta — the **D rule** from the
/// Sprint 16 rebrand spec (§5).
///
/// The caller should author the string in the case they want rendered;
/// no auto-lowercasing is applied, since onboarding question screens may
/// authorically choose to capitalise.
///
/// Examples:
/// ```dart
/// ElioPageTitle('hey kate. lets get started')   // mid-string . is terracotta
/// ElioPageTitle('tonights dinner.')              // terminal . is terracotta
/// ElioPageTitle('creamy lemon pasta')            // no terracotta
/// ElioPageTitle('what brought you to elio?')     // no terracotta (no .)
/// ```
class ElioPageTitle extends StatelessWidget {
  const ElioPageTitle(
    this.text, {
    super.key,
    this.fontSize,
    this.textAlign,
  });

  final String text;
  final double? fontSize;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = ElioTextStyles.pageTitleStyle.copyWith(
      fontSize: fontSize ?? ElioTextStyles.pageTitleStyle.fontSize,
    );

    final spans = <TextSpan>[];
    final buffer = StringBuffer();

    for (final char in text.split('')) {
      if (char == '.') {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(text: buffer.toString()));
          buffer.clear();
        }
        spans.add(const TextSpan(
          text: '.',
          style: TextStyle(color: ElioColors.terracotta),
        ));
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString()));
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      textAlign: textAlign,
    );
  }
}
