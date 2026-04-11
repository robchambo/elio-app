# Elio Roadmap

**Last updated:** 5 April 2026 (Sprint 15.3.19 — UX audit + free trial + paywall fix)

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

## Sprint 16 — Shared Launch Preparation

**Goal:** Everything that must be true before either store accepts a submission.

| # | Task | Est. Hours | Status |
|---|------|-----------|--------|
| 1 | Performance audit (DevTools profiling, list optimisation, cold start time) | 3–4 | ✅ Done |
| 2 | **Firestore security rules audit** — rules are currently permissive (dev mode); must be locked down before public launch. Firebase console already flagging this. Also: data retention policy, input sanitisation | 2–3 | Not started |
| 3 | GDPR compliance (data export, account deletion, consent tracking) | 2–3 | Not started |
| 4 | Privacy policy + Terms of Service (in-app screens + hosted URLs — shared across both stores) | 2–3 | Not started |
| 5 | Remove temporary debug messages from home_screen.dart | 0.5 | Not started |
| 6 | Crashlytics → Slack/Discord webhook (real-time error alerts via Cloud Function) | 1–2 | Not started |
| 7 | Wire `REVENUECAT_API_KEY` through build.ps1 / `.env.local` + configure live Play Store + App Store SKUs with 7-day free trial | 2–3 | Not started |
| 8 | Expand `ErrorService` coverage to GeminiService, FirestoreService, VoiceControlService, PurchaseService (currently only 4 call sites) | 1–2 | Not started |

**Estimate:** 13–21 hours

---

## Sprint 17 — Android Track

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

## Sprint 18 — iOS Track

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
| P3 | Offline mode | Cache recent recipes, local-first pantry for all users |

---

## Known Issues

- `google-services.json` not in git — must be added manually after fresh clone
- Dev flavor broken — always use `--flavor prod`
- iOS URL scheme placeholder needs filling before any iOS build
- APK size 71.3 MB (mobile_scanner ML Kit) — may need app bundles for Play Store
