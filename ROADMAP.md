# Elio Development Roadmap

**Last Updated:** 2026-03-29
**Current Status:** Sprint 10 complete. Next: Sprint 11.
**Design Doc Reference:** Recipe Generator App Design Document v2.1

---

## Completed Sprints

### Sprints 1-7 -- Foundation & Core Features

- [x] Onboarding flow (6 screens: welcome, dietary, kitchen preset, pantry review, household, style, appliances)
- [x] Google Sign-In + Guest Mode
- [x] Two-tier pantry (Always Have, Almost Always Have) + session perishables
- [x] Running Low flag per item
- [x] AI recipe generation (Gemini 2.5 Flash) with mood chips (time, style, mood)
- [x] Servings scaling
- [x] Substitution suggestions
- [x] Leftover mode
- [x] Recipe deduplication (last 20 titles)
- [x] Weekly meal planner (configurable days/meals, 3 meal types)
- [x] Meal plan persistence (Firestore)
- [x] Shopping list (auto-generated from meal plan, excludes pantry items)
- [x] Hands-free cooking mode (step highlighting, no voice)
- [x] Recipe rating (thumbs up/down) + adaptive taste profile
- [x] Household/family profiles with dietary constraint union
- [x] Crashlytics integration
- [x] Cost estimation per recipe (USD/GBP)
- [x] Pantry fuzzy deduplication with normalisation
- [x] Gemini 2.0 Flash -> 2.5 Flash migration
- [x] API key moved to .env.local + build scripts
- [x] GitHub Actions CI (flutter analyze)
- [x] Branch protection on main

### Sprint 8 -- Analytics & Core Polish (Complete)

| # | Task | Status |
|---|------|--------|
| 8.1 | Firebase Analytics: service, screen tracking, user properties | Done |
| 8.2 | Onboarding analytics events | Done |
| 8.3 | Core feature events (recipe, meal plan, pantry, shopping list) | Done |
| 8.4 | Engagement & monetisation events (cooking mode, upgrade funnel) | Done |
| 8.5 | Custom style input on Generate page (session-only, max 10) | Done |
| 8.6 | Menu plan empty day tiles | Done |
| 8.7 | Menu plan fill empty meal slots | Done |
| 8.8 | Pantry deduplication (normalisation + onboarding guard) | Done |

### Sprint 9 -- Paywall, Entitlements & Feature Gating (Complete)

| # | Task | Status |
|---|------|--------|
| 9.1 | EntitlementService: weekly caps, tier checks, feature gates | Done |
| 9.2 | PaywallScreen: 3 triggers (onboarding, capReached, lockedFeature) | Done |
| 9.3 | Feature gating: meal planner, shopping list, household, history | Done |
| 9.4 | Pro override for dev accounts (email allowlist + Firestore flag) | Done |
| 9.5 | Ingredient substitution popup on exclude | Done |
| 9.6 | Kitchen appliances onboarding + profile screen | Done |
| 9.7 | Cost estimation disclaimer popup | Done |
| 9.8 | Smoothies style option, High-protein dietary option | Done |
| 9.9 | Gemini API fix: remove responseMimeType, handle thinking parts, 16K tokens | Done |
| 9.10 | History screen: free tier 20-item cap with upgrade banner | Done |

### Sprint 10 -- QA, Tests & Bug Fixes (Complete)

| # | Task | Status |
|---|------|--------|
| 10.1 | Fix dietary persistence bug (null _ownerProfileId reverts UI + snackbar) | Done |
| 10.2 | Unit tests: entitlement logic (21 tests) | Done |
| 10.3 | Integration tests: KitchenAppliancesScreen (10 tests) | Done |
| 10.4 | Integration tests: PaywallScreen (9 tests) | Done |
| 10.5 | Custom styles: session-only, no persistence across restarts | Done |
| 10.6 | build.ps1: ASCII-safe rewrite (PowerShell compatibility) | Done |
| 10.7 | Android NDK updated to 28.2.13676358 | Done |

---

## Upcoming Sprints

### Sprint 11 -- Billing Integration & Pre-Launch Polish

**Goal:** Wire up actual payments so the paywall converts, and polish the remaining rough edges.

| # | Task | Estimate | Priority |
|---|------|----------|----------|
| 11.1 | RevenueCat integration (purchases_flutter) | 4-5 hrs | Critical |
| 11.2 | Configure products: elio_pro_monthly + elio_pro_annual in Play Console | 1-2 hrs | Critical |
| 11.3 | Wire PaywallScreen subscribe button to RevenueCat | 1-2 hrs | Critical |
| 11.4 | Subscription status synced to Firestore + EntitlementService | 2-3 hrs | Critical |
| 11.5 | Restore purchases button | 1 hr | Critical |
| 11.6 | Move Gemini API key to Firebase Remote Config | 2-3 hrs | Critical |
| 11.7 | Pantry deduplication: fuzzy match warning on add ("You already have...") | 2 hrs | Medium |
| 11.8 | Running Low -> Shopping List: separate "Restock" section | 1 hr | Medium |

**Exit criteria:** User can subscribe via Play Store, entitlements reflect real subscription status, API key is not baked into APK.

**Estimate:** ~14-19 hours

---

### Sprint 12 -- Persistent Shopping List & UX Polish

**Goal:** Make the shopping list a living document that persists across the week, combining manual adds, meal plan ingredients, and restock items.

| # | Task | Estimate | Priority |
|---|------|----------|----------|
| 12.1 | Firestore `shoppingItems` collection schema + ShoppingService CRUD | 1-2 hrs | High |
| 12.2 | Profile "Shopping" tab with persistent list (restock / meal plan / manual sections) | 2-3 hrs | High |
| 12.3 | Manual item add (text input at top of shopping tab) | 0.5 hr | High |
| 12.4 | Auto-populate from meal plan on generation (smart merge, no duplicates) | 1-2 hrs | High |
| 12.5 | Auto-add Running Low items to shopping list (sync on flag toggle) | 1 hr | High |
| 12.6 | Meal plan "Shopping List" button navigates to persistent list | 0.5 hr | Medium |
| 12.7 | Home screen heading/spacing cleanup (if more space still needed) | 0.5 hr | Low |

**Exit criteria:** User can add items to shopping list at any time, meal plan generation auto-merges ingredients, Running Low items auto-appear in Restock section, list persists across sessions.

**Estimate:** ~6-9 hours

---

### Sprint 13 -- Auth Expansion & Notifications

**Goal:** Broaden sign-in options and add re-engagement via push notifications.

| # | Task | Estimate | Priority |
|---|------|----------|----------|
| 13.1 | Email/password authentication (register, login, forgot password) | 3-4 hrs | High |
| 13.2 | Apple Sign-In (required for App Store) | 3-4 hrs | High (iOS) |
| 13.3 | Push notifications via FCM (expiry alerts, weekly prompt, re-engagement) | 4-5 hrs | Medium |
| 13.4 | Notification preferences screen | 1-2 hrs | Medium |
| 13.5 | iOS FCM setup (APNs certificate) | 2-3 hrs | Medium (iOS) |

**Estimate:** ~13-18 hours

---

### Sprint 14 -- Advanced Features

**Goal:** Differentiation features that make Elio stand out from competitors.

| # | Task | Estimate | Priority |
|---|------|----------|----------|
| 14.1 | Budget mode (mood chip + prompt tuning + cost-optimised recipes) | 3-4 hrs | Medium |
| 14.2 | Expiry date tracking with colour-coded indicators + "use it up" generation | 3-4 hrs | Medium |
| 14.3 | Three-tier persistent inventory (perishables as stored tier) | 2-3 hrs | Medium |
| 14.4 | Barcode scanning (mobile_scanner + Open Food Facts API) | 4-5 hrs | Low |
| 14.5 | Receipt scanning (Gemini Vision OCR -> batch pantry add) | 5-6 hrs | Low |
| 14.6 | Voice control for cooking mode (speech_to_text) | 4-5 hrs | Low |

**Estimate:** ~21-27 hours

---

### Sprint 15 -- Launch Preparation

**Goal:** Production-ready for both app stores.

| # | Task | Estimate | Priority |
|---|------|----------|----------|
| 15.1 | Performance audit (DevTools profiling, list optimisation, cold start) | 3-4 hrs | High |
| 15.2 | Security hardening (Firestore rules, data retention, GDPR) | 2-3 hrs | High |
| 15.3 | Privacy policy + terms of service (in-app screens + hosted URLs) | 2-3 hrs | High |
| 15.4 | App Store assets (screenshots, feature graphic, store listing copy) | 4-5 hrs | High |
| 15.5 | Full regression test: Android (physical device) | 2-3 hrs | High |
| 15.6 | Full regression test: iOS (physical device) | 2-3 hrs | High |
| 15.7 | Submit to Play Console internal testing track | 1-2 hrs | High |
| 15.8 | Submit to TestFlight | 1-2 hrs | High |

**Estimate:** ~17-24 hours

---

## Timeline Summary

| Sprint | Focus | Status | Estimate |
|--------|-------|--------|----------|
| **1-7** | Foundation & Core Features | Done | -- |
| **8** | Analytics & Core Polish | Done | -- |
| **9** | Paywall, Entitlements & Feature Gating | Done | -- |
| **10** | QA, Tests & Bug Fixes | Done | -- |
| **11** | Billing Integration & Pre-Launch Polish | **Done** | -- |
| **12** | Persistent Shopping List & UX Polish | **Next** | ~6-9 hrs |
| **13** | Auth Expansion & Notifications | Planned | ~13-18 hrs |
| **14** | Advanced Features | Planned | ~21-27 hrs |
| **15** | Launch Preparation | Planned | ~17-24 hrs |
| | **Total remaining** | | **~57-78 hrs** |

---

## Minimum Viable Launch (Android)

The app is launchable on Android after **Sprint 12** (shopping list) + **Sprint 15** (launch prep). That's ~23-33 hours of work.

Sprints 13 and 14 can ship as post-launch updates:
- Email/password auth and notifications (Sprint 13) improve retention
- Advanced features (Sprint 14) are differentiators, not blockers
- Apple Sign-In (13.2) blocks iOS App Store submission specifically

---

## Known Issues

| Issue | Severity | Notes |
|-------|----------|-------|
| `google-services.json` not in git | Low | Must be added manually after fresh clone |
| Dev flavor broken | Low | No Firebase client for `com.elio.elio_app.dev`; always use `--flavor prod` |
| iOS not built/tested | Medium | URL scheme placeholder needs filling before any iOS build |
| Pantry fuzzy match on add | Resolved | Duplicate warning with Levenshtein matching implemented |

---

## Test Coverage

| Suite | Tests | Location |
|-------|-------|----------|
| App smoke test | 3 | `integration_test/app_smoke_test.dart` |
| Onboarding flow | 5+ | `integration_test/onboarding_flow_test.dart` |
| Home screen | 5+ | `integration_test/home_screen_test.dart` |
| Navigation | 5+ | `integration_test/navigation_test.dart` |
| Paywall screen | 9 | `integration_test/paywall_test.dart` |
| Kitchen appliances | 10 | `integration_test/appliances_test.dart` |
| Entitlement logic | 21 | `test/entitlement_logic_test.dart` |
| **Total** | **~58+** | |

---

## Build Commands

```bash
# Dev run
flutter run --flavor prod -t lib/main.dart --dart-define=GEMINI_API_KEY=<key>

# Release APK (uses build.ps1)
powershell -ExecutionPolicy Bypass -File build.ps1 -sprint <number>

# Run unit tests
flutter test test/

# Run integration tests on device
flutter test integration_test/<test>.dart --flavor prod -d <device-id>
```
