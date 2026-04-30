// lib/widgets/elio/elio_hero_heading.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';

/// Editorial display heading — up to 3 lines, last line optionally in amber.
/// Example: ElioHeroHeading(lines: ['hey kate.', 'lets get', 'started'], amberLastLine: true)
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
                ? ElioTextStyles.heroDisplayAccent
                : ElioTextStyles.heroDisplay,
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
