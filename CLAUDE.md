# Elio — AI Recipe Generator

Flutter app. Gemini AI generates recipes from your actual pantry. Android-primary, coordinated iOS launch planned.

## Identity

- **What:** AI-powered recipe generator that knows your kitchen. Pantry built during onboarding, recipes grounded in what you have.
- **Who for:** Busy households (couples, families, flatshares) who want to eat well without daily meal-planning friction. US primary, UK secondary.
- **Core principle:** Remove friction. Minimal taps, simplicity over completeness. Every screen earns its place.
- **Repo:** `https://github.com/robchambo/elio-app` (private, `main` branch)
- **Local path:** `C:\Users\robth\.claude\ELio\elio-app` (Rob's device) / `C:\Users\kated\.claude\Elio` (Kate's device)
- **Stack:** Flutter/Dart, Firebase (Auth/Firestore/Crashlytics/Analytics/FCM/Remote Config), Gemini (2.5-flash streaming + 2.5-flash-lite batch), RevenueCat, mobile_scanner, shimmer
- **Flutter:** 3.27.x | Dart SDK `>=3.4.0 <4.0.0` | AGP 8.9.1 | Gradle 8.11.1

## Build — CRITICAL

```
powershell -ExecutionPolicy Bypass -File build.ps1 -sprint <version>
```

**NEVER** run raw `flutter build apk` — the Gemini API key comes from `.env.local` and is injected via `--dart-define` by `build.ps1`. Without it, generation fails with 403. Always `--flavor prod` (dev flavor is broken — missing Firebase client).

**Run command:** `flutter run --flavor prod -t lib/main.dart --dart-define=GEMINI_API_KEY=<key>`

**Dev account testing:** Dev accounts get Pro by adding their email (lowercase) to the `emails` array on Firestore doc `config/proTesters`. `EntitlementService._loadProTesters()` reads this once per session. The old hard-coded allowlist + `proOverride` flag were removed in Sprint 17; RevenueCat is the single source of truth for paying users.

## Rules

1. **Commit after every confirmed-working build** — never leave more than one sprint uncommitted. Code only exists if it's in git.
2. **Update `docs/roadmap.md` after every successful build** — mark completed tasks, update estimates.
3. **`flutter analyze` before every commit** — zero warnings.
4. **Git via terminal** — never browser. Use `git` CLI or `gh` CLI for all operations.
5. **Tag working builds** — immediately after user confirms on-device.
6. **Test Gemini changes** — never commit untested model/config changes. Each must be verified individually.
7. **Worktree merges: diff first, never blind `cp`** — worktrees snapshot main at launch; copying overwrites later changes. Use `git diff main -- <file>`, apply via Edit tool. New files are safe to copy. Files modified by multiple agents need manual merge.
8. **`.withValues(alpha: x)`** not `.withOpacity(x)`.
9. **Design: remove friction** — minimal taps, simplicity over completeness.

## Flutter Gotchas (hard-won)

- **No modal bottom sheet inside another bottom sheet** — use `showDialog` instead. The inner sheet fails silently.
- **No `SnackBar` from inside a bottom sheet** — renders behind the sheet. Use inline feedback.
- **`GestureDetector.onLongPress` in scrollable containers** — scroll gesture steals it. Use `RawGestureDetector` with `LongPressGestureRecognizer(duration: Duration(milliseconds: 300))`.
- **Fuzzy matching for toggle UIs** — never. Exact matching only. Fuzzy is for add-item duplicate warnings.
- **`showModalBottomSheet` in immersive/hands-free mode** — fails silently. Use `showDialog` instead.
- **Android speech recogniser beep** — mute NOTIFICATION + MUSIC + SYSTEM streams via platform channel for entire voice session, restore on exit. Per-listen mute/restore doesn't work (restart cycle re-triggers beep).
- **`GestureDetector` touch targets** — bare `GestureDetector` wrapping a small icon has a tiny hit area. Always add `Padding(padding: EdgeInsets.all(8))` inside the child, or use `IconButton` which has Material's 48px minimum built in.
- **`showDialog` after `Navigator.pop(bottomSheet)`** — the sheet dismiss animation takes ~300ms. If you call `showDialog` immediately after popping, it can fail silently. Add `await Future.delayed(Duration(milliseconds: 350))` before showing the dialog.
- **Auto-saved recipes need `_savedAt`** — when saving a recipe via `autoSave` in `initState`, capture the `savedAt` timestamp so bookmark toggling works. Without it, subsequent taps treat the recipe as new and create duplicates.

## Architecture Quick Reference

```
lib/
  models/        — elio_models, recipe_models (RecipeGenerationStatus sealed class), meal_plan_models, onboarding_state
  data/          — pantry_categories (12 categories, lazy lookup)
  services/      — gemini (SSE streaming, JSON mode, thinking off, side dish generation), firestore, auth, scanner, shopping,
                   meal_plan (timeouts, staggered progress), history (bookmarking), entitlement, analytics, notification, remote_config,
                   guest_pantry, purchase, error_service, voice_control
  screens/
    shell/       — AppShell with 4-tab bottom nav (Home / Pantry / Recipes / Shopping)
    home/        — Generate button with streaming shimmer skeleton
    pantry/      — Pantry tab: tiered inventory with Sprint 16 design system
    recipes/     — RecipesTab: saved recipe book
    shopping/    — Shopping list tab (aisle grouping, share)
    account/     — AccountScreen (Subscription / Household / Dietary / Food Style / Appliances / Metrics tiles)
    recipe/      — Recipe view, ingredient substitution, voice cooking, "Generate Another"
    profile/     — Sub-screens opened from AccountScreen: dietary_screen, kitchen_screen, household_screen, settings_screen, notification_prefs_screen, recipe_import_screen
    scanner/     — Barcode (mobile_scanner) + receipt scanning (Gemini Vision)
    onboarding/  — 8 screens (screen1_dietary → screen8_complete)
    meal_plan/   — Lazy-load detail on tap
    paywall/     — RevenueCat paywall (trial-first design)
  widgets/
    elio/        — Sprint 16 design system (shell, type, CTAs, cards, lists, controls — see Design System below)
    elio_progress_bar.dart, pantry_builder_sheet.dart — pre-Sprint-16 helpers still in use
  utils/         — region_utils, pantry_utils (fuzzy dedup), quantity_utils (ingredient consolidation + unit normalisation), aisle_utils (grocery aisle classification)
```

### Firestore Schema

All user data lives under `users/{uid}` — there are no top-level `inventory` or `recipes` collections.

```
config/{doc}              — readable by any signed-in user, admin-only writes
  proTesters              — { emails: [...] } for dev/tester Pro override

users/{uid}/
  (user doc)              — dietary, appliances[], stylePreferences[], region,
                            measurementUnits, subscription{tier, weeklyGenerations,
                            weekStartedAt, ...} (entitlement keys client-locked)
  profiles/{id}           — household members; name, dietaryRequirements[], isOwner
  inventory/{id}          — name, tier, category, expiryDate?, price?, runningLow
  recipes/{id}            — saved/bookmarked recipes
  ratings/{id}            — recipe likes/dislikes for adaptive learning
  mealPlan/{id}           — singular: weekly meal plan docs
  shoppingItems/{id}      — name, quantity, source, isChecked
  tierMemory/{name}       — normalised name → tier, lastSeen (scanner learning)
  fcmTokens/{id}          — push notification tokens
```

**Security (Sprint 17):** All sub-collections are owner-only via `firestore.rules`. The `subscription` keys `tier`, `proOverride`, `source`, `lastSyncedAt`, `entitlementGrantedAt` cannot be changed by clients (locked by `protectedSubKeysUnchanged()`). `weeklyGenerations` is still client-writable until the Cloud Functions backend lands.

## Gemini API

**Current config (Sprint 15.3):**
- **Model:** `gemini-2.5-flash` (streaming), `gemini-2.5-flash-lite` (batch: receipts, import, substitutions, meal plans)
- **Streaming endpoint:** `streamGenerateContent?alt=sse` via raw `http.Client` (static, reused — no per-request TCP/TLS overhead)
- **Generation config:** temperature 0.8, topK 40, topP 0.95, `responseMimeType: 'application/json'`, `thinkingConfig: { thinkingBudget: 0 }`
- **Max tokens:** 1024 (standard recipe), 2048 (bulk prep)
- **Timeout:** 60 seconds
- **Retry:** 2 attempts on failure
- **`_extractJson()`** kept as safety net for JSON parsing

**Prompt structure (`_buildPrompt` in `gemini_service.dart`):**
1. System identity ("You are Elio, a friendly AI cooking assistant")
2. Hard constraints: measurement units (imperial/metric based on user region), dietary requirements, UK/US region
3. Inventory section: perishable items with urgency descriptions, user-selected items as REQUIRED, pantry staples, usually-have items
4. Excluded ingredients (do NOT use)
5. Style/time/mood preferences
6. Recent titles (for deduplication — last 20)
7. Taste profile (liked/disliked recipes for adaptive learning)
8. Appliance constraints
9. Saver mode (budget-friendly instructions)
10. JSON schema for output

**Key prompt rule:** User-selected perishables are `REQUIRED ingredients — you MUST use ALL of these`. This was strengthened in Sprint 15.3.20 to prevent Gemini from dropping selected items.

**Do NOT change without testing on-device:** model name, temperature, thinkingBudget, responseMimeType, maxOutputTokens. Each must be verified individually.

## Design System

- **Navy:** `#1A2744` — primary surfaces, trust, calm
- **Amber:** `#F08C14` — single accent, CTAs, "Elio is doing something"
- **Sky:** `#4A90D9` — secondary accent, info states
- **Off-white:** `#F7F5F2` — backgrounds, breathing room
- **Fonts:** `GoogleFonts.outfit()` headings, `GoogleFonts.quicksand()` body
- **Shape:** Rounded corners throughout, soft cards, no hard edges. Shimmer skeletons during streaming.
- **API:** `.withValues(alpha: x)` not `.withOpacity(x)` | `activeTrackColor` not `activeColor`

### Sprint 16 design system (new)

Extended token files live alongside `elio_theme.dart`:

- `lib/theme/elio_spacing.dart` — 8-point spacing scale (`xs`/`sm`/`md`/`lg`/`xl`/`xxl`/`xxxl` + `screenEdge`).
- `lib/theme/elio_radii.dart` — rounded-corner scale + `card`/`button`/`chip` presets.
- `lib/theme/elio_text_styles.dart` — editorial ramp (`heroDisplay`/`heroDisplayAccent`/`heading1-5`/`eyebrow`/`body`/`bodySmall`/`statValue`/`stepNumeral`).
- `ElioColors.cream` — warmer cream used on cards over off-white backgrounds.

Reusable widgets in `lib/widgets/elio/`:

- Shell: `ElioAppScaffold`, `ElioTopAppBar`, `ElioBottomNav` (4 tabs: home / pantry / recipes / shopping).
- Type: `ElioHeroHeading` (editorial 1-3 line display with amber last line + underline), `ElioEyebrow`.
- CTAs: `ElioBigButton` (amber primary), `ElioChip` (selectable pill).
- Cards: `ElioSecondaryCard` (cream + View action), `ElioBentoCard` (two-tone action card).
- Lists: `ElioTierRow` (expandable tier), `ElioIngredientRow` (checkable), `ElioMethodStep` (big amber numeral).
- Pills / controls: `ElioStatBadge`, `ElioServingsControl`, `ElioFeedbackBar`, `ElioCustomField`.

Screens wired into the new shell (`AppShell`): `HomeScreen`, `PantryScreen`, `RecipesTabScreen`, `ShoppingListScreen`. The top-bar profile icon opens `AccountScreen` (Subscription / Household / Dietary / Food Style / Appliances / Metrics tiles). Recipe, Meal Plan, and Paywall keep their own `Scaffold` (pushed via Navigator). `RecipePreferencesScreen` is the new interstitial between Home's Generate CTA and `RecipeScreen`.

## Monetisation

**Model:** Freemium, no ads.

| | Free | Pro |
|---|---|---|
| Recipes/week | 7 | Unlimited |
| History | 20 | 50 |
| Household members | Owner only | 6 |
| Meal planner | No | Yes |
| Shopping list | No | Yes |
| Recipe import | No | Yes |
| Scanning | No | Yes |
| Voice cooking | Yes | Yes |

**Pricing:** UK £4.49/mo or £27.99/yr | US $4.99/mo or $29.99/yr
**Trial:** 7-day free trial configured at Play Store / App Store level, surfaced via `StoreProduct.introductoryPrice`.

### Paywall logic (IMPORTANT)

The paywall leads with "Start Your 7-Day Free Trial" hero. It uses context-specific headlines based on trigger (`weekly_limit` / `meal_planner` / `shopping_list` / `household` / `default`).

**Dry-mode rule:** When `REVENUECAT_API_KEY` isn't configured, `PurchaseService.getPackages()` returns `[]`. The `_showTrialState` getter in `paywall_screen.dart` returns `true` when packages are empty (covers dry mode + loading). It only returns `false` when packages have loaded AND none have an introductory price. **Never let package emptiness be interpreted as "no trial".** RevenueCat remains the source of truth at purchase time.

**Helpers on PurchaseService:** `hasFreeTrial(package)`, `trialDurationLabel(package)`, `isAnyTrialAvailable` getter.

## Agent Workflow

**Single agent (default):** Bug fixes, sequential features, UX polish, docs. Most sessions. This is usually faster.

**4-agent pattern (rare — only for parallel independent features):**

| Agent | Role | Isolation | Commits? |
|-------|------|-----------|----------|
| A | Feature work | worktree | NO |
| B | Feature work | worktree | NO |
| C | QA (tests, review) | worktree | NO |
| D | Review + Merge | foreground (main) | YES — only committer |

Agent D waits for A/B/C, runs `git status` + `flutter analyze`, fixes conflicts, commits in logical chunks, builds with `build.ps1`.

**Worktree merge safety:** Never blindly `cp` from worktree to main. `git diff main -- <file>` to see changes, apply via Edit tool. New files can be copied. Multi-agent file conflicts need manual merge.

## Known Issues

- **`google-services.json` not in git** — must add manually after fresh clone.
- **APK size 72.4 MB** — mobile_scanner ML Kit. May need app bundles for Play Store.
- **iOS not built/tested** — URL scheme placeholder must be filled first.
- **`mockup/` directory** untracked.
- **`REVENUECAT_API_KEY`** — wired through `build.ps1` but actual key not yet in `.env.local` (need RC project setup first).
- **Gemini first-attempt reliability** — Rob reports streaming generation commonly fails on the first attempt after app launch and succeeds on retry. Shows up on screen 13 first-recipe demo especially. Flagged for a dedicated reliability pass — hypotheses + investigation plan in memory `feedback_gemini_api.md` §5. Not blocking launch.

## Tracked Feature Work (post-copy-polish)

- **Guest shopping list + screen 13 "Add missing ingredients" affordance** — flagged in Sprint 16.2, Rob signed off on approach. Plan: build `GuestShoppingListService` (mirrors `GuestPantryService`), expose "Add N missing to shopping list" CTA on screen 13 recipe card (and normal recipe screen), persist items pre-auth, migrate on sign-in via `MigrationService`. Basic shopping list is **free** (Rob's decision 23 Apr); premium features (aisle grouping, share, restock suggestions) stay paywalled. Screen 14 paywall can then reference the items concretely ("Unlock Pro — your N items are ready"). Likely sprint tag `16.3`, own commit — not folded into onboarding-rebuild tag.

## Launch Strategy

Coordinated Android + iOS launch. Android built first, both released in the same window.

- **Sprint 16:** UI Overhaul — brand/art pass, design system, visual refresh across all screens
- **Sprint 17:** Shared launch preparation — *in progress.* ✅ Firestore security rules + entitlement hardening (commits `8a17e8c`, `8c9e318` on `sprint-17` branch). ❌ Outstanding: deploy rules, emulator rule tests, Cloud Functions backend (RC webhook + Gemini proxy + server-side rate limits), GCP budget caps, GDPR (export/delete/consent), privacy + ToS, Crashlytics webhook, debug-message removal, RC key in `.env.local`.
- **Sprint 18:** Android track — regression, Play Store listing, internal test, beta, staged rollout
- **Sprint 19:** iOS track — Apple Sign-In, Siri Shortcuts (pre-launch), TestFlight, App Store submission

## Doc Pointers — READ BEFORE EDITING

| When working on... | Read first |
|---|---|
| Paywall / monetisation | `docs/technical-design.md` Section 9 |
| Gemini prompts or API | `lib/services/gemini_service.dart` (full file) |
| Sprint planning | `docs/roadmap.md` |
| Onboarding flow | `docs/product-guide.md` onboarding section |
| Error reporting / Crashlytics | `docs/technical-design.md` Section 7 |
| Voice control | `docs/technical-design.md` Section 8 |
| Launch architecture | `docs/technical-design.md` Section 10 |
| Brand / art direction | `docs/brand-art-concept.md` |
| Sprint 16 design system | `lib/widgets/elio/` + Design System section above |

## Last Session (22 April 2026) — Sprint 16.2 Copy Polish (IN FLIGHT, screens 03–12 done)

**Branch:** `sprint/16-onboarding-rebuild` (still off `sprint/16`, pushed). `flutter analyze` clean. Per-screen commits with prefix `copy(sprint-16-onboarding): screen NN …` or `feat(sprint-16-onboarding): …` for feature additions.

**This session (copy polish, walkthrough in chat, one commit per screen):**
- **Screen 03 household** — "Me and my partner" → "Just the two of us"; goal-aware subhead "We'll make sure everyone's covered." when `userGoal=='household'`.
- **Screen 04 dietary** — "No restrictions" → "Happy with anything." (softer default); union heading "What's the combination of needs across your household?" → "Cover everyone's needs"; added union subtext "We'll make sure no one gets left out."
- **Screen 05 allergies** — headline → "Anything we should avoid?" (conditional dropped — softer baseline now default); subhead → "Allergies first, then anything you'd rather skip."; section 2 header → "Anything you'd rather skip?"; chips "Milk / dairy" → "Dairy", "Wheat / gluten" → "Gluten"; custom hint → "e.g. mustard, celery"; skip → "Nothing to avoid — skip".
- **Screen 06 time** — subhead → "We'll match recipes to you."
- **Screen 07 confidence** — default subhead → "Helps us pick how adventurous to go."; "Challenge me" → "Bring on the technique".
- **Screen 08 appliances** — subhead → "Tick what you've got. We'll only suggest recipes that fit."; "Pressure cooker" → "Pressure cooker / Instant Pot"; **grid layout 2-col → 3-col** (`childAspectRatio: 0.9`, tighter tiles, icon 32→28, label `maxLines:2 + ellipsis` so "Pressure cooker / Instant Pot" wraps cleanly).
- **Screen 09 region** — post-override helper text deliberately dropped for v1; spec note added.
- **Screen 10 pantry intro** — no copy change; hero illustration placeholder flagged for Kate.
- **Screens 11 + 12 — "+ Add something" tile + dedup (feature, not just copy).** Commit `feat(sprint-16-onboarding): + Add something tile on screens 11/12 with dedup`. Two new widgets: `ElioAddSomethingTile` (dashed amber border, cream fill, same grid footprint as pantry tiles) and `showAddPantryItemDialog` helper returning a sealed `AddItemResult` (Cancelled / PromoteExisting / AddNew). Dedup logic:
  - exact normalised match (via `PantryUtils.normalise`) → silently promote existing tile (usually for staples / fresh for perishables), no warning.
  - fuzzy match (via `PantryUtils.findDuplicates` — Levenshtein) → `PantryUtils.showDuplicateWarning` confirm dialog: Cancel / Add anyway.
  - no match → append custom tile in the user-chosen category, pre-selected at usually/fresh.
  Custom items persist with user-chosen category (fallback when `PantryCategories.categorize` returns null), flow through `controller.state.inventory` + `GuestPantryService` like spec items. +8 tests across screens 11/12 (26 passing total for those two files).

**Deferred this session (flagged, not built):**
- **Screen 11/12 search bar** — deferred to after on-device smoke test.
- **Screen 11/12 full dietary/allergy filtering** — requires per-item metadata pass on the ~100+ items in `PantryCategories.all` (content authoring + Kate-voice decision on hide-vs-grey). Not a code problem — flagged as separate work.

**Pending (in order):**

1. **Finish copy polish** — screens 13 (first-recipe demo), 14 (paywall), 15 (account). Same walkthrough pattern. Variants to flag on 13/14.
2. **On-device smoke test** — rebuild APK via `build.ps1 -sprint 16.2-copy-polish`; clear app data; walk 01 → 15. Verify Firestore write, RC alias, guest pantry clears, `onboardingComplete=true` lands, AuthGate routes to AppShell.
3. **Tag** `v16.1-onboarding-rebuild` after sign-off (Rule 5).
4. **Merge** `sprint/16-onboarding-rebuild` → `sprint/16`. Then Rob's minor Sprint 16 UI tweaks. Then tag `v0.16.0-ui-overhaul`. Then Sprint 17 (launch prep).

**Earlier in this run (state carried from 20 April session):** 15-screen sell-to-self onboarding. Pre-auth state in `OnboardingController` + `GuestPantryService`. `AuthGate` keys off `SharedPreferences.getBool('onboardingComplete')`. `MigrationService` handles guest→Firestore on sign-in. Option B **household union capture** on screen 04 (`householdCombinedDietary`, consumed via `state.effectiveDietary` by Gemini on screen 13). 11 new `lib/widgets/elio/` widgets from Phase 0. Analytics wired: `onboarding_step_completed` 01–14 + paywall/signin events, via lazy/null-safe `AnalyticsService.instance`. `PurchaseService.aliasToUid` + `MigrationService.migrateGuestToFirestore` full impls shipped.

**Still open (non-blocking):**
- Screen 11 default count: 20 staples pre-selected vs spec prose "~16" (table lists 20 — trim or update prose).
- Palette tokens `freshGreen` (#3D9970), `perishThisWeek` (amber), `perishToday` (#E06C5E) — Kate to ratify.
- Screen 10 hero illustration still 🧊 placeholder — Kate art.
- Screen 11/12 search bar — flagged v1 in spec, deliberately deferred.
- Screen 11/12 full dietary/allergy filtering beyond the default-exclude rule — deferred (content + UX pass).
- Coordinator lets each screen render its own progress bar rather than a single coordinator-owned bar — minor follow-up refactor for visual consistency.
- Local build-artefact tag `build/sprint-16.1-onboarding` auto-created by `build.ps1` (not pushed). Distinct from the release tag; delete locally with `git tag -d` if unwanted.

**Key files for on-device verification:**
- `lib/screens/onboarding/onboarding_flow.dart` (PageController coordinator; entry point)
- `lib/main.dart` AuthGate (keys off `SharedPreferences.getBool('onboardingComplete')`)
- `lib/services/migration_service.dart` (watch for Firestore write + RC alias on sign-in)
- `lib/services/analytics_service.dart` (lazy/null-safe — confirm events fire in release)

**Sprint 16 proper:** not tagged. Rob has minor UI bug tweaks outstanding separate from the onboarding rebuild. After those land + on-device verification: tag `v0.16.0-ui-overhaul`.

---

## Prior Session (13 April 2026) — Sprint 15.7 & 15.8

### Completed (Sprint 15.7)
- **Shopping list share button:** Share icon on shopping tab, formats unchecked items grouped by grocery aisle, shares via `share_plus` system share sheet
- **Unit abbreviations:** `QuantityUtils.normalizeUnit()` maps "grams"→"g", "millilitres"→"ml", "tablespoons"→"tbsp" etc. Applied to all 6 display locations in recipe_screen.dart
- **Pantry Builder tier picker:** Changed `showModalBottomSheet` → `showDialog` (nested sheet was failing silently — known Flutter gotcha)

### Completed (Sprint 15.8)
- **Pantry Builder long-press fix:** Removed guard that blocked tier change for items already in pantry — now you can long-press any item to change its tier
- **Bookmark toggle fix for imported recipes:** `_savedAt` now captured immediately on `autoSave` so subsequent bookmark taps toggle correctly instead of creating duplicates
- **Back button touch targets:** Added 8px padding to all 7 bare `GestureDetector` back buttons (profile, settings, household, dietary, kitchen, meal plan, shopping list screens) — ~36px touch area, up from 20px
- **Household member delete:** Added 350ms delay after bottom sheet dismiss before opening confirmation dialog (animation race condition was preventing dialog from appearing)

### Prior Sessions
- Sprint 15.6 (12 Apr): Shopping cart badge, meal plan & recipe shopping dialogs, side dish feature, staple purge, meal plan timeout fix, household edit/delete, build.ps1 flutter detection
- Sprint 15.5 (12 Apr): Bug fixes — paywall audit, notification wiring, paywall test assertions, RevenueCat key wiring, ErrorService coverage
- Sprint 15.4 (11 Apr): Collections/tags, makeable-now filter, aisle grouping, quantity consolidation, URL import, swipeable days, regen dialog
- Sprint 15.3.20 (11 Apr): Gemini prompt fix (selected perishables REQUIRED), brand & art concept doc
- Sprint 15.3.17–19 (5 Apr): UX audit Pass 1+2, trial-first paywall, dry-mode fix

### Needs Testing
- Sprint 15.8: pantry builder long-press tier change, bookmark toggle on imported recipes, household member delete, back button targets
- Sprint 15.7: shopping list share, unit abbreviations
- Sprint 15.6: side dish generation, shopping confirmation dialogs (meal plan + recipe), staggered meal plan progress, staple purge
- Sprint 15.4: collections tagging, makeable-now filter, aisle grouping, quantity consolidation, URL import
- Receipt scanner edit/delete/expiry, pantry expiry chips, onboarding success screen

### Gemini API State
- **Streaming**: gemini-2.5-flash via SSE, maxOutputTokens 1024 (standard) / 2048 (bulk prep), thinking disabled (thinkingBudget: 0), responseMimeType: application/json
- **Batch**: gemini-2.5-flash-lite, responseMimeType: application/json, used for: URL recipe import (1024 tokens), substitutions, meal plans (6144 weekly / 1024 single / 512 detail), **side dish generation (768 tokens)**
- **Timeouts**: 60s streaming, 90s meal plan weekly, 60s meal plan single, 45s meal plan detail, 20s side dish, 30s URL import
- **Connection**: static http.Client reused across calls
