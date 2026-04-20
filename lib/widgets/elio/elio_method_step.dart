// lib/widgets/elio/elio_method_step.dart
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(stepNumber.toString().padLeft(2, '0'),
                style: ElioTextStyles.stepNumeral),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(title, style: ElioTextStyles.heading4),
                  const SizedBox(height: 8),
                ],
                Text(body, style: ElioTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
