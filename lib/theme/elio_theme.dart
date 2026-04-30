import 'package:flutter/material.dart';
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

  // Sprint 16 rebrand palette.
  static const Color cream = Color(0xFFF4ECE0);
  static const Color creamDeep = Color(0xFFEFE3D2);
  static const Color terracotta = Color(0xFFE37B53);
  static const Color peach = Color(0xFFF2C9A8);
  static const Color espresso = Color(0xFF2A1F1A);
  static const Color mocha = Color(0xFF6B5A4F);
  static const Color rule = Color(0xFFD7C5B0);

  // Status / semantic.
  static const Color error = Color(0xFFD94A4A);
  static const Color success = Color(0xFF3D9970);

  // Onboarding perishable-tier tokens (screen 12 swatches).
  static const Color freshGreen = Color(0xFF3D9970);
  static const Color perishThisWeek = terracotta;
  static const Color perishToday = Color(0xFFE06C5E);
}

// ─── Legacy ElioText aliases ─────────────────────────────────────────────
// Kept as aliases pointing at the Sprint 16 rebrand ramp so existing call
// sites keep compiling. New code should use `ElioTextStyles.<role>`.

class ElioText {
  ElioText._();

  static TextStyle get displayLarge =>
      ElioTextStyles.pageTitleStyle.copyWith(fontSize: 32);
  static TextStyle get displayMedium => ElioTextStyles.sectionHeadingStyle;
  static TextStyle get headingLarge =>
      ElioTextStyles.sectionHeadingStyle.copyWith(fontSize: 20);
  static TextStyle get headingMedium =>
      ElioTextStyles.uiLabelStyle.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get bodyLarge => ElioTextStyles.bodyStyle;
  static TextStyle get bodyMedium => ElioTextStyles.bodySmallStyle;
  static TextStyle get label =>
      ElioTextStyles.bodySmallStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600);
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
