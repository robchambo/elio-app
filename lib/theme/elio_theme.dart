import 'package:flutter/material.dart';

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
// Typography: Outfit (Google Fonts)
// ─────────────────────────────────────────────

class ElioColors {
  ElioColors._();

  static const Color navy = Color(0xFF1A2744);
  static const Color amber = Color(0xFFF08C14);
  static const Color sky = Color(0xFF4A90D9);
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF7F5F2);
  static const Color border = Color(0xFFE8E4DF);
  static const Color textPrimary = Color(0xFF1A2744);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFFABABAB);
  static const Color error = Color(0xFFD94A4A);
  static const Color success = Color(0xFF3D9970);
}

class ElioText {
  ElioText._();

  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: ElioColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: ElioColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headingLarge = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: ElioColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: ElioColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: ElioColors.textPrimary,
    height: 1.55,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: ElioColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: ElioColors.textPrimary,
    letterSpacing: 0.3,
  );
}

ThemeData elioTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ElioColors.navy,
      brightness: Brightness.light,
    ).copyWith(
      primary: ElioColors.navy,
      secondary: ElioColors.amber,
      surface: ElioColors.white,
      onPrimary: ElioColors.white,
      onSecondary: ElioColors.white,
    ),
    scaffoldBackgroundColor: ElioColors.white,
    fontFamily: 'Outfit',
    appBarTheme: const AppBarTheme(
      backgroundColor: ElioColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ElioColors.navy,
      ),
      iconTheme: IconThemeData(color: ElioColors.navy),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ElioColors.amber,
        foregroundColor: ElioColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ElioColors.navy,
        side: const BorderSide(color: ElioColors.navy, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ElioColors.navy,
        textStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ElioColors.offWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ElioColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ElioColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ElioColors.navy, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ElioColors.error),
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Outfit',
        color: ElioColors.textMuted,
        fontSize: 15,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return ElioColors.amber;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: ElioColors.border, width: 1.5),
    ),
    dividerTheme: const DividerThemeData(
      color: ElioColors.border,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ElioColors.navy,
      contentTextStyle: const TextStyle(
        fontFamily: 'Outfit',
        color: Colors.white,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
