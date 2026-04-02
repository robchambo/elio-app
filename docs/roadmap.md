# Elio Roadmap

**Last updated:** 1 April 2026 (Sprint 15.3.9 — Sprint 15.3 complete, moving to Sprint 16)

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

## Current: Sprint 15.3 — Recipe Import & UX Polish

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

---

## Next: Sprint 16 — Launch Preparation

**Goal:** Get the app ready for public release on Google Play.

| # | Task | Est. Hours | Status |
|---|------|-----------|--------|
| 1 | Performance audit (DevTools profiling, list optimisation, cold start time) | 3–4 | Not started |
| 2 | **Firestore security rules audit** — rules are currently permissive (dev mode); must be locked down before public launch. Firebase console already flagging this. Also: data retention policy, input sanitisation | 2–3 | Not started |
| 3 | GDPR compliance (data export, account deletion, consent tracking) | 2–3 | Not started |
| 4 | Privacy policy + Terms of Service (in-app screens + hosted URLs) | 2–3 | Not started |
| 5 | Remove temporary debug messages from home_screen.dart | 0.5 | Not started |
| 6 | Full regression test — Android physical device | 3–4 | Not started |
| 7 | App Store assets (screenshots, feature graphic, store listing copy) | 2–3 | Not started |
| 8 | Submit to Google Play Console (internal testing track) | 1–2 | Not started |
| 9 | Crashlytics → Slack/Discord webhook (real-time error alerts via Cloud Function) | 1–2 | Not started |

**Estimate:** 17–24 hours

---

## Sprint 17 — iOS & App Store Launch

| # | Task | Est. Hours |
|---|------|-----------|
| 1 | iOS build configuration and signing | 2–3 |
| 2 | Apple Sign-In integration | 3–4 |
| 3 | iOS-specific UI adjustments | 2–3 |
| 4 | Full regression test — iOS physical device | 3–4 |
| 5 | App Store assets (iOS screenshots, App Store listing) | 2–3 |
| 6 | Submit to TestFlight | 1–2 |
| 7 | App Store review submission | 1 |

**Estimate:** 14–20 hours

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
