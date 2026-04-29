# Launch-Readiness Sprint — Backend & Operations Audit

> **For agentic workers:** This is a **discussion + audit** plan, not a TDD-style implementation plan. Each section poses a question, lists what to inventory, and proposes a recommendation. Rob and the implementing agent work through it one section at a time, deciding the right answer for Elio's scale and risk profile, then committing the answer to a `docs/operations/` doc.

**Goal:** Before Phase 1 launch, audit every place a secret, key, credential, or operational config lives. Decide where it should live, who can access it, how it rotates, and what happens when it leaks. Document the answers so they survive a hard-drive failure, a co-founder addition, or an acquisition.

**Why this exists:** A solo-developer indie app accumulates secrets fast — Firebase service-account JSONs, RevenueCat keys, Gemini API keys, Apple Developer cert + private key, Android upload keystore, Google Play service account, App Store Connect API key, Stripe (if added later), domain registrar credentials, email-service credentials, etc. At launch you want to know each one's: **where it lives, who has it, how it rotates, what breaks if it leaks**. Lose that map and the app turns into a hostage situation.

**Scope of this sprint:**
- Section A: Secrets inventory and storage strategy
- Section B: Firebase project hygiene (prod vs dev, security rules, retention, billing alerts)
- Section C: Gemini API operational concerns
- Section D: RevenueCat + store billing setup
- Section E: Store submission credentials (Apple Developer, Google Play, App Store Connect)
- Section F: Domain, DNS, email
- Section G: Backups, recovery, business-continuity
- Section H: Cost monitoring + budget alerts
- Section I: Incident response
- Section J: LLC formation and tax setup

**Out of scope:** Code changes (those live in Sprint 17 and beyond), legal-document drafting (already done in Sprint 17 GDPR sprint).

**Deliverable:** A `docs/operations/` directory containing:
- `secrets-inventory.md` (gitignored values, structure committed)
- `firebase-config.md`
- `incident-response.md`
- `runbook.md`

---

## Section A: Secrets inventory and storage strategy

**The question:** Where does every secret live today, where should it live, and what's the rotation plan?

### A.1 Inventory exercise

Walk the codebase and the filesystem. Find every secret, key, password, token, certificate, private key, API key. The canonical list to start from:

| Secret | Used by | Currently lives at? | Should live at? | Rotation? |
|---|---|---|---|---|
| **Firebase API key (Web/Android/iOS)** | App | `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart` | Same — these are public-by-design but the project + Firestore Rules must lock them down | When project changes |
| **Gemini API key** | App via Firebase Remote Config | Firebase Remote Config (`gemini_api_key`) — fetched at startup | Same — but switch to a **Cloud Function intermediary** for v1.1 so the key never ships to clients (see C.2) | Quarterly + on suspected leak |
| **Firebase service-account JSON (server-side)** | Cloud Functions (when deployed), CI/CD | ? | A 1Password / Bitwarden vault entry; never in git | On staff change, suspected leak |
| **RevenueCat API keys (public + secret)** | App (public), webhook receiver (secret) | ? | Public in `purchase_service.dart` (it's safe to ship); secret in 1Password | Annually + on leak |
| **Apple Developer certificate** (`.p12` + private key) | iOS build/sign | ? | 1Password + a printed-and-locked offline copy | When it expires (annually) |
| **App Store Connect API key** (`.p8` file + key ID + issuer ID) | TestFlight upload, store automation | ? | 1Password | Annually |
| **Apple Push Notification cert / APNs auth key** (`.p8`) | FCM → APNs delivery | Firebase Console | Note in `firebase-config.md` | Annually |
| **Android upload keystore** (`.jks`) + passwords | Android Play store signing | Local machine — **CRITICAL: lose this and you cannot update the app** | 1Password + an encrypted backup on a separate physical drive | Cannot rotate (it's the upload key) — **back up in two places** |
| **Google Play service-account JSON** | Play Console automation | ? | 1Password | Annually |
| **Domain registrar login** | DNS for elio.app (when bought) | ? | 1Password with 2FA recovery codes | Password annually, 2FA when device changes |
| **Email service credentials** (if you add Postmark/SendGrid for transactional email) | Server-side send | ? | 1Password | Annually |
| **Sentry / monitoring DSN** (if you add it) | App | DSN is publicly safe, but auth tokens are not | 1Password | Annually |

### A.2 Decision: where do secrets live?

**Recommendation for a solo dev:**

1. **Public client-shipped secrets** (Firebase Web API key, RevenueCat public key, Gemini API key as long as it's gated by Firebase App Check + Remote Config) → committed to the repo, but every public secret must have a backstop (App Check, Firestore Rules, RevenueCat's IP-restriction option, Gemini's quota-and-domain-restriction). **The threat model is "someone extracts the key and abuses it"** — App Check + quota = fine.

2. **Server / build-time secrets** → **1Password personal vault** (or Bitwarden, or Apple Keychain if you don't trust password managers). Free for one user. Categorise by: (i) Build & sign, (ii) Backend & infra, (iii) Stores & accounts.

3. **CI/CD secrets** (when you add a release pipeline) → GitHub Actions Encrypted Secrets, scoped to the elio-app repo. Reference 1Password for the canonical copy.

4. **Backups of irreplaceable secrets** (the Android upload keystore especially) → 1Password **plus** an encrypted dmg/7z file on an external drive in a different physical location from your Mac/PC. Print the recovery seed phrase for the password manager itself and put it in a fireproof envelope. This is the "house burns down" plan.

### A.3 Tasks

- [ ] Run `git grep` and a filesystem audit to find every existing secret. Document each in `docs/operations/secrets-inventory.md` (committed, with the actual values redacted to `[in 1Password under "RevenueCat → Secret Key"]`).
- [ ] Create the 1Password categories above and migrate every found secret.
- [ ] Add a `.gitignore` audit: ensure `*.p12`, `*.p8`, `*.jks`, `*service-account*.json`, `.env*` (except `.env.example`), `key.properties` are all ignored.
- [ ] `git log -p --all` for any of the patterns above — if a secret was ever committed, **rotate it** (the git history is forever).
- [ ] Rotate **every secret** before submission as a clean baseline, even the ones you think are safe. New secrets, fresh start, documented.
- [ ] Set up the offline backup of the Android keystore — physical backup is mandatory.

---

## Section B: Firebase project hygiene

**The question:** Is the prod Firebase project clean, locked down, monitored, and separate from dev?

### B.1 Inventory

- [ ] How many Firebase projects exist? (Probably: one prod, possibly one dev/staging.)
- [ ] Confirm the Firebase project ID matches the prod app config in `firebase_options.dart`.
- [ ] Who has Owner / Editor access on the project? (Probably just Rob; should be Rob plus one designated emergency contact.)
- [ ] Is billing enabled? Spark plan vs Blaze plan. (Gemini API access requires Blaze.)
- [ ] Is App Check enabled? (Recommended for v1; likely deferred to Sprint 18.)

### B.2 Recommendations

**Two projects, not one.**

- `elio-prod` — locked down, paid Blaze tier, real users, real money.
- `elio-dev` — your Flutter dev runs hit this; can break, get rate-limited, cost money on developer experiments. Spark tier (free) where possible.

If currently on one project, splitting is more work than it sounds (FCM tokens, RevenueCat aliasing, App Store Connect bundle IDs all reference the project). **Decision: live with one for v1**, do this in v1.1.

### B.3 Firestore security rules

- [ ] `firestore.rules` audit — verify every collection has owner-only `read`/`write`, that `subscription` write is locked to server-only fields, that no `allow read, write: if true` exists anywhere.
- [ ] Verify the rules match `firestore.rules.bak` (deployed version) by running `firebase deploy --only firestore:rules --dry-run`.
- [ ] Spot-check the rules with the **Firestore Rules Playground** (Firebase Console) using a real test user.
- [ ] Confirm the Sprint 17 `protectedSubKeysUnchanged()` rule is deployed.
- [ ] Add a CI job that runs `firebase emulators:exec --only firestore` against a small rule-test suite.

### B.4 Firestore indexes + cost

- [ ] Audit `firestore.indexes.json` — each composite index is a cost line item.
- [ ] Look at the project's Firestore Usage tab — read/write/delete counts per day. If a single user is generating 10k+ reads/day, find and optimise (likely a re-render loop).

### B.5 Cloud Functions

- [ ] Currently deployed? If yes, list each function and what it does.
- [ ] Lock down inbound — Cloud Functions on Firebase default to public; v2 functions need explicit IAM bindings.
- [ ] If a webhook (e.g. RevenueCat → Cloud Function for entitlement sync) exists, verify it validates the signature.

### B.6 Tasks

- [ ] Document the prod project ID, billing tier, Blaze quota alerts in `docs/operations/firebase-config.md`.
- [ ] Set up **Firebase budget alerts** at $10, $50, $100/month thresholds.
- [ ] Set up **Cloud Logging alerts** for "Firestore Rules deny rate > 10/min" (signals abuse or bug).

---

## Section C: Gemini API operational concerns

**The question:** Is the Gemini integration sustainable at launch scale, and is the API key protected?

### C.1 Tier and quota

- [ ] Confirm tier: paid Gemini API, billed via Google Cloud project linked to the Firebase project.
- [ ] Confirm per-minute and per-day quotas on the Google Cloud Console for the Generative Language API. Defaults are tight.
- [ ] Set up budget alerts on the GCP project (separate from Firebase budget alerts — same billing account, different surfaces).

### C.2 API key protection

**Current architecture:** API key is stored in Firebase Remote Config and fetched by the client at startup. **Risk:** anyone who decompiles the app can read Remote Config.

**Mitigations available:**
- (a) Restrict the API key to specific Android packages and iOS bundle IDs in the Google Cloud Console — already free and recommended; do this immediately. Limits usable surface to "people who built an app with this signature," still extractable but requires effort.
- (b) Gate Remote Config fetches behind **Firebase App Check** (BasicIntegrity / DeviceCheck / App Attest). Requires Sprint 18 work.
- (c) Move all Gemini calls server-side via a Cloud Function. App calls Cloud Function with user auth; Function calls Gemini with the API key (which never leaves the server). Cleanest architecture; biggest effort. **Recommendation for v1.1.**

**v1 decision:** ship with (a) only. Document the exposure in `docs/operations/threat-model.md`.

### C.3 Abuse handling

- [ ] If a single user starts generating 1000 recipes/hour (script kiddie), what stops them? Currently: nothing client-side. The free-tier weekly counter is in SharedPreferences and trivially bypassable. **Recommendation:** add server-side rate limiting (Cloud Function gating Gemini calls, by uid) in v1.1.
- [ ] Confirm Gemini API quota will surface a graceful error rather than billing your card to bankruptcy when abuse happens.

### C.4 Tasks

- [ ] Restrict Gemini API key to package/bundle IDs in GCP console.
- [ ] Set GCP budget alert at $25, $100, $250/month.
- [ ] Document the Gemini setup in `docs/operations/gemini-config.md`.
- [ ] Schedule "move Gemini server-side" as a v1.1 backlog item.

---

## Section D: RevenueCat + store billing setup

**The question:** Is the subscription flow ready end-to-end, with sandbox testing complete?

### D.1 Inventory

- [ ] RevenueCat account created? Project named `elio`?
- [ ] Two products configured: `elio_pro_monthly`, `elio_pro_annual`
- [ ] Entitlement `pro` configured, mapping both products to it
- [ ] Apple App Store: products created in App Store Connect with the same identifiers
- [ ] Google Play: products created in Play Console with the same identifiers
- [ ] 7-day free trial configured at store level (not in RevenueCat)
- [ ] Store-server-notification (Apple) / Real-time developer notifications (Google) wired to RevenueCat

### D.2 Webhook → server flow

When a user subscribes, RevenueCat receives the receipt. To sync `subscription.tier=pro` to Firestore:

- (a) **Client-side write on `EntitlementsLatestUpdate`** event — current implementation. Cheap. Risk: client could spoof. Firestore Rules (Sprint 17) lock the field to server-only writes, so this currently fails silently — which is itself a bug.
- (b) **RevenueCat webhook → Cloud Function → Firestore write** — proper. Requires Cloud Functions deployment.

**v1 decision:** rely on (a) for entitlement reads (RevenueCat is source of truth, queried at app open) and **don't write subscription.tier to Firestore** at all unless the rules are loosened or a Cloud Function is deployed. The `subscription` map can hold `weeklyGenerations` etc. (which client should write) but `tier` should be derived live from RevenueCat. Document this clearly.

### D.3 Sandbox / test purchases

- [ ] Apple sandbox tester accounts configured in App Store Connect
- [ ] Google Play license testers added in Play Console
- [ ] Walked through the full purchase + cancel + refund flow in sandbox on a real device, both stores
- [ ] Confirmed the "Restore Purchases" button works
- [ ] Confirmed the introductory free-trial price label shows correctly

### D.4 Tasks

- [ ] Run a sandbox subscribe → verify entitlement → cancel → verify entitlement removed cycle on iOS and Android
- [ ] Verify the paywall screen meets Apple Guideline 3.1.2(a) layout (title, length, price, free-trial terms, links to Terms + Privacy on the same screen)
- [ ] Document the verified RevenueCat config in `docs/operations/revenuecat-config.md`

---

## Section E: Store submission credentials

**The question:** Do you have everything Apple and Google ask for at submission, and is it backed up?

### E.1 Apple

- [ ] Apple Developer Program membership active (annual $99 USD)
- [ ] Team agent (Rob) and at minimum one Admin contact
- [ ] App Store Connect access set up
- [ ] Bundle ID `app.elio.elio` (or chosen ID) registered
- [ ] Apple Developer certificate (`.p12`) generated, exported, **stored in 1Password + offline encrypted backup**
- [ ] App Store Connect API key (`.p8`) generated for `fastlane` / CI uploads — stored in 1Password
- [ ] APNs auth key (`.p8`) uploaded to Firebase for FCM → APNs
- [ ] App Privacy "nutrition label" filled in App Store Connect to match the privacy policy
- [ ] Age rating configured to match the actual age floor (16+) and AI-content disclosure
- [ ] Sign in with Apple configured (Sprint 19 prerequisite)
- [ ] Tax forms filled in (US: W-9; non-US: W-8BEN — but you're US, so W-9)
- [ ] Banking info filled

### E.2 Google Play

- [ ] Google Play Console account active (one-off $25 USD registration)
- [ ] Developer account verified with Google (May 2024 onwards: ID verification required for new accounts)
- [ ] Application created in Play Console
- [ ] Android upload keystore generated, **stored in 1Password + offline encrypted backup** — **CRITICAL: this cannot be regenerated**
- [ ] Play App Signing enabled (Google manages the signing key; you only need the upload key)
- [ ] Google Play service account JSON for Play Console API automation — 1Password
- [ ] Closed testing track set up for pre-launch validation
- [ ] Data Safety form filled to match the privacy policy
- [ ] Content rating completed (IARC questionnaire)
- [ ] Target audience set to 16+ (matching the policy and age gate)
- [ ] Tax info and banking complete
- [ ] DUNS number obtained if required (Google requires it for verified developer accounts as of 2024 — confirm)

### E.3 Tasks

- [ ] Walk both consoles end-to-end with a checklist printed out
- [ ] Document each console's URL, login email, and 2FA recovery in 1Password
- [ ] Tag each backup with an expiration date so you remember when certs need renewing
- [ ] Schedule a calendar reminder 60 days before each cert/membership expires

---

## Section F: Domain, DNS, email

**The question:** Where does `elio.app` (or the chosen domain) live, who controls it, and is the email actually receiving?

### F.1 Inventory

- [ ] Has the domain been bought yet? (Earlier conversation: no.) — **launch blocker**
- [ ] If yes: which registrar? Login in 1Password with 2FA?
- [ ] DNS managed where? (Registrar default, Cloudflare, etc.)
- [ ] `support@elio.app` actually receiving mail? (Earlier: claimed, not verified.)

### F.2 Recommendations

- **Registrar:** Cloudflare Registrar (at-cost pricing) or Porkbun (cheap, decent UX). Avoid GoDaddy.
- **DNS:** Cloudflare (free tier).
- **Email:** Cloudflare Email Routing (free, forwards `support@elio.app` → your Gmail) — fine for v1. If you later need to *send* from elio.app, use **Postmark** or **SendGrid** for transactional, with SPF + DKIM + DMARC set up.

### F.3 Tasks

- [ ] Buy the domain
- [ ] Set up Cloudflare DNS
- [ ] Configure email routing → personal inbox
- [ ] Send a test message to `support@elio.app` and verify receipt
- [ ] Set up SPF + DKIM + DMARC if outbound email is needed
- [ ] Document the domain setup in `docs/operations/domain-config.md`

---

## Section G: Backups, recovery, business-continuity

**The question:** What survives a stolen laptop / fried hard drive / hacked Google account?

### G.1 The "if Rob falls under a bus" plan

This is the dark version. The point: a paying user expects the app to keep working. If you become unreachable for two weeks, what happens?

- [ ] **Trusted contact:** designate one person (family member or a fellow indie dev) who knows the 1Password recovery seed and has a sealed envelope of step-by-step instructions for "log in, freeze the app gracefully, refund what's outstanding, communicate with users."
- [ ] **Apple + Google legacy contacts:** both platforms have legacy/inheritance settings. Configure them.
- [ ] **DNS auto-renewal:** every domain on auto-renew with a backup payment card.
- [ ] **Apple Developer + Google Play auto-renewal:** same.
- [ ] **Firebase billing:** auto-renew with backup card.

### G.2 Code backups

- [ ] Repo lives on GitHub (already true)
- [ ] Branch protection rules on `main` (require PR, require passing CI)
- [ ] A clone of the repo on a second machine or a USB drive that you periodically refresh
- [ ] The git history of the legal docs preserved — you may need to prove version history to a regulator

### G.3 User-data recovery

- [ ] If Firestore data is lost (corruption, accidental rule-allow-all deploy, malicious actor), what's the recovery story?
- Decision needed: is **Firestore Point-in-Time Recovery** (7-day window, costs ~$0.20/GB/month) worth the cost for v1? Recommendation: **yes, enable it** — for a small user base it's pennies and the alternative is "hope you have a recent export."
- [ ] If enabled, update privacy policy §6 to reflect the 7-day PITR window.

### G.4 Tasks

- [ ] Configure Apple + Google legacy contacts
- [ ] Designate trusted contact + write the sealed-envelope instructions
- [ ] Set up auto-renewal with a backup card on every paid service
- [ ] Decide on PITR; if yes, enable and update the policy
- [ ] Document everything in `docs/operations/business-continuity.md`

---

## Section H: Cost monitoring and budget alerts

**The question:** What's your monthly cost ceiling, and what alerts you when you're approaching it?

### H.1 Expected costs at launch

| Service | Free tier | Cost above |
|---|---|---|
| Firebase Auth | Free up to 50k MAU | $0.0055/verification beyond |
| Firestore | 50k reads, 20k writes, 1 GiB free | $0.06/100k reads, $0.18/100k writes |
| Cloud Messaging | Free | Free |
| Crashlytics | Free | Free |
| Analytics | Free | Free |
| Cloud Functions | 2M invocations free | $0.40/M after |
| Gemini Flash 2.5 | Paid only | ~$0.075/M input tokens, $0.30/M output |
| RevenueCat | Free up to $2.5k MTR | 1% of MTR after |
| Apple Developer | $99/year | — |
| Google Play | $25 one-time | — |
| Domain | ~$15/year | — |
| Email routing | Free | — |

For v1 at <1k users: **<$50/month total** is realistic. The risk is Gemini abuse — a single bad actor could spike that to $1000+ in a day.

### H.2 Alerts

- [ ] GCP budget alert at $25/month, $100/month, $500/month (caps the worst case)
- [ ] Firebase budget alert (separate from GCP)
- [ ] Apple Developer renewal reminder 60 days out
- [ ] Google Play renewal reminder 60 days out
- [ ] Domain renewal reminder 60 days out

### H.3 Tasks

- [ ] Set up GCP budget alerts on the linked billing account
- [ ] Set up Firebase budget alerts
- [ ] Add all renewal dates to a `docs/operations/renewal-calendar.md` and to a real calendar with reminders

---

## Section I: Incident response

**The question:** When something breaks at 2am, what do you do?

### I.1 Define "incident"

- **Sev 1:** users can't sign in, app fully broken, data leak suspected
- **Sev 2:** key feature broken (recipe generation, paywall), but app usable
- **Sev 3:** cosmetic or low-frequency bug

### I.2 Runbook items

- [ ] How do I take the app offline gracefully? (**Firebase Remote Config kill switch:** add a `emergency_app_disabled` boolean Remote Config flag, gate `MaterialApp` on it, ship before launch)
- [ ] How do I revoke a leaked Gemini key? (GCP Console → Credentials → Disable. Revoke takes effect within seconds.)
- [ ] How do I roll back a bad release? (App Store: phased rollout pause. Play: halt rollout.)
- [ ] Who do I notify? (Trusted contact, then 24-48h later: posting to the app's social presence and emailing affected users)
- [ ] What's the user-facing message template for a privacy breach? (Drafted in `docs/operations/breach-template.md`)

### I.3 Tasks

- [ ] Add the `emergency_app_disabled` Remote Config flag and wire it
- [ ] Write the runbook in `docs/operations/runbook.md`
- [ ] Write the breach-notification template in `docs/operations/breach-template.md`
- [ ] Test the kill switch works on a sandbox build before launch

---

## Section J: LLC formation and tax setup

**The question:** Is the entity actually formed before launch, and is the tax setup correct?

### J.1 LLC formation (Washington State)

- [ ] File **Washington LLC** at https://ccfs.sos.wa.gov ($200 filing fee, $60 annual licence renewal)
- [ ] Get an **EIN** from the IRS (free, 5 minutes online)
- [ ] Open a separate business bank account (don't co-mingle funds — the corporate veil depends on it)
- [ ] File the WA Business Licence (state + city — Seattle adds its own)
- [ ] Decide if the LLC is single-member (default: disregarded entity, taxed on personal return) or files as S-corp (more complex, may save on self-employment tax once revenue is meaningful)
- [ ] Add the LLC name to **all** legal docs (replace `[Elio LLC — to be formed]` placeholder)
- [ ] Update Apple Developer + Google Play accounts to the LLC name (Apple offers org-tier; Google Play has individual + organisation options)

### J.2 Sales tax / VAT

- [ ] Apple and Google handle US sales tax for in-app purchases (they're the merchant of record)
- [ ] For UK launch: Apple and Google also handle UK VAT
- [ ] No separate sales-tax registration needed for v1 because of the merchant-of-record arrangement

### J.3 Tasks

- [ ] File LLC, get EIN, open bank account
- [ ] File WA + Seattle business licence
- [ ] Migrate Apple Developer + Google Play accounts to the LLC (or note that you're keeping individual for v1 and migrating later)
- [ ] Engage a US-based CPA familiar with single-member LLCs and digital products for an annual review (cheap; $300–$800/year for a one-person setup)
- [ ] Document everything in `docs/operations/entity-config.md`

---

## How to work this sprint

**Suggested rhythm:** one section per session, with Rob.

1. Read the section.
2. Answer the inventory questions.
3. Discuss the recommendation. Adjust to fit Elio's actual scale.
4. Execute the tasks (file, configure, document).
5. Commit the resulting `docs/operations/*.md` file.
6. Move on.

**Order of priority** for actually shipping v1:

1. **Section A** (secrets) — do first, blocks everything else
2. **Section J** (LLC formation) — start the paperwork early, takes 1-2 weeks
3. **Section F** (domain) — needed for legal pages hosting
4. **Section E** (store credentials) — needed for submission
5. **Section B** (Firebase hygiene) + **Section C** (Gemini) + **Section H** (cost) — needed before public launch
6. **Section D** (RevenueCat) — needed before public launch
7. **Section G** (backups) + **Section I** (incidents) — needed before public launch but lighter touch

**Definition of done:** every section has a `docs/operations/<name>.md` file, every task box is checked, and Rob can hand the entire `docs/operations/` directory to a new co-founder and they could understand the operational state of the business in 30 minutes.

---

## What this sprint deliberately does NOT cover

- Marketing, App Store Optimisation (ASO), launch comms — separate concern
- Visual design, brand identity, store screenshots — Kate's domain
- Feature work for v1.1 — separate plan
- A formal threat model or pen-test — overkill for v1; revisit at 10k MAU
- Compliance certifications (SOC 2, ISO 27001, HIPAA) — none required for v1
