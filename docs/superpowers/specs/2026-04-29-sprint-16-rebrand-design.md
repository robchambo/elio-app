# Sprint 16 Rebrand — Design System Spec

**Branch:** `sprint/16-rebrand` (off `sprint/16` at `7140169`)
**Status:** design spec — pending Rob review, then writing-plans hand-off
**Author:** Rob Thomas + Claude (sprint/16-rebrand brainstorm, 2026-04-29)
**Source material:**
- 9 Figma frames from Kate (Home, Recipe Detail, Onboarding splash, Onboarding Q1–Q4, Dietary & Allergens, Pantry tab)
- Type specimen `Elio — fonts.html` (Bricolage Grotesque + DM Sans + DM Mono)

---

## 1. Goal

Rebrand Elio's UI to Kate's 2026 design language in a single hard-rename migration on `sprint/16-rebrand`. Replace the navy/amber/Outfit identity with cream/terracotta/Bricolage. Land the new design system, all token renames, and every Kate-delivered screen on the new system. By end of branch, no references to the old palette or old font remain.

## 2. Scope

### In scope

- **Hard token rename** (no V1/V2 coexistence): `navy → espresso`, `amber → terracotta`, `offWhite → cream`, `sky → terracotta` (31 callers across 7 files; sky was secondary accent for info states, terracotta absorbs that role per Kate's frames), plus new tokens (`creamDeep`, `peach`, `mocha`, `rule`).
- **Font swap, bundled as assets**: Outfit → Bricolage Grotesque (display), Quicksand → DM Sans (body), introduce DM Mono (technical eyebrows/labels). Remove `google_fonts` package dependency.
- **New heading widgets**: `ElioPageTitle`, `ElioHeroDisplay`, `ElioSectionHeading`. The first two implement the **D-rule** (string-convention period detection — see §5).
- **Restyle every existing widget** in `lib/widgets/elio/` (~30 widgets) to the new tokens.
- **Migrate every screen** that uses any restyled widget. Two systems cannot coexist in the merged branch.
- **Add `ElioBackdropIllustration`** widget — full-app brand backdrop, kale-leaf SVG default, variant API for future swaps.
- **Bottom nav label change**: `SHOPPING` → `SHOPPING LIST`.
- **`flutter analyze` clean, all tests green, APK builds and runs on device.**

### Out of scope

- Behavioural / flow changes — this is a **visual rebrand only**. Same routes, same screens, same data flow, same Gemini prompts, same Firestore schema.
- Sprint 17 GDPR work (consent banner, age gate, Settings export/delete UI) — already specced in `docs/superpowers/plans/2026-04-28-sprint-17-gdpr-compliance.md`.
- Cloud Functions, Firebase App Check, server-side Gemini — Sprint 18 launch-readiness.
- Apple Sign-In — Sprint 19.
- Pre-Sprint-16 helpers in `lib/widgets/` outside `elio/` (`elio_progress_bar.dart`, `pantry_builder_sheet.dart`, `recipe_category_chip_row.dart`) — only restyled if they appear on a delivered screen.
- Replacing the kale leaf with per-screen illustrations — Kate flagged future variation; we ship single-variant API now.

---

## 3. Colour tokens (locked)

Source of truth: type specimen CSS variables, cross-checked against Kate's frames.

| Token name | Hex | Use |
|---|---|---|
| `ElioColors.cream` | `#F4ECE0` | App scaffold background, every screen except inverse moments |
| `ElioColors.creamDeep` | `#EFE3D2` | Card surfaces, idle chips, tier rows, bento tiles, idle inputs, feedback panel |
| `ElioColors.terracotta` | `#E37B53` | Primary CTA, period closer, selected chip fill, accent rule, terracotta numerals, scanner-icon tint |
| `ElioColors.peach` | `#F2C9A8` | Secondary pill button (e.g. "View"), stepper plus, soft accent on dark surfaces |
| `ElioColors.espresso` | `#2A1F1A` | Primary text, active nav, page titles |
| `ElioColors.mocha` | `#6B5A4F` | Secondary text, idle nav, sub-copy, eyebrow text |
| `ElioColors.rule` | `#D7C5B0` | Dividers, idle borders, progress-bar unfilled track |

**Retained from current system (no rename):**
- `ElioColors.error` `#D94A4A`
- `ElioColors.success` `#3D9970`
- Onboarding tier tokens `freshGreen` / `perishThisWeek` / `perishToday` — Kate has not redesigned the perishable-tier visual language yet, so these stay.

**Removed:**
- `ElioColors.navy`, `amber`, `sky`, `offWhite`, `white`, `border`, `textPrimary`, `textSecondary`, `textMuted` — replaced by new tokens or read from `Theme.of(context).textTheme`.

---

## 4. Typography (locked)

### Three families, bundled as assets

| Family | Weights bundled | File source | Role |
|---|---|---|---|
| Bricolage Grotesque | Variable 200–800 (single VF file) | Google Fonts open-source | Display, page titles, section headings |
| DM Sans | Variable 100–1000 | Google Fonts open-source | Body, UI labels, tab labels, lede |
| DM Mono | 400, 500 (statics) | Google Fonts open-source | Eyebrows, slide markers, units, dates |

**Rationale for bundling vs `google_fonts` package:**
- Removes a runtime sub-processor (cleaner against the privacy policy already drafted).
- Faster cold start, works offline.
- ~330 KB APK growth (Bricolage VF ~150 KB, DM Sans VF ~80 KB, DM Mono ~50 KB × 2). Acceptable.
- Drops `google_fonts` package — full grep required to confirm no callers outside `elio_theme.dart`/`elio_text_styles.dart`.

### Type roles

| Role | Family | Weight | Size | Tracking | Case | Used on |
|---|---|---|---|---|---|---|
| Hero display | Bricolage | 800 | 56–84 | -3.5% | lowercase | Onboarding splash |
| Page title | Bricolage | 800 | 40–48 | -3% | lowercase | Home, Recipe Detail, in-app screen titles |
| Section heading | Bricolage | 700 | 22–28 | -2.5% | sentence case | "Ingredients", "Pantry Builder", "Dietary requirements" |
| Lede / tagline | DM Sans | 500 | 17–22 | 0 | natural | Onboarding splash sub-copy |
| Body | DM Sans | 400 | 16 | 0 | natural | Paragraphs |
| Body small | DM Sans | 400 | 14 | 0 | natural | Sub-copy under page titles, sub-lines on rows |
| UI label | DM Sans | 600 | 16 | 0 | natural | List rows, button labels, ingredient names |
| Tab label | DM Sans | 500 | 11 | +18% | UPPERCASE | Bottom nav |
| Eyebrow | DM Mono | 500 | 12 | +20% | UPPERCASE | Section eyebrows, action-tile sub-labels |
| Slide marker | DM Mono | 500 | 14 | +18% | UPPERCASE | Marketing/onboarding slide numbers (post-launch) |
| Numeric | DM Mono | 600 | 13–15 | +12% | natural | Stat values, prices |

Sizes are min/max of observed; finalize by widget after first compile.

---

## 5. Heading widgets (the D rule)

`ElioPageTitle(String text, {double? fontSize, TextAlign? align})`
- Bricolage 800, lowercase, espresso colour.
- **Walks the string char-by-char and renders any `.` glyph in `ElioColors.terracotta` via `TextSpan`.**
- Question marks and exclamation marks stay espresso (no special handling).
- Caller authors string naturally; brand consistency is automatic.

| Author writes | Result |
|---|---|
| `'hey kate. lets get started'` | mid-string `.` is terracotta |
| `'tonights dinner, from what you already have.'` | terminal `.` is terracotta |
| `'creamy lemon pasta'` | no terracotta |
| `'what brought you to elio?'` | no terracotta |

`ElioHeroDisplay` — alias of `ElioPageTitle` with default `fontSize: 64`. Used on onboarding splash and any future cover screens.

`ElioSectionHeading(String text)`
- Bricolage 700, **case as authored** (no auto-lowercase), espresso.
- No period treatment.
- For "Ingredients" / "Pantry Builder" / "Custom allergens or dietary requirements".

**Rejected alternatives:**
- A: auto-append period — wrong because question screens and recipe titles don't take one.
- B: enum closer parameter — over-engineered; YAGNI.
- C: manual `ElioPeriod()` widget — relies on author discipline; brand consistency would drift.

**Edge case acknowledged:** `ElioPageTitle('elio.app')` would colour both periods. Not currently a real case in the app. If it arises, add `escapePeriods: true` — defer until needed.

---

## 6. Layout primitives

### Spacing (keep current `ElioSpacing`)
8-pt scale: `xs 4` / `sm 8` / `md 12` / `lg 16` / `xl 24` / `xxl 32` / `xxxl 48` / `screenEdge 20`.

### Radii (refresh from frames)
- `chip`: 999 (full pill) — ingredient chips, dietary chips
- `button`: 20 — primary CTA, peach pill, action tiles
- `card`: 16 — bento tiles, option cards, tier rows
- `panel`: 14 — feedback bar, stat pill row
- `input`: 14 — text fields

### Shell composition
- `ElioAppScaffold` gains an `ElioBackdropIllustration` layer behind the body content (positioned right, faded, bleeds off edge).
- Top app bar: `elio` wordmark left (Bricolage 800, lowercase, espresso), profile icon right (round, terracotta-tinted on tap).
- Bottom nav: 4 tabs `HOME / PANTRY / RECIPES / SHOPPING LIST`, active tab espresso icon + label, inactive mocha. Outline icons throughout.

---

## 7. Asset strategy

### Fonts

`pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: Bricolage Grotesque
      fonts:
        - asset: assets/fonts/bricolage_grotesque/BricolageGrotesque[opsz,wdth,wght].ttf
    - family: DM Sans
      fonts:
        - asset: assets/fonts/dm_sans/DMSans[opsz,wght].ttf
    - family: DM Mono
      fonts:
        - asset: assets/fonts/dm_mono/DMMono-Regular.ttf
        - asset: assets/fonts/dm_mono/DMMono-Medium.ttf
          weight: 500
```

Source files: download from Google Fonts (`fonts.google.com/specimen/Bricolage+Grotesque`, etc.). Variable fonts preferred where available.

`google_fonts` removed from `pubspec.yaml` after migration. Final compile sweep must show zero `GoogleFonts.` callers in `lib/`.

### Botanical illustration

`assets/illustrations/backdrop_kale.svg` — kale leaf, sketched style, single-colour outline (mocha tint, ~12% opacity overlay).

`ElioBackdropIllustration({Variant variant = .kale})` widget:
- Returns a `Positioned` `SvgPicture.asset(...)` aligned to the right edge of the parent stack, overflowing the right ~30%.
- Applies a `ColorFilter` with mocha @ ~12% opacity.
- Variant enum (`kale`, future: `tomato`, `herbs`, etc.) selects asset path; default is `kale`.
- Inserted by `ElioAppScaffold` into a `Stack` between scaffold background and body.

If the SVG can't be exported from Figma in time, ship a 2× PNG fallback at `assets/illustrations/backdrop_kale@2x.png` and load via `Image.asset` with the same opacity treatment. Figma's Dev Mode export should work; if not, Kate to provide.

---

## 8. Widget migration map

Every widget in `lib/widgets/elio/` is restyled. None are deleted. Most are mechanical re-skin; the heading widgets are the only structural changes.

| Widget | Action | Notes |
|---|---|---|
| `elio_app_scaffold.dart` | Add backdrop layer | Insert `ElioBackdropIllustration` into body Stack |
| `elio_top_app_bar.dart` | Restyle | Wordmark Bricolage 800 lowercase + profile icon right |
| `elio_bottom_nav.dart` | Restyle + relabel | "SHOPPING" → "SHOPPING LIST"; DM Sans 500 +18% UPPER; espresso/mocha |
| `elio_big_button.dart` | Restyle | Terracotta bg, white text, full-width pill, chevron-right or custom icon |
| `elio_hero_heading.dart` | **Delete after callers migrate** | Replaced by `ElioPageTitle` / `ElioHeroDisplay` |
| `elio_eyebrow.dart` | Restyle | DM Mono 500 +20% UPPER mocha |
| `elio_chip.dart` | Restyle | Selected: terracotta + tick; idle: cream-deep + espresso |
| `elio_chip_text_input.dart` | Restyle | Cream-deep, mocha placeholder |
| `elio_secondary_card.dart` | Restyle | Cream-deep panel + peach pill action |
| `elio_bento_card.dart` | Restyle | Round terracotta-tinted icon top, eyebrow + bold label |
| `elio_tier_row.dart` | Restyle | Cream-deep pill, sentence-case + count, right chevron |
| `elio_ingredient_row.dart` | Restyle | Terracotta circle (idle) → tick (checked); espresso name + mocha sub |
| `elio_method_step.dart` | Restyle | Terracotta numeral Bricolage 800 |
| `elio_stat_badge.dart` | Restyle | Cream-deep pill + terracotta-tinted icon |
| `elio_servings_control.dart` | Restyle | Flat panel, peach −/+ buttons |
| `elio_feedback_bar.dart` | Restyle | Cream-deep panel, thumbs up/down |
| `elio_custom_field.dart` | Restyle | Cream-deep input, mocha placeholder |
| `elio_onboarding_option_card.dart` | Restyle | Cream-deep panel, terracotta ring radio right |
| `elio_onboarding_progress_bar.dart` | Restyle | Mocha filled / rule unfilled |
| `elio_add_pantry_item_dialog.dart` | Restyle | Modal style + buttons |
| `elio_add_something_tile.dart` | Restyle | Cream-deep + dashed terracotta border |
| `elio_appliance_tile.dart` | Restyle | Match Q-card option pattern |
| `elio_household_stepper.dart` | Restyle | Match servings control |
| `elio_pantry_icon.dart` | Restyle | Outline icons in espresso/terracotta |
| `elio_pantry_item_tile.dart` | Restyle | Cream-deep tile |
| `elio_pantry_tag_pill.dart` | Restyle | Mini chip variant |
| `elio_pantry_tier_legend.dart` | Restyle | Match tier row palette |
| `elio_provider_signin_button.dart` | Restyle | Match `ElioBigButton` shape |
| `elio_segmented_toggle.dart` | Restyle | Cream-deep track, terracotta thumb |
| `elio_sticky_category_header.dart` | Restyle | Bricolage 700 sentence case |
| `phone_mockup_recipe_card.dart` | Restyle | Marketing/preview component |

**New widgets:**
- `ElioPageTitle` (`lib/widgets/elio/elio_page_title.dart`)
- `ElioHeroDisplay` (alias in same file or separate)
- `ElioSectionHeading` (`lib/widgets/elio/elio_section_heading.dart`)
- `ElioBackdropIllustration` (`lib/widgets/elio/elio_backdrop_illustration.dart`)

**Token-system file changes:**
- `lib/theme/elio_theme.dart` — rewrite `ElioColors`, rewrite `elioTheme()` ThemeData, drop `ElioText` legacy class.
- `lib/theme/elio_text_styles.dart` — rewrite `ElioTextStyles` for the new ramp; or fold into theme as `TextTheme`.
- `lib/theme/elio_radii.dart` — refresh values per §6.
- `lib/theme/elio_spacing.dart` — unchanged.

---

## 9. Screen migration order

Migrate in this order (matches Kate-delivery confidence and minimizes blast radius):

1. **Tokens + theme + heading widgets** — no screens yet, just the foundation.
2. **`ElioBackdropIllustration`** with kale asset.
3. **`ElioAppScaffold`** updated to include the backdrop.
4. **Bottom nav restyle + label change.**
5. **Onboarding splash** ("tonights dinner, from what you already have.")
6. **Onboarding question screens** (Q1–Q4 — same pattern repeated).
7. **Home screen** ("hey kate. lets get started")
8. **Pantry tab** ("what did you pick up?" + Pantry Builder accordion)
9. **Dietary & Allergens** (in-app settings sub-screen)
10. **Recipe Detail** ("creamy lemon pasta" + ingredients + method)
11. **Sweep**: every other screen using restyled widgets (recipes tab, shopping list, account, paywall, etc.). These don't have new Kate designs yet — apply the new tokens/widgets and accept that the look is "tokens-correct but not Kate-blessed." Flag the unblessed screens in the merge PR for Kate to review next.
12. **Cleanup**: delete `ElioHeroHeading` legacy widget, delete `ElioText` legacy class, drop `google_fonts` from pubspec, run final analyze + test.

---

## 10. Branch / commit / sprint discipline

- **Branch:** `sprint/16-rebrand` (already created off `sprint/16` at `7140169`).
- **Sprint label:** `16-rebrand` — within the Sprint 16 family, not a new top-level sprint.
- **Commit prefix:** `feat(sprint-16-rebrand): …` for new code, `style(sprint-16-rebrand): …` for restyle, `chore(sprint-16-rebrand): …` for token rename, `docs(sprint-16-rebrand): …` for spec/plan docs.
- **One logical change per commit.** No squashed mega-commits. Mechanical token rename can be one commit; each widget restyle one commit; each screen migration one commit.
- **`flutter analyze` clean before every commit** (existing rule from `CLAUDE.md`).
- **Build via `build.ps1 -sprint 16-rebrand`** when ready for on-device test. Local tag `build/sprint-16-rebrand`.
- **Merge target:** `sprint/16` after Rob's on-device sign-off. Then existing path: tag `v0.16.0-rebrand`, then Sprint 17 GDPR resumes.

---

## 11. Risks & unknowns

1. **Bricolage Grotesque variable font availability at weight 800.** Need to confirm the variable file covers w800. Mitigation: download the Google Fonts release, inspect supported weights, fall back to the static `BricolageGrotesque-ExtraBold.ttf` if the VF caps below 800.
2. **SVG export from Figma.** Need the kale-leaf as SVG (or 2× PNG fallback). Kate to provide; otherwise we extract via Figma Dev Mode.
3. **`google_fonts` external callers — 20 files.** Confirmed via grep on `sprint/16` HEAD: `GoogleFonts.` appears across `lib/theme/elio_theme.dart`, `lib/theme/elio_text_styles.dart`, all 11 screens that hand-roll text styles (paywall, auth, account, history, household, settings, notification prefs, scanner, recipe import, scan success, bulk prep results, receipt results, recipe screen, meal plan, scanner), `lib/widgets/elio/elio_bottom_nav.dart`, `lib/widgets/elio/elio_top_app_bar.dart`, `lib/widgets/elio/elio_secondary_card.dart`, and `lib/widgets/pantry_builder_sheet.dart`. Plan must visit every one of those files and replace `GoogleFonts.outfit(...)` / `GoogleFonts.quicksand(...)` with `Theme.of(context).textTheme.<role>` reads. Hardcoded `GoogleFonts` calls in widgets are the principal reason font swaps would otherwise be slow — eliminating them is a deliverable, not a side-effect.
4. **Screen #11 "sweep" screens** (Sprint 16.4 polish layer, account screens, paywall, meal plan, etc.) won't have Kate blessing yet. Risk: they may look off in places Kate cares about. Mitigation: PR notes call them out; Kate reviews before merge; we accept follow-up tweaks in a Sprint 16-rebrand-polish if needed.
5. **Performance.** Adding a Stack + SVG layer behind every screen could cost a couple of frames. Mitigation: SVG renders cheaply via `flutter_svg`; if it bites, swap to a pre-rasterised PNG.
6. **Dark mode.** Kate's frames are all light. We do not ship dark mode in this branch. If `MediaQuery.platformBrightness` is dark, the app keeps the cream theme. Acceptable trade-off — note in PR for future consideration.
7. **Two pre-Sprint-16 widgets** (`pantry_builder_sheet.dart`, `recipe_category_chip_row.dart`) live outside `lib/widgets/elio/` and weren't tokenised in Sprint 16. They appear in flow but Kate hasn't reskinned them. Restyle pragmatically using the new tokens; flag as needing Kate review.

---

## 12. Acceptance criteria

- [ ] All 9 currently-delivered Kate screens visually match the Figma frames on a Pixel-class device.
- [ ] No string in `lib/` references `navy`, `amber`, `sky`, `Outfit`, `Quicksand`, or `GoogleFonts.` (outside the theme migration commit history).
- [ ] `flutter analyze` reports zero issues.
- [ ] `flutter test` is green (existing 325 tests + any new tests added).
- [ ] `flutter build apk --flavor prod --dart-define=GEMINI_API_KEY=…` succeeds via `build.ps1 -sprint 16-rebrand`.
- [ ] APK installs and runs on Rob's device, full walkthrough Home → onboarding → recipe with no theme regression.
- [ ] Local tag `build/sprint-16-rebrand` set after on-device sign-off.
- [ ] PR notes list "sweep" screens that lack Kate blessing for follow-up.

---

## 13. Hand-off

When Rob approves this spec, transition to the **writing-plans** skill to produce the bite-sized TDD task plan (`docs/superpowers/plans/2026-04-29-sprint-16-rebrand.md`). The plan will sequence the migration per §9 above with specific file paths, code snippets, and per-step verification commands.
