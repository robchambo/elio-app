# Elio Roadmap

**Last updated:** 11 May 2026 (Sprint 16.1.x auth UX fix committed locally on `sprint/16.1-settings-redesign` at `8fbc553`. APK building. Awaiting on-device verification.)

**Active branch:** `sprint/16.1-settings-redesign` — Sprint 16.1 Settings Redesign + auth UX fix on top.
**Pushed to origin:** through `55a144f` (appliances case-mismatch fix). `8fbc553` (auth UX fix) is local-only pending on-device test.

**Recent (1–11 May 2026):**
- Sprint 15.9.2 — Gemini warmup (cold-start reliability)
- Dietary/allergen safety audit (8+ commits on `sprint/16`) — major pre-launch risk closed
- Sprint 16.1 — Settings Redesign (4-section tree, unified dietary plumbing)
- Sprint 16.1.x — Auth UX fix (Sign In tile, Restart Onboarding, sign-out preserves onboardingComplete)

**Sprint 16.4 polish (April 2026):**
- Bug 4 — Pantry single-tap removed (long-press only); Remove lives in the long-press picker.
- Bug 5 — Home Recent Recipes pushed below the fold via LayoutBuilder.
- Bug 6 — Recipes-tab filters (search, makeable-now, category chips) removed; TODO flag for revisit.
- Bug 3 — Per-tier "+ Add" chip on Pantry tab; perishables get a freshness-bucket follow-up.
- Bug 1 — EntitlementService.refresh() kicked off on Home initState so Plan-your-week appears on cold start.
- Bug 2 — Top-3 most-urgent perishables auto-selected in PerishablesPickerScreen (default; overridable).
- Bonus — Recipes-tab "Take photo" / "Manual entry" bento cards now wire to the live RecipeImportScreen with the right initial tab (photo import was already built, just unwired).

---

## Completed Sprints

### Sprint 1–8: Foundation
- Flutter app scaffold, Firebase integration
- Onboarding flow (8 screens)
- Basic recipe generation with Gemini
- Pantry inventory (3-tier system)
- User authentication (Google, email/password)
- Profile screen with dietary, style, kitchen tabs

### Sprint 9–11: Monetisation & Infrastructure
- Paywall and RevenueCat integration
- Entitlement system (Free/Pro/Guest tiers)
- Firebase Remote Config for API key management
- Push notifications via FCM

### Sprint 12–13: Engagement
- Meal planner (7-day, 3-meal, two-phase generation)
- Shopping list (persistent, multi-source)
- Notification preferences screen
- Analytics and Crashlytics integration

### Sprint 14: Advanced Features
- Voice-controlled cooking (wake word, TTS, continuous listening)
- Saver/budget mode
- Expiry date tracking with colour-coded urgency
- Pantry packs (quick-start kitchen presets)
- Measurement units and region settings

### Sprint 14.1: Scanning
- Barcode scanning via mobile_scanner + Open Food Facts
- Receipt OCR via Gemini Vision
- Tier memory (learns user categorisation choices)
- Save recipe from recipe screen
- Add ingredients to shopping list

### Sprint 14.2–14.5: Polish
- Ingredient substitution (AI-powered, in-place swap)
- Remove & regenerate excluded ingredients
- Household management moved to Settings
- Non-blocking recipe display (Firestore saves after navigation)
- API cost optimisation (Flash-Lite for lightweight calls)
- Two-phase meal plan generation

### Sprint 15.2: Pantry & Profile Overhaul ✅
- **Collapsible pantry sections** — Tiers collapse/expand, show item count
- **Group by Category** — Optional toggle, 12 categories, auto-assignment
- **Pantry Builder** — Categorised item browser (12 categories, search, tap/long-press)
- **Recipe Book tab** — Saved (bookmarked) + History with segmented control
- **Bookmark system** — `isBookmarked` field on SavedRecipe, toggle from history
- **Settings restructure** — Dietary & Kitchen moved from Profile tabs to Settings screen
- **Profile reduced to 4 tabs** — Pantry, Recipe Book, Style, Shopping
- **Bug fixes** — Fuzzy matching replaced with exact matching in Pantry Builder, bottom row padding, scanner button widths

---

## Sprint 15.3 — Recipe Import & UX Polish ✅

**Goal:** Let users bring external recipes into their Recipe Book via photo scan or manual entry, plus Pantry Builder improvements.

### Completed this sprint

| Task | Status |
|------|--------|
| Streaming recipe generation (SSE endpoint, shimmer skeleton, progress messages) | ✅ |
| Thinking mode disabled + JSON response mode enabled | ✅ |
| maxOutputTokens reduced 16384 → 4096 | ✅ |
| Pantry Builder repositioned above tier sections — visible on page open | ✅ |
| Pantry Builder — custom item text input + dialog-based tier picker | ✅ |
| Pantry Builder — long-press tier picker fixed (RawGestureDetector, 300ms threshold) | ✅ |
| Pantry Builder — Perishable added as third option in tier picker | ✅ |
| Settings — "Dietary & Allergens" subtitle simplified | ✅ |
| Added shimmer package for loading skeleton | ✅ |
| Bulk Prep Mode *(Pro)* — toggle + config popup, sequential streaming, bulk results screen, freezing/storage section on recipe screen | ✅ |
| Receipt scanner disclaimer added | ✅ |
| Recipe Import — photo scan, manual entry, entry point in Recipe Book *(Pro)* | ✅ |
| Bookmark toggle fix — no more duplicates, proper toggle from recipe screen | ✅ |
| Leftover regenerate bug fix — all request fields preserved on "Generate Another" | ✅ |
| Shopping list — accurate add/update messaging | ✅ |
| Recipe variety — last 5 session titles drive variety constraint in prompt | ✅ |
| Error reporting — ErrorService + Crashlytics non-fatal logging across all features | ✅ |
| Dietary options expanded — added Pescatarian, Egg-free, Soy-free, Shellfish-free (15 total) | ✅ |
| Custom allergens label → "Custom allergens or dietary requirements" | ✅ |
| Style section redesigned — grouped into Cuisines (14) and Styles (7) with headers | ✅ |
| Added Korean, Chinese, Caribbean, Southern, One-pot; removed Smoothies | ✅ |
| Bookmark duplication fix — recipes saved once, RecipeScreen always knows savedAt | ✅ |
| **Performance**: cold start parallelised, PurchaseService lazy init, NotificationService deferred | ✅ |
| **Performance**: static HTTP client, maxOutputTokens reduced (1024/2048), shared streaming helper | ✅ |
| **Performance**: taste profile cache, history cache, batched receipt tier lookups | ✅ |
| Voice control: RECORD_AUDIO permission added to manifest (was missing) | ✅ |
| Voice control: beep suppressed via platform channel (mutes audio streams during session) | ✅ |
| Voice control: help overlay converted to dialog (fixes immersive mode), TTS starts after Got It | ✅ |
| Voice control: "Hey Elio done" now only disables voice (stays in hands-free mode) | ✅ |
| Recipe screen bottom padding increased (hands-free button fully visible) | ✅ |
| Keyboard dismissed before recipe generation/navigation | ✅ |

---

## Launch Strategy

**Goal:** Launch Android and iOS together. Android builds first and may reach production a few days earlier, but both platforms are worked toward a coordinated public release. No dedicated "Android-only" launch — iOS parity is part of the launch deliverable.

Work is grouped into three parallel tracks:
1. **Shared platform work** (security, legal, assets, regression) — blocks both stores.
2. **Android track** — Play Console, internal testing, staged rollout.
3. **iOS track** — Xcode config, Apple Sign-In, Siri Shortcuts, TestFlight, App Store review.

---

## Sprint 15.4 — Recipe Book & Shopping List Improvements ✅

**Goal:** Strengthen the two areas identified in competitor analysis — recipe organisation and shopping list intelligence.

| # | Task | Est. Hours | Status |
|---|------|-----------|--------|
| 1 | Recipe Book — Collections/tags (tag saved recipes, filter by collection) | 2–3 | ✅ Done |
| 2 | Recipe Book — "Makeable now" filter (cross-reference saved recipes vs current pantry) | 1–2 | ✅ Done |
| 3 | Shopping list — Ingredient quantity consolidation (combine "1 cup flour" + "2 cups flour" = "3 cups") | 2–3 | ✅ Done |
| 4 | Shopping list — Aisle-based grouping (Produce, Meat & Fish, Dairy, Bakery, etc.) | 2–3 | ✅ Done |
| 5 | URL recipe import — import from URL on Recipe Book import screen | 1 | ✅ Done |
| 6 | Style hard constraint — user-selected style enforced as hard requirement in Gemini prompt | 0.5 | ✅ Done |
| 7 | Swipeable meal plan days — TabBarView for swipe navigation between days | 0.5 | ✅ Done |
| 8 | Regen preference dialog — after 3+ regenerations, offer style/preference adjustment | 1 | ✅ Done |

**New files:** `lib/utils/quantity_utils.dart`, `lib/utils/aisle_utils.dart`

---

## Sprint 15.5 — Bug Fixes ✅

**Goal:** Address known bugs before UI overhaul and launch.

| # | Task | Est. Hours | Status |
|---|------|-----------|--------|
| 1 | Google Sign-In SHA-1 fix for new devices | 0.5 | ✅ Done |
| 2 | Paywall appearing unexpectedly — audit trigger logic | 1–2 | ✅ Done (audited — all 4 triggers properly gated, no issue found) |
| 3 | Notification service — wire `requestPermissionAndRegister()` to a trigger | 1 | ✅ Done (`init()` at startup, permission request on first HomeScreen load) |
| 4 | Paywall integration tests — update stale assertions from trial-first rewrite | 1 | ✅ Done (headlines updated to match context-based copy) |
| 5 | RevenueCat API key — wire through `build.ps1` / `.env.local` | 1 | ✅ Done (optional — warns in dry mode, passes via `--dart-define`) |
| 6 | `ErrorService` coverage — add to GeminiService, FirestoreService, VoiceControlService, PurchaseService | 1–2 | ✅ Done (~15 new call sites across 6 services) |

---

## Sprint 15.6 — Side Dishes, Shopping UX & Bug Fixes ✅

**Goal:** New side dish feature, shopping list UX improvements, and bug fixes from on-device testing.

| # | Task | Est. Hours | Status |
|---|------|-----------|--------|
| 1 | Shopping cart badge — show only non-pantry ingredient count | 0.5 | ✅ Done |
| 2 | Meal plan shopping — confirmation dialog with editable items, select/deselect, "View shopping list" link | 2 | ✅ Done |
| 3 | Recipe screen shopping — same confirmation dialog for individual recipe add-to-shopping | 1.5 | ✅ Done |
| 4 | Purge residual staples (water/salt) from Firestore shopping items | 0.5 | ✅ Done |
| 5 | Meal plan timeout fix — HTTP timeouts (90s/60s/45s), token budget 4096→6144, staggered progress messages | 1.5 | ✅ Done |
| 6 | Remove duplicate hands-free FAB on recipe screen | 0.5 | ✅ Done |
| 7 | Household members — edit and delete functionality (unified add/edit sheet, confirmation dialog) | 1.5 | ✅ Done |
| 8 | **Suggest a Side Dish** — Pro feature, flash-lite batch call, complementary side dish generation with ingredient dedup, opens in new RecipeScreen | 2 | ✅ Done |
| 9 | build.ps1 — auto-find flutter when not on PATH | 0.5 | ✅ Done |

**Build:** `elio-sprint-15.6.apk` (72.9 MB)

---

## Sprint 15.7 — Shopping Share & Unit Abbreviations ✅

**Goal:** Share shopping list, abbreviate ingredient units, fix pantry builder tier picker.

| # | Task | Est. Hours | Status |
|---|------|-----------|--------|
| 1 | Shopping list share button — formats unchecked items by aisle, shares via system share sheet | 1 | ✅ Done |
| 2 | Unit abbreviations — `QuantityUtils.normalizeUnit()` maps "grams"→"g", "millilitres"→"ml" etc. across all recipe screen display locations | 1 | ✅ Done |
| 3 | Pantry Builder tier picker — changed `showModalBottomSheet` → `showDialog` (nested sheet was failing silently) | 0.5 | ✅ Done |

**Build:** `elio-sprint-15.7.apk` (72.9 MB)

---

## Sprint 15.8 — Bug Fixes & UX Polish ✅

**Goal:** Fix remaining bugs found during on-device testing.

| # | Task | Est. Hours | Status |
|---|------|-----------|--------|
| 1 | Pantry Builder long-press — removed guard that blocked tier change for items already in pantry | 0.5 | ✅ Done |
| 2 | Bookmark toggle on imported recipes — `_savedAt` now captured on auto-save so toggle works | 0.5 | ✅ Done |
| 3 | Back button touch targets — added 8px padding to all 7 bare `GestureDetector` back buttons across screens | 0.5 | ✅ Done |
| 4 | Household member delete — 350ms delay after sheet dismiss before opening confirmation dialog (animation race condition) | 0.5 | ✅ Done |

**Build:** `elio-sprint-15.8.apk` (72.9 MB)

---

## Sprint 15.9 — Personalised Pantry Builder ✅ (April 2026)

**Goal:** Memory-driven pantry builder — surface what users have actually had via tierMemory, custom items, and inventory backfill. Universal staples (salt, pepper, water, sugar, generic oils) excluded; dietary conflicts greyed.

| # | Task | Status |
|---|------|--------|
| 1 | Extract PantryStaples utility from ShoppingService | ✅ |
| 2 | PantryMemoryEntry model | ✅ |
| 3 | PantryMemoryService — read paths (recentUsuals, hadBeforeKeys, customsByCategory) | ✅ |
| 4 | PantryMemoryService — write paths (upsertCustom, backfillFromInventoryIfNeeded) | ✅ |
| 5 | showAddPantryItemDialog blocks staples with inline note | ✅ |
| 6 | Builder sheet — "Your usuals" section + tier-defaulting | ✅ |
| 7 | Builder sheet — had-before dots + customs-first chips + dietary greying | ✅ |
| 8 | Pantry-screen wiring of upsertCustom | ✅ |
| 9 | Docs (CLAUDE.md + roadmap.md) | ✅ |

**Branch:** `sprint/15.9-personalized-pantry`. Spec: `docs/superpowers/specs/2026-04-30-sprint-15.9-personalized-pantry-design.md`. Plan: `docs/superpowers/plans/2026-04-30-sprint-15.9-personalized-pantry.md`.

---

## Sprint 15.9.1 — Inventory Dedup ✅ (May 2026)

**Goal:** Stop `FirestoreService.addInventoryItem` creating duplicate Firestore docs when a user re-imports an item via any path. Existing rows update; tier sticks (existing wins); perishable expiry refreshes; `lastPurchasedAt` always refreshes.

| # | Task | Status |
|---|------|--------|
| 1 | Extract PantryStringMatch utility from ShoppingService._singularise | ✅ |
| 2 | InventoryWriter skeleton + storage interface + fake | ✅ |
| 3 | InventoryWriter.addItem with dedup + tier-sticky rule book | ✅ |
| 4 | Lazy migration of legacy rows on first addItem | ✅ |
| 5 | FirestoreService.addInventoryItem delegates to InventoryWriter | ✅ |
| 6 | Docs (CLAUDE.md schema + roadmap.md) | ✅ |

**Branch:** `sprint/15.9.1-inventory-dedup`. Spec: `docs/superpowers/specs/2026-05-01-sprint-15.9.1-inventory-dedup-design.md`. Plan: `docs/superpowers/plans/2026-05-01-sprint-15.9.1-inventory-dedup.md`.

---

## Sprint 16 — UI Overhaul — COMPLETE (April 2026, pending minor bug tweaks)

All 4 ready-for-dev screens (Home, Pantry, Recipe, Dietary) plus stretch screens (Shopping, Recipe Book, Account, Recipe Preferences, Paywall, Meal Plan, Hands-Free, Onboarding) shipped with the new Elio design system. 17 widgets in `lib/widgets/elio/`, 3 new token files in `lib/theme/`, 25/25 tests passing.

**Not tagged yet** — Rob has minor bug tweaks outstanding. Tag `v0.16.0-ui-overhaul` after those + on-device verification.

### Sprint 16b — Onboarding rebuild (branch: `sprint/16-onboarding-rebuild`, pushed 20 Apr)

15-screen, sell-to-self, sign-in-deferred onboarding. Replaces the legacy 8-screen sign-in-first flow. All pre-auth state lives in `OnboardingController` (ChangeNotifier) + `GuestPantryService` (SharedPreferences); `MigrationService` handles guest→Firestore on screen 15 sign-in.

**Plan:** `docs/superpowers/plans/2026-04-19-onboarding-rebuild.md` (7 phases, ~31 tasks)
**Specs:** `docs/onboarding/00-overview.md` + `01-welcome.md` → `15-account.md`
**Progress:** 42 commits, 239 tests passing, `flutter analyze` clean. APK `releases/elio-sprint-16.1-onboarding.apk` (71.7 MB).

| Phase | Scope | Status |
|---|---|---|
| 0 | State delta + controller + guest-pantry + AuthGate inversion + 11 widgets + palette tokens | ✅ Done |
| 1 | Screens 01 welcome, 02 goal, 03 household, 04 dietary (w/ Option B household union) | ✅ Done |
| 2 | Screen 05 allergies & dislikes | ✅ Done |
| 3 | Screens 06 time, 07 confidence, 08 appliances, 09 region & units | ✅ Done |
| 4 | Screens 10 pantry intro, 11 staples, 12 perishables | ✅ Done |
| 5 | Screen 13 first-recipe demo + Gemini ephemeral entry point | ✅ Done |
| 6 | Paywall (14, goal-keyed headlines) + Account (15, sign-in deferred) + MigrationService full impl + PurchaseService.aliasToUid | ✅ Done |
| 7 | Coordinator `onboarding_flow.dart` + analytics wiring + APK build | ✅ Done |

**In flight: Sprint 16.2 — Copy polish pass** (stays on `sprint/16-onboarding-rebuild`, not a separate sprint). Screen-by-screen walkthrough of copy on 01 → 15: spec `.md` + screen `.dart` kept in lockstep, commit per screen. Flag conditional variants (screens 05/07/10/13/14).

**Progress (22 Apr):** Screens 03 (household), 04 (dietary), 05 (allergies), 06 (time), 07 (confidence), 08 (appliances, 3-col grid + tighter tiles), 09 (region — post-override helper dropped) all polished + committed. Screen 10 reviewed, illustration flagged for Kate. Screens 11/12 got the v1 "+ Add something" per-category tile with dedup (exact-match silent promote / fuzzy-match confirm via `PantryUtils.findDuplicates`) — shipped `feat(sprint-16-onboarding): + Add something tile on screens 11/12 with dedup`. Still to review: 13 (first-recipe demo), 14 (paywall), 15 (account).

**Then:** on-device smoke test → tag `v16.1-onboarding-rebuild` → merge to `sprint/16`.

**Open items (non-blocking):**
- Screen 11 default count: 20 vs spec "~16" prose.
- Palette tokens `freshGreen`/`perishToday`/`perishThisWeek` placeholder hex — Kate to ratify.
- Screen 10 hero illustration placeholder (🧊) — Kate art.
- Screen 11/12 search bar not built (flagged later after on-device feedback).
- Screen 11/12 full dietary/allergy filtering beyond default-exclude — deferred: needs per-item metadata pass on ~100+ `PantryCategories` items (content authoring, Kate-voice decision on hide vs grey).
- Coordinator uses per-screen progress bars rather than a single coordinator-owned bar (minor visual refactor).
- **Bulk Prep on the recipe prefs screen — Kate design pass.** Flagged 24 Apr while restoring Saver / Leftover toggles on `RecipePreferencesScreen`. Bulk Prep can't reuse the regular single-recipe pipeline — `GeminiService.generateBulkRecipeStream` takes `portions`, `mealNumber`, `totalMeals`, `previousMealTitles`, and the result expects a `bulkPrepInfo` block (freezing/reheating/storage). Open questions for Kate: is "Bulk prep" on prefs single-recipe-but-batchable (portions slider, one recipe out) or does it pivot the UI to a mini multi-meal flow? Where does it sit relative to Saver / Leftover (constraints chip, separate hero CTA, dedicated screen)? Until designed, prefs screen has Saver + Leftover only and a `// TODO(sprint-16-polish-bulk-prep)` comment in `recipe_preferences_screen.dart`.

| # | Task | Est. Hours | Status |
|---|------|-----------|--------|
| 1 | Design system finalised — colours, typography, spacing, component specs | 2–3 | Done |
| 2 | Home screen — visual refresh | 2–3 | Done |
| 3 | Recipe screen — visual refresh | 1–2 | Done |
| 4 | Profile / pantry / recipe book — visual refresh | 2–3 | Done |
| 5 | Onboarding — visual refresh | 1–2 | Done |
| 6 | Paywall — visual refresh | 1 | Done |
| 7 | Cross-app consistency pass + cleanup | 1–2 | Done |

---

## Sprint 15.9.2 — Gemini Cold-Start Warmup ✅ (May 2026)

**Goal:** Address the known "Gemini first-attempt fails after app launch" reliability issue. Pre-warm the Flash connection at app launch + on Home so the first user-facing recipe generation doesn't pay the cold-start tax.

| # | Task | Status |
|---|------|--------|
| 1 | `GeminiService.prewarmConnection()` — fire-and-forget at app launch | ✅ |
| 2 | Home initState pre-warms on top of app-launch warmup (idempotent) | ✅ |
| 3 | Onboarding screen 12 calls warmup defensively before screen 13 transition | ✅ |
| 4 | Fix `MAX_TOKENS` no longer breaking recipe generation (related, batched together) | ✅ |

**Branch:** `sprint/15.9.2-gemini-warmup` (pushed). Covers every entry path — onboarding screen 13, returning-user Home Generate, post-background warm-starts.

---

## Sprint 16 — Dietary/Allergen Safety Audit ✅ (May 2026)

**Goal:** Close the highest-priority pre-launch risk — silent allergen/dietary failures. Pre-fix: peanuts could land in recipes for nut-allergic users, dietary constraints could be silently dropped, auto-save failures could surface as ghost settings, and AuthGate's Firestore fallback didn't cover the no-network case. Eight commits on `sprint/16` after the 16.4 polish that hardened the food-safety stack end-to-end.

| # | Task | Status |
|---|------|--------|
| 1 | Allergens silently dropped — root cause + hard fix in prompt assembly | ✅ |
| 2 | Auto-save was silently failing — three failure modes closed (verify-after-save, force-refresh, canonicalisation) | ✅ |
| 3 | Post-gen allergen filter + craving-override prompt | ✅ |
| 4 | Allergen filter singular/plural — "peanuts" and "peanut" both match | ✅ |
| 5 | AuthGate Firestore fallback for the no-local-flag case | ✅ |
| 6 | Allergen exclusion hoisted to a position-1 safety preamble in the Gemini prompt | ✅ |
| 7 | Time preference now drives recipe ambition | ✅ |
| 8 | Prompt audit fixes — appliances, mood, runningLow, default creative, dedup | ✅ |
| 9 | Verify-after-save read-back surfaces silent server denial | ✅ |
| 10 | Stamp request constraints onto `recipe.dietaryTags` (pill honesty) | ✅ |

**Branch:** `sprint/16` (pushed). Testing protocol: `docs/strategy/2026-05-06-allergen-testing-procedure.html` + `docs/strategy/2026-05-07-weekend-test-protocol.html`. Weekend on-device verification scheduled.

**Why this matters:** Competitor analysis (`docs/strategy/2026-05-03-competitor-analysis.html`) flagged DishGen's hallucination failure mode — "peanuts in recipes for allergic users" — as Elio's existential risk. This audit closes it before launch.

---

## Sprint 16.1 — Settings Redesign ✅ (May 2026)

**Goal:** Replace the legacy single-list "Account" screen with a four-section iOS-style Settings tree (Household / Preferences / Account / About). Unify dietary plumbing as a single source of truth with reactive sync so changes propagate from Settings → generation without manual refresh.

| # | Task | Status |
|---|------|--------|
| 1 | 4-section Settings tree (Household / Preferences / Account / About) | ✅ |
| 2 | Inline segmented controls for Measurement Units + Region (no sub-screen) | ✅ |
| 3 | Inline switch for Saver Mode default (writes to user doc) | ✅ |
| 4 | Account section: Manage Subscription + Restore Purchases + Sign Out + Delete Account | ✅ |
| 5 | About section: Privacy Policy + Terms of Service (in-app `LegalDocScreen`) + Export My Data + Send Feedback + App Version | ✅ |
| 6 | Drop the "Food Style" tile (per Rob's review of the spec) | ✅ |
| 7 | GDPR services (`AccountService.deleteAccount`, `DataExportService.exportData`) wired | ✅ |
| 8 | Send Feedback dialog with support email + tap-to-copy | ✅ |
| 9 | Unified dietary plumbing — single source of truth + reactive sync from Settings → generation | ✅ |
| 10 | Canonicalise lowercase onboarding tokens on read (drift between onboarding capture and Settings) | ✅ |
| 11 | Shopping list snackbar lifecycle (dismiss on time + on View tap) | ✅ |
| 12 | Appliances case-mismatch fix in Settings → Kitchen Appliances flow | ✅ |

**Branch:** `sprint/16.1-settings-redesign` (pushed through `55a144f`). Spec: `docs/strategy/Elio settings.docx`. File: `lib/screens/account/account_screen.dart` (rendered title is "settings.", file name kept for AppShell top-bar routing stability).

**Pending:** on-device weekend test pass per `docs/strategy/2026-05-07-weekend-test-protocol.html` → tag → merge to `sprint/16`.

---

## Sprint 16.1.x — Auth UX Fix ✅ (11 May 2026)

**Goal:** Fix the three-way trap blocking signed-out testing and confusing real users: (a) no Sign In path outside the 15-screen onboarding flow, (b) Sign Out wiped `onboardingComplete` forcing re-onboarding, (c) no deliberate "I want to walk onboarding again" action distinct from Sign Out.

| # | Task | Status |
|---|------|--------|
| 1 | Extract `performSignOut` + `performRestartOnboarding` to `lib/screens/account/account_actions.dart` — pure top-level helpers with injected callbacks for unit testability | ✅ |
| 2 | `performSignOut` no longer wipes `onboardingComplete` — user lands on AppShell as guest after sign-out | ✅ |
| 3 | AccountScreen Account section: conditional "Sign In" tile (guest only, pushes `EmailLoginScreen`); Sign Out + Delete hidden for guests | ✅ |
| 4 | AccountScreen About section: new "Restart Onboarding" action with confirm dialog — wipes guest pantry + flag, routes via AuthGate | ✅ |
| 5 | 7 unit tests in `test/screens/account/account_actions_test.dart`; full suite 448/448 passing, `flutter analyze` clean | ✅ |

**Commit:** `8fbc553` on `sprint/16.1-settings-redesign` (local only). **Not pushed** until on-device verification passes.

**Verification flow:** open the build → land on AppShell as guest → profile icon → AccountScreen → tap "Sign In" → email login → returns to AppShell signed-in. Then: AccountScreen → Sign Out → still on AppShell, still post-onboarding (no 15-screen replay). Then: AccountScreen → About → Restart Onboarding → walks the flow from screen 1.

---

## Competitor Analysis Cross-Reference (3 May 2026)

Source doc: `docs/strategy/2026-05-03-competitor-analysis.html` — deep-scan of 9 apps (Paprika · Mealime · SideChef · DishGen · Samsung Food · AnyList · Bring! · OurGroceries · Plan to Eat, plus Yummly postmortem after Whirlpool's December 2024 shutdown).

### Three moats Elio already owns — protect, don't erode

1. **AI generation grounded in actual pantry + perishable urgency.** Nobody else combines these. DishGen takes ingredient lists; Samsung Food has Vision AI but no expiry/dietary integration; Mealime + Paprika + AnyList don't generate at all.
2. **Receipt OCR + barcode + expiry-driven generation.** Samsung Food has barcode + Vision AI for ordering; no competitor does receipt OCR feeding recipe selection.
3. **Household dietary union math.** No competitor combines multiple humans' dietary restrictions and allergens into a single weekly plan.

### Five must-match gaps from analysis → sprint mapping

| # | Gap | Where it lives in this roadmap |
|---|-----|---------------------------|
| 1 | Real household sharing with email/link invite | **Sprint 16.7a investigation → 16.7b implementation** |
| 2 | In-app cooking timers + cook mode | **Sprint 16.6** |
| 3 | Browseable saved-recipe library + collections | **Sprint 16.7c** |
| 4 | Apple Watch + voice-assistant add-to-list | **Split:** Siri Shortcuts already in Sprint 19 (iOS pre-launch); Apple Watch + Google Assistant + Alexa post-launch |
| 5 | User-customisable aisle ordering | **Sprint 16.7c** |

### Deliberate omissions — features competitors have that Elio should NOT build

Capture here so they don't keep resurfacing in planning.

| Don't build | Why |
|---|---|
| Public recipe library / community feed | Yummly tried (now dead); DishGen does it badly (stolen recipes from Minimalist Baker). Moderation cost huge; dilutes the AI-from-your-pantry value. |
| Smart-fridge integration | Samsung Food's moat. Irrelevant for US-priority launch. |
| 18,000-recipe browseable corpus | SideChef's moat. Elio is generation-first; a library distracts from the differentiation. Personal saved-recipe library (Sprint 16.7c) is enough. |
| One-time pricing per platform (Paprika model) | Firestore + Gemini API recurring costs make it unsustainable for an AI app. |
| Step photos / videos for AI-generated recipes | Generated recipes can't have authentic cooking photos. Stock or AI-generated images would erode trust. Voice cooking is the "active cooking" answer. |
| Calorie/macro tracking with daily targets | MyFitnessPal territory. Different audience, harder to win. Per-recipe nutrition only. |
| Coupons / store flyers / price tracking | Flipp / Ibotta territory. Mood-killer for "what should I cook tonight." |

---

## Sprint 16.5 — Settings Menu On-Device Polish (Queued)

**Goal:** Walk every row of the new 4-section Settings tree on-device, catch the small things widget tests won't, ship the polish pass.

**Trigger:** Sprint 16.1 + 16.1.x both code-complete. Some items will be discovered during Rob's on-device run.

| # | Task | Status |
|---|------|--------|
| 1 | On-device walk of every Settings row — copy, layout, tap targets, sub-screen pushes | Pending on-device pass |
| 2 | Manage Subscription — keep snackbar pointing to store, or deep-link to platform subscription page? | Not started |
| 3 | Notification Prefs sub-screen — confirm topics + toggles match what FCM actually subscribes to | Not started |
| 4 | Region toggle side-effects audit — US ↔ UK should propagate measurement units + currency across every screen | Not started |
| 5 | App Version row — show build tag (`build/sprint-X.Y`) alongside semver for easier QA reporting | Not started |
| 6 | Guest empty-state for AccountScreen — verify nothing flashes or errors when guest hits Settings (Firestore reads no-op for guests) | Not started |
| 7 | "Restart Onboarding" copy + dialog tone — confirm wording explains "Firestore data is kept, only local guest selections are cleared" clearly | Not started |
| 8 | New items discovered during the on-device walk | TBD |

**Estimate:** ~2 days once items crystallise on-device.

---

## Sprint 16.6 — Cook & Polish (Queued)

**Goal:** The "small but loud" pre-launch polish batch — cheap features competitors all have that reviewers complain about when missing.

| # | Task | Source | Status |
|---|------|--------|--------|
| 1 | **Cooking timers + cook mode (screen-on)** on RecipeScreen | Competitor analysis must-match gap #2 (Paprika + SideChef ship; reviews cite as stickiness driver) | Not started |
| 2 | **Dark mode** — plumb `ElioColors` tokens through a dark variant | Competitor analysis (every competitor ships; absence shows up in 1-star reviews) | Not started |
| 3 | **Bulk-prep UI** — wire existing `BulkPrepInfo` Gemini data through to RecipeScreen | Existing TODO + competitor analysis | Not started |
| 4 | **Perishable chip urgency-coloured backgrounds** on Pantry tab | Standing follow-up (`project_perishable_chip_colors.md`) | Not started |
| 5 | Mood / style chip UI re-add on `RecipePreferencesScreen` — chips were removed in 16.4; prompts already wired in `59f39c5` | Sprint 16.4 deferred item | Not started |
| 6 | Widget test asserting dietary filter actually greys a chip (plumbing tested, render path not) | Sprint 15.9 pre-merge nit | Not started |
| 7 | `PantryMemoryEntry.isCustom` cleanup (drop or wire through) | Sprint 15.9 pre-merge nit | Not started |

**Estimate:** ~1 week.

---

## Sprint 16.7a — Household Sharing Investigation ✅ (11 May 2026)

**Goal:** Resolve the design complexity around real multi-user household sharing before committing to implementation. Output is a shovel-ready spec at `docs/superpowers/specs/2026-05-11-sprint-16.7-household-sharing-design.md` plus a complexity estimate that gates Sprint 16.7b pre-/post-launch.

**Outcome:** Spec landed. Six foundational design decisions locked (full-share opt-in, owner-seeds-invitee-chooses migration, 6-digit code invites, owner's Pro extends to members, per-user dietary with cached household union, single-owner lifecycle). Independent `superpowers:code-reviewer` QA pass applied 5 critical fixes (dietary location, invitee-self-add rule, delete order, EntitlementService snippet, owner-profile filtering) and 5 worth-flagging adjustments. Final estimate: **~11 days** of focused implementation.

**Why this matters:** Competitor analysis must-match gap #1. AnyList's $14.99/yr household tier is the price anchor below Elio's $29.99/yr — defending requires real household sharing.

| # | Investigation question | Status |
|---|------|--------|
| 1 | **Firestore schema** — `households/{hid}` subtree with `owner`, `members[]`. Which sub-collections (shoppingItems, mealPlan, inventory, ratings, customItems, tierMemory) move from `users/{uid}/` to `households/{hid}/` vs stay per-UID? | Not started |
| 2 | **Invite flow** — Firebase Email Link / dynamic link / 6-digit code? Deep-link with accept-invite token. Edge cases: existing-account user vs new sign-up | Not started |
| 3 | **Security rules** — cross-UID read/write inside `households/{hid}/*` keyed on custom claims vs `get()` lookup. Performance trade-off | Not started |
| 4 | **Migration** — current household members are local profiles under one UID. Design for: (a) "head of household + dependents without phones" → keep profile-based; (b) "two adults each with own phone" → invite flow | Not started |
| 5 | **RevenueCat** — does household pricing need a new entitlement, or does an existing Pro subscriber's household grant Pro to invited members? Affects paywall copy | Not started |
| 6 | **Conflict resolution** — Firestore last-write-wins is fine; UI should attribute changes ("Kate added milk") | Not started |
| 7 | **UI scope** — invite tile on AccountScreen, member list in HouseholdScreen, owner-only actions, leave-household, guest-vs-member visibility | Not started |
| 8 | Spec doc + decision-gate write-up | Not started |

**Estimate:** 1–2 days.

**Decision gate at end of 16.7a:**
- Implementation ≤2 weeks → ship as **Sprint 16.7b pre-launch**
- Implementation >2 weeks → spec is shovel-ready; **punt 16.7b to v1.1 post-launch**

---

## Sprint 16.7b — Household Sharing Implementation (PUNTED to v1.1 post-launch)

**Decision (11 May 2026):** punted to **v1.1 post-launch**. Spec at `docs/superpowers/specs/2026-05-11-sprint-16.7-household-sharing-design.md` is shovel-ready; implementation kicks off ~4-6 weeks after v1.0 launch as the headline feature of the first major update.

**Reasoning** (full version in spec §12):
- 11-day implementation estimate. Estimates run hot in this codebase (15.9 was 50% over, 16.1 trending similar). Realistic elapsed 15-18 days.
- Pre-launch already loaded with 16.6 + 16.8 + 17 + 18 + 19. Slotting 16.7b adds critical-path risk.
- Cloud Functions for `proActive` cheating prevention land in Sprint 17 — natural pairing if 16.7b ships post-launch alongside (rather than launching with a known security limitation in a marquee feature).
- Marketing benefit: dedicated "Elio now does household sharing" press moment vs. getting lost in launch noise.

**When work resumes:** writing-plans pass against the spec → Sprint 16.7b branch off whatever is `main` at the time.

---

## Sprint 16.7c — Browseable Library + Custom Aisles (Queued)

**Goal:** Decoupled from household sharing so it ships regardless of the 16.7a gate. Two competitor-analysis must-match gaps that don't depend on household infra.

| # | Task | Source | Status |
|---|------|--------|--------|
| 1 | **Browseable saved-recipe library + collections** — UI repackaging of existing `users/{uid}/recipes/{id}` data (filter, sort, collections). Data exists; mostly merchandising | Competitor analysis must-match gap #3 | Not started |
| 2 | **User-customisable aisle ordering** — per-user `aisleOrder` on user doc. Lift Plan to Eat pattern; reviews tie it to long-term retention | Competitor analysis must-match gap #5 | Not started |

**Estimate:** 3–4 days.

---

## Sprint 16.8 — Email-Forward Order Import (Pre-Launch, blocked on domain)

**Goal:** Capture the growing online-grocery slice. User gets a unique elio inbox (`<uid-hash>@in.elio.app`), forwards Instacart / Amazon Fresh / Tesco / Sainsbury's / Ocado order confirmations, Elio parses line items into pantry as if it were a receipt scan. Hybrid of receipt OCR + a new ingestion path.

**Blocked on:** Rob's domain registration (waiting on ISP login issue). Once `in.elio.app` MX is live, this can start.

| # | Task | Status |
|---|------|--------|
| 1 | Inbound email infra — Postmark vs AWS SES decision, MX setup on `in.elio.app` | Not started |
| 2 | Per-user unique inbox address (`<uid-hash>@in.elio.app`) — generate, store, surface in Settings | Not started |
| 3 | Cloud Function to receive incoming email, validate sender, parse, write to Firestore inventory | Not started |
| 4 | Email-to-pantry parser (Gemini-driven, reuses receipt OCR pipeline + `InventoryWriter` dedup) | Not started |
| 5 | Vendor presets — US: Instacart, Amazon Fresh, Walmart. UK: Tesco, Sainsbury's, Ocado | Not started |
| 6 | Settings UI — "Forward your shopping orders to: `<your-address>`" with copy button + instructions | Not started |
| 7 | Onboarding-friendly explainer — first-time discoverability | Not started |
| 8 | Spam / abuse guard — drop emails from unknown senders without an active forwarding rule | Not started |

**Estimate:** ~1.5 weeks once domain is live.

**Why pre-launch (Rob's call, 11 May):** the moat extension over Samsung Food's smart-fridge integration — same job-to-be-done (track what you actually have at home) but reachable without locked-in hardware.

---

## Sprint 17 — Shared Launch Preparation

**Goal:** Everything that must be true before either store accepts a submission.

| # | Task | Est. Hours | Status |
|---|------|-----------|--------|
| 1 | Performance audit (DevTools profiling, list optimisation, cold start time) | 3–4 | ✅ Done |
| 2 | **Firestore security rules audit** — rules are currently permissive (dev mode); must be locked down before public launch. Firebase console already flagging this. Also: data retention policy, input sanitisation | 2–3 | ⚠️ Partially done — rules + entitlement hardening landed on `sprint-17` branch (commits `8a17e8c`, `8c9e318`). Still to do: `firebase deploy --only firestore:rules`, emulator rule test suite, Cloud Functions backend so `weeklyGenerations` can be locked too, GCP budget caps |
| 3 | GDPR compliance (data export, account deletion, consent tracking) | 2–3 | Not started |
| 4 | Privacy policy + Terms of Service (in-app screens + hosted URLs — shared across both stores) | 2–3 | Not started |
| 5 | Remove temporary debug messages from home_screen.dart | 0.5 | Not started |
| 6 | Crashlytics → Slack/Discord webhook (real-time error alerts via Cloud Function) | 1–2 | Not started |
| 7 | Wire `REVENUECAT_API_KEY` through build.ps1 / `.env.local` + configure live Play Store + App Store SKUs with 7-day free trial | 2–3 | Partially done (build.ps1 wired, key not yet in .env.local) |
| 8 | Expand `ErrorService` coverage to GeminiService, FirestoreService, VoiceControlService, PurchaseService (currently only 4 call sites) | 1–2 | ✅ Done (Sprint 15.5 — ~15 call sites across 6 services) |
| 9 | **Email re-auth path for Delete Account.** `AccountScreen._reauthForDelete` currently only supports the Google provider — Email/password users get a snackbar pointing them at the support email. **Launch blocker** per Play Store + GDPR requirement for in-app account deletion across all auth methods. Wire `EmailAuthProvider.credential(...)` into the existing reauth callback, mirroring the Google branch. Added 11 May 2026 after discovering it during the Sprint 16.6 device-test pass. | 1–2 | Not started |
| 10 | **Forgot Password flow on-device verification.** `AuthService.sendPasswordReset` + `EmailLoginScreen` "Forgot password?" link are already wired. Verify end-to-end: enter email → tap link → email arrives → reset flow works → can sign in with the new password. Added 11 May 2026 — code in place since Sprint 15.x, never on-device confirmed. | 0.25 | Not started |

**Estimate:** 14.25–24.25 hours

**Sprint 17 progress note (16 April 2026):** Firestore rules + entitlement hardening were committed on the `sprint-17` branch (currently unmerged). The old hard-coded dev-email allowlist and `proOverride` flag have been removed entirely; dev/tester Pro now comes from the Firestore doc `config/proTesters` (emails array). RevenueCat is the single source of truth for paying users. Branch needs `flutter analyze` + a PR to `main`.

---

## Sprint 18 — Android Track

**Goal:** Play Store submission-ready. Runs in parallel with Sprint 19 iOS work.

| # | Task | Est. Hours | Status |
|---|------|-----------|--------|
| 1 | Full regression test — Android physical device | 3–4 | Not started |
| 2 | Play Store assets (screenshots, feature graphic, store listing copy) | 2–3 | Not started |
| 3 | Submit to Google Play Console (internal testing track) | 1–2 | Not started |
| 4 | Closed beta feedback loop (pro-tester Firestore list) | 2–3 | Not started |
| 5 | Production staged rollout (10% → 50% → 100%) | 1 | Not started |
| 6 | Yummly-migration landing page ("Coming from Yummly? We import your saved recipes") — capture residual displaced audience | 1 | Not started |

**Estimate:** 10–14 hours

---

## Sprint 19 — iOS Track

**Goal:** App Store submission-ready in parallel with Android. Target a coordinated launch window — Android may go live a few days earlier if Apple review is slower.

| # | Task | Est. Hours | Status |
|---|------|-----------|--------|
| 1 | iOS build configuration and signing (Xcode, provisioning profiles, bundle ID) | 2–3 | Not started |
| 2 | Apple Sign-In integration (required by App Store when Google Sign-In is present) | 3–4 | Not started |
| 3 | iOS-specific UI adjustments (safe areas, haptics, keyboard behaviour) | 2–3 | Not started |
| 4 | Replace `com.elio/audio` platform channel with iOS equivalent (AVAudioSession) OR gate voice-beep suppression to Android only | 1–2 | Not started |
| 5 | **Siri Shortcuts** — donate `NSUserActivity` for "Generate a recipe", "Open my shopping list", "What's in my pantry", "Start cooking last recipe", and "Add to my shopping list" (voice-assistant add-to-list from competitor analysis). Must be done before launch so iOS users get voice entry points on day one. | 3–4 | Not started |
| 6 | iOS permissions plist (NSMicrophoneUsageDescription, NSCameraUsageDescription, NSSpeechRecognitionUsageDescription) | 0.5 | Not started |
| 7 | Full regression test — iOS physical device | 3–4 | Not started |
| 8 | App Store assets (iOS screenshots at required sizes, App Store listing) | 2–3 | Not started |
| 9 | Submit to TestFlight | 1–2 | Not started |
| 10 | App Store review submission | 1 | Not started |

**Estimate:** 18.5–26.5 hours

---

## Post-Launch Backlog (Prioritised)

### v1.1 — from competitor analysis (early post-launch)

| Priority | Feature | Notes |
|----------|---------|-------|
| **P1** | **Sprint 16.7b — Real Household Sharing** (headline v1.1 feature) | Multi-UID household with full data sharing (inventory, shopping, meal plan), 6-digit code invites, owner's Pro extends to up to 6 members. Competitor-analysis must-match gap #1. Spec at `docs/superpowers/specs/2026-05-11-sprint-16.7-household-sharing-design.md`. **~11 days implementation** + Sprint 17 Cloud Function dependencies (RC webhook, monthly sweep, cascade-delete sweep — 2.5-3 days incremental). |
| P1 | **Apple Watch app** | Read-only shopping list with check-off. Three of four shopping-list competitors have it; AnyList + OurGroceries reviewers cite as top-3 feature. |
| P1 | **Google Assistant add-to-list (Android)** | "Hey Google, add milk to my Elio list" — Android equivalent of Siri Shortcuts (which ships in Sprint 19 pre-launch). |
| P1 | **Free-tier shopping list** (single list, no household, no recipe-link) | Widens conversion funnel. OurGroceries gives full list free; Elio's all-or-nothing gating may cap free-to-paid. |
| P2 | **Wider recipe-import site coverage** | Top-50 cooking domains with validated parsers as fallback to Vision OCR. AnyList + Plan to Eat publish supported-domain lists. |
| P2 | **Alexa skill** | Bring! ships it; lower priority than Siri / Google. |

### v1.2 — competitor analysis (data-driven post-launch)

| Priority | Feature | Notes |
|----------|---------|-------|
| P2 | **Multiple lists** (groceries, Costco, hardware) | AnyList + Bring! + OurGroceries + Plan to Eat all support. Generalize shopping-list model. After household sharing lands. |
| P2 | **Recurring lists / templates** | "Weekly staples" template that clones to active list. AnyList + OurGroceries have. |
| P2 | **Family pricing tier** ($X/yr household, AnyList-style at $14.99/yr) | After Sprint 16.7 household sharing proves out. Match AnyList structure. |
| P2 | **Per-store aisle layouts** ("my Trader Joe's, my Whole Foods") | After basic custom aisle ordering (16.7c) proves out. Plan to Eat's stickiness driver. |
| P3 | **Geofence "at the store" reminders** | Bring!-style. Niche-loved; battery + permission friction. |

### Carry-over from existing backlog

| Priority | Feature | Notes |
|----------|---------|-------|
| P1 | Accurate cost estimation | Supermarket API integration for real pricing |
| P1 | Regional language localisation | courgette/zucchini, coriander/cilantro, etc. |
| P2 | Grocery affiliate integration | Shopping list → delivery service |
| P2 | Social sharing | Recipe card as shareable image |
| P2 | Recipe ratings & feedback loop | Like/dislike influences future generation (internal adaptive learning already shipped — this is the user-visible surface) |
| P3 | Multilingual support | Full app translation |
| P3 | Tablet/web layout optimisation | Responsive layouts for larger screens |
| P3 | Offline mode | Cache recent recipes, local-first pantry for all users |

### Small loose ends from memory + earlier sprints

| Item | Notes |
|------|-------|
| Onboarding screens 06–15 still using `ElioHeroHeading` wrapper | Migrate to `ElioPageTitle` directly |
| Legacy `ElioTextStyles` aliases cleanup + delete `ElioHeroHeading` wrapper | Sweep callers, delete aliases |
| Per-pantry-item dietary metadata pass | ~100+ items in `PantryCategories.all` need per-item dietary tags (content authoring, Kate-voice decision on hide vs grey) |
| Screen 11/12 search bar | Deferred from Sprint 16.2; reassess after on-device feedback |
| Screen 10 hero illustration | Kate art (currently placeholder) |
| Coordinator-owned single progress bar | Replace per-screen progress bars (minor visual refactor) |
| Bulk Prep on prefs screen — Kate design pass | Open questions: single-recipe-but-batchable vs multi-meal flow; chip vs hero CTA vs dedicated screen |
| Sprint 18 original (App Check + server-side Gemini migration) | Deferred — original sprint number reused for Android track |

---

## Known Issues

- `google-services.json` not in git — must be added manually after fresh clone
- Dev flavor broken — always use `--flavor prod`
- iOS URL scheme placeholder needs filling before any iOS build
- APK size 72.9 MB (mobile_scanner ML Kit) — may need app bundles for Play Store
- `REVENUECAT_API_KEY` wired in build.ps1 but actual key not yet in `.env.local` (need RC project setup)