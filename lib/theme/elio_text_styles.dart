import 'package:flutter/material.dart';
import 'elio_theme.dart';

/// Editorial type ramp for the Sprint 16 rebrand.
///
/// All entries use bundled-font assets declared in pubspec.yaml:
///   - Bricolage Grotesque (display, w200-w800)
///   - DM Sans (body)
///   - DM Mono (technical)
///
/// Legacy names (`heading1-5`, `body`, `bodySmall`, `eyebrow`, `statValue`,
/// `stepNumeral`, `heroDisplay`, `heroDisplayAccent`) are kept as aliases
/// pointing at the new roles so existing call sites keep compiling. Prefer
/// the canonical names (`pageTitleStyle`, `sectionHeadingStyle`, `ledeStyle`,
/// `bodyStyle`, `bodySmallStyle`, `uiLabelStyle`, `tabLabelStyle`,
/// `eyebrowStyle`, `numericStyle`) for new code.
class ElioTextStyles {
  ElioTextStyles._();

  // ─── Canonical Sprint 16 rebrand ramp ─────────────────────────────────

  static const TextStyle pageTitleStyle = TextStyle(
    fontFamily: 'Bricolage Grotesque',
    fontWeight: FontWeight.w800,
    fontSize: 54,
    height: 0.96,
    letterSpacing: -1.5,
    color: ElioColors.espresso,
  );

  static const TextStyle sectionHeadingStyle = TextStyle(
    fontFamily: 'Bricolage Grotesque',
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.1,
    letterSpacing: -0.6,
    color: ElioColors.espresso,
  );

  static const TextStyle ledeStyle = TextStyle(
    fontFamily: 'DM Sans',
    fontWeight: FontWeight.w500,
    fontSize: 18,
    height: 1.45,
    color: ElioColors.mocha,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontFamily: 'DM Sans',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.5,
    color: ElioColors.espresso,
  );

  static const TextStyle bodySmallStyle = TextStyle(
    fontFamily: 'DM Sans',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.5,
    color: ElioColors.mocha,
  );

  static const TextStyle uiLabelStyle = TextStyle(
    fontFamily: 'DM Sans',
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.3,
    color: ElioColors.espresso,
  );

  static const TextStyle tabLabelStyle = TextStyle(
    fontFamily: 'DM Sans',
    fontWeight: FontWeight.w500,
    fontSize: 11,
    height: 1.2,
    letterSpacing: 1.98,
    color: ElioColors.mocha,
  );

  static const TextStyle eyebrowStyle = TextStyle(
    fontFamily: 'DM Mono',
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.2,
    letterSpacing: 2.4,
    color: ElioColors.mocha,
  );

  static const TextStyle numericStyle = TextStyle(
    fontFamily: 'DM Mono',
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.2,
    letterSpacing: 0.42,
    color: ElioColors.espresso,
  );

  // ─── Legacy aliases (Sprint 16 rebrand) ───────────────────────────────
  // These point at the new ramp so existing call sites compile while new
  // code migrates to the canonical names above.

  static const TextStyle heroDisplay = pageTitleStyle;
  static TextStyle get heroDisplayAccent =>
      pageTitleStyle.copyWith(color: ElioColors.terracotta);
  static const TextStyle heading1 = pageTitleStyle;
  static const TextStyle heading2 = sectionHeadingStyle;
  static const TextStyle heading3 = sectionHeadingStyle;
  static const TextStyle heading4 = sectionHeadingStyle;
  static const TextStyle heading5 = uiLabelStyle;
  static const TextStyle eyebrow = eyebrowStyle;
  static const TextStyle body = bodyStyle;
  static const TextStyle bodySmall = bodySmallStyle;
  static const TextStyle statValue = uiLabelStyle;
  static const TextStyle stepNumeral = TextStyle(
    fontFamily: 'Bricolage Grotesque',
    fontWeight: FontWeight.w800,
    fontSize: 56,
    height: 1.0,
    letterSpacing: -1.5,
    color: ElioColors.terracotta,
  );
}
