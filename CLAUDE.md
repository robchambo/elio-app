# Elio — AI Recipe Generator

Flutter app. Gemini AI generates recipes from your actual pantry. Android-primary, coordinated iOS launch planned.

## Identity

- **What:** AI-powered recipe generator that knows your kitchen. Pantry built during onboarding, recipes grounded in what you have.
- **Who for:** Busy households (couples, families, flatshares) who want to eat well without daily meal-planning friction. US primary, UK secondary.
- **Core principle:** Remove friction. Minimal taps, simplicity over completeness. Every screen earns its place.
- **Repo:** `https://github.com/robchambo/elio-app` (private, `main` branch)
- **Local path:** `C:\Users\kated\.claude\Elio`
- **Stack:** Flutter/Dart, Firebase (Auth/Firestore/Crashlytics/Analytics/FCM/Remote Config), Gemini (2.5-flash streaming + 2.5-flash-lite batch), RevenueCat, mobile_scanner, shimmer
- **Flutter:** 3.27.x | Dart SDK `>=3.4.0 <4.0.0` | AGP 8.9.1 | Gradle 8.11.1

## Build — CRITICAL

```
powershell -ExecutionPolicy Bypass -File build.ps1 -sprint <version>
```

**NEVER** run raw `flutter build apk` — the Gemini API key comes from `.env.local` and is injected via `--dart-define` by `build.ps1`. Without it, generation fails with 403. Always `--flavor prod` (dev flavor is broken — missing Firebase client).

**Run command:** `flutter run --flavor prod -t lib/main.dart --dart-define=GEMINI_API_KEY=<key>`

**Dev account testing:** Dev accounts auto-activate Pro via email allowlist in `EntitlementService`.

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

## Architecture Quick Reference

```
lib/
  models/        — elio_models, recipe_models (RecipeGenerationStatus sealed class), meal_plan_models, onboarding_state
  data/          — pantry_categories (12 categories, lazy lookup)
  services/      — gemini (SSE streaming, JSON mode, thinking off), firestore, auth, scanner, shopping,
                   meal_plan, history (bookmarking), entitlement, analytics, notification, remote_config,
                   guest_pantry, purchase, error_service, voice_control
  screens/
    home/        — Generate button with streaming shimmer skeleton
    recipe/      — Recipe view, ingredient substitution, voice cooking, "Generate Another"
    profile/     — 4 tabs: Pantry, Recipe Book, Style, Shopping
                   Also: dietary_screen, kitchen_screen, household_screen, settings_screen
    scanner/     — Barcode (mobile_scanner) + receipt scanning (Gemini Vision)
    onboarding/  — 8 screens (screen1_dietary → screen8_complete)
    meal_plan/   — Lazy-load detail on tap
    paywall/     — RevenueCat paywall (trial-first design)
  widgets/       — pantry_builder_sheet (dialog-based tier picker for custom items)
  utils/         — region_utils, pantry_utils (fuzzy dedup)
```

### Firestore Schema

```
users/{uid}/
  (user doc) — dietary, inventory[], appliances[], stylePreferences[], region, measurementUnits
  householdProfiles/{id} — name, dietaryRequirements[], isOwner
  shoppingItems/{id} — name, quantity, source, isChecked
  tierMemory/{normalizedName} — tier, lastSeen
  mealPlans/{id}
inventory/{docId} — name, tier, category, expiryDate?, price?, runningLow
recipes/{id} — generated recipe data
```

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

- **`REVENUECAT_API_KEY` not wired through `build.ps1`** — PurchaseService dry mode. Paywall relies on optimistic fallback. Sprint 16 blocker.
- **`google-services.json` not in git** — must add manually after fresh clone.
- **ErrorService coverage thin** — only ~4 call sites. GeminiService / FirestoreService / VoiceControlService / PurchaseService all swallow errors silently. Sprint 16 task.
- **`integration_test/paywall_test.dart`** has stale string assertions from before the trial-first rewrite.
- **APK size 72.4 MB** — mobile_scanner ML Kit. May need app bundles for Play Store.
- **iOS not built/tested** — URL scheme placeholder must be filled first.
- **`NotificationService.requestPermissionAndRegister()`** deferred but never wired to a trigger.
- **`mockup/` directory** untracked.

## Launch Strategy

Coordinated Android + iOS launch. Android built first, both released in the same window.

- **Sprint 16:** Shared launch preparation — Firestore security rules, GDPR, privacy/ToS, RC wiring, ErrorService coverage, Crashlytics webhook
- **Sprint 17:** Android track — regression, Play Store listing, internal test, beta, staged rollout
- **Sprint 18:** iOS track — Apple Sign-In, Siri Shortcuts (pre-launch), TestFlight, App Store submission

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

## Last Session (11 April 2026) — Sprint 15.3.20

### Completed
- **Gemini prompt fix (build 15.3.20):** User-selected perishables prompt tightened from "Fresh items (use these):" to "REQUIRED ingredients — you MUST use ALL of these in the recipe (not just some of them)... Every single one must appear in the ingredients list and be used meaningfully in the cooking steps." Fixed bug where Gemini was dropping selected ingredients (e.g., selecting chicken + peppers but only getting peppers in the recipe).
- **Brand & art concept doc:** Created `docs/brand-art-concept.md` one-pager for brand/art pass with Kate — personality, visual system, 6 open design decisions, constraints.
- **CLAUDE.md comprehensive rewrite:** Migrated all knowledge from memory files + conversation into CLAUDE.md for cross-device portability.

### Prior Session (5 April 2026) — Sprint 15.3.17 → 15.3.19
- UX audit Pass 1 (15.3.17): onboarding progress bars, fade gradients, receipt edit/delete, expiry dates + prices, recipe screen FAB/mic/cart badge, pantry expiry editing
- UX audit Pass 2 (15.3.18): onboarding screen8_complete, trial-first paywall with triggerContext, feature checklist, Monthly/Annual toggle
- Paywall dry-mode fix (15.3.19): `_showTrialState` returns true when packages empty

### Needs Testing
- Build 15.3.20: generate recipe with 2+ selected items, confirm ALL appear. Test "Generate Another" too.
- Build 15.3.19 paywall: onboarding + meal-plan triggers should show trial hero
- Receipt scanner edit/delete/expiry, pantry expiry chips, onboarding success screen

### Gemini API State
- **Streaming**: gemini-2.5-flash via SSE, maxOutputTokens 1024 (standard) / 2048 (bulk prep), thinking disabled (thinkingBudget: 0), responseMimeType: application/json
- **Batch**: gemini-2.5-flash-lite, responseMimeType: application/json
- **Connection**: static http.Client reused across calls
