// lib/screens/account/legal_doc_screen.dart
//
// Sprint 16.1 — minimal in-app viewer for the bundled legal markdown
// (Privacy Policy, Terms of Service). No flutter_markdown dep — we
// render with light styling rules:
//   - Lines starting with `# `   → page-title size
//   - Lines starting with `## `  → section heading
//   - Lines starting with `### ` → sub-heading
//   - `> ` blockquotes            → italic + indented
//   - Bullet lines (`- ` or `* `) → bullet rows
//   - Bold runs (`**text**`)      → rendered with Text.rich spans
//
// Anything else falls through as plain body text. The full markdown
// (links, tables, images) isn't needed for legal pages — they're
// long prose with headings and lists, which this handles.
//
// When url_launcher lands in Sprint 17 launch prep, this can be
// replaced (or remain as the offline fallback) with an external
// browser launch.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';

class LegalDocScreen extends StatefulWidget {
  /// Path under `assets/legal/` (e.g. `privacy-policy.md`).
  final String assetPath;

  /// Title shown in the app bar.
  final String title;

  const LegalDocScreen({
    super.key,
    required this.assetPath,
    required this.title,
  });

  @override
  State<LegalDocScreen> createState() => _LegalDocScreenState();
}

class _LegalDocScreenState extends State<LegalDocScreen> {
  String? _content;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/legal/${widget.assetPath}');
      if (mounted) {
        setState(() {
          _content = raw;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _content = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: ElioColors.espresso),
        title: Text(widget.title, style: ElioTextStyles.uiLabelStyle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ElioColors.terracotta))
          : _content == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(ElioSpacing.xl),
                    child: Text(
                      'Could not load this document. Please try again later.',
                      style: ElioTextStyles.bodyStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    ElioSpacing.xl,
                    ElioSpacing.md,
                    ElioSpacing.xl,
                    ElioSpacing.xxxl,
                  ),
                  child: _buildBody(_content!),
                ),
    );
  }

  Widget _buildBody(String md) {
    final widgets = <Widget>[];
    for (final raw in md.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: ElioSpacing.sm));
        continue;
      }
      if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: ElioSpacing.lg, bottom: ElioSpacing.sm),
          child: Text(line.substring(2), style: ElioTextStyles.pageTitleStyle),
        ));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: ElioSpacing.lg, bottom: ElioSpacing.xs),
          child: Text(line.substring(3), style: ElioTextStyles.sectionHeadingStyle),
        ));
      } else if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: ElioSpacing.md, bottom: ElioSpacing.xs),
          child: Text(line.substring(4), style: ElioTextStyles.uiLabelStyle),
        ));
      } else if (line.startsWith('> ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: ElioSpacing.md, top: 4, bottom: 4),
          child: _spans(line.substring(2),
              base: ElioTextStyles.bodySmallStyle.copyWith(
                fontStyle: FontStyle.italic,
                color: ElioColors.mocha,
              )),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 7),
                child: Container(
                  width: 4, height: 4,
                  decoration: const BoxDecoration(
                    color: ElioColors.mocha,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: _spans(line.substring(2), base: ElioTextStyles.bodyStyle),
              ),
            ],
          ),
        ));
      } else if (line.startsWith('---')) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: ElioSpacing.md),
          child: Container(height: 1, color: ElioColors.rule),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _spans(line, base: ElioTextStyles.bodyStyle),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  /// Splits on `**...**` for bold runs. Other inline markdown
  /// (links, italics, code) renders as raw — fine for the legal docs.
  Widget _spans(String text, {required TextStyle base}) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*([^*]+)\*\*');
    int cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
