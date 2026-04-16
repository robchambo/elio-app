# Onboarding Screen 15 — Soft account gate

**Step 15 of ~15** · Archetype: Conversion — sign-in / account creation
**Status:** Draft v1, awaiting Kate's design

---

## Objective

Persist the user's onboarding state (pantry, preferences, first recipe, subscription entitlement) to a real account so it survives device changes, reinstalls, and the move between platforms.

This is the final step. The user has:

- Spent ~3-4 minutes building their profile
- Seen a recipe that feels personalised
- Made a trial / free choice
- Invested enough that *they* want their state saved

Sign-in here is framed as "save what you just built", not "register to use the app". That framing matters — and so does having a real, non-punitive skip path (guest mode).

## Honest design principles

Account gates are the other place dark patterns grow. This screen follows three rules:

1. **Skip is real, not a dark pattern.** "Continue without an account" actually continues. No "Are you sure?" modal, no guilt copy, no forced path to email capture. The existing `guest_pantry` service makes this work.
2. **No email capture as a skip tax.** The "Continue without an account" link does not show an email form halfway through. It simply continues.
3. **Sign-in options at parity — no trickery.** Apple, Google, and Email sit as peer buttons. Platform convention dictates ordering, not our preference to harvest email addresses.

## Copy

### Headline (varies by screen 2 goal — per the overview personalisation matrix)

| Goal | Headline |
|---|---|
| Cook with what I've got (#1) | Save your pantry. |
| Waste less food (#2) | Save what you've got. |
| Decide dinner faster (#3) | Save your setup. |
| Feed the whole household (#4) | Save your household. |
| Stop ordering takeaway (#5) | Lock in your trial. *(If trial started on screen 14.)* · Save your setup. *(If Continue-with-Free.)* |
| *(fallback)* | Save your Elio setup. |

### Subhead (constant)

> Sign in to keep your pantry, recipes, and preferences across your devices. One tap.

### Sign-in buttons (peer buttons, full-width, stacked)

**Ordering** — platform-dependent:

- **iOS:** Apple → Google → Email
- **Android:** Google → Apple *(if built)* → Email

v1 Android ships without Apple Sign-In (Apple Sign-In is scoped for Sprint 19 / iOS launch per CLAUDE.md). Android v1 shows: Google → Email.

**Button labels:**

| Button | Label |
|---|---|
| Apple | Continue with Apple |
| Google | Continue with Google |
| Email | Continue with Email |

### Skip link (small, below the buttons, but prominent enough to be obvious)

> Continue without an account

### Footer (tiny, grey)

> By continuing, you agree to our Terms and Privacy Policy.

## Layout — iOS (Apple Sign-In required)

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ← prog │
│                                 │
│  Save your pantry.              │
│                                 │
│  Sign in to keep your pantry,   │
│  recipes, and preferences       │
│  across your devices. One tap.  │
│                                 │
│      ┌───────────────┐          │
│      │               │          │
│      │  [recipe      │          │
│      │   thumbnail]  │          │
│      │   + "Lemon &  │          │
│      │   Garlic…"    │          │
│      │               │          │
│      └───────────────┘          │
│                                 │
│  ┌───────────────────────────┐  │
│  │   Continue with Apple     │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │   Continue with Google    │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │   Continue with Email     │  │
│  └───────────────────────────┘  │
│                                 │
│    Continue without an account  │
│                                 │
│  By continuing, you agree to    │
│  our Terms and Privacy Policy.  │
└─────────────────────────────────┘
```

## Layout — Android v1 (no Apple Sign-In yet)

Same as above, but the Apple button is absent. Google button moves to top slot.

## Visual spec

- **Progress bar remains visible** at full (15/15 ≈ 100%). A near-full bar creates subtle "you've done the work — just save it" momentum.
- **Recipe thumbnail** — small card at top, ~80pt tall, showing the generated recipe's hero photo + title. Caption below it in small text: "Your first recipe." Anchors the "save" language to something real.
- **Sign-in buttons** — full-width, rounded, stacked with 10pt gaps.
  - **Apple:** black fill, white text + Apple glyph. Follows Apple's HIG exactly (required for App Store approval).
  - **Google:** white fill, Google colour glyph, navy text. Follows Google's brand guidelines.
  - **Email:** off-white fill, navy text, small envelope icon. Our own styling, but clearly of a kind with the others.
- **"Continue without an account"** — plain text link, centred, secondary colour, 14pt. **Not** a ghost button. Not the same weight as the sign-in buttons. But not hidden, not tiny, and not behind a "Not now" modal.
- **Footer legal** — 11pt grey, two lines max. Terms and Privacy are tappable and open external browser or in-app web view.
- **No loading state for page entry** — everything here is already local.
- **Motion** — recipe thumbnail fades in first (reinforces "this is yours"), then headline, then buttons stagger in (30ms), then skip link appears. Total ~400ms.

## Sign-in flow behaviour

### Apple (iOS)

1. Tap → system Sign in with Apple sheet.
2. Success: Firebase Auth handles the credential exchange (existing `AuthService`). Map to a Firebase user.
3. Migrate guest state (see below).
4. Advance to the home screen (end of onboarding).

### Google

1. Tap → Google Sign-In native flow (existing `AuthService`).
2. On success: Firebase Auth, migrate state, advance.

### Email

1. Tap → inline email + password form OR passwordless magic-link flow (Rob's call — recommendation below).
2. **Recommendation: passwordless magic link.** Skips password friction; matches the trust tone. If existing app only supports password auth, use that for v1 and flag magic-link as a follow-up.
3. On success: Firebase Auth, migrate state, advance.

### Skip (Continue without an account)

1. Tap → persist all onboarding state to the existing `guest_pantry` service (local-only).
2. Advance to home screen as a guest user.
3. User can sign in later from Settings; their guest state migrates on first sign-in (see below).

## Guest-to-account state migration

When a user signs in after being in guest mode (either immediately on this screen, or later from Settings), migrate:

| Local source | → Firestore target |
|---|---|
| `guest_pantry.inventory` | `inventory/` (write each item with the signed-in UID scope) |
| `guest_pantry.tierMemory` | `users/{uid}/tierMemory/` |
| `OnboardingState` (goal, dietary, allergies, household, time, confidence, appliances, region, units) | `users/{uid}` doc fields |
| First recipe (from screen 13) | `recipes/{id}` (user-scoped) + `users/{uid}/recipeHistory` |
| RevenueCat entitlement | Already handled by RC's `logIn(uid)` call |

Migration is idempotent — running it twice on the same data produces the same result. Rob should confirm the existing `AuthService.onSignIn` hook handles this; if not, add a `GuestMigrationService` that fires once on first authenticated session post-onboarding.

### Edge: user signs in with an existing account that already has Firestore state

Merge strategy:

- **Preferences** (dietary, allergies, household, etc.): existing account wins. Onboarding answers from this session are discarded. Show a one-time toast on home screen: "Welcome back — we kept your existing preferences."
- **Pantry**: union of both. Deduplicate via `pantry_utils` fuzzy match.
- **Entitlement**: RevenueCat is source of truth; take whichever is active.
- **First recipe**: add to history; don't conflict.

This behaviour is conservative — never overwrite existing-account data with onboarding state. An existing user re-running onboarding (reinstalled, signed in again) gets their old life back, not a reset.

## Personalisation — how earlier answers land here

Only the headline varies by goal (per the screen 2 matrix). Everything else — subhead, buttons, skip, footer — is constant.

The recipe thumbnail at the top uses the recipe generated on screen 13. If the user skipped the recipe (error state), the thumbnail is replaced with a soft illustration of a filled pantry + a caption: "Your pantry is ready."

## What Kate decides

- **Apple button styling on dark mode** — Apple HIG has specific rules; ensure we match for App Store review.
- **Google button styling** — follow Google brand guidelines exactly; no customisation.
- **Email button treatment** — custom, must feel of a kind with the branded buttons. Rob's default: off-white fill, navy text, subtle border, envelope icon — same geometry as Apple/Google.
- **Skip link prominence** — 14pt plain text link is the default. Kate may want it slightly larger or with a subtle underline. Do NOT make it smaller or greyer than specified.
- **Recipe thumbnail shape** — same as in-app recipe card, or a reduced version (just title + photo, no meta row). Rob's default: reduced — this screen isn't about the recipe, it's about saving it.
- **Transition from paywall** — paywall has no progress bar, this screen restores it. Kate may want a subtle progress-bar-fade-in to mark the return. Nice-to-have.

## Why these decisions

- **Sign-in at the end, not the start.** The user has experienced the product, made a paywall decision, seen their recipe. Asking them to sign in now carries the weight of "keep what I just built" rather than "let me in". This is the core insight behind the whole redesign.
- **Three peer providers.** Some users only trust Apple. Some only trust Google. Some want email. Forcing any one of them is lossy. The cost is three buttons; the benefit is not dropping users at the final conversion point.
- **Skip is a visible option.** Guest mode has real engineering cost (the `guest_pantry` service), and we built it because we don't want to lose users who aren't ready to commit to an account. Hiding the skip after having built it is self-sabotage.
- **Recipe thumbnail as anchor.** "Save your pantry" is abstract. "Save this: <recipe card>" is concrete. The thumbnail earns its pixels by giving the ask a specific referent.
- **Guest-to-account migration on first sign-in.** Users who skip initially but sign in later shouldn't lose their pantry. Migration is idempotent so implementation is safer.
- **Existing account wins on conflict.** Returning users never get their historical data stomped by onboarding answers. This is a trust issue more than a data issue — users who discover their preferences were overwritten by "Dietary: No restrictions" in a re-onboarding will never trust the app again.
- **Progress bar reappears at 15/15.** Completion is worth marking. Paywall was an aside; we're back in the flow and it's finished.
- **No loading state on entry.** Nothing here is async until the user taps. Spinners for nothing erode trust.
- **Passwordless magic link (if feasible).** Passwords are friction + reset flows + a whole support surface. If the app's existing auth supports email-link sign-in (Firebase does), use it. Flag as v1.1 if the auth stack isn't there yet.

## Edge cases & states

### Provider-specific

- **Apple declines to provide email** (user selects "Hide My Email"): standard Firebase + Sign in with Apple behaviour — stores the relay address. No onboarding-specific handling needed.
- **Google account has no primary email on the device:** rare but happens. Google Sign-In returns an error; toast: "Couldn't sign in with Google — try Email instead."
- **Email already exists as a different provider** (user tries Email with an address linked to Google): Firebase throws `auth/account-exists-with-different-credential`. Surface a helpful toast: "You already use Google for this email — tap Continue with Google."

### Network

- **Offline on entry:** buttons are still tappable; tap triggers an inline "No connection — reconnect and try again" toast. "Continue without an account" always works (it's local-only).
- **Offline mid-sign-in:** auth errors out; user stays on this screen with a retry affordance.

### Back / forward

- **Back arrow → screen 14 (Paywall).** The paywall is a closed-state decision (trial started or Free chosen), so going back doesn't re-fire the trial purchase — it just returns to view. Tap forward re-enters this screen.
- **Successful sign-in → home screen.** End of onboarding flow. Onboarding state is persisted; user lands on the generate button.
- **Skip → home screen as guest.**

### Tried-to-sign-in-failed-then-skip

User taps "Continue with Google" → fails (network), taps "Continue without an account" → proceeds as guest. State: entirely preserved. No trapped users.

### Dev account

Same as paywall: dev accounts auto-activate Pro. Sign-in still goes through real Firebase Auth; Pro entitlement derives from the allowlist in `EntitlementService`.

### Accessibility

- **Sign-in buttons** announce as "Continue with Apple, button" / "Continue with Google, button" / "Continue with Email, button". Provider names not truncated by VoiceOver.
- **Skip link** announced as "Continue without an account, text button." Explicit that it proceeds.
- **Recipe thumbnail** has alt text: "Your first recipe: Lemon & Garlic Chicken Traybake."
- **Focus order:** thumbnail → headline → subhead → Apple/Google → Email → Skip → Terms/Privacy. Tabable on Android/web.
- **Reduced Motion:** skip entrance stagger.

### Analytics

```
onboarding_account_viewed                 { goal, has_trial: bool }
onboarding_account_signin_tapped          { provider: "apple" | "google" | "email" }
onboarding_account_signin_success         { provider }
onboarding_account_signin_failed          { provider, error }
onboarding_account_skipped                { has_trial: bool }
onboarding_complete                       { path: "account" | "guest", has_trial: bool }
```

`onboarding_complete` is the top-of-funnel success event. Its cardinality across `path` and `has_trial` produces the four outcome buckets we care about post-launch.

### Onboarding completion state

On any forward exit (sign-in success OR skip), the onboarding controller sets `onboardingComplete = true` and persists to SharedPreferences. Subsequent app launches skip straight to home. If the user later signs out and back in, onboarding does not re-run.

## Behaviour

1. On entry: fire `onboarding_account_viewed`. Render headline, thumbnail, buttons, skip.
2. Tap an auth provider → fire `signin_tapped`, invoke the existing `AuthService` flow.
3. On success → fire `signin_success`, run guest-to-account migration, mark onboarding complete, advance to home.
4. On failure → fire `signin_failed`, show inline toast, remain on screen.
5. Tap **Continue without an account** → fire `account_skipped`, persist onboarding state to `guest_pantry`, mark onboarding complete, advance to home as guest.
6. Back arrow → return to screen 14. State preserved.

---

## Flag for implementation

- Reuse the existing `AuthService` and Firebase Auth wiring. Do not fork.
- Guest-to-account migration: confirm whether `AuthService.onSignIn` already migrates guest state; if not, add `GuestMigrationService.migrateFromGuest(uid)` called on first authenticated session.
- Existing-account conflict resolution: on sign-in, compare `users/{uid}` existence. If it exists, take the existing-wins-on-prefs, union-on-pantry path described above. If it doesn't, the migration path is a clean write.
- Apple Sign-In is iOS-only for v1 (Android Sprint TBD per CLAUDE.md launch strategy).
- All button styling must match the provider brand guidelines exactly — required for App Store / Play Store approval.
- The skip path must not touch any code that requires authentication. Guest mode is self-contained per `guest_pantry`.

---

## Post-onboarding — deferred work (flagged for after onboarding ships)

Per the memory pointer and the screen 4 personalisation note:

- **"Add household profile" home-screen nudge**, triggered when `householdHasDifferingDiet == true` from screen 4. Shows a one-time card: "Tell us about the others in your household → Add profile." Opens the existing household profile flow. Lives outside onboarding but is owed by it.
