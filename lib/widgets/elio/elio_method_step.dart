// lib/widgets/elio/elio_method_step.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';

class ElioMethodStep extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String body;

  const ElioMethodStep({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.body,
  });

  static const TextStyle _numeralStyle = TextStyle(
    fontFamily: 'Bricolage Grotesque',
    fontWeight: FontWeight.w800,
    fontSize: 56,
    height: 1.0,
    letterSpacing: -1.5,
    color: ElioColors.terracotta,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(stepNumber.toString().padLeft(2, '0'),
                style: _numeralStyle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(title, style: ElioTextStyles.uiLabelStyle),
                  const SizedBox(height: 8),
                ],
                Text(body, style: ElioTextStyles.bodySmallStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
