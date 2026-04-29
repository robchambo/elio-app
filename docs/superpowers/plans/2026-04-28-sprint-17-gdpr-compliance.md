# Sprint 17 — GDPR / MHMDA / Store-Submission Compliance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land all the code, config, and console changes the published Privacy Policy + Terms + WA MHMDA Notice depend on, so we are submission-ready for the Apple App Store (US-priority, UK close behind) and Google Play.

**Architecture:** No new architectural moves — this is plumbing. We add a small set of services (consent banner, age attestation), surgically remove one Analytics user property, flip several manifest/Info.plist flags, and configure a few Firebase Console settings. Settings UI tiles for export/delete are scoped here but their visual styling waits on Kate's design pass.

**Tech Stack:** Flutter / Dart, Firebase Analytics + Crashlytics + Remote Config, AndroidManifest.xml, Info.plist, Firebase Console.

**Status as of plan creation:**
- `lib/services/account_service.dart` ✅ shipped (Sprint 17)
- `lib/services/data_export_service.dart` ✅ shipped (Sprint 17)
- `lib/services/legal_links.dart` ✅ shipped (Sprint 17, placeholder URLs)
- Legal docs drafted at `docs/legal/{privacy-policy.md, terms-of-service.md, wa-consumer-health-data-notice.md}`
- Settings UI: not yet built (waiting on Kate)
- Sign in with Apple: deferred to Sprint 19

**Critical path for store submission:**
1. Tasks 1, 2, 3, 4 → required for both Play and App Store
2. Task 5 (Settings UI) → can ship as v1.1 post-launch if rights-via-email is acceptable for v1
3. Task 6 (legal pages hosted) → required for both stores at submission
4. Task 7 (console flips) → required for the policy claims to be true
5. Tasks 8 + 9 → required before launch but trivially small

---

## File Structure

```
lib/services/consent_service.dart                # NEW — gates analytics, crashlytics, dietary
lib/services/age_gate_service.dart               # NEW — single attestation flag
lib/services/analytics_service.dart              # MODIFY — drop dietary_profile
lib/screens/onboarding/age_attestation_screen.dart  # NEW
lib/screens/onboarding/consent_banner_screen.dart   # NEW
lib/screens/legal/                                  # NEW — webview wrappers for hosted pages
lib/main.dart                                       # MODIFY — gate Firebase init on consent
android/app/src/main/AndroidManifest.xml         # MODIFY — disable AdID
ios/Runner/Info.plist                            # MODIFY — disable IDFV/IDFA collection
test/services/consent_service_test.dart          # NEW
test/services/age_gate_service_test.dart         # NEW
test/services/analytics_service_test.dart        # MODIFY — verify dietary_profile not set
```

---

## Task 1: Drop `dietary_profile` Analytics user property

**Files:**
- Modify: `lib/services/analytics_service.dart`
- Test: `test/services/analytics_service_test.dart`

**Why:** WA MHMDA-compliance critical-path. Dietary requirements are consumer health data; sending them as a Firebase Analytics user property is an undisclosed sub-processor disclosure plus a third undisclosed processing purpose. Easiest fix: stop sending them.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/analytics_service_test.dart
test('setUserProperties never sets dietary_profile', () async {
  final calls = <(String, String?)>[];
  AnalyticsService.debugSetUserPropertyOverride =
      (name, value) async => calls.add((name, value));
  await AnalyticsService.setUserProperties(
    authMethod: 'google',
    subscriptionTier: 'free',
    householdSize: 2,
    dietaryProfile: ['vegetarian', 'gluten-free'],
  );
  expect(
    calls.any((c) => c.$1 == 'dietary_profile'),
    isFalse,
    reason: 'Dietary profile is consumer health data and must not flow to Analytics.',
  );
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/analytics_service_test.dart`
Expected: FAIL — `dietary_profile` is currently set.

- [ ] **Step 3: Modify `AnalyticsService.setUserProperties`**

Remove the `dietaryProfile` parameter and the corresponding `setUserProperty` call. Update all callers (likely the home / onboarding flow setting user properties on first login). Leave the parameter in place but ignored if removing it causes call-site churn — preferred: remove cleanly.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/analytics_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify no remaining references**

Run: `rg "dietary_profile" lib/ test/` (via Grep tool).
Expected: zero hits.

- [ ] **Step 6: Commit**

```bash
git add lib/services/analytics_service.dart test/services/analytics_service_test.dart
git commit -m "fix(analytics): drop dietary_profile user property (MHMDA)"
```

---

## Task 2: Disable AdID / IDFV / IDFA collection

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

**Why:** Privacy policy §2.2 claims "we do not assign you an Android Advertising ID or Apple IDFA". Currently false because Firebase Analytics collects them by default.

- [ ] **Step 1: Add Android manifest flag**

In `<application>` of `AndroidManifest.xml`, add:

```xml
<meta-data
    android:name="google_analytics_adid_collection_enabled"
    android:value="false" />
<meta-data
    android:name="google_analytics_ssaid_collection_enabled"
    android:value="false" />
```

- [ ] **Step 2: Add iOS Info.plist flags**

In `ios/Runner/Info.plist`, add inside the top-level `<dict>`:

```xml
<key>GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED</key>
<false/>
<key>GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS</key>
<false/>
<key>GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA</key>
<false/>
```

- [ ] **Step 3: Verify with a debug Analytics DebugView session**

Run the app on a physical device with `adb shell setprop debug.firebase.analytics.app io.elio.elio` (Android) or via the Firebase Console DebugView. Confirm no `_aid` or `_idfv` user properties appear on events.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "config(analytics): disable AdID/IDFV/IDFA collection"
```

---

## Task 3: Age attestation screen

**Files:**
- Create: `lib/services/age_gate_service.dart`
- Create: `lib/screens/onboarding/age_attestation_screen.dart`
- Modify: `lib/main.dart` (or wherever onboarding routing lives)
- Test: `test/services/age_gate_service_test.dart`
- Test: `test/screens/onboarding/age_attestation_screen_test.dart`

**Why:** Privacy policy §9 promises a 16+ enforcement mechanism. FTC has explicitly held that "we say 16+" without enforcement is not a defence. Cheapest enforcement: single attestation tap stored in SharedPreferences.

- [ ] **Step 1: Write the failing service test**

```dart
// test/services/age_gate_service_test.dart
test('isConfirmed16Plus returns false until confirm() is called', () async {
  SharedPreferences.setMockInitialValues({});
  final gate = AgeGateService();
  expect(await gate.isConfirmed16Plus(), isFalse);
  await gate.confirm();
  expect(await gate.isConfirmed16Plus(), isTrue);
});

test('confirm() persists across instances', () async {
  SharedPreferences.setMockInitialValues({});
  await AgeGateService().confirm();
  expect(await AgeGateService().isConfirmed16Plus(), isTrue);
});
```

- [ ] **Step 2: Run, verify fail**

`flutter test test/services/age_gate_service_test.dart` → FAIL (class doesn't exist).

- [ ] **Step 3: Implement `AgeGateService`**

```dart
// lib/services/age_gate_service.dart
class AgeGateService {
  static const String _kKey = 'age_confirmed_16plus_v1';

  Future<bool> isConfirmed16Plus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kKey) ?? false;
  }

  Future<void> confirm() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, true);
  }
}
```

- [ ] **Step 4: Run, verify pass**

`flutter test test/services/age_gate_service_test.dart` → PASS.

- [ ] **Step 5: Build the attestation screen**

Single screen, two buttons: **"I confirm I am 16 or older"** (continue) and **"I am under 16"** (route to a "you cannot use Elio yet" terminal screen). On tap of confirm, call `AgeGateService().confirm()` and pop to the next onboarding step.

Copy: "Elio is for people aged 16 and over. Please confirm before continuing."

- [ ] **Step 6: Wire into onboarding routing**

The age screen must run **before** any data collection (no Firestore writes, no analytics events except the attestation event itself). Place it as the first onboarding step after the welcome screen. Until `isConfirmed16Plus()` returns true, the rest of onboarding must not be reachable.

- [ ] **Step 7: Widget test**

```dart
testWidgets('Tapping confirm records attestation and advances', (tester) async {
  // pump AgeAttestationScreen, tap "I confirm I am 16 or older",
  // expect callback fired and AgeGateService flag set.
});
```

- [ ] **Step 8: Commit**

```bash
git add lib/services/age_gate_service.dart \
        lib/screens/onboarding/age_attestation_screen.dart \
        lib/main.dart \
        test/services/age_gate_service_test.dart \
        test/screens/onboarding/age_attestation_screen_test.dart
git commit -m "feat(onboarding): add 16+ age attestation screen"
```

---

## Task 4: Consent banner (analytics + crash reporting + dietary/health data)

**Files:**
- Create: `lib/services/consent_service.dart`
- Create: `lib/screens/onboarding/consent_banner_screen.dart`
- Modify: `lib/main.dart` — gate Firebase Analytics + Crashlytics initialisation on consent
- Modify: `lib/services/auth_service.dart` and any signup flow to gate dietary collection on consent
- Test: `test/services/consent_service_test.dart`
- Test: `test/screens/onboarding/consent_banner_screen_test.dart`

**Why:** Required by Washington MHMDA, EU/UK GDPR + ePrivacy, and California CPRA. Three granular toggles — must be separable, withdrawable, and the dietary one must allow withdrawal without bricking the whole app.

- [ ] **Step 1: Service test**

```dart
test('all consents default to denied', () async {
  SharedPreferences.setMockInitialValues({});
  final c = ConsentService();
  expect(await c.analyticsConsent(), isFalse);
  expect(await c.crashReportingConsent(), isFalse);
  expect(await c.healthDataConsent(), isFalse);
});

test('granting one consent does not grant others', () async {
  SharedPreferences.setMockInitialValues({});
  final c = ConsentService();
  await c.setAnalyticsConsent(true);
  expect(await c.analyticsConsent(), isTrue);
  expect(await c.healthDataConsent(), isFalse);
});

test('withdrawing health-data consent triggers a deletion request hook', () async {
  // Should call a registered deletion callback (used by AccountService
  // to clear dietary fields from the user doc).
});
```

- [ ] **Step 2: Implement `ConsentService`**

Keys: `consent_analytics_v1`, `consent_crashlytics_v1`, `consent_health_v1`. Each defaults to `false`. Setters persist to SharedPreferences and call any registered observers.

- [ ] **Step 3: Build the consent banner screen**

Three toggles, plain language:

> "**Analytics** — Help us understand how Elio is used so we can improve it. Off by default."
>
> "**Crash reporting** — Send anonymised error reports if Elio crashes. Off by default."
>
> "**Dietary & health data** — Required for AI recipe suggestions tailored to your needs. We treat this as health data under Washington's My Health My Data Act. You can withdraw consent at any time in Settings → Privacy."

A "Continue" button at the bottom. Each toggle independently togglable. Tapping "Continue" persists the choices.

- [ ] **Step 4: Gate Firebase init on consent**

In `main.dart` (or wherever `Firebase.initializeApp` is called), defer the **Analytics-collection-enabled** and **Crashlytics-collection-enabled** flags until after consent is read:

```dart
final consent = ConsentService();
await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
  await consent.analyticsConsent(),
);
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
  await consent.crashReportingConsent(),
);
```

Listen for consent changes and call `setAnalyticsCollectionEnabled` / `setCrashlyticsCollectionEnabled` again when toggled.

- [ ] **Step 5: Gate dietary data writes on consent**

In the onboarding screens that collect dietary data + the profile editor, check `ConsentService().healthDataConsent()` first. If `false`, skip those questions and the AI features that depend on them; show a Settings shortcut to enable.

- [ ] **Step 6: Wire withdraw-consent to delete dietary data**

When `setHealthDataConsent(false)` is called, dispatch an event handler that:
1. Wipes `dietaryRequirements`, `allergies` from the user doc;
2. Wipes `dietaryRequirements` from each household member doc;
3. Disables AI features in the UI.

This is the granular-withdrawal requirement under EDPB Guidelines 05/2020 + MHMDA §10.1.

- [ ] **Step 7: Place consent banner in onboarding flow**

Right after age attestation (Task 3) and before any dietary questions. Must run on first app open if not already completed.

- [ ] **Step 8: Tests pass**

`flutter test test/services/consent_service_test.dart` and the widget test.

- [ ] **Step 9: Commit**

```bash
git add lib/services/consent_service.dart \
        lib/screens/onboarding/consent_banner_screen.dart \
        lib/main.dart \
        lib/screens/onboarding/<dietary screens> \
        test/services/consent_service_test.dart \
        test/screens/onboarding/consent_banner_screen_test.dart
git commit -m "feat(consent): granular consent banner for analytics, crash, health data"
```

---

## Task 5: Settings UI — Export, Delete, Privacy toggles

**Files:**
- Create or extend: `lib/screens/settings/settings_screen.dart`
- Wire: `AccountService.deleteAccount()`, `DataExportService.exportAndShare()`
- Test: `test/screens/settings/settings_screen_test.dart`

**Why:** Privacy policy §7 currently routes rights requests through email until these tiles ship. We can ship v1 with email-only rights handling, but Settings UI must be the v1.1 follow-on. Visual styling waits on Kate.

This task is **scope-flexible** — bare-bones list-tile version is acceptable for v1.1. Kate's redesign comes later.

- [ ] **Step 1: Add Account section with two tiles**

```
Account
  - Export my data       [exports JSON via system share sheet]
  - Delete my account    [confirms, prompts re-auth, calls AccountService]
```

Both should call into the existing services. Show a loading state during the operations.

- [ ] **Step 2: Add Privacy section with three toggles**

```
Privacy
  - Analytics                  [toggles ConsentService.setAnalyticsConsent]
  - Crash reporting            [toggles ConsentService.setCrashReportingConsent]
  - Dietary & health data      [toggles ConsentService.setHealthDataConsent;
                                warns user about losing AI features]
```

- [ ] **Step 3: Add Legal section**

```
Legal
  - Privacy policy             [opens legal_links.privacyPolicyUrl]
  - Terms of service           [opens legal_links.termsOfServiceUrl]
  - Washington consumer health data notice
                               [opens hosted wa-consumer-health-data-notice URL]
```

- [ ] **Step 4: Widget tests**

Tapping each tile invokes the right service method. Toggles read/write `ConsentService`. Re-auth flow for delete is mocked.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings/ test/screens/settings/
git commit -m "feat(settings): export, delete, privacy toggles, legal links"
```

---

## Task 6: Host the legal pages

**Files:**
- Create or use: a static-site hosting setup (GitHub Pages, Vercel, Netlify, or Cloudflare Pages)
- Modify: `lib/services/legal_links.dart`

**Why:** Apple App Store and Google Play both require a publicly-accessible privacy-policy URL at submission. The Markdown files at `docs/legal/` need to render as HTML at stable URLs.

- [ ] **Step 1: Pick hosting**

Recommendation: **GitHub Pages from the elio-app repo**. Free, zero infra, version-controlled. Alternative: Cloudflare Pages if you want a custom domain on a non-elio.app domain.

- [ ] **Step 2: Convert markdown to a static site**

Two options:
- **(a) Cheap:** drop the three .md files into a `docs/` folder GitHub Pages serves, with Jekyll auto-rendering. URLs will be `https://<rob>.github.io/elio-app/legal/privacy-policy.html`.
- **(b) Better:** a tiny custom-domain static site at `legal.elio.app` (subdomain) using Cloudflare Pages and an MkDocs / VitePress / plain-HTML build.

Pick (a) for first launch.

- [ ] **Step 3: Replace placeholder dates and addresses**

Search-and-replace `[INSERT DATE BEFORE STORE SUBMISSION]` and `[INSERT BUSINESS ADDRESS]` and `[Elio LLC — to be formed]` across all three legal docs before publishing.

- [ ] **Step 4: Update `legal_links.dart` constants**

Replace the placeholders with the real hosted URLs and flip `urlsAreLive = true`. The sentinel test at `test/services/legal_links_test.dart` will then enforce that the URLs are not the elio.app placeholders.

- [ ] **Step 5: Run sentinel test**

`flutter test test/services/legal_links_test.dart` → all 4 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/legal_links.dart docs/legal/
git commit -m "config(legal): wire real hosted privacy + terms + WA notice URLs"
```

---

## Task 7: Firebase Console configuration (no code)

**Where:** Firebase Console for the prod project at https://console.firebase.google.com

**Why:** The privacy policy makes specific retention claims that need the console set to match.

- [ ] **Step 1: Set Analytics user-data retention to 14 months**

Firebase Console → Analytics → Admin (or Settings) → Data Retention → "User-property and event-data retention" → **14 months**. Save.

- [ ] **Step 2: Confirm Crashlytics retention default**

Firebase Console → Crashlytics → Settings — there is no user-changeable retention; Google's default is 90 days for non-fatals, 180 days for fatals. Confirm. Document the values in `docs/operations/firebase-config.md` (NEW — created in launch-readiness sprint).

- [ ] **Step 3: Confirm Firestore PITR is OFF (or decide to enable)**

Firebase Console → Firestore → Backups → Point-in-Time Recovery. Default: off. Recommendation: leave off for v1 (cost, complexity); the privacy policy currently does not promise PITR. If turned on later, update §6 of the privacy policy.

- [ ] **Step 4: Confirm Gemini API tier**

Google Cloud Console → API & Services → Generative Language API → Verify it's billed (paid tier) not free-tier. If free-tier, do not publish the "we use the paid tier" claim. _The privacy policy was deliberately left silent on training; revisit if/when paid tier is confirmed._

- [ ] **Step 5: Document the verified config**

Capture screenshots and write a short note at `docs/operations/firebase-config.md` (created in the launch-readiness sprint) so we know what was set when.

---

## Task 8: Sprint 17 sentinel — `LegalLinks.urlsAreLive` check in CI

**Files:**
- Modify: `.github/workflows/ci.yml` (or whatever runs `flutter test` in CI)

**Why:** A release build must not ship with `urlsAreLive=false`. Already enforced by the sentinel test, but currently CI doesn't gate releases on it explicitly.

- [ ] **Step 1: Add a release-only step that runs `flutter test test/services/legal_links_test.dart` separately**

Use a release-tag pattern (`v*.*.*`) on push to main to trigger the sentinel. If `urlsAreLive=false`, fail the release.

- [ ] **Step 2: Test it by tagging a no-op build**

Verify that with `urlsAreLive=false`, the sentinel correctly fails the release pipeline.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci(legal): block release if LegalLinks.urlsAreLive is false"
```

---

## Task 9: Free-trial cooling-off acknowledgement checkbox

**Files:**
- Modify: `lib/screens/paywall/paywall_screen.dart`
- Test: `test/screens/paywall/paywall_screen_test.dart`

**Why:** UK/EU 14-day cooling-off waiver requires explicit acknowledgement that user is requesting immediate performance and waives the right. Without it, EU consumers can claim the right back regardless of what the Terms say.

- [ ] **Step 1: Add an unchecked checkbox above the "Subscribe / Start free trial" button**

Copy: "**I expressly request that the service start now**, and I acknowledge that doing so means I lose my 14-day right to cancel for refund (UK/EU consumers only)."

The Subscribe button stays disabled until the box is ticked.

- [ ] **Step 2: Widget test**

Tapping Subscribe with the box unticked does nothing; ticking enables the button.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/paywall/paywall_screen.dart test/screens/paywall/paywall_screen_test.dart
git commit -m "feat(paywall): explicit 14-day cooling-off waiver checkbox"
```

---

## Task 10: Verify Google Play Data Safety form alignment

**Where:** Google Play Console → app → "App content" → Data safety

**Why:** Data Safety form must match the privacy policy. Mismatch = rejection.

- [ ] **Step 1: Walk the form**

Cross-check every category:
- Personal info: email, name (display name) — collected, encrypted in transit, deletion supported
- Health & fitness — health info — **YES** (allergies, dietary requirements). Required.
- App activity — analytics events — collected only with consent
- App info & performance — crash logs — collected only with consent
- Photos and videos — collected, **shared with Google Gemini for processing**, not stored
- Audio — voice cooking — collected, **shared with Google Speech / Apple Speech**, not stored by Elio
- Financial info — purchase history — collected via RevenueCat / Apple / Google

- [ ] **Step 2: Mark "Data shared" correctly**

Specifically declare **Google (Gemini API)** as receiving data shared with a third-party service. Even though they're a sub-processor, Google Play's taxonomy treats AI-processing relationships as "shared."

- [ ] **Step 3: Save and submit for review**

This is a console action, not code. Document the answers chosen in `docs/operations/play-data-safety.md` (NEW).

---

## Verification checklist before Phase 1 submission

After all tasks above complete, verify each statement is true:

- [ ] `dietary_profile` does not appear anywhere in `lib/` or `test/`
- [ ] AdID/IDFV/IDFA disable flags are present in manifest and Info.plist
- [ ] Age attestation screen runs before any data collection
- [ ] Consent banner runs before Firebase Analytics or Crashlytics initialise
- [ ] Withdrawing health-data consent deletes dietary fields from user doc
- [ ] Settings screen exposes Export / Delete / consent toggles / legal links
- [ ] All three legal docs are publicly hosted and `legal_links.dart` points at the live URLs with `urlsAreLive=true`
- [ ] Firebase Analytics retention is set to 14 months in Console
- [ ] Free-trial paywall has the cooling-off acknowledgement checkbox
- [ ] Google Play Data Safety form is filled and matches the policy
- [ ] App Store Privacy "nutrition labels" match the policy (set in App Store Connect)
- [ ] All `[INSERT ...]` placeholders in the legal docs are resolved

---

## Dependencies on other sprints

- **Sprint 19:** Sign in with Apple — required before iOS submission. Not in scope here. Without it the app is Android-only at Phase 1.
- **Launch-readiness sprint** (separate plan doc): backend audit, secrets, store submission keys, Firebase project hygiene. Required before Phase 1.

## Estimated effort

- Task 1 (drop dietary_profile): 30 minutes
- Task 2 (manifest flags): 30 minutes + 15 minutes verification
- Task 3 (age attestation): 1.5 hours including tests
- Task 4 (consent banner + Firebase gating + dietary deletion hook): 1 day — most complex task in the sprint
- Task 5 (Settings UI): 4 hours for the bare-bones version
- Task 6 (host legal pages, wire URLs): 2 hours
- Task 7 (console flips): 30 minutes
- Task 8 (CI sentinel): 30 minutes
- Task 9 (cooling-off checkbox): 30 minutes
- Task 10 (Play Data Safety form): 1 hour

**Total: ~3 working days** for a single developer including verification.
