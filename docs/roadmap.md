# Elio Roadmap

**Last updated:** 25 April 2026 (Sprint 16.4 polish on `sprint/16` at `b44a617`, pushed. On-device smoke test passed — all 6 reported bugs + photo import wire-up confirmed working. APK built: `releases/elio-sprint-16.4-polish.apk`, local tag `build/sprint-16.4-polish`. Ready to tag `v0.16.0-ui-overhaul`.)

**Sprint 16.4 polish (this session):**
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

**Estimate:** 13–21 hours

**Sprint 17 progress note (16 April 2026):** Firestore rules + entitlement hardening were committed on the `sprint-17` branch (currently unmerged). The old hard-coded dev-email allowlist and `proOverride` flag have been removed entirely; dev/tester Pro now comes from the Firestore doc `config/proTesters` (emails array). RevenueCat is the single source of truth for paying users. Branch needs `flutter analyze` + a PR to `main`.

---

## Sprint 18 — Android Track

**Goal:** Play Store submission-ready. Runs in parallel with Sprint 18 iOS work.

| # | Task | Est. Hours | Status |
|---|------|-----------|--------|
| 1 | Full regression test — Android physical device | 3–4 | Not started |
| 2 | Play Store assets (screenshots, feature graphic, store listing copy) | 2–3 | Not started |
| 3 | Submit to Google Play Console (internal testing track) | 1–2 | Not started |
| 4 | Closed beta feedback loop (pro-tester Firestore list) | 2–3 | Not started |
| 5 | Production staged rollout (10% → 50% → 100%) | 1 | Not started |

**Estimate:** 9–13 hours

---

## Sprint 19 — iOS Track

**Goal:** App Store submission-ready in parallel with Android. Target a coordinated launch window — Android may go live a few days earlier if Apple review is slower.

| # | Task | Est. Hours | Status |
|---|------|-----------|--------|
| 1 | iOS build configuration and signing (Xcode, provisioning profiles, bundle ID) | 2–3 | Not started |
| 2 | Apple Sign-In integration (required by App Store when Google Sign-In is present) | 3–4 | Not started |
| 3 | iOS-specific UI adjustments (safe areas, haptics, keyboard behaviour) | 2–3 | Not started |
| 4 | Replace `com.elio/audio` platform channel with iOS equivalent (AVAudioSession) OR gate voice-beep suppression to Android only | 1–2 | Not started |
| 5 | **Siri Shortcuts** — donate `NSUserActivity` for "Generate a recipe", "Open my shopping list", "What's in my pantry", "Start cooking last recipe". Must be done before launch so iOS users get voice entry points on day one. | 3–4 | Not started |
| 6 | iOS permissions plist (NSMicrophoneUsageDescription, NSCameraUsageDescription, NSSpeechRecognitionUsageDescription) | 0.5 | Not started |
| 7 | Full regression test — iOS physical device | 3–4 | Not started |
| 8 | App Store assets (iOS screenshots at required sizes, App Store listing) | 2–3 | Not started |
| 9 | Submit to TestFlight | 1–2 | Not started |
| 10 | App Store review submission | 1 | Not started |

**Estimate:** 18.5–26.5 hours

---

## Post-Launch Backlog (Prioritised)

| Priority | Feature | Notes |
|----------|---------|-------|
| P1 | Accurate cost estimation | Supermarket API integration for real pricing |
| P1 | Regional language localisation | courgette/zucchini, coriander/cilantro, etc. |
| P2 | Grocery affiliate integration | Shopping list → delivery service |
| P2 | Social sharing | Recipe card as shareable image |
| P2 | Recipe ratings & feedback loop | Like/dislike influences future generation |
| P3 | Multilingual support | Full app translation |
| P3 | Tablet/web layout optimisation | Responsive layouts for larger screens |
| P2 | Linked accounts — shared household shopping list | Requires: householdId on user doc, shared Firestore collection, invite code system, security rules. Current household members are local profiles under one UID — true sharing needs separate auth accounts linked to a household group. |
| P3 | Offline mode | Cache recent recipes, local-first pantry for all users |

---

## Known Issues

- `google-services.json` not in git — must be added manually after fresh clone
- Dev flavor broken — always use `--flavor prod`
- iOS URL scheme placeholder needs filling before any iOS build
- APK size 72.9 MB (mobile_scanner ML Kit) — may need app bundles for Play Store
- `REVENUECAT_API_KEY` wired in build.ps1 but actual key not yet in `.env.local` (need RC project setup)
