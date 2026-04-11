# Elio Technical Design Document

**Version:** Sprint 15.3.19 | **Date:** 5 April 2026 | **Status:** Pre-launch

---

## 1. System Architecture

### 1.1 Stack
| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.27.x / Dart SDK >=3.4.0 |
| Auth | Firebase Auth (Google Sign-In v6, email/password, anonymous/guest) |
| Database | Cloud Firestore |
| AI | Google Gemini API (2.5-flash for recipes via SSE, 2.5-flash-lite for lightweight calls) |
| Monetisation | RevenueCat SDK (dry mode if no API key) |
| Push | Firebase Cloud Messaging (FCM) + topic subscriptions |
| Analytics | Firebase Analytics + Crashlytics (non-fatal error logging via ErrorService) |
| Config | Firebase Remote Config (Gemini API key with dart-define fallback) |
| Scanning | mobile_scanner (barcode), image_picker + Gemini Vision (receipt OCR + recipe import) |
| Voice | speech_to_text + flutter_tts + platform channel (com.elio/audio) for beep suppression |
| Local Storage | SharedPreferences (history, guest mode) |

### 1.2 Build Process
```
powershell -ExecutionPolicy Bypass -File build.ps1 -sprint <version>
```
- Reads Gemini API key from `.env.local`
- Passes key via `--dart-define=GEMINI_API_KEY=<key>`
- Uses `--flavor prod` (dev flavor has no Firebase client)
- Copies APK to `releases/elio-sprint-<version>.apk`
- Creates git tag `build/sprint-<version>`

**Critical:** Never use raw `flutter build`. API calls return 403 without the injected key.

**Pre-launch TODO:** `build.ps1` does not currently pass `REVENUECAT_API_KEY`. Until this is wired through, `PurchaseService.init()` exits early ("dry mode") and `getPackages()` returns an empty list — which is why the paywall falls back to its optimistic trial copy in release builds today. Before Sprint 16 launch: add `REVENUECAT_API_KEY` to `.env.local` and pass it via `--dart-define` alongside `GEMINI_API_KEY`.

### 1.3 Project Structure
```
lib/
  main.dart                    # App entry, Firebase init, parallelised service init
  theme/elio_theme.dart        # Design tokens (ElioColors, ElioText)
  data/
    pantry_categories.dart     # Category definitions for Pantry Builder
  models/
    elio_models.dart           # InventoryItem, HouseholdProfile, KitchenPreset
    recipe_models.dart         # GeneratedRecipe, SavedRecipe, BulkPrepInfo
    meal_plan_models.dart      # MealPlan, DayPlan, MealSlot, ShoppingItem
    onboarding_state.dart      # Accumulated onboarding choices
  services/
    auth_service.dart          # Firebase Auth wrapper
    firestore_service.dart     # All Firestore CRUD + in-memory taste profile cache
    gemini_service.dart        # AI recipe generation (SSE streaming) + substitution
    scanner_service.dart       # Barcode (Open Food Facts) + receipt OCR
    history_service.dart       # Local recipe persistence + in-memory cache
    shopping_service.dart      # Persistent shopping list (Firestore)
    meal_plan_service.dart     # Weekly meal plan generation
    entitlement_service.dart   # Free vs Pro tier gating
    purchase_service.dart      # RevenueCat wrapper (lazy init)
    analytics_service.dart     # Firebase Analytics events + properties
    notification_service.dart  # FCM token lifecycle (split: init vs permission request)
    remote_config_service.dart # API key fetch with fallback
    guest_pantry_service.dart  # SharedPreferences for guest mode
    error_service.dart         # Crashlytics non-fatal logging with feature tags
  screens/
    home/home_screen.dart      # Central hub, recipe generation, saver/bulk toggles
    home/bulk_prep_results_screen.dart
    recipe/recipe_screen.dart  # Recipe display, voice control, substitution, bulk section
    profile/profile_screen.dart # 4-tab profile (Pantry, Recipe Book, Style, Shopping)
    profile/settings_screen.dart
    profile/dietary_screen.dart
    profile/kitchen_screen.dart
    profile/household_screen.dart
    profile/notification_prefs_screen.dart
    profile/recipe_import_screen.dart  # Photo scan + manual entry import (Pro)
    scanner/scanner_screen.dart
    scanner/receipt_results_screen.dart
    scanner/scan_success_screen.dart
    meal_plan/meal_plan_screen.dart
    history/history_screen.dart
    onboarding/                # 8 screens: screen1_dietary -> screen7_units_region + screen8_complete
    auth/                      # Welcome, email login/register
    paywall/paywall_screen.dart  # Trial-first, context-aware headlines
  widgets/
    pantry_builder_sheet.dart  # Categorised item browser
  utils/
    pantry_utils.dart          # Fuzzy matching, duplicate detection
    region_utils.dart          # Currency/measurement formatting
```

---

## 2. Firestore Schema

```
users/{uid}
  displayName, email, createdAt
  onboardingComplete: bool
  stylePreferences: [String]
  appliances: [String]
  measurementUnits: "metric" | "imperial"
  region: "UK" | "US"
  activeProfileIds: [String]
  subscription/
    tier: "free" | "pro"
    weeklyGenerations: int
    weekStartedAt: Timestamp
    proOverride: bool (dev only)
  notificationPrefs/
    weeklyReminder, restockReminder, tipsAndUpdates: bool

  /profiles/{docId}
    name, dietaryRequirements: [String], customAllergens: [String], isOwner: bool

  /inventory/{docId}
    name, tier: "alwaysHave"|"almostAlwaysHave"|"perishable"
    runningLow: bool, expiryDate: Timestamp?, category: String?
    price: String?  # optional, captured from receipt scans for future cost estimation

  /recipes/{docId}
    [GeneratedRecipe fields], isBookmarked: bool, savedAt: Timestamp

  /shoppingItems/{docId}
    name, nameLower, quantity, source: "manual"|"meal_plan"|"restock"
    isChecked: bool, addedAt: Timestamp

  /tierMemory/{normalizedName}
    tier: String, lastSeen: Timestamp

  /fcmTokens/{tokenHash}
    token, platform, updatedAt

  /meal_plan (single doc)
    [MealPlan JSON]
```

---

## 3. AI Integration

### 3.1 Recipe Generation (Gemini 2.5 Flash — SSE Streaming)
- **Transport:** HTTP SSE via `http.Request` with `stream: true`; chunks parsed as they arrive
- **HTTP client:** Static `_httpClient = http.Client()` — shared across all calls (no per-request TCP/TLS overhead)
- **Max output:** 1,024 tokens (standard) | 2,048 tokens (bulk prep)
- **Temperature:** 0.8 | **Thinking:** disabled (`thinkingBudget: 0`)
- **Response format:** `responseMimeType: application/json` — clean JSON guaranteed, no markdown fence extraction needed
- **Shared helper:** `_streamFromPrompt(prompt, {required int maxOutputTokens})` — single implementation used by both `generateRecipeStream()` and `generateBulkRecipeStream()`
- **Prompt includes:** hard dietary constraints, soft preferences (style/mood/time), perishable inventory with expiry urgency, running low items, excluded ingredients, VARIETY section with last 5 session titles (different base ingredient + cooking method + cuisine), liked/disliked recipes, appliances, budget mode flag, regional pricing

### 3.2 Ingredient Substitution (Gemini 2.5 Flash-Lite)
- **Max output:** 256 tokens | **Response MIME:** application/json
- Returns: substitute name, adjusted quantity, unit, trade-off description

### 3.3 Receipt OCR (Gemini 2.5 Flash-Lite + Vision)
- Image compressed to 1,600px max width, 85% quality
- Extracts: item names, prices, store name, isFood flag
- Non-food items filtered automatically during parsing
- Tier lookups batched via `Future.wait()` — no sequential N+1 calls
- ~35% cost saving vs full Flash model

### 3.4 Recipe Import (Gemini 2.5 Flash-Lite + Vision)
- Photo of recipe (book, card, screenshot) → structured recipe object
- Extracts: title, description, ingredients (with quantities), steps
- Falls back to manual entry if OCR quality is poor
- Image compressed to 1,600px max width, 85% quality

### 3.5 Meal Plan Generation (Gemini 2.5 Flash-Lite)
- Generates 7-day x 3-meal matrix
- Phase-1: titles + brief info; Phase-2: lazy-loads full steps/nutrition on tap

---

## 4. Entitlement System

| Feature | Free | Pro | Guest |
|---------|------|-----|-------|
| Recipes/week | 7 | Unlimited | 3 |
| History | 20 | 50 | 20 (local) |
| Household | Owner only | 6 members | None |
| Meal planner | No | Yes | No |
| Shopping list | No | Yes | No |
| Scanning | Yes | Yes | No |
| Bulk Prep Mode | No | Yes | No |
| Recipe Import | No | Yes | No |

- Weekly counter resets on schedule
- Dev email bypass: always Pro
- proOverride flag in Firestore for test accounts
- RevenueCat syncs purchases to Firestore subscription doc
- **Lazy init:** `PurchaseService._ensureInitialised()` called at start of every public method — not initialised at app startup

---

## 5. Data Flow

### 5.1 Recipe Generation (Streaming)
```
User selects perishables + mood/style/time
  -> HomeScreen dismisses keyboard (FocusScope.unfocus)
  -> Builds RecipeGenerationRequest (with last 5 session titles for variety)
  -> EntitlementService.canGenerate() check
  -> GeminiService.generateRecipeStream(request) — SSE stream
  -> Shimmer skeleton shown during generation
  -> JSON streamed in chunks, parsed on completion
  -> Recipe saved to HistoryService (local cache + SharedPreferences)
     + FirestoreService (cloud) BEFORE navigation
  -> Navigator.push(RecipeScreen) with savedAt timestamp
  -> Increment weekly counter
```

### 5.2 Pantry Builder
```
User taps "Pantry Builder" button
  -> Opens PantryBuilderSheet (draggable bottom sheet)
  -> Tap item: adds to Always Have with auto-categorisation
  -> Long-press (300ms, RawGestureDetector): tier picker dialog
  -> PantryCategories.categorize() resolves category
  -> FirestoreService.addInventoryItem(name, tier, category)
```

### 5.3 Scanner Pipeline
```
Barcode scan -> Open Food Facts API -> product name + brand
Receipt photo -> Gemini Vision (Flash-Lite) -> item list + prices
  -> Non-food items filtered during parsing
  -> ScannerService.suggestTier() batched via Future.wait()
     (memory -> category heuristic -> name heuristic -> fallback)
  -> ReceiptResultsScreen: user reviews items
       * edit icon -> rename dialog
       * × icon -> remove before commit
       * tier badge (with dropdown chevron + first-run hint) -> tier picker
       * expiry presets (3 days / 1 week / 2 weeks / none) for perishables
  -> ScannerScreen: user taps "Add X Items to Pantry"
  -> _addToPantry():
       * _expiryDateFromLabel() converts shelf-life strings to Timestamps
       * saves tier memory
       * addInventoryItem(name, tier, category, expiryDate, price)
  -> ScanSuccessScreen: confirms counts by tier
```

### 5.4 Recipe Import
```
User taps "Import recipe" in Recipe Book (Pro gate)
  -> RecipeImportScreen: two tabs (Photo / Manual)
  Photo path:
    -> ImagePicker (camera or gallery), compressed to 1600px / 85%
    -> GeminiService.importRecipeFromImage() — Flash-Lite Vision
    -> Parsed into GeneratedRecipe
  Manual path:
    -> Title, description, dynamic ingredient rows, instruction text
    -> Parsed into GeneratedRecipe
  -> RecipeScreen(recipe: recipe, autoSave: true)
  -> RecipeScreen saves to history on init, bookmark toggle works normally
```

### 5.5 Hands-Free Voice Cooking
```
User taps "Start Hands-Free Mode"
  -> Immersive sticky UI mode
  -> User taps mic button
  -> _initVoiceControl(): speech_to_text.initialize() (prompts RECORD_AUDIO permission)
  -> Platform channel (com.elio/audio) muteBeep — mutes NOTIFICATION + MUSIC + SYSTEM streams
  -> Voice help dialog shown (showDialog, not bottom sheet)
  -> User taps "Got It"
  -> _startListening() begins continuous recognition
  -> TTS reads current step aloud
  -> "Hey Elio, [command]" detected -> action
  -> "Hey Elio, done" -> voice off, stays in hands-free
  -> Exit button -> restoreBeep, TTS stop, back to normal mode
```

---

## 6. Performance Optimisations (Sprint 15.3)

### 6.1 Cold Start
- `Firebase.initializeApp()` → then `Future.wait([Analytics.init(), RemoteConfig.init()])` in parallel
- `PurchaseService`: lazy init via `_ensureInitialised()` — not called at startup
- `NotificationService`: `init()` registers handlers only; `requestPermissionAndRegister()` deferred until user grants permission

### 6.2 Network
- `GeminiService._httpClient`: static, shared across all recipe generation calls — avoids TCP/TLS handshake per request
- `ScannerService`: receipt tier lookups batched with `Future.wait()` — previously N sequential Firestore reads

### 6.3 In-Memory Caches
- `FirestoreService._cachedTasteProfile`: taste profile fetched once per session, invalidated on `rateRecipe()`
- `HistoryService._cache`: history list cached after first load, invalidated on any mutation (save, delete, toggle, clear)

---

## 7. Error Reporting

### 7.1 Wiring
`main.dart` routes uncaught errors to Crashlytics:
```dart
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

### 7.2 Non-fatal logging
`ErrorService` (lib/services/error_service.dart):
```dart
static void log(String feature, dynamic error, [StackTrace? stack])
```
- Wraps `FirebaseCrashlytics.instance.recordError()` as non-fatal
- Sets `feature` custom key for filtering in the console (e.g. `recipe_generation`, `receipt_scan`, `bulk_prep`)
- **Current coverage:** only ~4 call sites (home, recipe, recipe import, scanner service). **Sprint 16 task:** expand to GeminiService, FirestoreService, VoiceControlService, PurchaseService — these currently swallow errors silently in their outer try/catch blocks.

### 7.3 Reading Crashlytics
1. Open https://console.firebase.google.com
2. Select the **Elio** project
3. Left rail: **Release & Monitor → Crashlytics**
4. Dashboards: Crash-free users, crash-free sessions, top issues, device/OS breakdowns
5. **Non-fatal issues** tab shows everything logged via `ErrorService.log()` — filter by the `feature` custom key to find feature-specific problems
6. Each issue opens a stack trace, breadcrumb timeline, and affected device list
7. First reports can take 5–15 minutes to appear after a crash; subsequent reports are near real-time

### 7.4 Pre-launch improvements (Sprint 16)
- **Slack/Discord webhook** via a Cloud Function that fires on new Crashlytics issues — so regressions surface without having to check the console
- **Expanded coverage** as above
- **Breadcrumb logging** — `Crashlytics.log("...")` before high-risk operations (Gemini calls, receipt OCR, purchase flow) so crash reports include the last few actions

---

## 8. Voice Control — Platform Channel

`MainActivity.kt` exposes `com.elio/audio` method channel:

| Method | Action |
|--------|--------|
| `muteBeep` | Saves and mutes NOTIFICATION, MUSIC, SYSTEM audio streams |
| `restoreBeep` | Restores all three streams to saved volumes |

Called from `RecipeScreen`:
- `muteBeep` on voice control activation (stays muted for entire session)
- `restoreBeep` on: mic toggle off, "Hey Elio done", exit hands-free, screen dispose

**iOS parity (Sprint 18):** `com.elio/audio` is Android-only. For iOS we either (a) implement the equivalent via `AVAudioSession` in `AppDelegate.swift`, or (b) gate the platform-channel calls so they no-op on iOS and rely on iOS's quieter built-in recognition beep. Decide during iOS QA.

## 9. Monetisation & Paywall

### 9.1 RevenueCat integration
- **SDK:** `purchases_flutter` 8.x
- **Entitlement:** `"pro"` — attached to both `elio_pro_monthly` and `elio_pro_annual` products
- **Init:** Lazy (`_ensureInitialised()` on every public method). If `REVENUECAT_API_KEY` is empty, runs in "dry mode" — purchase methods return false without crashing.
- **Trial eligibility:** Determined by RevenueCat server-side via `StoreProduct.introductoryPrice`. The app does **not** track trial state locally — RC is the source of truth.
- **Sync:** `addCustomerInfoUpdateListener()` writes `subscription.tier` + `lastSyncedAt` to the user's Firestore doc, then refreshes `EntitlementService`.

### 9.2 Trial helpers (PurchaseService)
| Method | Returns |
|--------|---------|
| `hasFreeTrial(Package)` | `true` if `introductoryPrice.periodNumberOfUnits > 0` |
| `trialDurationLabel(Package)` | e.g. `"7-day"`, `"1-month"` — weeks normalised to days |
| `isAnyTrialAvailable` | Sync getter over cached `_lastFetchedPackages` |

### 9.3 Paywall display logic
`_showTrialState` in `paywall_screen.dart`:
1. Packages loaded AND at least one has `hasFreeTrial == true` → **trial state**.
2. Packages empty (dry mode / still loading) → **trial state** (optimistic). RevenueCat remains authoritative at purchase time.
3. Packages loaded AND none have a trial → **upgrade state** ("Upgrade to Pro").

Context-specific headlines are keyed off `triggerContext`:
| Context | Headline |
|---------|----------|
| `weekly_limit` | Unlock unlimited recipes |
| `meal_planner` | Plan your whole week |
| `shopping_list` | Shop smarter with one list |
| `household` | Cook for your whole household |
| `null` | Go Pro with Elio |

Legacy `PaywallTrigger` enum + `lockedFeatureName` are retained for existing callers and integration tests (which still compile but need copy updates for the new strings).

### 9.4 Pre-launch checklist
- [ ] Add `REVENUECAT_API_KEY` to `.env.local`
- [ ] Pass it through `build.ps1` as `--dart-define=REVENUECAT_API_KEY=<key>`
- [ ] Create `elio_pro_monthly` + `elio_pro_annual` in Play Console **with a 7-day free trial** attached to each
- [ ] Create matching products in App Store Connect **with a 7-day introductory offer**
- [ ] Create the `pro` entitlement in RevenueCat and attach all 4 SKUs
- [ ] Update `integration_test/paywall_test.dart` assertions for the new trial-first copy

---

## 10. Launch Architecture (Sprint 16–18)

Elio is being prepared for a **coordinated Android + iOS launch**. Android builds first and may ship to production a few days ahead of iOS, but iOS parity is part of the launch deliverable — not a follow-up release.

Three parallel tracks:

| Track | Scope |
|-------|-------|
| **Shared** (Sprint 16) | Firestore security rules, GDPR, privacy/ToS, RevenueCat wiring, ErrorService coverage, Crashlytics webhook |
| **Android** (Sprint 17) | Regression on physical device, Play Store assets, internal testing, closed beta, staged rollout |
| **iOS** (Sprint 18) | Xcode config, Apple Sign-In, iOS UI adjustments, iOS audio platform channel parity, **Siri Shortcuts**, permissions plist, regression, App Store assets, TestFlight, review |

### 10.1 Siri Shortcuts (iOS pre-launch)
- **Mechanism:** `NSUserActivity` donation from key screens, eligible for Siri suggestions and prediction
- **Shortcuts to ship on day one:**
  - "Generate a recipe" → opens the app on the Home tab with recipe generation primed
  - "Open my shopping list" → deep-links to the Shopping tab (Pro gate still enforced)
  - "What's in my pantry" → opens the Pantry tab
  - "Start cooking [last recipe]" → opens the most recent recipe directly in hands-free mode
- **Implementation notes:** Donate `NSUserActivity` from the relevant screen `initState`/`didChangeAppLifecycleState` hooks via a thin platform channel (`com.elio/siri`). Parse the activity identifier on cold start in `AppDelegate.swift` and route through Flutter's initial-route mechanism.
- **Why pre-launch:** Voice-first entry points are an iOS-native expectation, and they're the iOS analogue of Elio's hands-free voice control — launching without them leaves a visible gap on iOS vs Android.

---

## 11. Key Architectural Decisions

1. **Local-first history:** SharedPreferences for speed + offline. Firestore backup for signed-in users. In-memory cache invalidated on mutation.
2. **Save before navigate:** Recipe saved to history (with `savedAt`) before `Navigator.push(RecipeScreen)`. RecipeScreen receives `savedAt` — bookmark toggle uses it to update existing record rather than create duplicates.
3. **Mutable recipe state:** RecipeScreen uses `_currentRecipe` for in-place ingredient swaps without regeneration.
4. **Dual Gemini models:** Flash (SSE streaming) for heavy generation, Flash-Lite for lightweight calls (substitution, scanning, import, meal plans).
5. **Batch onboarding writes:** Single Firestore batch transaction for atomic onboarding completion.
6. **Category auto-tagging:** Items matched against canonical category lists on add; unmatched items go to "Other" in grouped view.
7. **Tier memory learning:** Scanner remembers user's categorisation choices in Firestore for future scans.
8. **Lazy service init:** PurchaseService and NotificationService not initialised at cold start — deferred to first use or explicit permission grant.
9. **showDialog not showModalBottomSheet** inside immersive/hands-free mode — bottom sheets fail silently in that context.
