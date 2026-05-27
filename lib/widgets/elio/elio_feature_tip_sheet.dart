// lib/widgets/elio/elio_feature_tip_sheet.dart
//
// Sprint 16.8 row 7 — Style A bottom-sheet tip (the v1 visual for the
// FeatureTipService). Lightweight modal: icon + title + body + optional
// "Try it" CTA + "Got it" dismiss. Themed against the rebrand tokens.
//
// Use via the static [show] method, which auto-persists seen-state on
// either path so callers don't have to remember.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/analytics_service.dart';
import '../../services/feature_tip_catalog.dart';
import '../../services/feature_tip_service.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';

class ElioFeatureTipSheet extends StatelessWidget {
  final FeatureTip tip;
  final VoidCallback? onCta;

  const ElioFeatureTipSheet({
    super.key,
    required this.tip,
    this.onCta,
  });

  /// Show the tip and persist seen-state on dismiss / CTA. Returns true if
  /// the user tapped the CTA, false otherwise.
  ///
  /// The [onCta] callback fires *after* the sheet pops, so the caller can
  /// safely push another route from inside it without "dismissed mid-pop"
  /// races.
  static Future<bool> show(
    BuildContext context,
    FeatureTip tip, {
    VoidCallback? onCta,
  }) async {
    unawaited(AnalyticsService.instance.logFeatureTipShown(tip.id));
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: ElioColors.cream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ElioFeatureTipSheet(tip: tip, onCta: onCta),
    );
    await FeatureTipService.instance.markSeen(tip.id);
    if (result == true) {
      unawaited(AnalyticsService.instance.logFeatureTipCta(tip.id));
    }
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ElioSpacing.lg,
          ElioSpacing.md,
          ElioSpacing.lg,
          ElioSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: ElioSpacing.lg),
                decoration: BoxDecoration(
                  color: ElioColors.rule,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ElioColors.peach,
                    borderRadius: BorderRadius.circular(ElioRadii.card),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: ElioColors.espresso,
                  ),
                ),
                const SizedBox(width: ElioSpacing.md),
                Expanded(
                  child: Text(
                    tip.title,
                    style: ElioTextStyles.sectionHeadingStyle
                        .copyWith(fontSize: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ElioSpacing.md),
            Text(
              tip.body,
              style: ElioTextStyles.bodyStyle.copyWith(color: ElioColors.mocha),
            ),
            const SizedBox(height: ElioSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Got it'),
                  ),
                ),
                if (tip.ctaLabel != null) ...[
                  const SizedBox(width: ElioSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                        onCta?.call();
                      },
                      child: Text(tip.ctaLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
