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
}
