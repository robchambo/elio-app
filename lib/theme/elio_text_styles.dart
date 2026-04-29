import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'elio_theme.dart';

/// Editorial type ramp for the Sprint 16 UI refresh.
///
/// Kept separate from the existing [ElioText] class so we can migrate screens
/// incrementally without breaking legacy screens. Outfit for display / headings
/// / eyebrow, Quicksand for body.
class ElioTextStyles {
  ElioTextStyles._();

  // ─── Editorial display ────────────────────────────────────────────────
  static TextStyle get heroDisplay => GoogleFonts.outfit(
        fontSize: 54,
        height: 1.0,
        fontWeight: FontWeight.w800,
        color: ElioColors.navy,
        letterSpacing: -1.5,
      );

  static TextStyle get heroDisplayAccent => heroDisplay.copyWith(
        color: ElioColors.amber,
      );

  // ─── Section headings ─────────────────────────────────────────────────
  static TextStyle get heading1 => GoogleFonts.outfit(
        fontSize: 36,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: ElioColors.navy,
      );

  static TextStyle get heading2 => GoogleFonts.outfit(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: ElioColors.navy,
      );

  static TextStyle get heading3 => GoogleFonts.outfit(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: ElioColors.navy,
      );

  static TextStyle get heading4 => GoogleFonts.outfit(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: ElioColors.navy,
      );

  static TextStyle get heading5 => GoogleFonts.outfit(
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: ElioColors.navy,
      );

  // ─── Eyebrow / overline ───────────────────────────────────────────────
  static TextStyle get eyebrow => GoogleFonts.outfit(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.8,
        color: ElioColors.textSecondary,
      );

  // ─── Body ─────────────────────────────────────────────────────────────
  static TextStyle get body => GoogleFonts.quicksand(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: ElioColors.textPrimary,
      );

  static TextStyle get bodySmall => GoogleFonts.quicksand(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: ElioColors.textSecondary,
      );

  // ─── Stat / pill label ────────────────────────────────────────────────
  static TextStyle get statValue => GoogleFonts.outfit(
        fontSize: 16,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: ElioColors.navy,
      );

  // ─── Big numeral (method step) ────────────────────────────────────────
  static TextStyle get stepNumeral => GoogleFonts.outfit(
        fontSize: 48,
        height: 1.0,
        fontWeight: FontWeight.w800,
        color: ElioColors.amber,
      );

  // ─── Sprint 16 rebrand: bundled-font ramp ─────────────────────────
  // These use the bundled Bricolage Grotesque / DM Sans / DM Mono
  // font assets declared in pubspec.yaml. They replace the old
  // GoogleFonts.outfit() / GoogleFonts.quicksand() entries above.
  // The old entries are removed in Task 35.

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
    letterSpacing: 1.98, // 18% of 11
    color: ElioColors.mocha,
  );

  static const TextStyle eyebrowStyle = TextStyle(
    fontFamily: 'DM Mono',
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.2,
    letterSpacing: 2.4, // 20% of 12
    color: ElioColors.mocha,
  );

  static const TextStyle numericStyle = TextStyle(
    fontFamily: 'DM Mono',
    fontWeight: FontWeight.w500, // Medium static
    fontSize: 14,
    height: 1.2,
    letterSpacing: 0.42, // 3% of 14
    color: ElioColors.espresso,
  );
}
