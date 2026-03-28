# Elio Development Roadmap

**Last Updated:** 2026-03-27
**Current Status:** Sprint 7.3 (Stabilization)
**Design Doc Reference:** Recipe Generator App Design Document v2.1

---

## Feature Audit Summary

### Implemented (Sprints 1–7)
- [x] Onboarding flow (6 screens: welcome, dietary, kitchen preset, pantry review, household, style)
- [x] Google Sign-In + Guest Mode
- [x] Two-tier pantry (Always Have, Almost Always Have) + session perishables
- [x] Running Low flag per item
- [x] AI recipe generation (Gemini 2.5 Flash) with mood chips (time, style, mood)
- [x] Servings scaling
- [x] Substitution suggestions
- [x] Leftover mode
- [x] Recipe deduplication (last 20 titles)
- [x] Weekly meal planner (7 days, 3 meals/day)
- [x] Meal plan persistence (Firestore)
- [x] Shopping list (auto-generated from meal plan, excludes pantry items)
- [x] Hands-free cooking mode (basic — step highlighting, no voice)
- [x] Recipe rating (thumbs up/down) + adaptive taste profile
- [x] Household/family profiles with dietary constraint union
- [x] Crashlytics integration
- [x] Subscription UI (free tier: 3/day cap, Pro placeholder)
- [x] Cost estimation per recipe (USD/GBP)

### Not Yet Implemented
- [ ] Firebase Analytics (event tracking, screen views)
- [ ] Custom style input on Generate page (only via onboarding)
- [x] Menu plan UX: empty day tiles — fixed 2026-03-27 (shows "not included" message)
- [x] Post-generation editing: fill empty meal slots — already functional (↺ button on empty slots)
- [x] Pantry deduplication logic — partial: onboarding guard added 2026-03-27, needs fuzzy matching
- [x] Shopping list ← Running Low integration — done 2026-03-27 (restock items injected)
- [ ] Apple Sign-In (required for App Store)
- [ ] Email/password auth
- [ ] Expiry date tracking + alerts
- [ ] Barcode/receipt scanning
- [ ] Push notifications (FCM)
- [ ] Budget mode (dedicated constraint)
- [ ] In-app purchases (actual payment flow)
- [ ] Voice control for hands-free cooking
- [ ] Three-tier persistent inventory (perishables as stored tier)
- [x] API key moved to secure location — done 2026-03-27 (.env.local + run.ps1)

---

## Sprint 7.3 — Stabilization (Current)

**Goal:** Fix all known bugs and technical debt before adding features. No new functionality.

| # | Task | Status |
|---|------|--------|
| 7.3.1 | Fix Google Sign-In (SHA-1 fingerprint registered) | ✅ Done |
| 7.3.2 | Fix guest pantry persistence (SharedPreferences) | ✅ Done |
| 7.3.3 | Migrate Gemini 2.0 Flash → 2.5 Flash | ✅ Done |
| 7.3.4 | Bump recipe deduplication list to 20 | ✅ Done |
| 7.3.5 | Set up GitHub Actions CI (flutter analyze) | ✅ Done |
| 7.3.6 | Branch protection on main (PRs required) | ✅ Done |
| 7.3.7 | Fix .gitignore gaps (.claude/, *.hprof) | ✅ Done |
| 7.3.8 | Add CONTRIBUTING.md (branching conventions) | ✅ Done |
| 7.3.9 | Move Gemini API key out of source code | ✅ Done (`.env.local` + `run.ps1`) |
| 7.3.10 | Fix remaining lint warnings (unused import, unnecessary cast) | ✅ Done |
| 7.3.11 | Fix widget_test.dart (references non-existent MyApp) | ✅ Done |

**Exit criteria:** Clean CI on main, no hardcoded secrets, all known bugs resolved.

---

## Sprint 8 — Analytics & Core Polish

**Goal:** Add analytics from day one so we have data, and polish the core UX gaps users will hit most.

### 8.1 — Firebase Analytics: Service & Setup (2 hours)
Create `AnalyticsService` class, add `firebase_analytics` to pubspec, initialise in `main.dart`, add `FirebaseAnalyticsObserver` to `MaterialApp` for automatic screen tracking. Set user properties: `subscription_tier`, `dietary_profile`, `household_size`, `days_since_install`.

### 8.2 — Firebase Analytics: Onboarding Events (1 hour)
Instrument the onboarding flow with events:

| Event | Trigger |
|-------|---------|
| `onboarding_started` | Welcome screen shown |
| `onboarding_step_completed` | Each screen completed (param: step name) |
| `onboarding_completed` | Final screen passed |
| `onboarding_abandoned` | App closed mid-onboarding (param: last step) |
| `sign_in_method` | Auth method chosen (google / guest) |

### 8.3 — Firebase Analytics: Core Feature Events (1–2 hours)
Instrument recipe generation, meal planning, and pantry:

| Event | Trigger |
|-------|---------|
| `recipe_generated` | Successful generation (params: cuisine, time, mood) |
| `recipe_generation_failed` | Gemini call failed (param: error type) |
| `recipe_saved` | User bookmarks a recipe |
| `recipe_rated` | Thumbs up/down (param: direction) |
| `meal_plan_generated` | Full weekly plan created |
| `meal_plan_day_generated` | Single day generated |
| `shopping_list_viewed` | Shopping list opened |
| `shopping_list_shared` | List shared |
| `pantry_item_added` | Item added (param: tier) |
| `pantry_item_running_low` | Item flagged running low |

### 8.4 — Firebase Analytics: Engagement & Monetisation Events (1 hour)
Instrument cooking mode and upgrade flow:

| Event | Trigger |
|-------|---------|
| `cooking_mode_started` | User enters hands-free mode |
| `cooking_mode_completed` | User reaches last step |
| `upgrade_prompt_shown` | Free tier limit hit |
| `upgrade_prompt_dismissed` | User dismisses upgrade dialog |

### 8.5 — Custom Style Input on Generate Page (2–3 hours)
- Add a "Custom..." chip at the end of the Style row on the home screen
- Tapping opens a small text input (bottom sheet or inline expansion)
- User types free-form preference (e.g., "something with peanut butter", "Korean street food")
- Value passed to Gemini as an additional style constraint for that generation only
- Persist as "recent custom styles" list (SharedPreferences, max 10) for quick re-use

### 8.6 — Menu Plan: Empty Day Tiles ✅ Done (2026-03-27)
- Days not included in the plan now show a friendly message instead of crashing
- Back arrow clears plan and returns to config screen for reconfiguration

### 8.7 — Menu Plan: Fill Empty Meal Slots ✅ Already Functional
- Empty meal slots show "Tap ↺ to generate" with a regenerate button
- Tapping generates just that one meal using the day's context

### 8.8 — Pantry Deduplication (2–3 hours) — Partially Done
- ✅ Onboarding guard: checks for existing inventory before writing (prevents duplicate batches)
- 🔲 Add normalisation logic: lowercase, trim whitespace, strip plurals (eggs → egg), handle common variants (e.g., "olive oil" vs "extra virgin olive oil")
- 🔲 Prevent duplicates on add: fuzzy match warning ("You already have 'Eggs' — add anyway?")
- 🔲 One-time cleanup migration for existing users on first load after update

**Sprint 8 total estimate:** ~12–16 hours

---

## Sprint 9 — Shopping, Inventory & Auth

**Goal:** Make the inventory system smarter, the shopping list genuinely useful, and add email/password auth.

### 9.1 — Email/Password Authentication (2–3 hours)
- Add registration screen: email, password, confirm password
- Add login screen: email, password, "Forgot password?" link
- Password reset via Firebase Auth email
- Email verification flow (send on register, check on login)
- Add email/password option to onboarding welcome screen alongside Google Sign-In and Guest Mode
- Handle edge cases: weak password, email already in use, unverified email

### 9.2 — Running Low → Shopping List Integration ✅ Done (2026-03-27, pulled forward)
- Running low items automatically included in shopping list with "Restock" label
- 🔲 Remaining: group as separate "Restock" section at top, prompt to remove flag after check-off

### 9.3 — Expiry Date Tracking (3–4 hours)
- Add optional `expiryDate` field to inventory items (perishables and Almost Always Have)
- Date picker on item add/edit
- Sort perishables by expiry (soonest first) in profile pantry view
- Visual indicators: green (>3 days), amber (1–3 days), red (today/expired)
- "Use it up" button on expiring items → triggers recipe generation prioritising that ingredient

### 9.4 — Three-Tier Persistent Inventory (2–3 hours)
- Promote "perishables" from session-only to a stored Firestore tier
- Users can add perishables that persist across sessions (not just the "what's new today" flow)
- Session perishables still work as before for quick one-off adds
- Perishables tier shows on profile screen alongside Always Have and Almost Always Have
- Expiry dates (from 9.3) attach naturally to this tier

### 9.5 — Push Notifications via FCM (4–5 hours)
- Set up Firebase Cloud Messaging for Android
- Notification types:
  - "Your [item] expires tomorrow — want a quick recipe?" (daily check)
  - "Your weekly meal plan is ready to generate" (weekly prompt, Monday morning)
  - "You haven't cooked in a while — what's in your fridge?" (re-engagement, 7-day inactive)
- User can toggle notification categories in a new Settings screen
- Requires Cloud Function for scheduled expiry checks
- iOS FCM setup deferred to Sprint 11 (needs APNs certificate)

**Sprint 9 total estimate:** ~14–18 hours

---

## Sprint 10 — Advanced Features

**Goal:** Differentiation features that make Elio stand out from competitors.

### 10.1 — Budget Mode (3–4 hours)
- New mood chip: "Budget friendly" on the generate screen
- Modifies Gemini prompt: "Maximise use of existing inventory, suggest only the cheapest supplementary ingredients, prefer store-cupboard recipes"
- Prioritises recipes with fewest additional purchases
- Shopping list shows estimated cost per item when generated from a budget meal plan

### 10.2 — Barcode Scanning (4–5 hours)
- Add `mobile_scanner` package
- Camera permission handling (Android manifest + runtime request)
- Scan → lookup via Open Food Facts API (free, no API key needed)
- Auto-populate item name from barcode, suggest tier placement based on category
- "Scan as you unpack" flow: continuous scanning mode with item confirmation after each scan

### 10.3 — Voice Control for Cooking Mode (4–5 hours)
- Add `speech_to_text` package
- Supported commands: "next step", "previous step", "repeat", "start timer [X minutes]"
- Visual feedback when listening (microphone icon pulse)
- Works alongside existing tap navigation
- Timer integration: countdown overlay with alarm sound
- Microphone permission handling

### 10.4 — Receipt Scanning (5–6 hours)
- Camera capture of shopping receipt
- OCR via Gemini Vision (already have API access) — send receipt image, get structured item list
- Present parsed items for user confirmation before adding to pantry
- Handle common OCR issues: abbreviations, store-specific names, multi-item lines
- Batch add confirmed items to appropriate inventory tier

**Sprint 10 total estimate:** ~16–20 hours

---

## Sprint 11 — Auth Completion & Payments

**Goal:** App Store compliance and actual revenue capability.

### 11.1 — Apple Sign-In (3–4 hours)
- Required by App Store when offering any other sign-in method
- Add `sign_in_with_apple` package
- Configure in Apple Developer portal (App ID, Service ID, key)
- Add "Sign in with Apple" button to login screen and onboarding welcome
- Handle credential revocation
- Test on physical iOS device or simulator

### 11.2 — iOS Push Notifications (2–3 hours)
- Generate APNs key in Apple Developer portal
- Upload to Firebase Console → Cloud Messaging
- Add iOS notification permissions request
- Verify all notification types from Sprint 9.5 work on iOS

### 11.3 — In-App Purchases (6–8 hours)
- Integrate `purchases_flutter` (RevenueCat) — handles both stores, receipt validation, analytics
- Configure products in App Store Connect and Google Play Console:
  - `elio_pro_monthly` — £3.99/month with 7-day free trial
  - `elio_pro_annual` — £29.99/year with 7-day free trial
- Paywall screen design (comparison table from design doc Section 9.2)
- Restore purchases button
- Subscription status synced to Firestore `users/{uid}.subscription`
- Enforce generation limits based on actual subscription status (replace local counter)
- Handle edge cases: expired subscription, cancelled mid-trial, family sharing

**Sprint 11 total estimate:** ~12–16 hours

---

## Sprint 12 — Launch Preparation

**Goal:** Production-ready for both app stores.

### 12.1 — Performance Audit (3–4 hours)
- Profile with Flutter DevTools (CPU, memory, rendering)
- Optimise large lists (ensure all use `ListView.builder`)
- Add `RepaintBoundary` to expensive widgets (recipe cards, meal plan tiles)
- Image caching and compression via `cached_network_image`
- Cold start time optimisation (defer non-critical init)
- Memory leak check on long sessions (particularly meal plan generation)

### 12.2 — Security Hardening (2–3 hours)
- Verify all Firestore security rules are production-ready (test with Rules Playground)
- Final audit for any remaining hardcoded values
- Confirm API key is in secure storage / server-side proxy
- Review data retention and deletion flows (GDPR compliance)
- Add privacy policy and terms of service screens (in-app)

### 12.3 — App Store Assets & Submission (4–5 hours)
- Generate screenshots for all required device sizes (phone + tablet)
- Feature graphic (1024x500 for Play Store)
- App icon final check (512x512)
- Write store listing copy (title, short description, full description, keywords)
- Privacy policy URL hosted
- Age rating questionnaire (both stores)
- Android: Generate signed AAB, submit to Play Console internal testing track
- iOS: Generate signed IPA, submit to TestFlight

### 12.4 — Final Testing (4–5 hours)
- Full regression test on physical Android device
- Full regression test on physical iOS device
- Edge cases: no internet, slow connection, empty pantry, max inventory items
- Guest mode full flow (onboarding → generation → pantry persistence)
- Subscription flow end-to-end (sandbox purchases)
- Onboarding flow end-to-end (fresh install)
- Push notification delivery on both platforms
- Barcode and receipt scanning on real receipts/products

**Sprint 12 total estimate:** ~14–18 hours

---

## Timeline Summary

| Sprint | Focus | Sub-tasks | Estimate |
|--------|-------|-----------|----------|
| **7.3** | Stabilization (current) | 7.3.1–7.3.11 | ~2 hrs remaining |
| **8** | Analytics & Core Polish | 8.1–8.8 | ~12–16 hrs |
| **9** | Shopping, Inventory & Auth | 9.1–9.5 | ~14–18 hrs |
| **10** | Advanced Features | 10.1–10.4 | ~16–20 hrs |
| **11** | Auth Completion & Payments | 11.1–11.3 | ~12–16 hrs |
| **12** | Launch Preparation | 12.1–12.4 | ~14–18 hrs |
| | **Total remaining** | | **~70–90 hrs** |

---

## Priority Notes

- **Sprint 8 is non-negotiable before anything else** — analytics must be in place before user testing, and the UX gaps (menu tiles, custom style) are the most visible friction points.
- **Sprint 9 email/password auth** comes before iOS-specific work because it's platform-agnostic and useful for testing without a Google account.
- **Sprint 11 (Apple Sign-In + payments) blocks App Store submission** — can be pulled earlier if iOS launch becomes urgent.
- **Sprint 10 features are differentiators, not blockers** — the app is launchable after Sprint 9 on Android. These can ship as post-launch updates if needed.
- **Gemini model deprecation (1 June 2026)** — already resolved (migrated to 2.5 Flash in Sprint 7.3).
