// lib/widgets/elio/elio_hero_heading.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';

/// Legacy editorial heading. The Sprint 16 rebrand replaced this with
/// [ElioPageTitle] (single-string D-rule). This widget is kept as a thin
/// wrapper that renders each [lines] entry on its own line in the new
/// page-title style so existing call sites keep their line-break layout
/// without a per-site migration.
///
/// `amberLastLine` is honoured by colouring the final line in terracotta.
/// `showUnderline` still draws the small terracotta rule below the block
/// for callers that opted into that treatment.
///
/// New code should use [ElioPageTitle] directly.
class ElioHeroHeading extends StatelessWidget {
  final List<String> lines;
  final bool amberLastLine;
  final bool showUnderline;

  const ElioHeroHeading({
    super.key,
    required this.lines,
    this.amberLastLine = false,
    this.showUnderline = false,
  });

  @override
  Widget build(BuildContext context) {
    assert(lines.isNotEmpty);
    final lastIndex = lines.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < lines.length; i++)
          Text(
            lines[i],
            style: (amberLastLine && i == lastIndex)
                ? ElioTextStyles.pageTitleStyle.copyWith(color: ElioColors.terracotta)
                : ElioTextStyles.pageTitleStyle,
          ),
        if (showUnderline) ...[
          const SizedBox(height: 16),
          Container(
            width: 96,
            height: 4,
            decoration: const BoxDecoration(
              color: ElioColors.terracotta,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
        ],
      ],
    );
  }
}
