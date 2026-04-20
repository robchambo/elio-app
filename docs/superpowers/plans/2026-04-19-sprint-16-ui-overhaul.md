# Sprint 16 — UI Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Kate's 4 ready-for-dev screens (Home, Pantry, Recipe, Dietary & Allergens) on `sprint/16`, establishing a reusable design system that scales to remaining screens. After the 4 core screens land, take a first pass at the remaining screens (onboarding, paywall, meal planner, profile sub-screens, shopping list, recipes tab) to match the new design language.

**Architecture:** Design-system-first. Extract shared widgets into `lib/widgets/elio/` and compose screens from them. Preserve all existing business logic (Gemini, Firestore, entitlement, voice cooking, scanning) by keeping state and service calls intact — only widget trees change. Restructure the app shell: promote Pantry, Recipes, Shopping List out of Profile sub-tabs into a 4-tab bottom nav.

**Tech Stack:** Flutter 3.27.x / Dart, existing theme in `lib/theme/elio_theme.dart` (ElioColors), GoogleFonts (Outfit headings + Quicksand body), go_router for navigation, existing Firestore / Gemini / RevenueCat services.

**Figma source:** https://www.figma.com/design/BOcjrItjk36Mtjgofqq6qV/elio-design?node-id=2-3045 (file key `BOcjrItjk36Mtjgofqq6qV`, dev-ready section `2:3045`).

**User flow (FigJam):** https://www.figma.com/board/vz3KBKX8ZxH4CCi8mLvDpv/Elio (file key `vz3KBKX8ZxH4CCi8mLvDpv`) — reference when implementing not-yet-designed screens.

---

## Architectural Decisions (confirmed with Rob)

1. **Bottom nav restructure** — 4 top-level tabs: `HOME / PANTRY / RECIPES / SHOPPING LIST`. Pantry, Recipe Book, Shopping promote out of Profile sub-tabs. Profile shrinks to a Settings/Style screen reached via the top-right profile icon.
2. **Dietary & Allergens** — standalone route reached from Settings (replaces current `lib/screens/profile/dietary_screen.dart`).
3. **In-place rewrites** — edit existing screen files directly. No `*_v2.dart` / flag-gated duplicates.
4. **Testing split** — widget tests for stateful/interactive widgets (servings stepper, chip selection). Pure visual widgets (hero heading, eyebrow) rely on on-device visual verification.
5. **Design system scope** — build generically to serve all future screens, not just the 4 ready ones.

## Scope boundaries (what this plan does NOT do)

- Not changing Gemini prompts, API config, or model choice.
- Not changing Firestore schema.
- Not changing RevenueCat paywall logic (only the paywall visual shell in Phase 6).
- Not adding new features. Visual + structural refactor only.
- Not touching tests in `test/entitlement_logic_test.dart` (they are pure logic tests and are unaffected).

---

## File Structure

**New files (design system):**

```
lib/theme/
  elio_theme.dart              (existing — extend with new tokens)
  elio_spacing.dart            (NEW — 8-point spacing scale)
  elio_radii.dart              (NEW — border-radius scale)
  elio_text_styles.dart        (NEW — editorial type ramp)

lib/widgets/elio/
  elio_top_app_bar.dart        (NEW — 64px app bar with elio logo + profile icon)
  elio_bottom_nav.dart         (NEW — 4-tab bottom nav, amber active state)
  elio_hero_heading.dart       (NEW — editorial heading + optional amber underline)
  elio_eyebrow.dart            (NEW — all-caps small label)
  elio_big_button.dart         (NEW — primary amber CTA w/ chevron or icon)
  elio_secondary_card.dart     (NEW — cream card with View button)
  elio_bento_card.dart         (NEW — two-tone action card, icon + label + title)
  elio_tier_row.dart           (NEW — expandable tier row, label + count + chevron)
  elio_stat_badge.dart         (NEW — pill with icon + value)
  elio_servings_control.dart   (NEW — stepper: − value +)
  elio_ingredient_row.dart     (NEW — checkbox + name + detail)
  elio_method_step.dart        (NEW — big number + title + body)
  elio_feedback_bar.dart       (NEW — "How was the recipe?" + thumbs)
  elio_chip.dart               (NEW — selectable chip, amber-active or grey-outline)
  elio_custom_field.dart       (NEW — rounded cream text field)
  elio_app_scaffold.dart       (NEW — common Scaffold wrapper with bottom nav slot)
```

**Modified files (screens):**

```
lib/main.dart                                          (add route for new shell)
lib/screens/shell/app_shell.dart                       (NEW — holds bottom nav + IndexedStack)
lib/screens/home/home_screen.dart                      (rewrite UI, preserve logic)
lib/screens/pantry/pantry_screen.dart                  (rewrite UI, preserve logic)
lib/screens/recipe/recipe_screen.dart                  (rewrite UI, preserve logic)
lib/screens/profile/dietary_screen.dart                (rewrite UI, preserve logic)
lib/screens/profile/profile_screen.dart                (simplify — remove Pantry/Recipe Book/Shopping tabs)
lib/screens/shopping/shopping_list_screen.dart         (keep logic, apply new shell)
lib/screens/profile/recipe_book_screen.dart            (may need extracting from Profile tabs — see Phase 6)
```

**Deleted files:** none in this sprint. Orphaned widgets get removed in Phase 5 after all screens migrate.

---

## Phase 0 — Foundation

### Task 0.1: Create sprint 16 working commit

**Files:**
- No file changes; just confirm branch state.

- [ ] **Step 1: Confirm branch**

```bash
cd C:\Users\robth\.claude\ELio\elio-app
git status
# Expected: "On branch sprint/16", clean working tree (or only GeneratedPluginRegistrant.java modified, which is auto-generated)
```

- [ ] **Step 2: Run baseline analyze**

```bash
C:\src\flutter\bin\flutter analyze
# Expected: "No issues found!"
```

- [ ] **Step 3: Run baseline tests**

```bash
C:\src\flutter\bin\flutter test
# Expected: All 22 tests pass
```

### Task 0.2: Design tokens — spacing scale

**Files:**
- Create: `lib/theme/elio_spacing.dart`

- [ ] **Step 1: Create spacing scale**

```dart
// lib/theme/elio_spacing.dart
/// 8-point grid spacing. Use instead of magic numbers in layouts.
class ElioSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Default horizontal screen padding (matches Figma: 24px edge margin).
  static const double screenEdge = 24;
}
```

- [ ] **Step 2: Verify compiles**

```bash
C:\src\flutter\bin\flutter analyze lib/theme/elio_spacing.dart
# Expected: "No issues found!"
```

### Task 0.3: Design tokens — radii scale

**Files:**
- Create: `lib/theme/elio_radii.dart`

- [ ] **Step 1: Create radii scale**

```dart
// lib/theme/elio_radii.dart
import 'package:flutter/material.dart';

/// Border-radius scale, matches Figma rounded-corner system.
class ElioRadii {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
  static const BorderRadius card = BorderRadius.all(Radius.circular(24));
  static const BorderRadius button = BorderRadius.all(Radius.circular(20));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(999));
}
```

- [ ] **Step 2: Verify compiles**

```bash
C:\src\flutter\bin\flutter analyze lib/theme/elio_radii.dart
```

### Task 0.4: Editorial text styles

**Files:**
- Create: `lib/theme/elio_text_styles.dart`

- [ ] **Step 1: Derive type ramp from Figma**

Figma "Heading 1" on Recipe is ~54px Outfit Bold with tight line-height. Home hero is similar. Eyebrow is 12-13px, letter-spaced, uppercase, Outfit Medium. Body is Quicksand 14/16.

- [ ] **Step 2: Create text styles**

```dart
// lib/theme/elio_text_styles.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'elio_theme.dart';

class ElioTextStyles {
  // Editorial display
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

  // Section headings
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

  // Eyebrow / overline
  static TextStyle get eyebrow => GoogleFonts.outfit(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.8,
        color: ElioColors.textSecondary,
      );

  // Body
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

  // Stat / pill label
  static TextStyle get statValue => GoogleFonts.outfit(
        fontSize: 16,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: ElioColors.navy,
      );

  // Big numeral (method step)
  static TextStyle get stepNumeral => GoogleFonts.outfit(
        fontSize: 48,
        height: 1.0,
        fontWeight: FontWeight.w800,
        color: ElioColors.amber,
      );
}
```

- [ ] **Step 3: Verify compiles**

```bash
C:\src\flutter\bin\flutter analyze lib/theme/elio_text_styles.dart
```

- [ ] **Step 4: Commit foundation tokens**

```bash
git add lib/theme/elio_spacing.dart lib/theme/elio_radii.dart lib/theme/elio_text_styles.dart
git commit -m "feat(sprint-16): design system tokens — spacing, radii, text styles"
```

---

## Phase 1 — Core shared widgets

### Task 1.1: ElioEyebrow

**Files:**
- Create: `lib/widgets/elio/elio_eyebrow.dart`

- [ ] **Step 1: Create widget**

```dart
// lib/widgets/elio/elio_eyebrow.dart
import 'package:flutter/material.dart';
import '../../theme/elio_text_styles.dart';

/// Small all-caps label ("YOUR KITCHEN IS READY FOR ELIO", "YOU CAN PICK MULTIPLE").
class ElioEyebrow extends StatelessWidget {
  final String text;
  final TextAlign textAlign;

  const ElioEyebrow(this.text, {super.key, this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: ElioTextStyles.eyebrow,
      textAlign: textAlign,
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
C:\src\flutter\bin\flutter analyze lib/widgets/elio/elio_eyebrow.dart
```

### Task 1.2: ElioHeroHeading

**Files:**
- Create: `lib/widgets/elio/elio_hero_heading.dart`

- [ ] **Step 1: Create widget**

Kate's hero heading is two lines: first line dark, second line amber. Optional amber underline beneath. Supports 1, 2, or 3 lines.

```dart
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
              color: ElioColors.amber,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
C:\src\flutter\bin\flutter analyze lib/widgets/elio/elio_hero_heading.dart
```

### Task 1.3: ElioBigButton

**Files:**
- Create: `lib/widgets/elio/elio_big_button.dart`

- [ ] **Step 1: Create widget**

Matches the "Generate a recipe" button in Home and "Generate another" button in Recipe. Amber fill, dark text, optional trailing icon (chevron or infinity).

```dart
// lib/widgets/elio/elio_big_button.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioBigButton extends StatelessWidget {
  final String label;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final bool loading;

  const ElioBigButton({
    super.key,
    required this.label,
    this.trailingIcon,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: ElioRadii.button,
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: onTap == null ? ElioColors.amber.withValues(alpha: 0.5) : ElioColors.amber,
          borderRadius: ElioRadii.button,
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: ElioTextStyles.heading3.copyWith(color: ElioColors.navy),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: ElioColors.navy),
              )
            else if (trailingIcon != null)
              Icon(trailingIcon, color: ElioColors.navy, size: 28),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
C:\src\flutter\bin\flutter analyze lib/widgets/elio/elio_big_button.dart
```

### Task 1.4: ElioTopAppBar

**Files:**
- Create: `lib/widgets/elio/elio_top_app_bar.dart`

- [ ] **Step 1: Create widget**

```dart
// lib/widgets/elio/elio_top_app_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/elio_theme.dart';

/// 64px top app bar: elio wordmark left, profile icon right.
class ElioTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onProfileTap;

  const ElioTopAppBar({super.key, this.onProfileTap});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: ElioColors.offWhite,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'elio',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: ElioColors.amber,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined,
                color: ElioColors.navy, size: 28),
            onPressed: onProfileTap,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
C:\src\flutter\bin\flutter analyze lib/widgets/elio/elio_top_app_bar.dart
```

### Task 1.5: ElioBottomNav

**Files:**
- Create: `lib/widgets/elio/elio_bottom_nav.dart`

- [ ] **Step 1: Create widget**

4 tabs: Home, Pantry, Recipes, Shopping List. Active tab has amber pill background + white icon/text. Inactive: grey.

```dart
// lib/widgets/elio/elio_bottom_nav.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';

enum ElioNavTab { home, pantry, recipes, shoppingList }

class ElioBottomNav extends StatelessWidget {
  final ElioNavTab active;
  final ValueChanged<ElioNavTab> onTap;

  const ElioBottomNav({super.key, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 107,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      color: ElioColors.offWhite,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home_outlined, label: 'HOME',
              active: active == ElioNavTab.home, onTap: () => onTap(ElioNavTab.home)),
          _NavItem(icon: Icons.kitchen_outlined, label: 'PANTRY',
              active: active == ElioNavTab.pantry, onTap: () => onTap(ElioNavTab.pantry)),
          _NavItem(icon: Icons.menu_book_outlined, label: 'RECIPES',
              active: active == ElioNavTab.recipes, onTap: () => onTap(ElioNavTab.recipes)),
          _NavItem(icon: Icons.add_shopping_cart_outlined, label: 'SHOPPING\nLIST',
              active: active == ElioNavTab.shoppingList, onTap: () => onTap(ElioNavTab.shoppingList)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = active ? ElioColors.amber : Colors.transparent;
    final fg = active ? Colors.white : ElioColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: ElioRadii.all(24),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: active ? 14 : 8, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: ElioRadii.all(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  letterSpacing: 0.8, color: fg)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Widget test — tap callback fires with correct tab**

Create `test/widgets/elio_bottom_nav_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_bottom_nav.dart';

void main() {
  testWidgets('tapping Pantry fires onTap with ElioNavTab.pantry', (tester) async {
    ElioNavTab? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: ElioBottomNav(
          active: ElioNavTab.home,
          onTap: (t) => captured = t,
        ),
      ),
    ));
    await tester.tap(find.text('PANTRY'));
    await tester.pump();
    expect(captured, ElioNavTab.pantry);
  });
}
```

- [ ] **Step 3: Run test**

```bash
C:\src\flutter\bin\flutter test test/widgets/elio_bottom_nav_test.dart
# Expected: PASS
```

### Task 1.6: ElioAppScaffold

**Files:**
- Create: `lib/widgets/elio/elio_app_scaffold.dart`

- [ ] **Step 1: Create widget**

Thin wrapper that glues TopAppBar + body + BottomNav together so screens don't repeat this.

```dart
// lib/widgets/elio/elio_app_scaffold.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import 'elio_bottom_nav.dart';
import 'elio_top_app_bar.dart';

class ElioAppScaffold extends StatelessWidget {
  final Widget body;
  final ElioNavTab? activeTab;
  final ValueChanged<ElioNavTab>? onTabChanged;
  final VoidCallback? onProfileTap;
  final bool showBottomNav;

  const ElioAppScaffold({
    super.key,
    required this.body,
    this.activeTab,
    this.onTabChanged,
    this.onProfileTap,
    this.showBottomNav = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      appBar: ElioTopAppBar(onProfileTap: onProfileTap),
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: showBottomNav && activeTab != null && onTabChanged != null
          ? ElioBottomNav(active: activeTab!, onTap: onTabChanged!)
          : null,
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
C:\src\flutter\bin\flutter analyze lib/widgets/elio
```

- [ ] **Step 3: Commit Phase 1 primitives**

```bash
git add lib/widgets/elio/ test/widgets/
git commit -m "feat(sprint-16): design system primitives — top bar, bottom nav, hero, button, scaffold"
```

---

## Phase 2 — Home screen

### Task 2.1: Create ElioSecondaryCard

**Files:**
- Create: `lib/widgets/elio/elio_secondary_card.dart`

- [ ] **Step 1: Create widget**

Matches "Plan your week / 21 meals generated in one tap / View" card. Cream background, dark title + subtitle, amber "View" pill on the right.

```dart
// lib/widgets/elio/elio_secondary_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioSecondaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onAction;

  const ElioSecondaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: ElioRadii.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ElioTextStyles.heading3),
                const SizedBox(height: 4),
                Text(subtitle, style: ElioTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: onAction,
            borderRadius: ElioRadii.all(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: ElioColors.amber,
                borderRadius: ElioRadii.all(24),
              ),
              child: Text(actionLabel,
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
C:\src\flutter\bin\flutter analyze lib/widgets/elio/elio_secondary_card.dart
```

### Task 2.2: Rewrite HomeScreen

**Files:**
- Read current: `lib/screens/home/home_screen.dart` (to capture every service call + state variable)
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Audit current screen**

Read the whole file. Make a bullet list (scratch pad) of:
- Every service reference (GeminiService, HistoryService, GuestPantryService, EntitlementService)
- Every state variable
- Every button's onPressed callback
- Every side effect (Firestore writes, analytics events)

These MUST all be preserved in the rewrite.

- [ ] **Step 2: Rewrite build() method only**

Keep class name, state object, all methods and service calls. Replace only the `Widget build(BuildContext context)` body with new widget tree.

```dart
// Skeleton structure:
@override
Widget build(BuildContext context) {
  final firstName = _extractFirstName(); // existing helper or inline
  return Padding(
    padding: const EdgeInsets.fromLTRB(
        ElioSpacing.screenEdge, ElioSpacing.lg,
        ElioSpacing.screenEdge, ElioSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElioHeroHeading(
          lines: ['hey ${firstName.toLowerCase()}.', 'lets get', 'started'],
          amberLastLine: true,
          showUnderline: true,
        ),
        const SizedBox(height: ElioSpacing.md),
        const ElioEyebrow('your kitchen is ready for elio'),
        const Spacer(),
        ElioBigButton(
          label: 'Generate a recipe',
          trailingIcon: Icons.chevron_right,
          loading: _isGenerating,
          onTap: _canGenerate ? _handleGenerate : null,
        ),
        const SizedBox(height: ElioSpacing.md),
        if (_proUnlocked)
          ElioSecondaryCard(
            title: 'Plan your week',
            subtitle: '21 meals generated in one tap',
            actionLabel: 'View',
            onAction: _openMealPlanner,
          ),
        const SizedBox(height: ElioSpacing.md),
      ],
    ),
  );
}

String _extractFirstName() {
  final displayName = FirebaseAuth.instance.currentUser?.displayName;
  if (displayName == null || displayName.isEmpty) return 'there';
  return displayName.split(' ').first;
}
```

- [ ] **Step 3: Analyze**

```bash
C:\src\flutter\bin\flutter analyze lib/screens/home/home_screen.dart
# Expected: "No issues found!"
```

### Task 2.3: Wire HomeScreen into AppShell

**Files:**
- Create: `lib/screens/shell/app_shell.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Create AppShell**

```dart
// lib/screens/shell/app_shell.dart
import 'package:flutter/material.dart';
import '../../widgets/elio/elio_app_scaffold.dart';
import '../../widgets/elio/elio_bottom_nav.dart';
import '../home/home_screen.dart';
import '../pantry/pantry_screen.dart';
// TEMP: until Phase 3+6 land these screens get placeholder content
// import '../recipe_book/recipes_tab_screen.dart';
// import '../shopping/shopping_list_screen.dart';
import '../profile/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  ElioNavTab _tab = ElioNavTab.home;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    switch (_tab) {
      case ElioNavTab.home: body = const HomeScreen(); break;
      case ElioNavTab.pantry: body = const PantryScreen(); break;
      case ElioNavTab.recipes: body = const _Placeholder(label: 'Recipes'); break;
      case ElioNavTab.shoppingList: body = const _Placeholder(label: 'Shopping List'); break;
    }
    return ElioAppScaffold(
      body: body,
      activeTab: _tab,
      onTabChanged: (t) => setState(() => _tab = t),
      onProfileTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String label;
  const _Placeholder({required this.label});
  @override
  Widget build(BuildContext c) => Center(child: Text('$label — coming soon'));
}
```

- [ ] **Step 2: Route main to AppShell**

Find wherever `main.dart` routes to `HomeScreen` directly after auth and replace with `AppShell`.

- [ ] **Step 3: Analyze + existing tests**

```bash
C:\src\flutter\bin\flutter analyze
C:\src\flutter\bin\flutter test
```

### Task 2.4: Build and verify Home on-device

- [ ] **Step 1: Build APK**

```bash
powershell.exe -ExecutionPolicy Bypass -Command "& { $env:PATH='C:\src\flutter\bin;'+$env:PATH; .\build.ps1 -sprint 16.0-home }"
```

- [ ] **Step 2: Install, check visually against Figma node `2:3292`**

Acceptance: layout matches, amber underline present, Generate button clickable, Plan your week card visible for Pro users.

- [ ] **Step 3: Commit**

```bash
git add .
git commit -m "feat(sprint-16): home screen — new editorial layout with design system primitives"
```

---

## Phase 3 — Pantry screen

### Task 3.1: ElioBentoCard

**Files:**
- Create: `lib/widgets/elio/elio_bento_card.dart`

- [ ] **Step 1: Create widget**

Matches the "Scan Receipt" / "Scan Barcode" action cards. Two-tone gradient background, icon in a rounded square top-left, label + title in bottom-left.

```dart
// lib/widgets/elio/elio_bento_card.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioBentoCard extends StatelessWidget {
  final IconData icon;
  final String kicker;
  final String title;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const ElioBentoCard({
    super.key,
    required this.icon,
    required this.kicker,
    required this.title,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: ElioRadii.card,
      child: Container(
        height: 150,
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: backgroundColor, borderRadius: ElioRadii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: ElioRadii.all(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kicker, style: ElioTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 4),
                Text(title, style: ElioTextStyles.heading4.copyWith(color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
C:\src\flutter\bin\flutter analyze lib/widgets/elio/elio_bento_card.dart
```

### Task 3.2: ElioTierRow

**Files:**
- Create: `lib/widgets/elio/elio_tier_row.dart`

- [ ] **Step 1: Create widget**

Row with label + count + trailing chevron. Cream background, rounded.

```dart
// lib/widgets/elio/elio_tier_row.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioTierRow extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback? onTap;
  final Widget? expandedBody;

  const ElioTierRow({
    super.key,
    required this.label,
    required this.count,
    this.onTap,
    this.expandedBody,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: ElioRadii.card,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: ElioColors.cream,
          borderRadius: ElioRadii.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('$label ($count)', style: ElioTextStyles.heading5),
                ),
                const Icon(Icons.chevron_right,
                    color: ElioColors.navy, size: 24),
              ],
            ),
            if (expandedBody != null) ...[
              const SizedBox(height: 12),
              expandedBody!,
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

### Task 3.3: Rewrite PantryScreen

**Files:**
- Modify: `lib/screens/pantry/pantry_screen.dart`

- [ ] **Step 1: Audit current screen**

Capture: scanner entry points, PantryBuilder sheet, tier collapse state, Firestore stream subscription, category-grouping toggle.

- [ ] **Step 2: Rewrite build() body**

Match Figma node `2:3192` — hero heading, 2-column bento row, Pantry Builder row, 3 tier rows (Perishables, Always Have, Almost Always Have).

```dart
// Simplified skeleton — adapt inside existing State class.
@override
Widget build(BuildContext context) {
  return SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(
        ElioSpacing.screenEdge, ElioSpacing.lg,
        ElioSpacing.screenEdge, ElioSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ElioHeroHeading(
          lines: ['what did you', 'pick up?'],
          amberLastLine: true,
          showUnderline: true,
        ),
        const SizedBox(height: ElioSpacing.xl),
        Row(
          children: [
            Expanded(
              child: ElioBentoCard(
                icon: Icons.receipt_long_outlined,
                kicker: 'Photo or camera',
                title: 'Scan receipt',
                backgroundColor: const Color(0xFFE87A5C), // salmon from Figma
                onTap: _openReceiptScanner,
              ),
            ),
            const SizedBox(width: ElioSpacing.lg),
            Expanded(
              child: ElioBentoCard(
                icon: Icons.qr_code_scanner_outlined,
                kicker: 'Item lookup',
                title: 'Scan barcode',
                backgroundColor: ElioColors.amber,
                onTap: _openBarcodeScanner,
              ),
            ),
          ],
        ),
        const SizedBox(height: ElioSpacing.xl),
        _PantryBuilderRow(onTap: _openPantryBuilder),
        const SizedBox(height: ElioSpacing.md),
        ElioTierRow(
            label: 'Perishables',
            count: _perishableCount,
            onTap: () => _toggleTier(Tier.perishable)),
        const SizedBox(height: ElioSpacing.sm),
        ElioTierRow(
            label: 'Always Have',
            count: _alwaysHaveCount,
            onTap: () => _toggleTier(Tier.alwaysHave)),
        const SizedBox(height: ElioSpacing.sm),
        ElioTierRow(
            label: 'Almost Always Have',
            count: _almostAlwaysCount,
            onTap: () => _toggleTier(Tier.almostAlwaysHave)),
      ],
    ),
  );
}
```

- [ ] **Step 3: Preserve existing tier-expansion body**

If `_toggleTier` currently shows items inline, pass them via `ElioTierRow.expandedBody`.

- [ ] **Step 4: Analyze**

```bash
C:\src\flutter\bin\flutter analyze
```

### Task 3.4: Build and verify Pantry on-device

- [ ] **Step 1: Build APK**

```bash
powershell.exe -ExecutionPolicy Bypass -Command "& { $env:PATH='C:\src\flutter\bin;'+$env:PATH; .\build.ps1 -sprint 16.1-pantry }"
```

- [ ] **Step 2: Visually verify against Figma node `2:3192`**

Acceptance: hero heading matches, bento cards correct colors, tier rows show live counts, scan actions open existing scanner screens.

- [ ] **Step 3: Commit**

```bash
git add .
git commit -m "feat(sprint-16): pantry screen — bento cards, tier rows, new hero heading"
```

---

## Phase 4 — Recipe screen

### Task 4.1: ElioStatBadge

**Files:**
- Create: `lib/widgets/elio/elio_stat_badge.dart`

- [ ] **Step 1: Create widget**

Small pill with icon + value. Used for time, prep, cost, kcal.

```dart
// lib/widgets/elio/elio_stat_badge.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioStatBadge extends StatelessWidget {
  final IconData icon;
  final String value;

  const ElioStatBadge({super.key, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: ElioRadii.all(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: ElioColors.navy),
          const SizedBox(width: 8),
          Text(value, style: ElioTextStyles.statValue),
        ],
      ),
    );
  }
}
```

### Task 4.2: ElioServingsControl

**Files:**
- Create: `lib/widgets/elio/elio_servings_control.dart`

- [ ] **Step 1: Create widget with state**

```dart
// lib/widgets/elio/elio_servings_control.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioServingsControl extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const ElioServingsControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(icon: Icons.remove,
            onTap: value > min ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 48,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: ElioTextStyles.heading3),
        ),
        _RoundButton(icon: Icons.add,
            onTap: value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundButton({required this.icon, this.onTap});
  @override
  Widget build(BuildContext c) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: ElioRadii.all(999),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: enabled ? ElioColors.amber : ElioColors.amber.withValues(alpha: 0.3),
          borderRadius: ElioRadii.all(999),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
```

- [ ] **Step 2: Widget test — increment/decrement + bounds**

Create `test/widgets/elio_servings_control_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_servings_control.dart';

void main() {
  testWidgets('increments and decrements, respects bounds', (tester) async {
    int value = 2;
    await tester.pumpWidget(StatefulBuilder(builder: (c, setState) =>
      MaterialApp(home: Scaffold(body: ElioServingsControl(
        value: value, min: 1, max: 4,
        onChanged: (v) => setState(() => value = v),
      ))),
    ));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('4'), findsOneWidget);

    // At max — add button disabled, nothing happens
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('4'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test**

```bash
C:\src\flutter\bin\flutter test test/widgets/elio_servings_control_test.dart
```

### Task 4.3: ElioIngredientRow, ElioMethodStep, ElioFeedbackBar

**Files:**
- Create: `lib/widgets/elio/elio_ingredient_row.dart`
- Create: `lib/widgets/elio/elio_method_step.dart`
- Create: `lib/widgets/elio/elio_feedback_bar.dart`

- [ ] **Step 1: ElioIngredientRow**

```dart
// Circle checkbox + bold name + small detail underneath.
class ElioIngredientRow extends StatelessWidget {
  final String name;
  final String? detail;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  const ElioIngredientRow({
    super.key,
    required this.name,
    this.detail,
    this.checked = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24, height: 24,
              margin: const EdgeInsets.only(right: 16, top: 2),
              decoration: BoxDecoration(
                color: checked ? ElioColors.amber : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: checked ? ElioColors.amber : ElioColors.border,
                  width: 2,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: ElioTextStyles.heading5),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail!, style: ElioTextStyles.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: ElioMethodStep**

```dart
class ElioMethodStep extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String body;

  const ElioMethodStep({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(stepNumber.toString().padLeft(2, '0'),
                style: ElioTextStyles.stepNumeral),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ElioTextStyles.heading4),
                const SizedBox(height: 8),
                Text(body, style: ElioTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: ElioFeedbackBar**

```dart
class ElioFeedbackBar extends StatelessWidget {
  final ValueChanged<bool> onRated; // true = thumbs up

  const ElioFeedbackBar({super.key, required this.onRated});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: ElioRadii.card,
      ),
      child: Row(
        children: [
          Expanded(child: Text('How was the recipe?', style: ElioTextStyles.heading5)),
          IconButton(
            icon: const Icon(Icons.thumb_up_outlined, color: ElioColors.navy),
            onPressed: () => onRated(true),
          ),
          IconButton(
            icon: const Icon(Icons.thumb_down_outlined, color: ElioColors.navy),
            onPressed: () => onRated(false),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Analyze all three**

```bash
C:\src\flutter\bin\flutter analyze lib/widgets/elio
```

### Task 4.4: Rewrite RecipeScreen

**Files:**
- Modify: `lib/screens/recipe/recipe_screen.dart`

- [ ] **Step 1: Audit current recipe screen**

Critical business logic to preserve:
- Streaming generation + shimmer skeleton
- Ingredient tap → substitution dialog
- Voice cooking (hands-free mode)
- Save / bookmark toggle
- Add to shopping list
- Generate another / regenerate with exclusions
- Cost display (region-aware)
- Taste profile tracking (liked/disliked recipes)

Every one of these features must still work post-rewrite.

- [ ] **Step 2: Rewrite body build() using primitives**

Match Figma node `2:3046`. Rough structure:

```dart
ListView(
  padding: const EdgeInsets.symmetric(horizontal: ElioSpacing.xl, vertical: ElioSpacing.lg),
  children: [
    // Top actions: share, bookmark, shopping list
    Row(mainAxisAlignment: MainAxisAlignment.end, children: [...]),
    const SizedBox(height: ElioSpacing.md),
    Text(recipe.title, style: ElioTextStyles.heroDisplayAccent), // amber title
    const SizedBox(height: ElioSpacing.md),
    Text(recipe.description, style: ElioTextStyles.body),
    const SizedBox(height: ElioSpacing.lg),
    Wrap(spacing: 8, runSpacing: 8, children: [
      ElioStatBadge(icon: Icons.schedule, value: '${recipe.totalMinutes}m'),
      ElioStatBadge(icon: Icons.restaurant, value: '${recipe.prepMinutes}m prep'),
      ElioStatBadge(icon: Icons.attach_money, value: recipe.formattedCost),
      ElioStatBadge(icon: Icons.local_fire_department, value: '${recipe.kcal} kcal'),
    ]),
    const SizedBox(height: ElioSpacing.lg),
    Row(children: [
      const Icon(Icons.people_outline, color: ElioColors.navy),
      const SizedBox(width: 12),
      const Expanded(child: Text('Servings')),
      ElioServingsControl(
          value: _servings,
          onChanged: _adjustServings),
    ]),
    const SizedBox(height: ElioSpacing.xl),
    Text('Ingredients', style: ElioTextStyles.heading2),
    const SizedBox(height: ElioSpacing.md),
    for (final ing in recipe.ingredients)
      ElioIngredientRow(
          name: ing.name,
          detail: ing.detail,
          checked: _checkedIngredients.contains(ing.id),
          onChanged: (v) => _onIngredientTap(ing, v)),
    const SizedBox(height: ElioSpacing.xl),
    Text('Method', style: ElioTextStyles.heading2),
    const SizedBox(height: ElioSpacing.md),
    for (int i = 0; i < recipe.steps.length; i++)
      ElioMethodStep(
          stepNumber: i + 1,
          title: recipe.steps[i].title,
          body: recipe.steps[i].body),
    const SizedBox(height: ElioSpacing.xl),
    ElioFeedbackBar(onRated: _saveRating),
    const SizedBox(height: ElioSpacing.md),
    ElioBigButton(
      label: 'Generate another',
      trailingIcon: Icons.all_inclusive,
      loading: _isGenerating,
      onTap: _generateAnother,
    ),
  ],
)
```

- [ ] **Step 3: Preserve shimmer/streaming state**

If title is empty (streaming), wrap in Shimmer block as before — don't remove loading UI.

- [ ] **Step 4: Preserve ingredient long-press → substitution**

The ingredient row's `onChanged` handles tap-to-check; long-press still opens substitution dialog. Use `GestureDetector` or wrap `ElioIngredientRow` in a `Listener` that captures both.

- [ ] **Step 5: Analyze + tests**

```bash
C:\src\flutter\bin\flutter analyze
C:\src\flutter\bin\flutter test
```

### Task 4.5: Build and verify Recipe on-device

- [ ] **Step 1: Build APK**

```bash
powershell.exe -ExecutionPolicy Bypass -Command "& { $env:PATH='C:\src\flutter\bin;'+$env:PATH; .\build.ps1 -sprint 16.2-recipe }"
```

- [ ] **Step 2: Full regression walkthrough**

Test on device:
- Generate a recipe from home, verify streaming + shimmer
- Tap an ingredient → check toggles
- Long-press an ingredient → substitution dialog opens
- Tap bookmark → saves to recipe book
- Tap shopping cart → adds missing ingredients
- Tap thumbs up/down → writes to taste profile
- Tap "Generate another" → regenerates using same pantry/preferences
- Voice cooking (hands-free) still works

Any failed item is a blocker.

- [ ] **Step 3: Commit**

```bash
git add .
git commit -m "feat(sprint-16): recipe screen — new typographic layout, stats pills, numbered steps"
```

---

## Phase 5 — Dietary & Allergens screen

### Task 5.1: ElioChip

**Files:**
- Create: `lib/widgets/elio/elio_chip.dart`

- [ ] **Step 1: Create widget**

Two states: selected (amber fill, white text) and unselected (white background, navy text, grey border). Optional dropdown caret for chips with sub-choices (e.g., "Vegetarian ▾").

```dart
// lib/widgets/elio/elio_chip.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool hasDropdown;
  final VoidCallback? onTap;

  const ElioChip({
    super.key,
    required this.label,
    required this.selected,
    this.hasDropdown = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? ElioColors.amber : Colors.white;
    final fg = selected ? Colors.white : ElioColors.navy;
    final borderColor = selected ? ElioColors.amber : ElioColors.border;
    return InkWell(
      onTap: onTap,
      borderRadius: ElioRadii.chip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: ElioRadii.chip,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: ElioTextStyles.body.copyWith(color: fg)),
            if (hasDropdown) ...[
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down, color: fg, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Widget test — tap flips selected state via callback**

```dart
// test/widgets/elio_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_chip.dart';

void main() {
  testWidgets('tapping chip fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: ElioChip(label: 'Vegetarian', selected: false, onTap: () => tapped = true),
    ))));
    await tester.tap(find.text('Vegetarian'));
    expect(tapped, true);
  });
}
```

- [ ] **Step 3: Run test + analyze**

```bash
C:\src\flutter\bin\flutter test test/widgets/elio_chip_test.dart
C:\src\flutter\bin\flutter analyze
```

### Task 5.2: ElioCustomField

**Files:**
- Create: `lib/widgets/elio/elio_custom_field.dart`

- [ ] **Step 1: Create widget**

```dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

class ElioCustomField extends StatelessWidget {
  final String placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;

  const ElioCustomField({
    super.key,
    required this.placeholder,
    this.controller,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: ElioRadii.card,
      ),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        style: ElioTextStyles.body,
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: ElioTextStyles.body.copyWith(color: ElioColors.textSecondary),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

### Task 5.3: Rewrite DietaryScreen

**Files:**
- Modify: `lib/screens/profile/dietary_screen.dart`

- [ ] **Step 1: Audit current**

Capture: list of dietary option strings, multi-select state, allergy text field, Firestore save on dismiss.

- [ ] **Step 2: Rewrite build()**

Match Figma node `43:6505`. Hero heading, Eyebrow "you can pick multiple", Wrap of ElioChips, custom allergens section with ElioCustomField.

```dart
@override
Widget build(BuildContext context) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(ElioSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ElioHeroHeading(
          lines: ['dietary &', 'allergens'],
          amberLastLine: true,
        ),
        const SizedBox(height: ElioSpacing.md),
        Text("elio wont suggest recipes that dont work for you.",
            style: ElioTextStyles.body),
        const SizedBox(height: ElioSpacing.xl),
        Text('Dietary requirements', style: ElioTextStyles.heading3),
        const SizedBox(height: ElioSpacing.sm),
        const ElioEyebrow('you can pick multiple'),
        const SizedBox(height: ElioSpacing.md),
        Wrap(
          spacing: 8, runSpacing: 10,
          children: [
            for (final opt in _dietaryOptions)
              ElioChip(
                label: opt.label,
                selected: _selected.contains(opt.id),
                hasDropdown: opt.hasDropdown,
                onTap: () => _toggle(opt.id),
              ),
          ],
        ),
        const SizedBox(height: ElioSpacing.xxl),
        Text('Custom allergens or dietary requirements',
            style: ElioTextStyles.heading3),
        const SizedBox(height: ElioSpacing.sm),
        Text("add anything that isn't listed above in the custom text field below",
            style: ElioTextStyles.bodySmall),
        const SizedBox(height: ElioSpacing.md),
        ElioCustomField(
          placeholder: 'e.g. shellfish, mustard',
          controller: _customCtrl,
          onSubmitted: _saveCustom,
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: Analyze + test**

### Task 5.4: Build and verify Dietary on-device

- [ ] **Step 1: Build APK**

```bash
powershell.exe -ExecutionPolicy Bypass -Command "& { $env:PATH='C:\src\flutter\bin;'+$env:PATH; .\build.ps1 -sprint 16.3-dietary }"
```

- [ ] **Step 2: Visually verify against Figma node `43:6505`**

Acceptance: chips toggle correctly, Firestore save fires on change, custom allergen text persists, hero heading matches.

- [ ] **Step 3: Commit**

```bash
git add .
git commit -m "feat(sprint-16): dietary & allergens screen — chip-based selector, custom field"
```

---

## Phase 6 — Remaining screens (stretch — match new design language)

These screens are NOT in Kate's ready-for-dev set. Apply the new design system consistently. Expect Kate to iterate once she sees them in context.

### Task 6.1: Shopping List screen (new top-level tab)

**Files:** `lib/screens/shopping/shopping_list_screen.dart`

- [ ] Wrap in ElioAppScaffold, use ElioTierRow for aisle groupings, ElioIngredientRow for items, ElioBigButton for "Share list".
- [ ] Preserve: isChecked toggle, source tracking, share functionality, aisle sort.
- [ ] Analyze + test + build + on-device verify.
- [ ] Commit.

### Task 6.2: Recipes tab (Recipe Book)

**Files:** Create `lib/screens/recipes/recipes_tab_screen.dart` (extract from Profile). Modify `app_shell.dart` to route the tab here.

- [ ] ElioHeroHeading "your recipes", segmented control for Saved / History, grid or list of recipe cards using existing cover-image layout restyled with ElioRadii.card + ElioTextStyles.
- [ ] Preserve: bookmark toggle, tap to open recipe detail.
- [ ] Analyze + build + verify.
- [ ] Commit.

### Task 6.3: Profile screen simplification

**Files:** `lib/screens/profile/profile_screen.dart`

- [ ] Remove Pantry, Recipe Book, Shopping tabs. Keep Style (or fold into Settings).
- [ ] Apply ElioAppScaffold with `showBottomNav: false` (not a main nav destination).
- [ ] Settings entry point lists: Dietary & Allergens, Kitchen/Appliances, Household, Account, Measurement Units, etc.
- [ ] Analyze + build + verify.
- [ ] Commit.

### Task 6.4: Onboarding (8 screens)

**Files:** `lib/screens/onboarding/screen1_dietary.dart` through `screen8_complete.dart`

- [ ] Apply ElioHeroHeading, ElioChip (for dietary, allergies, appliances), ElioBigButton for CTAs, ElioCustomField where used.
- [ ] Each screen one commit.
- [ ] Final build + on-device walk-through.

### Task 6.5: Paywall

**Files:** `lib/screens/paywall/paywall_screen.dart`

- [ ] Apply ElioHeroHeading, ElioBigButton for "Start your 7-day trial", ElioSecondaryCard for feature bullets.
- [ ] Preserve ALL paywall logic — trigger context, dry-mode `_showTrialState`, package handling (see CLAUDE.md Paywall logic section).
- [ ] Regression test: package-empty path still shows trial state.
- [ ] Commit.

### Task 6.6: Meal planner

**Files:** `lib/screens/meal_plan/meal_plan_screen.dart`

- [ ] Apply ElioAppScaffold, ElioTierRow for day grouping, ElioStatBadge for stats, ElioBigButton for "Generate plan".
- [ ] Preserve two-phase generation, lazy detail load.
- [ ] Commit.

---

## Phase 7 — Cleanup + release

### Task 7.1: Remove orphaned old widgets

- [ ] **Step 1:** `grep` for old `.withOpacity(` — should be zero. Fix any remaining.
- [ ] **Step 2:** Find unreferenced widgets. Delete them.
- [ ] **Step 3:** `flutter analyze` — zero warnings.

### Task 7.2: Update docs

**Files:**
- Modify: `CLAUDE.md` (Design System section)
- Modify: `docs/roadmap.md` (mark Sprint 16 complete)
- Create: `docs/brand-art-concept.md` sync block (if Kate wants it)

- [ ] **Step 1:** Update CLAUDE.md Design System section to reference `lib/theme/elio_spacing.dart`, `elio_radii.dart`, `elio_text_styles.dart` and `lib/widgets/elio/` primitives.
- [ ] **Step 2:** Roadmap — mark tasks 1–7 of Sprint 16 complete, set status row.
- [ ] **Step 3:** Commit.

```bash
git commit -m "docs(sprint-16): update CLAUDE.md + roadmap for new design system"
```

### Task 7.3: Final release build + tag

- [ ] **Step 1:** Full build

```bash
powershell.exe -ExecutionPolicy Bypass -Command "& { $env:PATH='C:\src\flutter\bin;'+$env:PATH; .\build.ps1 -sprint 16 }"
```

- [ ] **Step 2:** Install on device, full smoke test across every screen.
- [ ] **Step 3:** Tag (script handles this).
- [ ] **Step 4:** Push branch

```bash
git push origin sprint/16
```

- [ ] **Step 5:** Delete `design/ui-refresh` (now redundant)

```bash
git push origin --delete design/ui-refresh
git branch -D design/ui-refresh
```

---

## Confirmed user flow (Elio V1 diagram, 19 Apr 2026)

Rob supplied the complete V1 user flow as a diagram. It resolves the previous
open questions. The four bottom-nav destinations and their sub-flows are:

### 1. Home
- Hero CTA: **Generate Recipe** → **Recipe Preferences Screen** (Mood / Style /
  Time selectors with a "Generate" CTA) → **Recipe Screen**.
- Secondary CTA: **Meal Plan** → Meal Plan flow (see below).

### 2. Recipe Book (new tab — replaces old Profile tab)
Contents, top to bottom:
- **Search Everything** field.
- **Saved** list.
- **History** list.
- **Pantry Availability** switch (filter to recipes you can cook now).
- **Import Recipe** row → split CTA: **Take Photo** / **Manual Entry**.

### 3. Shopping List
- **Add Item** field with inline Add CTA.
- **Active Shopping List** with check / uncheck rows.
- **Share Shopping List** action (reuses existing `share_plus` formatter,
  grouped by aisle).

### 4. Account (replaces legacy Profile screen)
Account landing is a list of sub-screens:
- Manage Subscription (deep-links to Google Play / App Store native management)
- Manage Household Members
- Dietary & Allergens
- Food Style
- Kitchen Appliances
- Metrics Preferences (imperial / metric)

### Recipe Screen CTAs (confirmed)
Bookmark · Share · Shopping List · Servings · Thumbs Up/Down · **Hands-Free
Mode** · **Generate Another**.

### Hands-Free Mode (triggered from Recipe Screen)
Staggered "Recipe Step" screens with chrome: **Exit**, **Mic On/Off**, **Back**.
Existing voice-cooking implementation is preserved; only chrome is re-skinned.

### Meal Plan flow
1. Home CTA → **Meal Plan** (Week Calendar view, rows = Breakfast / Lunch /
   Dinner, columns = Mon–Sun).
2. Per-meal actions: **Regenerate**, **Add to Shopping List**, **Restart**,
   **Batch Regenerate** (regen all remaining in a day / week).
3. Tapping "Add to Shopping List" surfaces a **Suggested Additions** popup
   (missing pantry items) → **Confirm Add** or **Go To Shopping List**.

### Impact on plan tasks
- **Phase 3 bottom nav enum** — tab 2 is `recipeBook` (icon: book), tab 4 is
  `account` (icon: person). Keep labels: Home · Recipes · Shop · Account.
- **Phase 5 — Home screen** adds a new downstream screen: **Recipe Preferences
  Screen** (Mood / Style / Time selectors) between Generate CTA and Recipe
  Screen. Create `lib/screens/home/recipe_preferences_screen.dart`. Widgets
  reused: `ElioAppScaffold`, `ElioEyebrow`, `ElioChip` (for mood/style/time
  options), `ElioBigButton` ("Generate").
- **Phase 6 — Recipe Book tab** (new screen): `lib/screens/recipe_book/recipe_book_screen.dart`.
  Sections: search field (`ElioCustomField`), Saved list, History list,
  `SwitchListTile` styled with Elio tokens for Pantry Availability, Import row
  with two `ElioSecondaryCard` CTAs (Take Photo / Manual Entry). This replaces
  the Assumed "Saved + History segmented" layout from earlier drafts.
- **Phase 6 — Account screen**: `lib/screens/account/account_screen.dart` — a
  vertical list of `ElioSecondaryCard` rows, one per sub-screen listed above.
  Each row navigates to the existing sub-screen (dietary, kitchen, household,
  settings/metrics). Subscription row uses platform URL launch.
- **Phase 6 — Shopping tab**: confirm Add Item + inline CTA at top, existing
  checkable list below, Share action in app-bar trailing.
- **Phase 6 — Meal Plan**: keep week grid; per-cell sheet must expose the four
  actions (Regenerate / Add to Shopping / Restart / Batch Regenerate) via
  `showDialog` (not nested bottom sheet). Suggested Additions popup is a
  `showDialog` with two CTAs.
- **Phase 6 — Hands-Free Mode**: re-skin chrome only. Existing `voice_control`
  service, beep mute behaviour, and `LongPressGestureRecognizer` must be
  preserved (see CLAUDE.md gotchas).

## Remaining open questions (still for Kate)

- Paywall visual design — can the trial hero be applied to the new layout
  without breaking `_showTrialState` logic? (Code logic is fixed; only visuals
  change.)
- Onboarding — is the 8-screen flow unchanged, or does it collapse into fewer
  screens with the new design system?
- Recipe Preferences screen — exact chip options for Mood / Style / Time and
  whether any are multi-select.
- Meal Plan week grid — exact visual treatment of empty cells vs. planned
  meals.

## Known risks

- Ingredient long-press vs. tap-to-check conflict on Recipe screen — existing code uses `RawGestureDetector` with `LongPressGestureRecognizer` (see CLAUDE.md Flutter gotchas). Must preserve.
- Bottom sheets inside bottom sheets — CLAUDE.md says fail silently. Any new flows must use `showDialog` when nested.
- Paywall dry-mode logic — do not let package-empty be treated as "no trial". The `_showTrialState` getter is non-trivial.
- Firebase client breakage — dev flavor is broken. Always `--flavor prod` per build.ps1.
