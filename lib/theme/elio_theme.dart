import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// Elio Design System — Vibrant Editorial
// Design philosophy: warm, editorial, alive.
// A kitchen companion that feels like a trusted
// food magazine — confident, seasonal, expressive.
//
// Palette:
//   Dark        #121F0D  — primary text, deep earthy near-black
//   Amber       #FE9D00  — CTA buttons, highlights
//   HeroOrange  #A43D09  — hero headers, section backgrounds
//   WarmOrange  #E86F3B  — secondary accent, chips, tags
//   Scaffold    #FFF6EB  — screen background (warm cream)
//   CardSurface #F3E9DE  — card and input backgrounds
//   White       #FFFFFF  — text on dark, overlays
//   Taupe       #73594C  — secondary text, subdued UI
//   Peach       #FFB599  — decorative, soft accents
//   Error       #BA1A1A  — errors, destructive actions
//   Success     #3D9970  — success states (unchanged)
//
// Typography: Plus Jakarta Sans via google_fonts package
// ─────────────────────────────────────────────

class ElioColors {
  ElioColors._();

  // Core
  static const Color dark        = Color(0xFF121F0D); // primary text & dark surfaces
  static const Color amber       = Color(0xFFFE9D00); // CTA buttons, highlights
  static const Color heroOrange  = Color(0xFFA43D09); // hero headers, big section fills
  static const Color warmOrange  = Color(0xFFE86F3B); // secondary accent, chips, tags
  static const Color white       = Color(0xFFFFFFFF); // text on dark, overlays
  static const Color scaffold    = Color(0xFFFFF6EB); // screen background
  static const Color cardSurface = Color(0xFFF3E9DE); // cards, inputs, list tiles
  static const Color taupe       = Color(0xFF73594C); // secondary/subdued text
  static const Color darkAmber   = Color(0xFF885200); // deep amber detail
  static const Color peach       = Color(0xFFFFB599); // decorative soft accent

  // Semantic
  static const Color textPrimary   = Color(0xFF121F0D);
  static const Color textSecondary = Color(0xFF73594C);
  static const Color textMuted     = Color(0xFF73594C); // use withOpacity(0.6) for muted
  static const Color textOnDark    = Color(0xFFFFFFFF); // text on heroOrange / dark
  static const Color border        = Color(0xFFF3E9DE); // dividers, input borders
  static const Color error         = Color(0xFFBA1A1A);
  static const Color success       = Color(0xFF3D9970);

  // Legacy alias — kept for backward compatibility during migration
  // Remove once all screens are updated to new token names.
  static const Color navy     = dark;
  static const Color offWhite = cardSurface;
  static const Color sky      = Color(0xFF4A90D9); // not in new palette — review usage
}

// ─── Text styles using GoogleFonts.plusJakartaSans() ─────────────────────────
// These are getters (not constants) because GoogleFonts returns a new
// TextStyle object each time — it cannot be a compile-time const.

class ElioText {
  ElioText._();

  // Hero display — large editorial headlines (home screen, recipe title)
  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontSize: 48,
        fontWeight: FontWeight.w400,
        color: ElioColors.textOnDark,
        height: 1.0,
        letterSpacing: -1.2,
      );

  // Section headings, card titles
  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: ElioColors.textPrimary,
        height: 1.15,
        letterSpacing: -0.6,
      );

  // Screen titles, prominent headings
  static TextStyle get headingLarge => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: ElioColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.3,
      );

  // Sub-headings, card section labels
  static TextStyle get headingMedium => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ElioColors.textPrimary,
        height: 1.3,
      );

  // Body copy
  static TextStyle get bodyLarge => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: ElioColors.textPrimary,
        height: 1.6,
      );

  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: ElioColors.textPrimary,
        height: 1.5,
      );

  // Labels, tags, chips, captions
  static TextStyle get label => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: ElioColors.textPrimary,
        letterSpacing: 0.2,
      );

  // AppBar title
  static TextStyle get appBarTitle => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ElioColors.textPrimary,
      );
}

ThemeData elioTheme() {
  final jakartaTextTheme = GoogleFonts.plusJakartaSansTextTheme();

  return ThemeData(
    useMaterial3: true,
    textTheme: jakartaTextTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ElioColors.dark,
      brightness: Brightness.light,
    ).copyWith(
      primary:     ElioColors.dark,
      secondary:   ElioColors.amber,
      surface:     ElioColors.scaffold,
      onPrimary:   ElioColors.white,
      onSecondary: ElioColors.white,
      error:       ElioColors.error,
    ),
    scaffoldBackgroundColor: ElioColors.scaffold,
    appBarTheme: AppBarTheme(
      backgroundColor: ElioColors.scaffold,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: ElioText.appBarTitle,
      iconTheme: const IconThemeData(color: ElioColors.dark),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ElioColors.amber,
        foregroundColor: ElioColors.dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ElioColors.dark,
        side: const BorderSide(color: ElioColors.dark, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ElioColors.dark,
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ElioColors.cardSurface,
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
        borderSide: const BorderSide(color: ElioColors.dark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ElioColors.error),
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        color: ElioColors.textMuted,
        fontSize: 15,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return ElioColors.amber;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(ElioColors.dark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: ElioColors.border, width: 1.5),
    ),
    dividerTheme: const DividerThemeData(
      color: ElioColors.border,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ElioColors.dark,
      contentTextStyle: GoogleFonts.plusJakartaSans(
        color: ElioColors.white,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
