// lib/widgets/elio/elio_feedback_bar.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioFeedbackBar extends StatelessWidget {
  final ValueChanged<bool> onRated; // true = thumbs up

  const ElioFeedbackBar({super.key, required this.onRated});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(ElioRadii.card),
      ),
      child: Row(
        children: [
          Expanded(child: Text('How was the recipe?', style: ElioTextStyles.heading5)),
          IconButton(
            icon: const Icon(Icons.thumb_up_outlined, color: ElioColors.espresso),
            onPressed: () => onRated(true),
          ),
          IconButton(
            icon: const Icon(Icons.thumb_down_outlined, color: ElioColors.espresso),
            onPressed: () => onRated(false),
          ),
        ],
      ),
    );
  }
}
