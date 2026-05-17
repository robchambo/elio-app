// lib/elio/elio_feedback_bar.dart
//
// Thumbs-up / thumbs-down rating bar at the bottom of RecipeScreen.
//
// Wires straight to RecipeScreen._rateRecipe → FirestoreService.
// rateRecipe → users/{uid}.tasteProfile.{liked,disliked}Titles, which
// HomeScreen reads on init and threads into the request as
// likedRecipes / dislikedRecipes for the prompt's TASTE PROFILE
// section.
//
// 16 May 2026 (Notion rev pass): pre-fix this was stateless — taps
// fired the callback (Firestore write succeeded) but the icon stayed
// outlined, so the user got no feedback that the rating registered
// and assumed it was broken. Now stateful with a "rated" state that:
//   • Swaps the matching icon to its filled terracotta variant.
//   • Disables further taps on either button (one rating per
//     RecipeScreen mount — re-rating would mean re-writing Firestore
//     in conflicting directions, and RecipeScreen.regen-pushReplaces
//     to a fresh instance anyway).
//   • Replaces the prompt copy with a "Thanks — we'll learn from
//     this." confirmation.

import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioFeedbackBar extends StatefulWidget {
  final ValueChanged<bool> onRated; // true = thumbs up

  const ElioFeedbackBar({super.key, required this.onRated});

  @override
  State<ElioFeedbackBar> createState() => _ElioFeedbackBarState();
}

class _ElioFeedbackBarState extends State<ElioFeedbackBar> {
  /// null until the user taps. Once set the bar is read-only.
  bool? _rated;

  void _handle(bool liked) {
    if (_rated != null) return;
    setState(() => _rated = liked);
    widget.onRated(liked);
  }

  @override
  Widget build(BuildContext context) {
    final rated = _rated != null;
    final upActive = _rated == true;
    final downActive = _rated == false;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ElioColors.creamDeep,
        borderRadius: BorderRadius.circular(ElioRadii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rated ? "Thanks — we'll learn from this." : 'How was the recipe?',
              style: ElioTextStyles.bodyStyle.copyWith(color: ElioColors.mocha),
            ),
          ),
          IconButton(
            icon: Icon(
              upActive ? Icons.thumb_up : Icons.thumb_up_outlined,
              color: upActive ? ElioColors.terracotta : ElioColors.espresso,
            ),
            onPressed: rated ? null : () => _handle(true),
          ),
          IconButton(
            icon: Icon(
              downActive ? Icons.thumb_down : Icons.thumb_down_outlined,
              color: downActive ? ElioColors.terracotta : ElioColors.espresso,
            ),
            onPressed: rated ? null : () => _handle(false),
          ),
        ],
      ),
    );
  }
}
