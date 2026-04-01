# Elio Technical Design Document

**Version:** Sprint 15.2 | **Date:** 31 March 2026 | **Status:** Pre-launch

---

## 1. System Architecture

### 1.1 Stack
| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.27.x / Dart SDK >=3.4.0 |
| Auth | Firebase Auth (Google Sign-In v6, email/password, anonymous/guest) |
| Database | Cloud Firestore |
| AI | Google Gemini API (2.5-flash for recipes, 2.5-flash-lite for lightweight calls) |
| Monetisation | RevenueCat SDK (dry mode if no API key) |
| Push | Firebase Cloud Messaging (FCM) + topic subscriptions |
| Analytics | Firebase Analytics + Crashlytics |
| Config | Firebase Remote Config (Gemini API key with dart-define fallback) |
| Scanning | mobile_scanner (barcode), image_picker + Gemini Vision (receipt OCR) |
| Voice | speech_to_text + flutter_tts |
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

### 1.3 Project Structure
```
lib/
  main.dart                    # App entry, Firebase init, notification setup
  theme/elio_theme.dart        # Design tokens (ElioColors, ElioText)
  data/
    pantry_categories.dart     # Category definitions for Pantry Builder
  models/
    elio_models.dart           # InventoryItem, HouseholdProfile, KitchenPreset
    recipe_models.dart         # GeneratedRecipe, SavedRecipe, RecipeIngredient
    meal_plan_models.dart      # MealPlan, DayPlan, MealSlot, ShoppingItem
    onboarding_state.dart      # Accumulated onboarding choices
  services/
    auth_service.dart          # Firebase Auth wrapper
    firestore_service.dart     # All Firestore CRUD operations
    gemini_service.dart        # AI recipe generation + substitution
    scanner_service.dart       # Barcode (Open Food Facts) + receipt OCR
    history_service.dart       # Local recipe persistence (SharedPreferences)
    shopping_service.dart      # Persistent shopping list (Firestore)
    meal_plan_service.dart     # Weekly meal plan generation
    entitlement_service.dart   # Free vs Pro tier gating
    purchase_service.dart      # RevenueCat wrapper
    analytics_service.dart     # Firebase Analytics events + properties
    notification_service.dart  # FCM token lifecycle + topic subscriptions
    remote_config_service.dart # API key fetch with fallback
    guest_pantry_service.dart  # SharedPreferences for guest mode
  screens/
    home/home_screen.dart      # Central hub, recipe generation
    recipe/recipe_screen.dart  # Recipe display, voice control, substitution
    profile/profile_screen.dart # 4-tab profile (Pantry, Recipe Book, Style, Shopping)
    profile/settings_screen.dart
    profile/dietary_screen.dart
    profile/kitchen_screen.dart
    profile/household_screen.dart
    profile/notification_prefs_screen.dart
    scanner/scanner_screen.dart
    meal_plan/meal_plan_screen.dart
    history/history_screen.dart
    onboarding/                # 8 screens (0-7)
    auth/                      # Welcome, email login/register
    paywall/paywall_screen.dart
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

  /recipes/{docId}
    [GeneratedRecipe fields]

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

### 3.1 Recipe Generation (Gemini 2.5 Flash)
- **Max output:** 16,384 tokens | **Temperature:** 0.8
- **Response format:** JSON extracted from markdown fences with fallback brace extraction
- **Retry logic:** Up to 2 retries on parse failure
- **Prompt includes:** hard dietary constraints, soft preferences (style/mood/time), perishable inventory with expiry urgency, running low items, excluded ingredients, recent titles for dedup, liked/disliked recipes for taste learning, appliance list, budget mode flag, regional pricing

### 3.2 Ingredient Substitution (Gemini 2.5 Flash-Lite)
- **Max output:** 256 tokens | **Response MIME:** application/json
- **Filters thinking parts** from response
- Returns: substitute name, adjusted quantity, unit, trade-off description

### 3.3 Receipt OCR (Gemini 2.5 Flash-Lite + Vision)
- Image compressed to 1600px max width, 85% quality
- Extracts: item names, prices, store name
- Filters non-food items automatically
- 35% cost saving vs full Flash model

### 3.4 Meal Plan Generation (Gemini 2.5 Flash-Lite)
- Generates 7-day x 3-meal matrix
- Phase-1: titles + brief info; Phase-2: lazy-loads full steps/nutrition

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

- Weekly counter resets on schedule
- Dev email bypass: always Pro
- proOverride flag in Firestore for test accounts
- RevenueCat syncs purchases to Firestore subscription doc

---

## 5. Data Flow

### 5.1 Recipe Generation
```
User selects perishables + mood/style/time
  -> HomeScreen builds RecipeGenerationRequest
  -> EntitlementService.canGenerate() check
  -> GeminiService.generateRecipe(request)
  -> JSON parsed -> GeneratedRecipe
  -> Navigator.push(RecipeScreen) immediately
  -> Background: save to HistoryService (local) + FirestoreService (cloud)
  -> Increment weekly counter
```

### 5.2 Pantry Builder
```
User taps "Pantry Builder" button
  -> Opens PantryBuilderSheet (draggable bottom sheet)
  -> Tap item: adds to Always Have with auto-categorization
  -> Long-press: tier picker modal
  -> PantryCategories.categorize() resolves category
  -> FirestoreService.addInventoryItem(name, tier, category)
```

### 5.3 Scanner Pipeline
```
Barcode scan -> Open Food Facts API -> product name + brand
Receipt photo -> Gemini Vision -> item list + prices
  -> ScannerService.assignTier() (memory -> heuristic -> fallback)
  -> User confirms -> batch write to Firestore inventory
  -> TierMemory updated for future scans
```

---

## 6. Voice Control

- Wake word: "Hey Elio"
- Commands: next, back/previous, repeat/read, done/exit/stop
- TTS reads current step aloud
- Continuous listening with auto-restart on silence/error
- Toggle via microphone button in RecipeScreen

---

## 7. Key Architectural Decisions

1. **Local-first history:** SharedPreferences for speed + offline. Firestore backup for signed-in users.
2. **Non-blocking recipe display:** Navigator.push fires before Firestore saves complete.
3. **Mutable recipe state:** RecipeScreen uses `_currentRecipe` for in-place ingredient swaps without regeneration.
4. **Dual Gemini models:** Flash for heavy generation, Flash-Lite for lightweight calls (substitution, scanning, meal plans) at lower cost.
5. **Batch onboarding writes:** Single Firestore batch transaction for atomic onboarding completion.
6. **Category auto-tagging:** Items matched against canonical category lists on add; unmatched items go to "Other" in grouped view.
7. **Tier memory learning:** Scanner remembers user's categorization choices in Firestore for future scans.
