// lib/widgets/elio/elio_method_step.dart
//
// Sprint 16.6: when [onTimeTap] is provided, parses [body] with
// TimeParser.findMatches() and renders matches as inline tappable
// pills (Paprika-style). When [onTimeTap] is null the widget behaves
// exactly as before — plain Text — so existing callers are
// unaffected.
//
// Sprint 16.7d: the body-with-pills rendering is exposed via the
// public [ElioMethodStepBody] widget so Cook Mode (and any other
// caller without the numeral/title chrome) can reuse it at its own
// text size.
import 'package:flutter/material.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../utils/time_parser.dart';

class ElioMethodStep extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String body;

  /// Sprint 16.6: optional handler fired when the user taps an
  /// inline time pill (e.g. "25 min" inside the body). The parent
  /// (RecipeScreen) opens the duration-picker bottom sheet pre-filled
  /// with [duration].
  ///
  /// When null, the body renders as plain Text — preserves the
  /// pre-Sprint-16.6 behaviour for any caller that hasn't opted in.
  final void Function(TimeMatch match)? onTimeTap;

  const ElioMethodStep({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.body,
    this.onTimeTap,
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
                ElioMethodStepBody(
                  body: body,
                  onTimeTap: onTimeTap,
                  baseStyle: ElioTextStyles.bodySmallStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders step prose with inline tappable terracotta time pills
/// (Sprint 16.6 cooking timer). When [onTimeTap] is null the body
/// renders as plain Text. [baseStyle] is applied to the surrounding
/// prose AND scales the pill text — pass the larger body style in
/// Cook Mode so the pills track the 18pt prose.
class ElioMethodStepBody extends StatelessWidget {
  final String body;
  final void Function(TimeMatch match)? onTimeTap;
  final TextStyle baseStyle;

  const ElioMethodStepBody({
    super.key,
    required this.body,
    required this.onTimeTap,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final tap = onTimeTap;
    if (tap == null) return Text(body, style: baseStyle);

    final matches = TimeParser.findMatches(body);
    if (matches.isEmpty) return Text(body, style: baseStyle);

    final pillTextStyle = baseStyle.copyWith(
      color: Colors.white,
      fontFamily: 'DM Mono',
      fontWeight: FontWeight.w500,
    );

    // Walk the matches in order, emitting plain text + tappable
    // widget spans alternately. RichText so pills sit cleanly inline
    // with the surrounding prose.
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: body.substring(cursor, m.start)));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _TimePill(
          label: m.matchedText,
          textStyle: pillTextStyle,
          onTap: () => tap(m),
        ),
      ));
      cursor = m.end;
    }
    if (cursor < body.length) {
      spans.add(TextSpan(text: body.substring(cursor)));
    }
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}

/// Tappable terracotta pill rendered inline in step prose. Visual
/// matches the cooking-timer mockup at
/// `docs/strategy/2026-05-11-cooking-timer-mockup.html`.
class _TimePill extends StatelessWidget {
  final String label;
  final TextStyle textStyle;
  final VoidCallback onTap;

  const _TimePill({
    required this.label,
    required this.textStyle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // A touch of vertical padding so the hit target clears the
        // accessibility minimum without inflating line height too much.
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: ElioColors.terracotta,
            borderRadius: BorderRadius.circular(ElioRadii.chip),
          ),
          child: Text(label, style: textStyle),
        ),
      ),
    );
  }
}
