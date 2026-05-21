# Elio — Privacy Policy

**Document version:** 3.0-draft
**Effective date:** _[INSERT DATE BEFORE STORE SUBMISSION]_
**Last updated:** _[INSERT DATE BEFORE STORE SUBMISSION]_

> **PUBLISHING CHECKLIST — DO NOT SHIP UNTIL EACH IS RESOLVED:**
> 1. `[INSERT BUSINESS ADDRESS]` placeholder replaced with real Seattle, WA address (PO Box acceptable)
> 2. `[Elio LLC — to be formed]` replaced with the actual filed entity name (or kept as "Rob Thomas (sole proprietor) doing business as Elio" until LLC is filed)
> 3. **Pre-collection consent banner shipped** for analytics, crash reporting, and dietary/health data — required by Washington's My Health My Data Act, EU/UK GDPR, and California CPRA (Sprint 17 task)
> 4. **Age attestation screen shipped** at sign-up — "I confirm I am 16 or older" — required to enforce §9 (Sprint 17 task)
> 5. **`dietary_profile` Analytics user property removed** from `AnalyticsService` — consumer health data must not flow to Firebase Analytics (Sprint 17 task)
> 6. **Sign in with Apple shipped on iOS** — required by Apple Review Guideline 4.8 (Sprint 19 task; iOS submission blocked until landed)
> 7. **Settings UI Export + Delete tiles shipped** — until then §7 routes rights requests through email only
> 8. **AdID/IDFA collection disabled**: Android `AndroidManifest.xml` (`<meta-data android:name="google_analytics_adid_collection_enabled" android:value="false" />`); iOS `Info.plist` (`GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED=false`)
> 9. **Firebase Analytics retention set to 14 months** in Firebase Console → Admin → Data Retention (default is 2 months)
> 10. Confirm `google_fonts` runtime CDN behaviour once Kate's font set is finalised — either bundle as assets or keep §4 disclosure
> 11. Confirm **standalone Washington Consumer Health Data Privacy Notice** (`wa-consumer-health-data-notice.md`) is linked from app Settings → Legal AND from the app store listings
> 12. Replace all `[INSERT DATE...]` placeholders with the launch date

---

This Privacy Policy explains how the Elio mobile application ("**Elio**", "**we**", "**us**", "**our**") collects, uses, shares, and protects information about you when you use the app. Elio is a recipe and meal-planning app that uses generative AI to suggest meals based on the food you have, your dietary needs, and your household.

If you have any questions about this policy or how your data is handled, contact us at **support@elio.app**.

---

## 1. Who is responsible for your data

The business responsible for the personal information described in this policy (the "data controller" under EU/UK law and the "business" under US state laws) is:

> **[Elio LLC — to be formed] / Rob Thomas (sole owner)**
> [INSERT BUSINESS ADDRESS — Seattle, WA, USA]
> Email: **support@elio.app**

We do not currently appoint a representative under Article 27 of the UK or EU GDPR; if you are an EU or UK resident and would prefer to direct enquiries to a representative, contact us at the email above and we will respond directly within 30 days.

We have **not appointed a Data Protection Officer**. Our processing activities do not meet the thresholds in Article 37(1) of the UK or EU GDPR that would require us to appoint one (we are not a public authority, our core activities do not consist of large-scale monitoring of data subjects, and our core activities do not consist of large-scale processing of special-category data — we process dietary/allergy data only as a small consumer service). If our activities later cross those thresholds, we will appoint a DPO and update this notice.

---

## 2. What data we collect

We collect only the data we need to run the app. We **do not** collect: phone numbers, dates of birth, profile photos, GPS or precise location, contacts, social-media connections, or web-browsing history outside the app.

### 2.1 Data you give us directly

| Category | Examples | Where it's stored |
|---|---|---|
| **Account identity** | Email address, sign-in provider (Google, Apple, or email/password), display name (optional) | Google Firebase Authentication and your user record in Google Cloud Firestore |
| **Onboarding profile** | Cooking confidence level, household type, household composition, primary cooking goal, time/mood preferences, disliked ingredients | Google Cloud Firestore |
| **Dietary and health-related preferences** | Dietary requirements (e.g. vegetarian, gluten-free), allergies and intolerances, household members' names and their dietary requirements | Google Cloud Firestore. **We treat allergies and dietary requirements as "consumer health data" under Washington's My Health My Data Act and as "special category" / "sensitive" data under EU/UK GDPR and California's CPRA.** See §3 (Legal bases) and §8b (Washington Consumer Health Data Privacy Notice). |
| **Region and units** | Country/region (used to choose imperial vs metric units and currency display) | Google Cloud Firestore |
| **Kitchen setup** | Available appliances (oven, microwave, blender, etc.), cuisine and style preferences | Google Cloud Firestore |
| **Pantry inventory** | Names of foods you tell Elio you have, categories, optional expiry dates, optional prices, "running low" flags | Google Cloud Firestore |
| **Scanner learning** | A normalised mapping of ingredient names to pantry tiers built from your past scanner uses | Google Cloud Firestore (`tierMemory` subcollection) |
| **Recipes you save, generate, or rate** | Recipes you bookmark, like, dislike, or generate, plus the resulting "taste profile" we keep for the AI (a list of recipe titles you've liked or disliked) | Google Cloud Firestore |
| **Meal plans and shopping lists** | Weekly meal plans you create or accept, items on your shopping list and their status | Google Cloud Firestore |
| **Photos you import** | Photos of recipes (from camera or gallery) used for AI recipe import; photos of receipts used for the AI receipt scanner | Sent to Google's Gemini API for processing; **not stored by Elio** |
| **Barcode scans** | Live camera frames during scanning | Processed on-device only; **not stored or transmitted** |
| **Voice input/output** | Spoken commands during voice cooking; recipe text spoken back to you by the device | Sent to your device's speech-recognition / speech-synthesis service. On Android most spoken audio is processed by **Google Speech Services** (which may transmit audio off-device for processing); on iOS it is processed by **Apple's Speech framework** (typically on-device but may transmit depending on device settings). **Elio does not receive or store your voice audio.** Google or Apple may receive and process it under their own retention policies — see their privacy policies linked in §4. |
| **Notification preferences** | Your toggles for weekly meal reminders, restock reminders, and tips & updates | Google Cloud Firestore |

### 2.2 Data we collect automatically when you use the app

| Category | Examples | Purpose |
|---|---|---|
| **Push notification tokens** | Firebase Cloud Messaging device token, platform (iOS/Android) | To deliver push notifications you've opted in to |
| **Subscription state and usage counters** | Subscription tier (free or Pro), trial status, renewal status, daily/weekly recipe-generation counters and reset timestamps (so we can apply free-tier limits) | To unlock paid features and enforce free-tier limits |
| **Crash and error reports (Firebase Crashlytics)** | Stack traces of crashes and non-fatal errors, a tag describing which feature was being used, plus the standard device metadata Crashlytics collects automatically: device model, OS version, app version, locale, available RAM and disk, device orientation, and a randomly-generated installation identifier | To diagnose and fix bugs |
| **Analytics (Firebase Analytics)** | Screen views; feature usage events including (but not limited to) onboarding step completed, paywall shown / dismissed / subscribe tapped, purchase completed, purchase restored, recipe generated, recipe saved, recipe rated, ingredient substituted, ingredient added to shopping, side-dish generated, voice cooking started / stopped / completed, hands-free cooking started / exited / completed, scan items added, meal plan generated / regenerated, sign-in method; user properties: authentication method, subscription tier, household size; device type, app version, country derived from IP address, app instance ID (a pseudonymous per-install identifier set by Firebase). **We do not send dietary requirements, allergies, or any other consumer health data to Firebase Analytics** — see the standalone [Washington Consumer Health Data Privacy Notice](./wa-consumer-health-data-notice.md). | To understand how the app is used so we can improve it |
| **App configuration** | App build name and number, locale, device language | For sizing UI, localising units, and reporting in crash logs |

We **do not** run third-party advertising, sell your data to data brokers, or use it for behavioural marketing. We **do not** assign you an Android Advertising ID or Apple IDFA — both are explicitly disabled in our build configuration (subject to publishing checklist item 5 above).

> ⚠️ **Consent dependency.** Several of the items in this section — analytics, crash reporting, and dietary/health-data collection — require your prior, opt-in consent before we initialise the underlying SDKs. We collect that consent through an in-app banner the first time you open the app. You can change your choices at any time in **Settings → Privacy** (once shipped) or by emailing **support@elio.app**.

### 2.3 Data sent to the AI model (Google Gemini API)

When you ask Elio to suggest a recipe, generate a meal plan, import a recipe from a photo or URL, scan a receipt, or get an ingredient substitution, we send the following information to **Google's Gemini API** (operated by Google LLC) so it can produce a useful answer:

- Your dietary requirements, allergies, and household members' dietary requirements (as the union — without their names);
- The kitchen appliances you've told us about;
- Your preferred measurement units, region, cuisine, mood, and time preferences;
- The number of servings you've configured (which reflects your household size);
- Whether **budget/saver mode** is enabled and any **leftover-mode** ingredients you've selected;
- The contents of your pantry, which items are getting close to expiry, and which are flagged "running low";
- Recently generated recipe titles, so suggestions don't repeat;
- Your "taste profile": titles of recipes you've previously liked or disliked;
- Any free-text request you type in (e.g. "something quick and warming");
- For **photo recipe import** and **receipt scanning**: the image bytes you selected from your camera or gallery;
- For **URL recipe import**: the web URL you provided **and** up to ~8,000 characters of text scraped from that webpage by the app, sent together to the AI for parsing.

We **do not** send your name, email address, location, household member names, or any other directly identifying information to the AI model.

Google's Gemini API processes the request and returns a result. Google retains prompts and responses for a limited period for abuse-monitoring purposes; please refer to Google's **Gemini API Additional Terms of Service** (https://ai.google.dev/gemini-api/terms) for the current details on Google's processing of API data. We do not separately control Google's retention.

### 2.4 Data stored only on your device

The following data is stored locally in the app's standard preference storage (**Android `SharedPreferences` / iOS `NSUserDefaults`**, which are **not** encrypted — do not assume secure storage) and is not transmitted to our servers:

- An "onboarding complete" flag;
- Pantry selections you make before signing up (held locally so you don't lose your work; transferred to your account when you sign up);
- A weekly recipe-generation counter and the timestamp the current week started (used to enforce free-tier limits before you sign up);
- A history of up to **50 recently generated recipes** (titles, ingredients, instructions, your bookmarks, ratings, and any collections you've assigned), used for offline access and quick reference;
- Internal one-time migration markers.

This data is **wiped when you delete your account** in the app. Signing out **does not** automatically wipe locally-cached recipe history; if you want it gone without deleting the account, also reinstall the app or use **Settings → Clear local cache** (once shipped).

### 2.5 Payment data

Subscription billing is handled by **RevenueCat** in partnership with the **Apple App Store** or **Google Play Store**. Card numbers, billing addresses, and payment processing are handled entirely by Apple, Google, and RevenueCat — **Elio never sees your payment details.**

We receive only:

- Whether you have an active subscription, and if so which tier;
- When the subscription started and renews;
- Whether you are in a free trial;
- A subscription identifier we alias to your account so we can sync entitlements across devices.

---

## 3. Why we collect this data and our legal bases

The legal basis we rely on depends on which jurisdiction's privacy law applies to you.

### 3.1 If you live in the United States

We collect and process your information based on the **notice provided in this Privacy Policy** and **your continued use of the app**, except where a US state law requires explicit opt-in consent. We **do** require explicit, in-app, opt-in consent before:

- Initialising **Firebase Analytics** or **Firebase Crashlytics**;
- Collecting or processing your **dietary requirements, allergies, or any other consumer health data** (required by Washington's My Health My Data Act — see §8b);
- Processing **sensitive personal information** as defined under California's CPRA;
- Sending you **push notifications** (via the OS-level permission prompt).

You can withdraw any of these consents at any time through Settings or by emailing **support@elio.app**.

### 3.2 If you live in the United Kingdom or the European Economic Area (UK/EU GDPR)

We rely on the following legal bases under Article 6 of the UK GDPR and EU GDPR:

| Purpose | Legal basis |
|---|---|
| Creating and running your account, syncing your pantry, processing your subscription | **Performance of a contract** (Art. 6(1)(b)) |
| Processing your dietary requirements and allergies | **Explicit consent** (Art. 9(2)(a)) — these are health-related "special category" data under Article 9 |
| Analytics, crash reporting, and any storage/access to your device for non-essential purposes | **Consent** (Art. 6(1)(a) and PECR / ePrivacy regulations) — collected via the in-app banner |
| Push notifications you've opted in to | **Consent** (Art. 6(1)(a)) |
| Responding to legal requests, preventing abuse, defending legal claims | **Legal obligation** (Art. 6(1)(c)) and **legitimate interests** (Art. 6(1)(f)) |
| Tax and billing records (held by Apple/Google/RevenueCat) | **Legal obligation** (Art. 6(1)(c)) |

You can withdraw consent at any time. Withdrawal does not affect the lawfulness of processing that occurred before withdrawal.

**Granular consent.** The consent banner is structured so that consent for dietary/allergy data, analytics, and crash reporting is granular and separately togglable. **Withdrawing your consent for dietary/allergy processing means the AI features that depend on it (recipe generation, meal plan, photo recipe import, receipt scanning) become unavailable, but the rest of the app — including viewing recipes you've already saved, manual pantry editing, manual meal-plan editing, and shopping list — continues to function**. This separation is intended to satisfy the requirement under Article 7(4) and EDPB Guidelines 05/2020 that consent be freely given and not bundled with contractual necessity.

---

## 4. Who we share data with (sub-processors)

We share data with the following service providers ("sub-processors") so the app can work. Each one is contractually required to protect your data and use it only for the purpose we engage them for.

| Sub-processor | Purpose | Where data is processed | More info |
|---|---|---|---|
| **Google LLC / Google Cloud / Firebase** (incl. Authentication, Firestore, Cloud Messaging, Crashlytics, Analytics, Remote Config) | Authentication, database, push messaging, crash reporting, analytics, remote configuration | US and global Google Cloud regions; transfers from UK/EEA protected by EU Standard Contractual Clauses and the UK International Data Transfer Addendum | https://firebase.google.com/support/privacy |
| **Google LLC (Generative AI / Gemini API)** | Recipe generation, photo and URL recipe import, receipt scanning, ingredient substitution | US data centres; transfers from UK/EEA protected by EU SCCs / UK IDTA | https://ai.google.dev/gemini-api/terms |
| **RevenueCat, Inc.** | Subscription management and entitlement | US data centres; transfers from UK/EEA protected by EU SCCs / UK IDTA | https://www.revenuecat.com/privacy |
| **Apple Inc.** | App Store payment processing on iOS, push notification delivery (APNs), Sign in with Apple where you choose to use it | Apple's global infrastructure | https://www.apple.com/legal/privacy/ |
| **Google LLC** (Google Play, Google Sign-In, Google Speech Services on Android, Google ML Kit via `mobile_scanner`) | Google Play payment processing on Android, OAuth sign-in, on-device speech recognition (which may transmit audio for processing depending on device settings), on-device barcode scanning (which may use Google Play Services for ML Kit) | Google's global infrastructure | https://policies.google.com/privacy |
| **Google Fonts** (CDN at `fonts.gstatic.com`) | Serving display fonts at runtime | Google's global CDN. _[Subject to publishing checklist item 6 — this row will be removed if Kate's final font set ships bundled as app assets.]_ | https://policies.google.com/privacy |

We **do not** share your data with advertisers, data brokers, marketing companies, or any third party for their own marketing purposes.

If we ever engage a new sub-processor, we will update this list before they start processing your data.

---

## 5. International transfers

Some of our sub-processors are based in the United States or process data outside the UK and EEA. Where this happens:

- **For UK/EEA users:** transfers are protected by the **EU Standard Contractual Clauses** approved by the European Commission, the **UK International Data Transfer Addendum**, and where applicable, certifications under the **EU–US Data Privacy Framework** and **UK–US Data Bridge** held by the receiving organisation (Google LLC is currently certified; we monitor the status of other sub-processors).
- **For US users:** your data is processed primarily in the US and may also be processed in any region where our sub-processors have infrastructure.

You can request copies of the relevant safeguards by emailing **support@elio.app**.

---

## 6. How long we keep your data

We keep your data for as long as your account exists. When you delete your account (currently by emailing **support@elio.app** with the subject "Delete my account", and in a future app version by tapping **Settings → Account → Delete account**), we erase your account, profile, pantry, recipes, ratings, meal plans, shopping list, household members, scanner-learning records, and push tokens from our active databases immediately.

Some residual data persists beyond account deletion:

- **Disaster-recovery copies** held by our cloud infrastructure provider (Google Cloud) are aged out under Google's standard infrastructure schedule. We do not maintain user-recoverable point-in-time backups.
- **Billing and subscription records** held by Apple, Google, and RevenueCat are retained by those parties as required for tax, accounting, and dispute purposes (typically several years), even after you delete your Elio account. We have no control over those retention periods.
- **Crashlytics** crash and error reports are retained by Google for **90 days** for non-fatal errors (Google's default; we have not modified it).
- **Firebase Analytics** event data is retained for **14 months** at user-level (the maximum Google offers); aggregate/anonymous statistics are retained longer.

If you would like a more detailed retention statement for a specific category, email us.

---

## 7. Your rights

The exact rights available to you depend on where you live (see below). For all rights, the easiest way to exercise them today is by emailing **support@elio.app** with the subject **"Privacy request"**. We will respond within 30 days (45 days for California residents where allowed by the CPRA, with notice).

A future version of the app will add **Settings → Account → Export my data** (a JSON export of everything we hold about you, in line with GDPR Article 20 portability) and **Settings → Account → Delete account** (in-app one-tap erasure). Until those tiles ship, all rights requests go through email.

### 7.1 Rights summary

| Right | Available to | How to exercise it |
|---|---|---|
| **Access / Know** — get a copy of your data | All users | Email us; we send a JSON file |
| **Correction / Rectification** | All users | Edit in the app, or email us |
| **Deletion / Erasure** | All users | Email us with "Delete my account"; in-app tile coming |
| **Portability** | UK/EEA + California users | The JSON export above is structured and machine-readable |
| **Opt out of sale or sharing** | California users (and other US states with similar laws) | We do not sell or share personal information for cross-context behavioural advertising. We honour the **Global Privacy Control (GPC)** signal where the platform supports it. To make an explicit opt-out request, email us. |
| **Limit use of sensitive personal information** | California users | Email us; we will limit processing to what is strictly necessary to deliver the service |
| **Withdraw consent** for analytics, crash reporting, dietary/health data, or notifications | All users | Toggle in **Settings → Privacy** (once shipped) or email us |
| **Object to processing based on legitimate interests** | UK/EEA users | Email us |
| **Restrict processing** | UK/EEA users | Email us |
| **Lodge a complaint** | UK: **Information Commissioner's Office** (https://ico.org.uk). EEA: your local supervisory authority (https://edpb.europa.eu/about-edpb/about-edpb/members_en). California: California Privacy Protection Agency (https://cppa.ca.gov). Washington: Washington State Attorney General (https://www.atg.wa.gov). |

We do not discriminate against you for exercising any of these rights. We will not charge for these requests unless they are manifestly unfounded or excessive.

### 7.2 Authorised agents

California and several other US state laws allow you to authorise an agent to act on your behalf. To do so, the agent must provide us with written, signed permission from you and verify their own identity. Email **support@elio.app** with the subject "Authorised agent request".

---

## 8. California residents (CCPA / CPRA)

This section supplements the rest of the policy and applies if you are a California resident.

### 8.1 Categories of personal information collected (last 12 months)

Under the CPRA's standard categories:

| CPRA category | Do we collect it? | Source | Purpose |
|---|---|---|---|
| Identifiers (e.g. email, account ID, device IDs) | Yes | You; your device | Account, service delivery, security |
| Customer records (name) | Yes (display name, optional) | You | Personalisation |
| Protected classifications | No | — | — |
| Commercial information (subscription state, usage counters) | Yes | You; the App Store / Play Store / RevenueCat | Billing, free-tier enforcement |
| Biometric information | No | — | — |
| Internet/device activity (analytics events, crash reports, screen views, app instance ID) | Yes (with consent) | Your device | Product improvement, debugging |
| Geolocation (country derived from IP) | Yes (coarse only) | Your device's IP | Localisation, regional store routing |
| Sensory data (voice audio for voice cooking; photos for recipe import / receipts) | Yes (only when you initiate) | You | Feature delivery |
| Professional / employment | No | — | — |
| Education | No | — | — |
| Inferences (taste profile, dietary profile user property) | Yes | Derived from your usage | AI personalisation |
| **Sensitive personal information** (account credentials, health-related data: dietary requirements + allergies) | Yes | You | Account access; AI personalisation. We do not use sensitive personal information beyond what is necessary to provide the service you've requested. |

### 8.1a Categories disclosed for a business purpose (preceding 12 months)

In the preceding 12 months we have **disclosed** the following categories of personal information to the sub-processors listed in §4 for the business purposes set out in this policy:

- Identifiers
- Customer records (display name, where provided)
- Commercial information (subscription state, usage counters)
- Internet/device activity (analytics events, crash reports, app instance ID)
- Coarse geolocation (country derived from IP)
- Sensory data (photos for recipe import / receipt scanning; voice audio routed to Google or Apple speech services)
- Inferences (taste profile)
- Sensitive personal information (account credentials; dietary requirements and allergies disclosed only to the sub-processors listed in the [Washington Consumer Health Data Privacy Notice](./wa-consumer-health-data-notice.md))

We have **not sold** or **shared** any category of personal information for cross-context behavioural advertising in the preceding 12 months.

### 8.2 Sources

We collect the categories above from: (i) you directly, when you sign up and use the app; (ii) your device, automatically (analytics, crash reports, push tokens); (iii) Apple, Google, and RevenueCat for subscription state.

### 8.3 Sale and sharing

**We do not sell personal information for money.** **We do not share personal information for cross-context behavioural advertising** as those terms are defined under the CPRA. We have not done so in the preceding 12 months and do not currently plan to.

We honour the **Global Privacy Control (GPC)** browser/device signal where it is technically detectable to us.

### 8.4 Retention

See §6.

### 8.5 Notice at collection

A condensed notice is presented in the app at the point of collection (during onboarding for dietary/allergy data; via the analytics consent banner for analytics). The full disclosures are in this Policy.

### 8.6 Your CPRA rights

See §7. To exercise any right, email **support@elio.app**.

**Verification of consumer requests.** We verify your identity by matching the email address you contact us from against the email on your account. For deletion requests and requests involving sensitive personal information, we apply the CPRA-mandated "reasonably high degree of certainty" standard by also requesting at least one additional matching data point — typically your account creation date, the device or sign-in method you most recently used, or a recent transaction identifier. We will not use the verification information for any other purpose.

### 8.7 Financial-incentive programs

We do **not** offer financial incentives in exchange for the collection, sale, retention, or processing of personal information. Subscription tiers (free/Pro) reflect feature differences only, not data-collection differences — Pro subscribers do not pay less and do not surrender additional data.

### 8.8 Contact

**Email:** support@elio.app
**Subject line:** "California privacy request"

---

## 8b. Washington residents — Consumer Health Data

If you are a Washington State resident, **dietary requirements and allergies you tell us are "consumer health data"** under Washington's My Health My Data Act (RCW 19.373).

A separate, dedicated notice covering this data — including how we collect, use, and share it; your rights to confirm, access, delete, and withdraw consent; and the appeal mechanism — is provided here:

> 📄 **[Washington Consumer Health Data Privacy Notice](./wa-consumer-health-data-notice.md)**

This standalone notice satisfies the distinct-notice requirement of RCW 19.373.020.

---

## 9. Children

Elio is not directed at children. **You must be at least 16 years old to use the app**, regardless of where you live.

**How we enforce this:** at sign-up, we present an age-attestation screen requiring you to confirm that you are 16 or older. We do not collect your date of birth — the attestation is a single confirmation step.

We do not knowingly collect personal information or consumer health data from anyone under 16. If we become aware that a user is under 16, we will delete the account and all associated data. If you believe a child has used the app and given us their data, contact **support@elio.app** and we will investigate and delete the account.

If you are between 16 and 18, we recommend that a parent or guardian reviews this policy with you.

---

## 10. Security

We protect your data using:

- **TLS encryption** for all data in transit between the app and our servers;
- **Encryption at rest** for data stored in Firebase and RevenueCat (provided by Google Cloud and AWS respectively);
- **Firestore Security Rules** that lock every user's data to that user's own account — no other user can read or write your data, and certain billing-related fields can only be written by our server;
- **OAuth tokens** rather than storing passwords ourselves where you sign in with Google or Apple.

Locally-cached data on your device is stored in standard preference storage, which is **not** encrypted at the application level (it is protected by your device's encrypted file system if you have a device passcode set). Do not assume secure storage for the local-cache items listed in §2.4.

No system is perfectly secure. If we ever become aware of a data breach affecting your account, we will notify you and the relevant supervisory authority within the timeframes required by applicable law:

- **EU/UK GDPR:** within 72 hours of becoming aware;
- **Washington State (RCW 19.255 / RCW 42.56.590):** as soon as possible and **no later than 30 days** after discovery, with notice to the WA Attorney General if 500+ Washington residents are affected;
- **California (Cal. Civ. Code §1798.82):** in the most expedient time possible and without unreasonable delay, with notice to the CA Attorney General if 500+ California residents are affected;
- **Other US states:** in line with each state's breach-notification statute.

---

## 11. Automated decision-making, profiling, and AI logic

Recipe suggestions, meal plans, and similar outputs are generated by a **large language model** (Google Gemini). At a high level, the model takes the following as input: your pantry, your dietary requirements, your appliances, your preferences, your taste profile (recipes you've previously liked or disliked), and any free-text request you've typed; and produces a recipe or meal plan as output.

This constitutes **profiling** within the meaning of GDPR Art. 4(4) — automated processing of personal data to evaluate aspects relating to a person, including dietary preferences. Under Art. 13(2)(f), we disclose:

- **The logic involved:** an LLM generates a candidate recipe by combining your pantry, dietary needs, appliances, preferences, and recent history into a prompt and selecting probable next words to form a recipe.
- **The significance:** recommendations only — they do not affect your access to the Service or to any external service. You always control whether to accept, edit, or ignore them.
- **The envisaged consequences:** you may be shown recipes more closely tailored to your stated preferences and pantry. You will not be shown recipes the model believes contain ingredients you've told us you can't eat — but the model can make mistakes, so always check (see the [Terms of Service §4](./terms-of-service.md#4-ai-generated-content)).

These suggestions are **not** automated decisions in the GDPR Article 22 sense — they have no legal or similarly significant effect on you. You can also opt out of AI features entirely by not using the recipe-generation, meal-plan, photo-import, URL-import, or receipt-scanning features.

---

## 12. Changes to this policy

We will update this policy when our practices change. The "Last updated" date at the top will reflect the most recent version. If the change is material (for example, adding a new sub-processor or a new category of data), we will notify you in the app or by email before the change takes effect.

We keep prior versions of this policy on request — email **support@elio.app**.

---

## 13. Contact

For any privacy question, request, or complaint:

**Email:** support@elio.app
**Subject line:** depends on your request — "Privacy request", "California privacy request", "Washington health data request", "Authorised agent request", etc.

We will respond within 30 days (45 for California / Washington residents where the law allows).
