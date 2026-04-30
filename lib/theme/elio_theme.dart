import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'elio_text_styles.dart';
import 'elio_radii.dart';

// ─────────────────────────────────────────────
// Elio Design System
// Design philosophy: approachable utility.
// Clean, warm, and functional. Not a food magazine —
// a trusted kitchen companion.
//
// Palette:
//   Navy   #1A2744  — primary text, buttons, trust
//   Amber  #F08C14  — CTA, highlights, warmth
//   Sky    #4A90D9  — secondary accent, info
//   White  #FFFFFF  — backgrounds
//   Off-white #F7F5F2 — card backgrounds
//   Border #E8E4DF  — dividers, input borders
//
// Typography: Outfit via google_fonts package
// Updated Sprint 16 rebrand: bundled Bricolage Grotesque + DM Sans
// ─────────────────────────────────────────────

class ElioColors {
  ElioColors._();

  static const Color navy = Color(0xFF1A2744);
  static const Color amber = Color(0xFFF08C14);
  static const Color sky = Color(0xFF4A90D9);
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF7F5F2);
  // Warmer cream used on cards that sit on offWhite backgrounds (Sprint 16).
  // Hex updated to #F4ECE0 by Sprint 16 rebrand (Task 5); was #FBF3E7.
  static const Color cream = Color(0xFFF4ECE0);
  static const Color border = Color(0xFFE8E4DF);
  static const Color textPrimary = Color(0xFF1A2744);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFFABABAB);
  static const Color error = Color(0xFFD94A4A);
  static const Color success = Color(0xFF3D9970);

  // ─── Sprint 16 onboarding perishable-tier tokens (placeholder hex) ──
  // These power the 3-tier tile state on screen 12. Hex values are
  // provisional — confirm with Kate before Phase 4 ships.
  static const Color freshGreen = Color(0xFF3D9970);
  static const Color perishThisWeek = terracotta;
  static const Color perishToday = Color(0xFFE06C5E);

  // ─── Sprint 16 rebrand: new palette tokens ──────────────────────────
  // These supersede navy/amber/sky/offWhite/border. Old tokens stay
  // until every caller migrates (Task 36), then they are removed.
  static const Color creamDeep = Color(0xFFEFE3D2);
  static const Color terracotta = Color(0xFFE37B53);
  static const Color peach = Color(0xFFF2C9A8);
  static const Color espresso = Color(0xFF2A1F1A);
  static const Color mocha = Color(0xFF6B5A4F);
  static const Color rule = Color(0xFFD7C5B0);
}

// ─── Text styles using GoogleFonts.outfit() ──────────────────────────────────
// These are functions (not constants) because GoogleFonts returns a new
// TextStyle object each time — it cannot be a compile-time const.

class ElioText {
  ElioText._();

  static TextStyle get displayLarge => GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: ElioColors.textPrimary,
        height: 1.2,
      );

  static TextStyle get displayMedium => GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: ElioColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get headingLarge => GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ElioColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get headingMedium => GoogleFonts.outfit(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: ElioColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get bodyLarge => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: ElioColors.textPrimary,
        height: 1.55,
      );

  static TextStyle get bodyMedium => GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: ElioColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get label => GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ElioColors.textPrimary,
        letterSpacing: 0.3,
      );
}

ThemeData elioTheme() {
  const textTheme = TextTheme(
    displayLarge: ElioTextStyles.pageTitleStyle,   // Bricolage 800 / 54
    displayMedium: ElioTextStyles.pageTitleStyle,
    displaySmall: ElioTextStyles.sectionHeadingStyle,
    headlineLarge: ElioTextStyles.sectionHeadingStyle,
    headlineMedium: ElioTextStyles.sectionHeadingStyle,
    headlineSmall: ElioTextStyles.uiLabelStyle,
    titleLarge: ElioTextStyles.uiLabelStyle,
    titleMedium: ElioTextStyles.uiLabelStyle,
    titleSmall: ElioTextStyles.bodyStyle,
    bodyLarge: ElioTextStyles.bodyStyle,
    bodyMedium: ElioTextStyles.bodyStyle,
    bodySmall: ElioTextStyles.bodySmallStyle,
    labelLarge: ElioTextStyles.uiLabelStyle,
    labelMedium: ElioTextStyles.tabLabelStyle,
    labelSmall: ElioTextStyles.eyebrowStyle,
  );

  return ThemeData(
    useMaterial3: true,
    textTheme: textTheme,
    colorScheme: const ColorScheme.light(
      primary: ElioColors.terracotta,
      onPrimary: Colors.white,
      secondary: ElioColors.peach,
      onSecondary: ElioColors.espresso,
      surface: ElioColors.cream,
      onSurface: ElioColors.espresso,
      error: ElioColors.error,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: ElioColors.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: ElioColors.cream,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: ElioTextStyles.uiLabelStyle,
      iconTheme: IconThemeData(color: ElioColors.espresso),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ElioColors.terracotta,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElioRadii.button),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        textStyle: ElioTextStyles.uiLabelStyle.copyWith(color: Colors.white),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ElioColors.espresso,
        side: const BorderSide(color: ElioColors.rule, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElioRadii.button),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: ElioTextStyles.uiLabelStyle,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ElioColors.espresso,
        textStyle: ElioTextStyles.uiLabelStyle,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ElioColors.creamDeep,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ElioRadii.input),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ElioRadii.input),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ElioRadii.input),
        borderSide: const BorderSide(color: ElioColors.terracotta, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ElioRadii.input),
        borderSide: const BorderSide(color: ElioColors.error),
      ),
      hintStyle: ElioTextStyles.bodyStyle.copyWith(color: ElioColors.mocha),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return ElioColors.terracotta;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: ElioColors.rule, width: 1.5),
    ),
    dividerTheme: const DividerThemeData(
      color: ElioColors.rule,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ElioColors.espresso,
      contentTextStyle: ElioTextStyles.bodyStyle.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ElioRadii.panel)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
