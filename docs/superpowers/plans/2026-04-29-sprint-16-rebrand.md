# Sprint 16 Rebrand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Elio's UI from the navy/amber/Outfit identity to Kate's 2026 cream/terracotta/Bricolage design language in a single hard-rename branch (`sprint/16-rebrand`), bundling fonts as assets, introducing D-rule heading widgets, restyling every existing widget, and hand-tuning the 9 Kate-delivered screens.

**Architecture:** Phased migration. Phase 1 lays foundations (tokens, fonts, theme, new heading widgets). Phase 2 sweeps `GoogleFonts.` and renames colour token symbols across the codebase under brief V1+V2 coexistence so `flutter analyze` stays green per commit. Phase 3 restyles every `lib/widgets/elio/` widget. Phase 4 hand-tunes the 6 Kate-blessed screens (onboarding splash, onboarding question, home, pantry, dietary & allergens, recipe detail). Phase 5 deletes legacy code, drops `google_fonts`, and ships APK.

**Tech Stack:** Flutter 3.27.x / Dart, Material 3, `flutter_svg` (new dep), bundled TTF fonts (Bricolage Grotesque + DM Sans + DM Mono), existing `google_fonts` package removed at end. No backend changes.

**Spec:** `docs/superpowers/specs/2026-04-29-sprint-16-rebrand-design.md` (read for visual specs, palette, type roles).

---

## Phase 0 — Branch state and pre-flight

### Task 1: Confirm branch state and acquire fonts

**Files:**
- Read: `pubspec.yaml`
- Create: `assets/fonts/bricolage_grotesque/BricolageGrotesque-VariableFont.ttf`
- Create: `assets/fonts/dm_sans/DMSans-VariableFont.ttf`
- Create: `assets/fonts/dm_mono/DMMono-Regular.ttf`
- Create: `assets/fonts/dm_mono/DMMono-Medium.ttf`

- [ ] **Step 1: Confirm current branch is `sprint/16-rebrand`**

```bash
git -C C:/Users/robth/.claude/ELio/elio-app branch --show-current
```

Expected: `sprint/16-rebrand`. If not, `git checkout sprint/16-rebrand`. The branch was created off `sprint/16` at `7140169` earlier.

- [ ] **Step 2: Download Bricolage Grotesque variable font**

Source: https://fonts.google.com/specimen/Bricolage+Grotesque (download family ZIP).

Place the variable font file at:
`C:/Users/robth/.claude/ELio/elio-app/assets/fonts/bricolage_grotesque/BricolageGrotesque-VariableFont.ttf`

The filename Google ships is `BricolageGrotesque[opsz,wdth,wght].ttf`. Rename to `BricolageGrotesque-VariableFont.ttf` for filesystem-friendliness (no brackets in path).

- [ ] **Step 3: Download DM Sans variable font**

Source: https://fonts.google.com/specimen/DM+Sans

Place at: `assets/fonts/dm_sans/DMSans-VariableFont.ttf` (rename from `DMSans[opsz,wght].ttf`).

- [ ] **Step 4: Download DM Mono Regular and Medium statics**

Source: https://fonts.google.com/specimen/DM+Mono

Place at:
- `assets/fonts/dm_mono/DMMono-Regular.ttf`
- `assets/fonts/dm_mono/DMMono-Medium.ttf`

- [ ] **Step 5: Verify font files are valid**

Run on each TTF:

```bash
file assets/fonts/bricolage_grotesque/BricolageGrotesque-VariableFont.ttf
file assets/fonts/dm_sans/DMSans-VariableFont.ttf
file assets/fonts/dm_mono/DMMono-Regular.ttf
file assets/fonts/dm_mono/DMMono-Medium.ttf
```

Expected output for each: `TrueType Font data, ...` (or similar from the `file` utility). On Windows without `file`, open each in Windows Font Viewer to confirm it loads.

- [ ] **Step 6: Commit fonts**

```bash
git add assets/fonts/
git commit -m "feat(sprint-16-rebrand): bundle Bricolage Grotesque / DM Sans / DM Mono font assets"
```

---

### Task 2: Acquire kale-leaf SVG illustration

**Files:**
- Create: `assets/illustrations/backdrop_kale.svg`

- [ ] **Step 1: Export the kale leaf from Figma**

In Figma desktop, open the Elio design file (`BOcjrItjk36Mtjgofqq6qV`), select the kale-leaf decorative layer used as backdrop on the Home frame (`node 76:1118`). Right-click → **Copy/Paste as → Copy as SVG**, then paste into a new file at:
`C:/Users/robth/.claude/ELio/elio-app/assets/illustrations/backdrop_kale.svg`

If Figma export is unavailable, save a 2× PNG instead at `assets/illustrations/backdrop_kale@2x.png` and adjust §Task 11 to load with `Image.asset` instead of `SvgPicture.asset`.

- [ ] **Step 2: Verify SVG renders**

Open the file in a browser:

```bash
start assets/illustrations/backdrop_kale.svg
```

Expected: a single-colour kale-leaf outline renders. The colour will be replaced at runtime via `ColorFilter`, so any source colour is fine.

- [ ] **Step 3: Commit illustration**

```bash
git add assets/illustrations/
git commit -m "feat(sprint-16-rebrand): add kale-leaf backdrop SVG"
```

---

### Task 3: Add `flutter_svg` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Read current pubspec to find dependencies block**

```bash
grep -n "^dependencies:" pubspec.yaml
```

- [ ] **Step 2: Add `flutter_svg` under dependencies**

In `pubspec.yaml`, add after the existing `google_fonts:` line (which we'll remove later in Task 35):

```yaml
  flutter_svg: ^2.0.10
```

- [ ] **Step 3: Run `flutter pub get`**

```bash
flutter pub get
```

Expected: `Got dependencies!` plus possibly upgrade messages. No errors.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(sprint-16-rebrand): add flutter_svg for backdrop illustration"
```

---

### Task 4: Declare font assets in pubspec

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add font and asset declarations under `flutter:` block**

In `pubspec.yaml`, locate the `flutter:` block (typically near bottom). Add or extend the `assets:` and `fonts:` keys:

```yaml
flutter:
  uses-material-design: true

  assets:
    - assets/illustrations/

  fonts:
    - family: Bricolage Grotesque
      fonts:
        - asset: assets/fonts/bricolage_grotesque/BricolageGrotesque-VariableFont.ttf
    - family: DM Sans
      fonts:
        - asset: assets/fonts/dm_sans/DMSans-VariableFont.ttf
    - family: DM Mono
      fonts:
        - asset: assets/fonts/dm_mono/DMMono-Regular.ttf
        - asset: assets/fonts/dm_mono/DMMono-Medium.ttf
          weight: 500
```

If `assets:` already lists other entries, append `assets/illustrations/` to that list rather than overwriting.

- [ ] **Step 2: Run `flutter pub get`**

```bash
flutter pub get
```

Expected: no errors.

- [ ] **Step 3: Sanity-check fonts load by running a smoke build**

```bash
flutter analyze
```

Expected: clean (no errors related to fonts; existing project warnings, if any, unchanged).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml
git commit -m "chore(sprint-16-rebrand): declare bundled fonts and illustrations in pubspec"
```

---

## Phase 1 — Theme foundation

### Task 5: Add new colour tokens alongside existing tokens

**Files:**
- Modify: `lib/theme/elio_theme.dart`
- Test: `test/theme/elio_colors_test.dart` (create)

This task does NOT remove old tokens (navy/amber/sky). It adds new ones. Removal happens in Task 31 after every caller migrates.

- [ ] **Step 1: Write the failing test**

Create `test/theme/elio_colors_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/theme/elio_theme.dart';

void main() {
  group('ElioColors new palette tokens', () {
    test('cream is #F4ECE0', () {
      expect(ElioColors.cream, const Color(0xFFF4ECE0));
    });
    test('creamDeep is #EFE3D2', () {
      expect(ElioColors.creamDeep, const Color(0xFFEFE3D2));
    });
    test('terracotta is #E37B53', () {
      expect(ElioColors.terracotta, const Color(0xFFE37B53));
    });
    test('peach is #F2C9A8', () {
      expect(ElioColors.peach, const Color(0xFFF2C9A8));
    });
    test('espresso is #2A1F1A', () {
      expect(ElioColors.espresso, const Color(0xFF2A1F1A));
    });
    test('mocha is #6B5A4F', () {
      expect(ElioColors.mocha, const Color(0xFF6B5A4F));
    });
    test('rule is #D7C5B0', () {
      expect(ElioColors.rule, const Color(0xFFD7C5B0));
    });
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

```bash
flutter test test/theme/elio_colors_test.dart
```

Expected: FAIL — undefined getters.

- [ ] **Step 3: Add new tokens to `ElioColors` class in `lib/theme/elio_theme.dart`**

Append to the existing `ElioColors` class (do NOT remove existing tokens yet):

```dart
  // ─── Sprint 16 rebrand: new palette tokens ──────────────────────────
  // These supersede navy/amber/sky/offWhite/border. Old tokens stay
  // until every caller migrates (Task 31), then they are removed.
  static const Color cream = Color(0xFFF4ECE0);
  static const Color creamDeep = Color(0xFFEFE3D2);
  static const Color terracotta = Color(0xFFE37B53);
  static const Color peach = Color(0xFFF2C9A8);
  static const Color espresso = Color(0xFF2A1F1A);
  static const Color mocha = Color(0xFF6B5A4F);
  static const Color rule = Color(0xFFD7C5B0);
```

- [ ] **Step 4: Run test, verify it passes**

```bash
flutter test test/theme/elio_colors_test.dart
```

Expected: 7 passed.

- [ ] **Step 5: Run full analyze to confirm no regression**

```bash
flutter analyze
```

Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add lib/theme/elio_theme.dart test/theme/elio_colors_test.dart
git commit -m "feat(sprint-16-rebrand): add cream/terracotta/espresso palette tokens

New tokens live alongside navy/amber/sky during widget migration.
Old tokens removed in Task 31 once every caller has migrated."
```

---

### Task 6: Refresh `ElioRadii` to spec values

**Files:**
- Modify: `lib/theme/elio_radii.dart`
- Test: `test/theme/elio_radii_test.dart` (create)

- [ ] **Step 1: Read current `ElioRadii` to know baseline**

```bash
cat lib/theme/elio_radii.dart
```

- [ ] **Step 2: Write the failing test**

Create `test/theme/elio_radii_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/theme/elio_radii.dart';

void main() {
  group('ElioRadii rebrand values', () {
    test('chip is 999 (full pill)', () {
      expect(ElioRadii.chip, 999.0);
    });
    test('button is 20', () {
      expect(ElioRadii.button, 20.0);
    });
    test('card is 16', () {
      expect(ElioRadii.card, 16.0);
    });
    test('panel is 14', () {
      expect(ElioRadii.panel, 14.0);
    });
    test('input is 14', () {
      expect(ElioRadii.input, 14.0);
    });
  });
}
```

- [ ] **Step 3: Run test, verify it fails**

```bash
flutter test test/theme/elio_radii_test.dart
```

Expected: FAIL.

- [ ] **Step 4: Update `lib/theme/elio_radii.dart`**

Replace the file with:

```dart
/// Rounded-corner scale for the Sprint 16 rebrand.
///
/// Sourced from spec §6 (`docs/superpowers/specs/2026-04-29-sprint-16-rebrand-design.md`).
class ElioRadii {
  ElioRadii._();

  /// Full pill — used on chips and ingredient pills.
  static const double chip = 999.0;

  /// Primary CTA, peach pill, action tiles.
  static const double button = 20.0;

  /// Bento tiles, option cards, tier rows.
  static const double card = 16.0;

  /// Feedback bar, stat pill row.
  static const double panel = 14.0;

  /// Text fields.
  static const double input = 14.0;

  // Legacy aliases — kept until widgets migrate. Removed in Task 31.
  static const double small = panel;
  static const double medium = card;
  static const double large = button;
}
```

- [ ] **Step 5: Run test, verify it passes**

```bash
flutter test test/theme/elio_radii_test.dart && flutter analyze
```

Expected: tests pass, analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/theme/elio_radii.dart test/theme/elio_radii_test.dart
git commit -m "feat(sprint-16-rebrand): refresh ElioRadii to chip/button/card/panel/input scale"
```

---

### Task 7: Add new `ElioTextStyles` ramp using bundled fonts

**Files:**
- Modify: `lib/theme/elio_text_styles.dart`
- Test: `test/theme/elio_text_styles_test.dart` (create)

This adds the new ramp ALONGSIDE the existing one. Old `ElioTextStyles.heroDisplay` etc. (using Outfit/Quicksand via google_fonts) are kept until widgets migrate. New roles get unique names: `pageTitle`, `sectionHeading`, `lede`, `bodyMono`, etc.

- [ ] **Step 1: Write the failing test**

Create `test/theme/elio_text_styles_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/theme/elio_text_styles.dart';
import 'package:elio/theme/elio_theme.dart';

void main() {
  group('ElioTextStyles rebrand ramp', () {
    test('pageTitleStyle uses Bricolage Grotesque w800 size 54', () {
      final s = ElioTextStyles.pageTitleStyle;
      expect(s.fontFamily, 'Bricolage Grotesque');
      expect(s.fontWeight, FontWeight.w800);
      expect(s.fontSize, 54);
      expect(s.color, ElioColors.espresso);
    });
    test('sectionHeadingStyle uses Bricolage Grotesque w700 size 24', () {
      final s = ElioTextStyles.sectionHeadingStyle;
      expect(s.fontFamily, 'Bricolage Grotesque');
      expect(s.fontWeight, FontWeight.w700);
      expect(s.fontSize, 24);
    });
    test('bodyStyle uses DM Sans w400 size 16', () {
      final s = ElioTextStyles.bodyStyle;
      expect(s.fontFamily, 'DM Sans');
      expect(s.fontWeight, FontWeight.w400);
      expect(s.fontSize, 16);
    });
    test('eyebrowStyle uses DM Mono uppercase tracked-out', () {
      final s = ElioTextStyles.eyebrowStyle;
      expect(s.fontFamily, 'DM Mono');
      expect(s.fontWeight, FontWeight.w500);
      expect(s.letterSpacing, isNotNull);
      expect(s.letterSpacing! > 0, true);
    });
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

```bash
flutter test test/theme/elio_text_styles_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Add new ramp to `lib/theme/elio_text_styles.dart`**

Append to the existing `ElioTextStyles` class (do NOT remove old entries yet):

```dart
  // ─── Sprint 16 rebrand: bundled-font ramp ─────────────────────────
  // These use the bundled Bricolage Grotesque / DM Sans / DM Mono
  // font assets declared in pubspec.yaml. They replace the old
  // GoogleFonts.outfit() / GoogleFonts.quicksand() entries above.
  // The old entries are removed in Task 31.

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
```

Remove the existing `import 'package:google_fonts/google_fonts.dart';` only if no other declarations in this file use `GoogleFonts`. Otherwise leave it.

- [ ] **Step 4: Run test, verify it passes**

```bash
flutter test test/theme/elio_text_styles_test.dart && flutter analyze
```

Expected: pass + clean.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/elio_text_styles.dart test/theme/elio_text_styles_test.dart
git commit -m "feat(sprint-16-rebrand): add bundled-font type ramp (page/section/lede/body/eyebrow)"
```

---

### Task 8: Update `elioTheme()` to use the new TextTheme

**Files:**
- Modify: `lib/theme/elio_theme.dart`
- Test: `test/theme/elio_theme_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `test/theme/elio_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/theme/elio_theme.dart';

void main() {
  group('elioTheme()', () {
    test('uses cream as scaffoldBackgroundColor', () {
      final t = elioTheme();
      expect(t.scaffoldBackgroundColor, ElioColors.cream);
    });
    test('primary colour is terracotta', () {
      final t = elioTheme();
      expect(t.colorScheme.primary, ElioColors.terracotta);
    });
    test('text theme bodyMedium uses DM Sans', () {
      final t = elioTheme();
      expect(t.textTheme.bodyMedium?.fontFamily, 'DM Sans');
    });
    test('text theme displayLarge uses Bricolage Grotesque', () {
      final t = elioTheme();
      expect(t.textTheme.displayLarge?.fontFamily, 'Bricolage Grotesque');
    });
    test('elevatedButton background is terracotta', () {
      final t = elioTheme();
      final style = t.elevatedButtonTheme.style;
      expect(style, isNotNull);
      final bg = style!.backgroundColor?.resolve(<WidgetState>{});
      expect(bg, ElioColors.terracotta);
    });
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

```bash
flutter test test/theme/elio_theme_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Replace the `elioTheme()` function in `lib/theme/elio_theme.dart`**

Replace the entire `elioTheme()` function body (keep the function signature). Drop the `GoogleFonts.outfitTextTheme()` call.

```dart
import 'package:flutter/material.dart';
// Remove: import 'package:google_fonts/google_fonts.dart';
import 'elio_text_styles.dart';

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
```

Add the import at the top: `import 'elio_radii.dart';`

- [ ] **Step 4: Run test, verify it passes**

```bash
flutter test test/theme/elio_theme_test.dart
```

Expected: 5 passed.

- [ ] **Step 5: Run full analyze**

```bash
flutter analyze
```

Expected: clean OR errors only on existing screens that read from `Theme.of(context)` and now get different colours. Such errors are surface-level (not compile errors) and resolve in subsequent tasks. If `flutter analyze` reports compile errors, stop and investigate.

- [ ] **Step 6: Run all existing tests to confirm nothing broke**

```bash
flutter test
```

Expected: all 325 existing tests still pass. Theme changes only affect appearance, not logic.

- [ ] **Step 7: Commit**

```bash
git add lib/theme/elio_theme.dart test/theme/elio_theme_test.dart
git commit -m "feat(sprint-16-rebrand): rewrite elioTheme() with bundled fonts and new palette"
```

---

## Phase 2 — Heading widgets (D rule)

### Task 9: Build `ElioPageTitle` with terracotta period detection

**Files:**
- Create: `lib/widgets/elio/elio_page_title.dart`
- Test: `test/widgets/elio_page_title_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/elio_page_title_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/elio/elio_page_title.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    theme: elioTheme(),
    home: Scaffold(body: child),
  ));
}

void main() {
  group('ElioPageTitle', () {
    testWidgets('renders the text', (tester) async {
      await _pump(tester, const ElioPageTitle('hey kate'));
      expect(find.text('hey kate'), findsOneWidget);
    });

    testWidgets('lowercases the text via fontFeatures-free string', (tester) async {
      // Text is rendered as-authored. Caller should pass lowercase.
      // We test that capital input is preserved (no auto-lowercase).
      await _pump(tester, const ElioPageTitle('Hey Kate'));
      expect(find.text('Hey Kate'), findsOneWidget);
    });

    testWidgets('renders any . glyph in terracotta via TextSpan', (tester) async {
      await _pump(tester, const ElioPageTitle('hey kate. lets get started'));
      // Find the RichText / Text.rich and inspect spans.
      final richTextFinder = find.byType(RichText).last;
      final richText = tester.widget<RichText>(richTextFinder);
      final span = richText.text;
      expect(span, isA<TextSpan>());
      final textSpan = span as TextSpan;
      // Walk children, count terracotta-coloured spans.
      final terracottaCount = _countSpansWithColor(textSpan, ElioColors.terracotta);
      // Source has one '.' → exactly one terracotta span.
      expect(terracottaCount, 1);
    });

    testWidgets('terminal . is also terracotta', (tester) async {
      await _pump(tester,
          const ElioPageTitle('tonights dinner, from what you already have.'));
      final richText = tester.widget<RichText>(find.byType(RichText).last);
      final terracottaCount =
          _countSpansWithColor(richText.text as TextSpan, ElioColors.terracotta);
      expect(terracottaCount, 1);
    });

    testWidgets('strings without . have zero terracotta spans', (tester) async {
      await _pump(tester, const ElioPageTitle('creamy lemon pasta'));
      final richText = tester.widget<RichText>(find.byType(RichText).last);
      final terracottaCount =
          _countSpansWithColor(richText.text as TextSpan, ElioColors.terracotta);
      expect(terracottaCount, 0);
    });

    testWidgets('? does not become terracotta', (tester) async {
      await _pump(tester, const ElioPageTitle('what brought you to elio?'));
      final richText = tester.widget<RichText>(find.byType(RichText).last);
      final terracottaCount =
          _countSpansWithColor(richText.text as TextSpan, ElioColors.terracotta);
      expect(terracottaCount, 0);
    });

    testWidgets('two . in same string both become terracotta', (tester) async {
      // Hypothetical edge case; D-rule treats every . the same.
      await _pump(tester, const ElioPageTitle('one. two.'));
      final richText = tester.widget<RichText>(find.byType(RichText).last);
      final terracottaCount =
          _countSpansWithColor(richText.text as TextSpan, ElioColors.terracotta);
      expect(terracottaCount, 2);
    });
  });
}

int _countSpansWithColor(TextSpan root, Color color) {
  var count = 0;
  void walk(InlineSpan s) {
    if (s is TextSpan) {
      if (s.style?.color == color && (s.text == '.' || s.text?.contains('.') == true)) {
        // Only count if this span IS the period (not a parent span tinted differently)
        if (s.text == '.') count++;
      }
      final children = s.children;
      if (children != null) {
        for (final c in children) {
          walk(c);
        }
      }
    }
  }
  walk(root);
  return count;
}
```

- [ ] **Step 2: Run the test, verify it fails**

```bash
flutter test test/widgets/elio_page_title_test.dart
```

Expected: FAIL — `ElioPageTitle` not found.

- [ ] **Step 3: Implement `ElioPageTitle`**

Create `lib/widgets/elio/elio_page_title.dart`:

```dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';

/// Hero / page-title heading.
///
/// Renders [text] in Bricolage Grotesque ExtraBold (800), espresso, with
/// every `.` glyph rendered in terracotta — the **D rule** from the
/// Sprint 16 rebrand spec (§5).
///
/// The caller should author the string in the case they want rendered;
/// no auto-lowercasing is applied, since onboarding question screens may
/// authorically choose to capitalise.
///
/// Examples:
/// ```dart
/// ElioPageTitle('hey kate. lets get started')   // mid-string . is terracotta
/// ElioPageTitle('tonights dinner.')              // terminal . is terracotta
/// ElioPageTitle('creamy lemon pasta')            // no terracotta
/// ElioPageTitle('what brought you to elio?')     // no terracotta (no .)
/// ```
class ElioPageTitle extends StatelessWidget {
  const ElioPageTitle(
    this.text, {
    super.key,
    this.fontSize,
    this.textAlign,
  });

  final String text;
  final double? fontSize;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = ElioTextStyles.pageTitleStyle.copyWith(
      fontSize: fontSize ?? ElioTextStyles.pageTitleStyle.fontSize,
    );

    final spans = <TextSpan>[];
    final buffer = StringBuffer();

    for (final char in text.split('')) {
      if (char == '.') {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(text: buffer.toString()));
          buffer.clear();
        }
        spans.add(const TextSpan(
          text: '.',
          style: TextStyle(color: ElioColors.terracotta),
        ));
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString()));
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      textAlign: textAlign,
    );
  }
}
```

- [ ] **Step 4: Run the test, verify it passes**

```bash
flutter test test/widgets/elio_page_title_test.dart
```

Expected: 7 passed.

- [ ] **Step 5: Run full analyze**

```bash
flutter analyze
```

Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/elio/elio_page_title.dart test/widgets/elio_page_title_test.dart
git commit -m "feat(sprint-16-rebrand): add ElioPageTitle with D-rule period detection"
```

---

### Task 10: Add `ElioHeroDisplay` and `ElioSectionHeading`

**Files:**
- Modify: `lib/widgets/elio/elio_page_title.dart` (add `ElioHeroDisplay` alias)
- Create: `lib/widgets/elio/elio_section_heading.dart`
- Test: `test/widgets/elio_section_heading_test.dart`

- [ ] **Step 1: Write the failing test for `ElioSectionHeading`**

Create `test/widgets/elio_section_heading_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/theme/elio_text_styles.dart';
import 'package:elio/widgets/elio/elio_section_heading.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    theme: elioTheme(),
    home: Scaffold(body: child),
  ));
}

void main() {
  group('ElioSectionHeading', () {
    testWidgets('renders the text', (tester) async {
      await _pump(tester, const ElioSectionHeading('Ingredients'));
      expect(find.text('Ingredients'), findsOneWidget);
    });

    testWidgets('uses sectionHeadingStyle from ElioTextStyles', (tester) async {
      await _pump(tester, const ElioSectionHeading('Pantry Builder'));
      final textWidget = tester.widget<Text>(find.text('Pantry Builder'));
      expect(textWidget.style?.fontFamily, ElioTextStyles.sectionHeadingStyle.fontFamily);
      expect(textWidget.style?.fontWeight, ElioTextStyles.sectionHeadingStyle.fontWeight);
      expect(textWidget.style?.fontSize, ElioTextStyles.sectionHeadingStyle.fontSize);
    });

    testWidgets('does NOT lowercase or recolor any character', (tester) async {
      // Section heading text is rendered as authored.
      await _pump(tester, const ElioSectionHeading('Custom allergens or dietary requirements'));
      expect(find.text('Custom allergens or dietary requirements'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the test, verify it fails**

```bash
flutter test test/widgets/elio_section_heading_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement `ElioSectionHeading`**

Create `lib/widgets/elio/elio_section_heading.dart`:

```dart
import 'package:flutter/material.dart';
import '../../theme/elio_text_styles.dart';

/// Section heading — Bricolage Grotesque Bold (700), sentence case as authored,
/// espresso colour, no period treatment.
///
/// Used for in-page section labels: "Ingredients", "Pantry Builder",
/// "Custom allergens or dietary requirements", etc.
class ElioSectionHeading extends StatelessWidget {
  const ElioSectionHeading(this.text, {super.key, this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: ElioTextStyles.sectionHeadingStyle,
      textAlign: textAlign,
    );
  }
}
```

- [ ] **Step 4: Add `ElioHeroDisplay` alias to `lib/widgets/elio/elio_page_title.dart`**

Append at the end of `elio_page_title.dart`:

```dart
/// Hero display — same rendering as [ElioPageTitle] with a larger default
/// font size (64). Use on splash / cover screens.
class ElioHeroDisplay extends StatelessWidget {
  const ElioHeroDisplay(this.text, {super.key, this.fontSize = 64, this.textAlign});

  final String text;
  final double fontSize;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ElioPageTitle(text, fontSize: fontSize, textAlign: textAlign);
  }
}
```

- [ ] **Step 5: Run all heading tests**

```bash
flutter test test/widgets/elio_page_title_test.dart test/widgets/elio_section_heading_test.dart
```

Expected: all pass.

- [ ] **Step 6: Run analyze**

```bash
flutter analyze
```

Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/elio/elio_page_title.dart lib/widgets/elio/elio_section_heading.dart test/widgets/elio_section_heading_test.dart
git commit -m "feat(sprint-16-rebrand): add ElioHeroDisplay alias and ElioSectionHeading widget"
```

---

### Task 11: Build `ElioBackdropIllustration` widget

**Files:**
- Create: `lib/widgets/elio/elio_backdrop_illustration.dart`
- Test: `test/widgets/elio_backdrop_illustration_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/elio_backdrop_illustration_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/elio/elio_backdrop_illustration.dart';

void main() {
  testWidgets('ElioBackdropIllustration renders the kale SVG asset', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(
        body: Stack(children: [ElioBackdropIllustration()]),
      ),
    ));
    // SvgPicture.asset is the implementation; check it is present.
    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test, verify it fails**

```bash
flutter test test/widgets/elio_backdrop_illustration_test.dart
```

Expected: FAIL — widget not found.

- [ ] **Step 3: Implement `ElioBackdropIllustration`**

Create `lib/widgets/elio/elio_backdrop_illustration.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/elio_theme.dart';

/// Full-app brand backdrop. Single hardcoded variant (kale leaf) for now;
/// add a `Variant` enum when a second illustration ships (spec §7).
///
/// Place inside a [Stack] behind the page content. Designed to be inserted
/// by [ElioAppScaffold] but also usable directly.
class ElioBackdropIllustration extends StatelessWidget {
  const ElioBackdropIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      right: -120, // bleeds off the right edge by ~30%
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.12,
          child: SvgPicture.asset(
            'assets/illustrations/backdrop_kale.svg',
            colorFilter: const ColorFilter.mode(
              ElioColors.mocha,
              BlendMode.srcIn,
            ),
            fit: BoxFit.fitHeight,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test, verify it passes**

```bash
flutter test test/widgets/elio_backdrop_illustration_test.dart
```

Expected: 1 passed.

- [ ] **Step 5: Run analyze**

```bash
flutter analyze
```

Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/elio/elio_backdrop_illustration.dart test/widgets/elio_backdrop_illustration_test.dart
git commit -m "feat(sprint-16-rebrand): add ElioBackdropIllustration kale-leaf widget"
```

---

### Task 12: Insert backdrop into `ElioAppScaffold`

**Files:**
- Modify: `lib/widgets/elio/elio_app_scaffold.dart`
- Test: `test/widgets/elio_app_scaffold_test.dart` (extend)

- [ ] **Step 1: Read current `ElioAppScaffold` to understand structure**

```bash
cat lib/widgets/elio/elio_app_scaffold.dart
```

Note: the body content lives inside Scaffold.body. We will wrap it in a `Stack` with the backdrop as the first child.

- [ ] **Step 2: Write the failing test**

Append to (or create) `test/widgets/elio_app_scaffold_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/elio/elio_app_scaffold.dart';
import 'package:elio/widgets/elio/elio_backdrop_illustration.dart';

void main() {
  testWidgets('ElioAppScaffold inserts ElioBackdropIllustration behind body', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const ElioAppScaffold(
        body: Center(child: Text('Page content')),
      ),
    ));
    expect(find.byType(ElioBackdropIllustration), findsOneWidget);
    expect(find.text('Page content'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the test, verify it fails**

```bash
flutter test test/widgets/elio_app_scaffold_test.dart
```

Expected: FAIL — backdrop not present.

- [ ] **Step 4: Modify `lib/widgets/elio/elio_app_scaffold.dart`**

Find the `Scaffold(body: ...)` invocation. Replace whatever body widget is passed with:

```dart
Stack(
  fit: StackFit.expand,
  children: [
    const ElioBackdropIllustration(),
    body, // existing body widget passed into the scaffold
  ],
),
```

Add the import: `import 'elio_backdrop_illustration.dart';`

If the existing implementation already has a Stack around the body (e.g. for an overlay), insert `ElioBackdropIllustration()` as the second child (above the cream scaffold background, below all other content).

- [ ] **Step 5: Run the test, verify it passes**

```bash
flutter test test/widgets/elio_app_scaffold_test.dart
```

Expected: pass.

- [ ] **Step 6: Run all existing tests to confirm no regression**

```bash
flutter test
```

Expected: all pass. The backdrop is non-interactive (`IgnorePointer`) so existing tap-target tests should still work.

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/elio/elio_app_scaffold.dart test/widgets/elio_app_scaffold_test.dart
git commit -m "feat(sprint-16-rebrand): insert ElioBackdropIllustration into ElioAppScaffold"
```

---

## Phase 3 — `GoogleFonts` and old-token sweep across codebase

The next two tasks are mechanical sweeps. They affect ~20 files but are individually small.

### Task 13: Sweep `GoogleFonts.outfit(...)` callers in widget files

**Files modified:**
- `lib/widgets/elio/elio_top_app_bar.dart`
- `lib/widgets/elio/elio_bottom_nav.dart`
- `lib/widgets/elio/elio_secondary_card.dart`
- `lib/widgets/pantry_builder_sheet.dart`

- [ ] **Step 1: Grep to confirm caller list and counts**

```bash
grep -rn "GoogleFonts\." lib/widgets/
```

Expected output (approximately): the four files above.

- [ ] **Step 2: For each file, replace `GoogleFonts.outfit(...)` with the appropriate `ElioTextStyles.<role>` constant**

The mapping is:

| Old call | New replacement |
|---|---|
| `GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)` (top app bar title) | `ElioTextStyles.uiLabelStyle.copyWith(fontSize: 18)` |
| `GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.x)` (bottom nav label) | `ElioTextStyles.tabLabelStyle` |
| `GoogleFonts.quicksand(fontSize: 14, ...)` (body text) | `ElioTextStyles.bodySmallStyle` |
| Any other Outfit/Quicksand call | Map to closest ramp role per spec §4 |

Open each file. Replace every `GoogleFonts.foo(...)` call site.

- [ ] **Step 3: Remove unused `import 'package:google_fonts/google_fonts.dart';` lines**

For each modified file, if no `GoogleFonts` reference remains, remove the import.

- [ ] **Step 4: Add `import '../../theme/elio_text_styles.dart';`** (or matching relative path) where not already imported.

- [ ] **Step 5: Run analyze + tests to confirm no compilation errors**

```bash
flutter analyze
flutter test
```

Expected: both clean. Visual changes are deferred to per-widget restyle tasks; these edits only swap font sources.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/
git commit -m "chore(sprint-16-rebrand): replace GoogleFonts.outfit in widget files with ElioTextStyles"
```

---

### Task 14: Sweep `GoogleFonts.outfit(...)` callers in screens — batch 1 (auth + paywall + settings)

**Files modified:**
- `lib/screens/auth/email_login_screen.dart`
- `lib/screens/auth/email_register_screen.dart`
- `lib/screens/paywall/paywall_screen.dart`
- `lib/screens/profile/settings_screen.dart`
- `lib/screens/profile/notification_prefs_screen.dart`

- [ ] **Step 1: For each file, run a per-file grep to find each `GoogleFonts.` site**

```bash
grep -n "GoogleFonts\." lib/screens/auth/email_login_screen.dart
```

Repeat for each file in the batch.

- [ ] **Step 2: Replace each call site with the matching `ElioTextStyles.<role>`**

Use the same mapping as Task 13 step 2. Common pattern:

```dart
// before
Text('Email', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600))

// after
Text('Email', style: ElioTextStyles.uiLabelStyle.copyWith(fontSize: 14))
```

- [ ] **Step 3: Remove unused imports and add the `ElioTextStyles` import**

- [ ] **Step 4: Run analyze + tests**

```bash
flutter analyze
flutter test
```

Expected: clean + green.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/auth/ lib/screens/paywall/ lib/screens/profile/settings_screen.dart lib/screens/profile/notification_prefs_screen.dart
git commit -m "chore(sprint-16-rebrand): replace GoogleFonts in auth/paywall/profile screens"
```

---

### Task 15: Sweep `GoogleFonts.outfit(...)` callers in screens — batch 2 (account + history + household)

**Files modified:**
- `lib/screens/account/account_screen.dart`
- `lib/screens/history/history_screen.dart`
- `lib/screens/profile/household_screen.dart`

- [ ] **Step 1: Repeat the same pattern as Task 14**

- [ ] **Step 2: Run analyze + tests**

```bash
flutter analyze && flutter test
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/account/ lib/screens/history/ lib/screens/profile/household_screen.dart
git commit -m "chore(sprint-16-rebrand): replace GoogleFonts in account/history/household screens"
```

---

### Task 16: Sweep `GoogleFonts.outfit(...)` callers in screens — batch 3 (scanner + recipe + meal plan)

**Files modified:**
- `lib/screens/scanner/scanner_screen.dart`
- `lib/screens/scanner/scan_success_screen.dart`
- `lib/screens/scanner/receipt_results_screen.dart`
- `lib/screens/recipe/recipe_screen.dart`
- `lib/screens/profile/recipe_import_screen.dart`
- `lib/screens/home/bulk_prep_results_screen.dart`
- `lib/screens/meal_plan/meal_plan_screen.dart` (if it has GoogleFonts; otherwise skip)

- [ ] **Step 1: Repeat the pattern**

- [ ] **Step 2: Run analyze + tests**

- [ ] **Step 3: Commit**

```bash
git add lib/screens/scanner/ lib/screens/recipe/ lib/screens/profile/recipe_import_screen.dart lib/screens/home/bulk_prep_results_screen.dart lib/screens/meal_plan/
git commit -m "chore(sprint-16-rebrand): replace GoogleFonts in scanner/recipe/meal_plan screens"
```

- [ ] **Step 4: Confirm zero `GoogleFonts.` callers remain in `lib/`**

```bash
grep -rn "GoogleFonts\." lib/
```

Expected: only matches in `lib/theme/elio_theme.dart` if any remain there (we'll clean those in Task 35); zero in `lib/widgets/` and `lib/screens/`.

If the grep returns lines from `lib/screens/` or `lib/widgets/`, address them in this task before moving on.

---

### Task 17: Mechanical token rename — `ElioColors.navy` → `ElioColors.espresso`

**Files modified:** every file referencing `ElioColors.navy` (typically 30+ files).

- [ ] **Step 1: Confirm caller list**

```bash
grep -rln "ElioColors\.navy" lib/ test/
```

- [ ] **Step 2: Run a project-wide replace via Edit tool, file-by-file**

For each file, use the Edit tool with `replace_all: true`:

`old_string`: `ElioColors.navy`
`new_string`: `ElioColors.espresso`

Do this in commits of ~10 files at a time so the diff stays reviewable. (For a single agent inline, one commit covering all is acceptable.)

- [ ] **Step 3: Run analyze + tests**

```bash
flutter analyze && flutter test
```

Expected: clean + green. Visual differences are intentional — espresso is darker than the old navy.

- [ ] **Step 4: Commit**

```bash
git add lib/ test/
git commit -m "chore(sprint-16-rebrand): rename ElioColors.navy -> ElioColors.espresso (31+ callers)"
```

---

### Task 18: Mechanical token rename — `ElioColors.amber` → `ElioColors.terracotta`

- [ ] **Step 1: Confirm caller list**

```bash
grep -rln "ElioColors\.amber" lib/ test/
```

- [ ] **Step 2: Replace each occurrence**

`old_string`: `ElioColors.amber`
`new_string`: `ElioColors.terracotta`

- [ ] **Step 3: Run analyze + tests**

```bash
flutter analyze && flutter test
```

- [ ] **Step 4: Commit**

```bash
git add lib/ test/
git commit -m "chore(sprint-16-rebrand): rename ElioColors.amber -> ElioColors.terracotta"
```

---

### Task 19: Mechanical token rename — `ElioColors.sky` → context-appropriate replacement

`sky` doesn't have a clean 1-to-1 replacement. Per spec §2, use **peach** for fills and **mocha** for icons/text.

- [ ] **Step 1: List every `ElioColors.sky` use site with surrounding context**

```bash
grep -rn "ElioColors\.sky" lib/ test/ -B 1 -A 1
```

- [ ] **Step 2: For each site, decide peach or mocha**

| Context | Replace with |
|---|---|
| `Container(color: ElioColors.sky, ...)` (background fill) | `ElioColors.peach` |
| `Container(decoration: BoxDecoration(color: ElioColors.sky))` | `ElioColors.peach` |
| `Icon(..., color: ElioColors.sky)` | `ElioColors.mocha` |
| `Text(..., style: ...color: ElioColors.sky)` | `ElioColors.mocha` |
| `border: Border.all(color: ElioColors.sky)` | `ElioColors.mocha` |
| `BoxShadow(color: ElioColors.sky.withValues(alpha: …))` | `ElioColors.mocha` |

When the use is ambiguous (e.g. an accent-tinted divider that's both a border and a "decorative" colour), pick **mocha** — the safer default since most divider/border usage already used `rule` or `border`.

- [ ] **Step 3: Apply replacements per file**

Use the Edit tool per file with the chosen replacement. Do NOT use a single project-wide replace; the decision is contextual.

- [ ] **Step 4: Run analyze + tests**

```bash
flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/ test/
git commit -m "chore(sprint-16-rebrand): replace ElioColors.sky with peach (fills) or mocha (foreground)"
```

---

### Task 20: Mechanical token rename — `ElioColors.offWhite` → `ElioColors.cream`

- [ ] **Step 1: Confirm caller list**

```bash
grep -rln "ElioColors\.offWhite" lib/ test/
```

- [ ] **Step 2: Replace via Edit tool with `replace_all: true`**

`old_string`: `ElioColors.offWhite`
`new_string`: `ElioColors.cream`

- [ ] **Step 3: Also handle `ElioColors.white` if used as page bg**

```bash
grep -rn "ElioColors\.white" lib/ | grep -i "background\|scaffold\|surface"
```

For each match where `white` is being used as a background (not a literal pure-white text colour), replace with `ElioColors.cream`. Other uses (e.g. text on dark surface) keep `Colors.white`.

- [ ] **Step 4: Replace `ElioColors.border` → `ElioColors.rule`**

```bash
grep -rln "ElioColors\.border" lib/ test/
```

`old_string`: `ElioColors.border`
`new_string`: `ElioColors.rule`

- [ ] **Step 5: Replace `ElioColors.cream` (legacy) call sites — already correct since both old + new aliasing point to the same hex; no action**

The legacy `ElioColors.cream` token (added in Sprint 16 for warm-card backgrounds) was `#FBF3E7`. The new spec uses `#F4ECE0`. The new value supersedes — Step 1 of Task 5 already redefined `cream`. Existing call sites just inherit the new hex.

- [ ] **Step 6: Run analyze + tests**

```bash
flutter analyze && flutter test
```

- [ ] **Step 7: Commit**

```bash
git add lib/ test/
git commit -m "chore(sprint-16-rebrand): rename offWhite/white-bg/border tokens to cream/rule"
```

---

## Phase 4 — Widget restyles

Each widget restyle follows the same pattern: open the file, apply spec §8 to set its colours/fonts/radii to the new tokens. Some widgets need new sub-elements (e.g. `ElioBigButton` gets a chevron). Tests are widget-rendering tests that confirm the new tokens are applied.

### Task 21: Restyle `ElioBigButton` (primary CTA)

**Files:**
- Modify: `lib/widgets/elio/elio_big_button.dart`
- Test: `test/widgets/elio_big_button_test.dart`

- [ ] **Step 1: Read current implementation**

```bash
cat lib/widgets/elio/elio_big_button.dart
```

Note the current API surface: button text, onTap callback, optional icon, etc.

- [ ] **Step 2: Write the failing test**

Create or extend `test/widgets/elio_big_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/theme/elio_radii.dart';
import 'package:elio/widgets/elio/elio_big_button.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(theme: elioTheme(), home: Scaffold(body: child)));
}

void main() {
  testWidgets('ElioBigButton uses terracotta background and white text', (tester) async {
    await _pump(tester, ElioBigButton(label: 'Generate', onPressed: () {}));
    final container = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ElioBigButton), matching: find.byType(DecoratedBox)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, ElioColors.terracotta);
  });

  testWidgets('ElioBigButton uses pill radius (button = 20)', (tester) async {
    await _pump(tester, ElioBigButton(label: 'Generate', onPressed: () {}));
    final container = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ElioBigButton), matching: find.byType(DecoratedBox)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    final radius = (decoration.borderRadius as BorderRadius).topLeft;
    expect(radius, Radius.circular(ElioRadii.button));
  });

  testWidgets('ElioBigButton renders trailing chevron icon', (tester) async {
    await _pump(tester, ElioBigButton(label: 'Generate', onPressed: () {}));
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test, verify it fails**

```bash
flutter test test/widgets/elio_big_button_test.dart
```

Expected: FAIL.

- [ ] **Step 4: Restyle `lib/widgets/elio/elio_big_button.dart`**

Replace the build method (or relevant decoration) so:
- Background colour: `ElioColors.terracotta`
- Foreground colour: `Colors.white`
- Border radius: `ElioRadii.button` (20)
- Padding: `EdgeInsets.symmetric(horizontal: 24, vertical: 18)`
- Text: `ElioTextStyles.uiLabelStyle.copyWith(color: Colors.white)`
- Trailing icon: `Icons.chevron_right` in white, sized 24

If the existing widget supports an optional custom trailing icon (for the recipe-detail "infinity" CTA), keep that surface intact and default to `Icons.chevron_right`.

- [ ] **Step 5: Run test, verify it passes**

```bash
flutter test test/widgets/elio_big_button_test.dart
```

Expected: pass.

- [ ] **Step 6: Run analyze + full tests**

```bash
flutter analyze && flutter test
```

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/elio/elio_big_button.dart test/widgets/elio_big_button_test.dart
git commit -m "style(sprint-16-rebrand): restyle ElioBigButton to terracotta pill with chevron"
```

---

### Task 22: Restyle `ElioBottomNav` and rename `SHOPPING` → `SHOPPING LIST`

**Files:**
- Modify: `lib/widgets/elio/elio_bottom_nav.dart`
- Test: `test/widgets/elio_bottom_nav_test.dart`

- [ ] **Step 1: Read current implementation**

```bash
cat lib/widgets/elio/elio_bottom_nav.dart
```

Note: existing labels are likely `HOME / PANTRY / RECIPES / SHOPPING`. We're updating the last to `SHOPPING LIST`.

- [ ] **Step 2: Write the failing test**

Create or extend `test/widgets/elio_bottom_nav_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/elio/elio_bottom_nav.dart';

void main() {
  testWidgets('ElioBottomNav shows HOME / PANTRY / RECIPES / SHOPPING LIST', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: Scaffold(
        bottomNavigationBar: ElioBottomNav(currentIndex: 0, onTap: (_) {}),
      ),
    ));
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('PANTRY'), findsOneWidget);
    expect(find.text('RECIPES'), findsOneWidget);
    expect(find.text('SHOPPING LIST'), findsOneWidget);
    expect(find.text('SHOPPING'), findsNothing);
  });
}
```

- [ ] **Step 3: Run test, verify it fails**

- [ ] **Step 4: Update `lib/widgets/elio/elio_bottom_nav.dart`**

- Change the fourth tab label from `'SHOPPING'` to `'SHOPPING LIST'`.
- Replace any inline font style with `ElioTextStyles.tabLabelStyle` (or copy with active/idle colour override).
- Active tab: icon + label in `ElioColors.espresso`.
- Idle tab: icon + label in `ElioColors.mocha`.
- Use outline icons: `Icons.home_outlined`, `Icons.kitchen_outlined`, `Icons.menu_book_outlined`, `Icons.checklist_outlined` (or existing equivalent if the design uses different icons).

- [ ] **Step 5: Run tests + analyze**

```bash
flutter test test/widgets/elio_bottom_nav_test.dart && flutter analyze
```

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/elio/elio_bottom_nav.dart test/widgets/elio_bottom_nav_test.dart
git commit -m "style(sprint-16-rebrand): restyle ElioBottomNav and rename SHOPPING -> SHOPPING LIST"
```

---

### Task 23: Restyle `ElioTopAppBar`

**Files:**
- Modify: `lib/widgets/elio/elio_top_app_bar.dart`
- Test: `test/widgets/elio_top_app_bar_test.dart`

- [ ] **Step 1: Read current implementation**

```bash
cat lib/widgets/elio/elio_top_app_bar.dart
```

- [ ] **Step 2: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/elio/elio_top_app_bar.dart';

void main() {
  testWidgets('ElioTopAppBar shows lowercase elio wordmark', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: Scaffold(appBar: const ElioTopAppBar()),
    ));
    expect(find.text('elio'), findsOneWidget);
  });

  testWidgets('ElioTopAppBar wordmark uses Bricolage 800', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: Scaffold(appBar: const ElioTopAppBar()),
    ));
    final wordmark = tester.widget<Text>(find.text('elio'));
    expect(wordmark.style?.fontFamily, 'Bricolage Grotesque');
    expect(wordmark.style?.fontWeight, FontWeight.w800);
  });
}
```

- [ ] **Step 3: Run test, verify it fails**

- [ ] **Step 4: Update `lib/widgets/elio/elio_top_app_bar.dart`**

- Wordmark text: `'elio'` (lowercase).
- Style: `ElioTextStyles.pageTitleStyle.copyWith(fontSize: 28)` (or similar — measure on device).
- Background: `ElioColors.cream` (transparent over scaffold cream).
- Profile icon (right): existing `IconButton` with `Icons.account_circle_outlined`, color `ElioColors.espresso`.

- [ ] **Step 5: Run tests + analyze + commit**

```bash
flutter test test/widgets/elio_top_app_bar_test.dart && flutter analyze
git add lib/widgets/elio/elio_top_app_bar.dart test/widgets/elio_top_app_bar_test.dart
git commit -m "style(sprint-16-rebrand): restyle ElioTopAppBar with lowercase elio wordmark"
```

---

### Task 24: Restyle `ElioChip` (selectable pill)

**Files:**
- Modify: `lib/widgets/elio/elio_chip.dart`
- Test: `test/widgets/elio_chip_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/elio/elio_chip.dart';

void main() {
  testWidgets('ElioChip selected uses terracotta fill', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: Scaffold(body: ElioChip(label: 'Vegetarian', selected: true, onTap: () {})),
    ));
    final container = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ElioChip), matching: find.byType(DecoratedBox)).first,
    );
    expect((container.decoration as BoxDecoration).color, ElioColors.terracotta);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('ElioChip idle uses creamDeep fill, no tick', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: Scaffold(body: ElioChip(label: 'Vegetarian', selected: false, onTap: () {})),
    ));
    final container = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ElioChip), matching: find.byType(DecoratedBox)).first,
    );
    expect((container.decoration as BoxDecoration).color, ElioColors.creamDeep);
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

- [ ] **Step 3: Restyle `lib/widgets/elio/elio_chip.dart`**

- Selected: `BoxDecoration(color: ElioColors.terracotta, borderRadius: BorderRadius.circular(ElioRadii.chip))`, label colour white, trailing `Icon(Icons.check, color: Colors.white, size: 18)`.
- Idle: `BoxDecoration(color: ElioColors.creamDeep, borderRadius: BorderRadius.circular(ElioRadii.chip))`, label colour `ElioColors.espresso`, no icon.
- Padding: `EdgeInsets.symmetric(horizontal: 16, vertical: 10)`.
- Text style: `ElioTextStyles.uiLabelStyle.copyWith(color: <state-dependent>)`.

- [ ] **Step 4: Run tests + analyze + commit**

```bash
flutter test test/widgets/elio_chip_test.dart && flutter analyze
git add lib/widgets/elio/elio_chip.dart test/widgets/elio_chip_test.dart
git commit -m "style(sprint-16-rebrand): restyle ElioChip selected/idle states"
```

---

### Task 25: Restyle `ElioTierRow`, `ElioBentoCard`, `ElioSecondaryCard`

These three widgets share the cream-deep panel pattern. Restyle in a single task with shared conventions.

**Files:**
- Modify: `lib/widgets/elio/elio_tier_row.dart`
- Modify: `lib/widgets/elio/elio_bento_card.dart`
- Modify: `lib/widgets/elio/elio_secondary_card.dart`
- Tests: corresponding `_test.dart` files

For each widget:

- [ ] **Step 1: Background colour to `ElioColors.creamDeep`**
- [ ] **Step 2: Border radius to `ElioRadii.card` (16)**
- [ ] **Step 3: Title text to `ElioTextStyles.uiLabelStyle` or `sectionHeadingStyle` per spec**
- [ ] **Step 4: Sub/eyebrow text to `ElioTextStyles.eyebrowStyle` (DM Mono uppercase)**
- [ ] **Step 5: Icon tint to `ElioColors.terracotta`** (for action-tile icons)
- [ ] **Step 6: For `ElioSecondaryCard`'s peach pill action button, set background to `ElioColors.peach`, text colour `ElioColors.espresso`**
- [ ] **Step 7: Write a smoke test per file confirming the surface colour**

```dart
testWidgets('ElioTierRow renders cream-deep surface', (tester) async {
  // pump and assert BoxDecoration color is ElioColors.creamDeep
});
```

- [ ] **Step 8: Run analyze + tests**

```bash
flutter analyze && flutter test
```

- [ ] **Step 9: Commit**

```bash
git add lib/widgets/elio/elio_tier_row.dart lib/widgets/elio/elio_bento_card.dart lib/widgets/elio/elio_secondary_card.dart test/widgets/
git commit -m "style(sprint-16-rebrand): restyle TierRow/BentoCard/SecondaryCard to cream-deep panels"
```

---

### Task 26: Restyle `ElioIngredientRow`, `ElioMethodStep`, `ElioStatBadge`, `ElioServingsControl`, `ElioFeedbackBar`

These five widgets all appear on the Recipe Detail screen. Restyle in one task.

**Files:**
- Modify: `lib/widgets/elio/elio_ingredient_row.dart`
- Modify: `lib/widgets/elio/elio_method_step.dart`
- Modify: `lib/widgets/elio/elio_stat_badge.dart`
- Modify: `lib/widgets/elio/elio_servings_control.dart`
- Modify: `lib/widgets/elio/elio_feedback_bar.dart`

For each, apply per spec §8:

- **`ElioIngredientRow`**: idle = empty terracotta circle (`Icons.circle_outlined` size 22 in `ElioColors.terracotta`); checked = filled terracotta circle with white tick. Name in `ElioTextStyles.uiLabelStyle`. Sub-line in `ElioTextStyles.bodySmallStyle`.
- **`ElioMethodStep`**: numeral `01`, `02` in Bricolage 800 size 56 colour `ElioColors.terracotta`. Step title `ElioTextStyles.uiLabelStyle`. Body `ElioTextStyles.bodySmallStyle`.
- **`ElioStatBadge`**: cream-deep pill, terracotta-tinted leading icon, espresso label. Padding `EdgeInsets.symmetric(horizontal: 14, vertical: 10)`. Border radius `ElioRadii.panel` (14).
- **`ElioServingsControl`**: flat panel, peach `−` and `+` circular buttons, espresso numeral, "Servings" label in `ElioTextStyles.uiLabelStyle`.
- **`ElioFeedbackBar`**: cream-deep panel, "How was the recipe?" in `ElioTextStyles.bodyStyle` mocha, two `IconButton`s for thumbs up/down using outline icons.

- [ ] **Step 1: For each widget, restyle per the bullet above**
- [ ] **Step 2: For each, write a single smoke test confirming the surface colour or distinctive token**
- [ ] **Step 3: Run analyze + tests**
- [ ] **Step 4: Commit**

```bash
git add lib/widgets/elio/elio_ingredient_row.dart lib/widgets/elio/elio_method_step.dart lib/widgets/elio/elio_stat_badge.dart lib/widgets/elio/elio_servings_control.dart lib/widgets/elio/elio_feedback_bar.dart test/widgets/
git commit -m "style(sprint-16-rebrand): restyle Ingredient/Method/Stat/Servings/Feedback widgets"
```

---

### Task 27: Restyle onboarding-specific widgets

**Files:**
- Modify: `lib/widgets/elio/elio_onboarding_option_card.dart`
- Modify: `lib/widgets/elio/elio_onboarding_progress_bar.dart`
- Modify: `lib/widgets/elio/elio_appliance_tile.dart`
- Modify: `lib/widgets/elio/elio_household_stepper.dart`
- Modify: `lib/widgets/elio/elio_provider_signin_button.dart`

Per spec §8:

- **`ElioOnboardingOptionCard`**: cream-deep panel `ElioRadii.card`, bold + sub line (uiLabel + bodySmall), right-side terracotta ring radio (filled when selected).
- **`ElioOnboardingProgressBar`**: track `ElioColors.rule` height 4, fill `ElioColors.mocha`, animated transitions kept.
- **`ElioApplianceTile`**: same pattern as `ElioOnboardingOptionCard` but with appliance icon and grid layout (3-col already established in Sprint 16.2).
- **`ElioHouseholdStepper`**: cream-deep panel, peach `−`/`+`, espresso numeral.
- **`ElioProviderSignInButton`**: pill (`ElioRadii.button`), white background, espresso text + provider icon. Apple-style buttons keep their black variant per Apple HIG.

- [ ] **Step 1: Restyle each per the bullet**
- [ ] **Step 2: Run existing onboarding screen tests to confirm no regression in tap interactions**

```bash
flutter test test/screens/onboarding/ test/widgets/
```

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/elio/elio_onboarding_option_card.dart lib/widgets/elio/elio_onboarding_progress_bar.dart lib/widgets/elio/elio_appliance_tile.dart lib/widgets/elio/elio_household_stepper.dart lib/widgets/elio/elio_provider_signin_button.dart
git commit -m "style(sprint-16-rebrand): restyle onboarding-specific widgets"
```

---

### Task 28: Restyle remaining minor widgets

**Files:**
- Modify: `lib/widgets/elio/elio_eyebrow.dart`
- Modify: `lib/widgets/elio/elio_custom_field.dart`
- Modify: `lib/widgets/elio/elio_chip_text_input.dart`
- Modify: `lib/widgets/elio/elio_add_pantry_item_dialog.dart`
- Modify: `lib/widgets/elio/elio_add_something_tile.dart`
- Modify: `lib/widgets/elio/elio_pantry_icon.dart`
- Modify: `lib/widgets/elio/elio_pantry_item_tile.dart`
- Modify: `lib/widgets/elio/elio_pantry_tag_pill.dart`
- Modify: `lib/widgets/elio/elio_pantry_tier_legend.dart`
- Modify: `lib/widgets/elio/elio_segmented_toggle.dart`
- Modify: `lib/widgets/elio/elio_sticky_category_header.dart`
- Modify: `lib/widgets/elio/phone_mockup_recipe_card.dart`

For each: apply spec §8 mapping. Most are mechanical: replace any hardcoded colour with the new token, replace any explicit `GoogleFonts` call with `ElioTextStyles.<role>`, replace radius constants if hardcoded.

Specific notes:
- `ElioEyebrow` text style → `ElioTextStyles.eyebrowStyle`.
- `ElioCustomField` → `ElioColors.creamDeep` background, `ElioRadii.input` (14), placeholder in `ElioColors.mocha`.
- `ElioAddSomethingTile` → cream-deep with dashed terracotta border (`DottedBorder` package or custom painter; keep existing implementation if already dashed).
- `ElioPantryIcon` → outline icons in `ElioColors.espresso` or `ElioColors.terracotta` per category.
- `ElioSegmentedToggle` → cream-deep track, terracotta thumb, espresso labels.

- [ ] **Step 1: Apply restyles file-by-file**
- [ ] **Step 2: Run analyze + tests**

```bash
flutter analyze && flutter test
```

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/elio/
git commit -m "style(sprint-16-rebrand): restyle remaining ElioWidgets (eyebrow/custom field/pantry/segmented)"
```

---

### Task 29: Restyle pre-Sprint-16 widgets (`pantry_builder_sheet.dart`, `recipe_category_chip_row.dart`, `elio_progress_bar.dart`)

These three widgets live outside `lib/widgets/elio/` and were not tokenised in Sprint 16. They appear in flow (especially the recipe screen) so they need the new tokens too.

**Files:**
- Modify: `lib/widgets/pantry_builder_sheet.dart`
- Modify: `lib/widgets/recipe_category_chip_row.dart`
- Modify: `lib/widgets/elio_progress_bar.dart`

- [ ] **Step 1: Read each, identify hardcoded colours / fonts**
- [ ] **Step 2: Replace navy/amber/sky/Outfit/Quicksand references with new tokens / ElioTextStyles**
- [ ] **Step 3: Run analyze + tests**
- [ ] **Step 4: Commit**

```bash
git add lib/widgets/pantry_builder_sheet.dart lib/widgets/recipe_category_chip_row.dart lib/widgets/elio_progress_bar.dart
git commit -m "style(sprint-16-rebrand): tokenise pre-Sprint-16 widgets to rebrand palette"
```

---

## Phase 5 — Kate-blessed screen migrations

Each screen task:
1. Open the screen file
2. Replace existing heading widgets / hardcoded titles with `ElioPageTitle` / `ElioSectionHeading`
3. Confirm widget composition matches the Figma frame
4. Test that key interactions still work (existing tests should pass; add a smoke test if missing)
5. Commit

### Task 30: Migrate Onboarding splash screen

**Files:**
- Modify: `lib/screens/onboarding/screen1_dietary.dart` OR the actual splash file (verify before editing).

Reference frame: title `tonights dinner, from what you already have.`, sub-copy `recipes built around you. tailored to you, tailored to your kitchen`, terracotta `Get started` CTA, "i already have an account" text link.

- [ ] **Step 1: Identify the splash screen file**

```bash
grep -rln "tonights dinner\|Get started" lib/screens/onboarding/
```

If the file uses different copy currently, locate by structure: it's the FIRST onboarding step before any question.

- [ ] **Step 2: Replace the title with `ElioPageTitle`**

```dart
// before (typical)
Text('Welcome to Elio', style: GoogleFonts.outfit(...))

// after
const ElioPageTitle('tonights dinner, from what you already have.')
```

- [ ] **Step 3: Replace the sub-copy with `Text(... ElioTextStyles.ledeStyle)`**

- [ ] **Step 4: Replace the primary CTA with `ElioBigButton(label: 'Get started', onPressed: …)`**

- [ ] **Step 5: Add the "i already have an account" `TextButton` below CTA**

If not already present, add:

```dart
TextButton(
  onPressed: _goToSignIn,
  child: Text(
    'i already have an account',
    style: ElioTextStyles.bodyStyle.copyWith(
      color: ElioColors.mocha,
      decoration: TextDecoration.underline,
    ),
  ),
),
```

- [ ] **Step 6: Run existing screen test if any**

```bash
flutter test test/screens/onboarding/
```

Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/onboarding/screen1_dietary.dart
git commit -m "style(sprint-16-rebrand): migrate onboarding splash to new design"
```

---

### Task 31: Migrate Onboarding question screens (Q1–Q4)

**Files:**
- Modify: 4 onboarding screen files for "what brought you to elio?", "who are you cooking for?", "any dietary preferences we should follow?", "any allergies we should be aware of?"

For each:

- [ ] **Step 1: Find the file** via `grep -l "what brought you\|who are you cooking\|dietary preferences\|allergies we should" lib/screens/onboarding/`
- [ ] **Step 2: Replace the title with `ElioPageTitle('<question copy>')`**
- [ ] **Step 3: Replace the sub-copy with `Text(... ElioTextStyles.ledeStyle)` or `bodyStyle` based on size**
- [ ] **Step 4: Replace each option with `ElioOnboardingOptionCard`**
- [ ] **Step 5: Replace the bottom CTA with `ElioBigButton(label: 'Continue', onPressed: …)`**
- [ ] **Step 6: Confirm `ElioOnboardingProgressBar` is visible at top**
- [ ] **Step 7: Run tests**
- [ ] **Step 8: Commit per screen**

```bash
git add lib/screens/onboarding/<file>.dart
git commit -m "style(sprint-16-rebrand): migrate onboarding <screen-name> to new design"
```

---

### Task 32: Migrate Home screen

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

Reference frame: title `hey kate. lets get started`, sub-copy line "Sub copy to fit brand" (placeholder; check Figma final copy), terracotta `Generate a recipe` CTA, peach `Plan your week` secondary card.

- [ ] **Step 1: Replace the heading with `ElioPageTitle`**

```dart
// before (probably)
ElioHeroHeading(['hey kate', 'lets get started']) // or similar

// after
ElioPageTitle('hey ${user.firstName ?? 'there'}. lets get started')
```

If the user's name isn't available at this point, use `'hey there. lets get started'` as fallback.

- [ ] **Step 2: Replace the primary CTA with `ElioBigButton(label: 'Generate a recipe', onPressed: …)`**

- [ ] **Step 3: Replace the "Plan your week" secondary card with restyled `ElioSecondaryCard`**

- [ ] **Step 4: Confirm `ElioAppScaffold` is the wrapper (it provides backdrop + bottom nav)**

- [ ] **Step 5: Run existing home screen tests**

```bash
flutter test test/screens/home/
```

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "style(sprint-16-rebrand): migrate Home screen to new design"
```

---

### Task 33: Migrate Pantry tab and Dietary & Allergens screens

**Files:**
- Modify: `lib/screens/pantry/pantry_screen.dart`
- Modify: `lib/screens/profile/dietary_screen.dart`

For Pantry (frame: "what did you pick up?" + Scan Receipt/Scan Barcode bento + Pantry Builder accordion):
- [ ] Replace the title with `ElioPageTitle('what did you pick up?')`
- [ ] Confirm two `ElioBentoCard`s for scanner shortcuts
- [ ] Replace "Pantry Builder" sub-section header with `ElioSectionHeading('Pantry Builder')`
- [ ] Confirm the three `ElioTierRow`s (Perishables / Always Have / Almost Always Have)

For Dietary (frame: "dietary and allergens" + chip grid + custom field):
- [ ] Replace the title with `ElioPageTitle('dietary and allergens')`
- [ ] Sub-copy "elio wont suggest recipes that dont work for you and your settings."
- [ ] Replace section header with `ElioSectionHeading('Dietary requirements')`
- [ ] Confirm `ElioChip` instances render in a `Wrap`
- [ ] Replace bottom section header with `ElioSectionHeading('Custom allergens or dietary requirements')`
- [ ] Confirm `ElioCustomField` for the free-text input

- [ ] Run tests
- [ ] Commit per screen

---

### Task 34: Migrate Recipe Detail screen

**Files:**
- Modify: `lib/screens/recipe/recipe_screen.dart`

Reference frame: hero title `creamy lemon pasta`, sub-copy, 2x2 stat pill grid, servings control, ingredients section, method section, feedback bar, "Generate again" CTA with infinity icon.

- [ ] **Step 1: Replace the recipe title with `ElioPageTitle(recipe.title)`** — recipe titles authored without periods, so D-rule produces no terracotta.

- [ ] **Step 2: Replace section headers (`Ingredients`, `Method`) with `ElioSectionHeading`**

- [ ] **Step 3: Confirm 2x2 grid of `ElioStatBadge`s** (cook time / prep time / cost / kcal). If not currently a 2x2 grid, restructure using `GridView` or `Column(Row, Row)`.

- [ ] **Step 4: Confirm `ElioServingsControl` placement**

- [ ] **Step 5: Confirm ingredient list uses `ElioIngredientRow` with terracotta circles**

- [ ] **Step 6: Confirm method steps use `ElioMethodStep` with terracotta numerals**

- [ ] **Step 7: Confirm `ElioFeedbackBar` at bottom**

- [ ] **Step 8: Replace the "Generate again" CTA**

```dart
ElioBigButton(
  label: 'Generate again',
  onPressed: _onGenerateAgain,
  trailingIcon: Icons.all_inclusive, // infinity from Material outline set
)
```

If `ElioBigButton` doesn't expose a `trailingIcon` parameter yet, extend its API to accept one (default `Icons.chevron_right`). This is a small API addition — update the test in Task 21 if needed.

- [ ] **Step 9: Run recipe-screen tests**

```bash
flutter test test/screens/recipe/
```

- [ ] **Step 10: Commit**

```bash
git add lib/screens/recipe/recipe_screen.dart lib/widgets/elio/elio_big_button.dart
git commit -m "style(sprint-16-rebrand): migrate Recipe Detail screen to new design"
```

---

## Phase 6 — Cleanup, package drop, build

### Task 35: Remove legacy `ElioText` class and unused imports

**Files:**
- Modify: `lib/theme/elio_theme.dart` (remove the legacy `ElioText` class)
- Modify: `lib/theme/elio_text_styles.dart` (remove old Outfit/Quicksand entries: `heroDisplay`, `heroDisplayAccent`, `heading1-5`, `eyebrow`, `body`, `bodySmall`, `statValue`, `stepNumeral`)

- [ ] **Step 1: Confirm zero callers of `ElioText.<anything>`**

```bash
grep -rn "ElioText\." lib/ test/ | grep -v "ElioTextStyles" | grep -v "ElioTextField"
```

Expected: zero matches. If matches exist, migrate those call sites to `ElioTextStyles.<role>` first.

- [ ] **Step 2: Delete the `ElioText` class from `lib/theme/elio_theme.dart`**

- [ ] **Step 3: Confirm zero callers of legacy `ElioTextStyles.<old role>`**

```bash
grep -rn "ElioTextStyles\.\(heroDisplay\|heroDisplayAccent\|heading[1-5]\|eyebrow[^S]\|^body\|bodySmall[^S]\|statValue\|stepNumeral\)" lib/ test/
```

The grep is approximate; manually verify any remaining call sites and migrate them to the new ramp.

- [ ] **Step 4: Delete legacy entries from `lib/theme/elio_text_styles.dart`**

Keep only the new Sprint-16-rebrand entries (pageTitleStyle, sectionHeadingStyle, ledeStyle, bodyStyle, bodySmallStyle, uiLabelStyle, tabLabelStyle, eyebrowStyle, numericStyle).

- [ ] **Step 5: Run analyze + tests**

```bash
flutter analyze && flutter test
```

Expected: clean + green. If analyze reports unresolved references, those are leftover legacy callers — migrate or delete.

- [ ] **Step 6: Commit**

```bash
git add lib/theme/elio_theme.dart lib/theme/elio_text_styles.dart
git commit -m "chore(sprint-16-rebrand): delete legacy ElioText / ElioTextStyles entries"
```

---

### Task 36: Remove old colour token names

**Files:**
- Modify: `lib/theme/elio_theme.dart`

- [ ] **Step 1: Confirm zero callers**

```bash
grep -rn "ElioColors\.\(navy\|amber\|sky\|offWhite\|white\|border\|textPrimary\|textSecondary\|textMuted\)" lib/ test/
```

Expected: zero. If any remain, address them.

- [ ] **Step 2: Delete the legacy fields from the `ElioColors` class**

Keep only: `cream`, `creamDeep`, `terracotta`, `peach`, `espresso`, `mocha`, `rule`, `error`, `success`, `freshGreen`, `perishThisWeek`, `perishToday`.

- [ ] **Step 3: Also delete legacy `ElioRadii` aliases** (`small`/`medium`/`large` from Task 6 step 4) once no callers remain

```bash
grep -rn "ElioRadii\.\(small\|medium\|large\)" lib/ test/
```

If zero, delete those aliases.

- [ ] **Step 4: Run analyze + tests**

```bash
flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/theme/elio_theme.dart lib/theme/elio_radii.dart
git commit -m "chore(sprint-16-rebrand): remove legacy ElioColors and ElioRadii aliases"
```

---

### Task 37: Delete `ElioHeroHeading` widget

**Files:**
- Delete: `lib/widgets/elio/elio_hero_heading.dart`
- Delete: `test/widgets/elio_hero_heading_test.dart` (if exists)

- [ ] **Step 1: Confirm zero callers of `ElioHeroHeading`**

```bash
grep -rn "ElioHeroHeading" lib/ test/
```

Expected: zero. If any remain (typically Home screen, onboarding splash), migrate them to `ElioPageTitle` first.

- [ ] **Step 2: Delete the widget file**

```bash
rm lib/widgets/elio/elio_hero_heading.dart
rm test/widgets/elio_hero_heading_test.dart  # if exists
```

- [ ] **Step 3: Run analyze + tests**

```bash
flutter analyze && flutter test
```

- [ ] **Step 4: Commit**

```bash
git add -A lib/widgets/elio/elio_hero_heading.dart test/widgets/elio_hero_heading_test.dart
git commit -m "chore(sprint-16-rebrand): delete legacy ElioHeroHeading widget"
```

---

### Task 38: Drop `google_fonts` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Confirm zero `GoogleFonts.` callers**

```bash
grep -rn "GoogleFonts\." lib/ test/
grep -rn "package:google_fonts" lib/ test/
```

Both expected: zero matches.

- [ ] **Step 2: Remove `google_fonts:` line from `pubspec.yaml`**

- [ ] **Step 3: Run `flutter pub get`**

```bash
flutter pub get
```

Expected: success; no errors.

- [ ] **Step 4: Run analyze + tests**

```bash
flutter analyze && flutter test
```

Expected: clean + green.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(sprint-16-rebrand): drop google_fonts dependency (now using bundled assets)"
```

---

### Task 39: Update CLAUDE.md and memory file

**Files:**
- Modify: `CLAUDE.md`
- Modify: `C:/Users/robth/.claude/projects/C--Users-robth--claude-ELio/memory/project_elio_overview.md`

- [ ] **Step 1: Update `CLAUDE.md` Design System section**

Replace the existing palette/font block with:

```markdown
## Design System (Sprint 16 rebrand)

- **Cream:** `#F4ECE0` — primary background
- **Cream-deep:** `#EFE3D2` — card surfaces, idle inputs, chip idle
- **Terracotta:** `#E37B53` — primary CTA, period closer, selected states
- **Peach:** `#F2C9A8` — secondary pill, soft accent
- **Espresso:** `#2A1F1A` — primary text, active nav
- **Mocha:** `#6B5A4F` — secondary text, idle nav
- **Rule:** `#D7C5B0` — dividers
- **Fonts:** bundled `Bricolage Grotesque` (display, w200-w800), `DM Sans` (body), `DM Mono` (technical)
- **Heading rule (D rule):** `ElioPageTitle` walks the string and renders any `.` in terracotta. Authors include the period in source text where the brand calls for it. Section headings use `ElioSectionHeading` (sentence case, no period).
- **Backdrop:** `ElioBackdropIllustration` (kale leaf SVG, mocha @ 12% opacity) inserted by `ElioAppScaffold` behind every page.
- **API:** `.withValues(alpha: x)` not `.withOpacity(x)` | always `Theme.of(context).textTheme.<role>` (never hardcode `fontFamily`).
```

- [ ] **Step 2: Update memory file** to reflect Sprint 16 rebrand shipped state.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(sprint-16-rebrand): update CLAUDE.md design system section"
```

---

### Task 40: Build APK and on-device sign-off

**Files:**
- Execute: `build.ps1`

- [ ] **Step 1: Build the rebrand APK**

```bash
powershell -ExecutionPolicy Bypass -File build.ps1 -sprint 16-rebrand
```

Expected: APK at `releases/elio-sprint-16-rebrand.apk`. Local tag `build/sprint-16-rebrand` created.

- [ ] **Step 2: Install on device and walk through the full flow**

- Onboarding splash → splash CTA → Q1 → Q2 → Q3 → Q4 → sign-in → Home
- Home → Generate → Recipe Detail → Generate again
- Pantry tab → Scan Receipt / Scan Barcode → Pantry Builder accordion
- Profile → Dietary & Allergens
- Bottom nav — confirm "SHOPPING LIST" label
- Confirm botanical leaf appears on every cream-bg screen
- Confirm headlines are lowercase Bricolage with terracotta periods where authored

- [ ] **Step 3: If sign-off passes, push branch**

```bash
git push -u origin sprint/16-rebrand
```

- [ ] **Step 4: Open PR (or merge per project flow)**

The PR description should:
- Link the spec (`docs/superpowers/specs/2026-04-29-sprint-16-rebrand-design.md`)
- Link the plan (this file)
- List the 9 Kate-blessed screens that match Figma
- List the ~16 "unblessed" screens that inherited the new tokens but lack Kate eyeball — flagged for follow-up

- [ ] **Step 5: After merge, tag release**

```bash
git tag v0.16.0-rebrand
git push origin v0.16.0-rebrand
```

---

## Acceptance Criteria

- [ ] All 9 Kate-blessed screens visually match the Figma frames on a Pixel-class device.
- [ ] `grep -rn "ElioColors\.\(navy\|amber\|sky\|offWhite\|border\)" lib/ test/` returns zero matches.
- [ ] `grep -rn "GoogleFonts\." lib/ test/` returns zero matches.
- [ ] `grep -rn "package:google_fonts" lib/` returns zero matches.
- [ ] `flutter analyze` reports zero issues.
- [ ] `flutter test` passes (existing 325 tests + new theme/widget tests).
- [ ] APK builds via `build.ps1 -sprint 16-rebrand`.
- [ ] APK runs on device with no theme regression.
- [ ] PR notes list every unblessed screen for Kate follow-up.
