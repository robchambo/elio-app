# Elio — On-Device Test Backlog

**Living doc.** Each entry sits here from "code shipped, awaits on-device verification" through "tested on-device, signed off". Move to a new "Signed off" section (or just delete) once a verification passes. New code-side work adds entries.

**Convention:**
- `[ ]` pending on-device test
- `[~]` tested but issues found (notes follow)
- `[x]` signed off — safe to merge / push / tag

---

## Currently pending (newest first)

### Sprint 16.6 wakelock + dietary-tile regression tests — `sprint/16.6-quick-wins` (commit hash TBD)

Layered on top of cooking timers v1:

- [ ] **Screen stays on while a timer is active.** Start a timer → leave the phone untouched for longer than your usual auto-lock threshold (e.g. 60s with default Android settings). Screen should remain on. Lock-screen should NOT engage.
- [ ] **Screen auto-locks normally once all timers are done / cancelled / dismissed.** Wakelock is edge-triggered, so this catches the disable path. Test by: cancel the last running timer → wait past your auto-lock threshold → screen should lock.
- [ ] **Navigating away from RecipeScreen drops the wakelock.** Start a timer → tap back to Home → wait past auto-lock → screen should lock normally (we drop wakelock unconditionally in `dispose`).
- [ ] **No on-device check needed for the dietary blocked-state widget tests** — they're regression guards added at the code-side test layer (4 new tests in `test/widgets/elio_pantry_item_tile_test.dart`). Sprint 15.9 pre-merge nit ticked off.

### Sprint 16.6 cooking timers — `sprint/16.6-quick-wins` at `26f7dcb`

Paprika-style inline tappable times in step text + sticky timer bar at top of RecipeScreen. Mockup: `docs/strategy/2026-05-11-cooking-timer-mockup.html`. Android-only for v1 (in-foreground delivery); backgrounded local notifications + wakelock deferred to follow-ups.

- [ ] **Open any saved/generated recipe with cookable times** in the method (e.g. "Bake for 25 minutes"). Verify the time text "25 minutes" renders as a small terracotta pill inside the step prose. Steps without parseable times render as plain prose unchanged.
- [ ] **Tap an inline time pill** → bottom-sheet picker opens with the matched duration pre-selected (e.g. "25 min"). Tap "Start 25-minute timer" → sheet dismisses, sticky terracotta timer bar appears at top of body.
- [ ] **Timer counts down visibly** at 1-second cadence. mm:ss format under 1 hour, h:mm:ss at or over 1 hour.
- [ ] **Tap the running chip** → pauses (chip turns mocha-grey, dot disappears, countdown freezes).
- [ ] **Tap the paused chip** → resumes from the frozen remaining time (not a fresh start of the planned duration).
- [ ] **Long-press a chip** → confirm dialog ("Cancel timer?"). Tap "Cancel timer" → chip disappears. Tap "Keep" → chip stays.
- [ ] **Multi-timer**: start two timers (different steps) → both chips visible in the timer bar.
- [ ] **Max-concurrent cap**: start 5 timers → trying to start a 6th surfaces snackbar "You have the maximum number of timers running."
- [ ] **Expiry while app is foreground**: timer hits zero → haptic buzz, system alert sound, snackbar "Step N timer done" with OK button. Tap OK → chip removed.
- [ ] **Expiry while app is backgrounded** (deferred): currently does NOTHING in v1 — Dart timers pause when the app is suspended. flutter_local_notifications is a follow-up. Verify this is the actual behaviour so we know what to ship next.
- [ ] **Custom duration**: tap the "custom…" chip in the picker → Material time picker opens (24h mode) → pick a non-standard duration (e.g. 12 min) → returns to picker with "custom…" chip selected. Tap Start.
- [ ] **Decimal / range edge cases**: a step containing "1.5 hours" should NOT render as a time pill (parser rejects decimals). A step containing "5-10 minutes" should NOT render as a time pill (parser rejects ranges).
- [ ] **No regressions**: existing RecipeScreen functionality (servings adjust, ingredient swap, side dish gen, hands-free mode, share, bookmark, generate-another, feedback) all still work.

### Sprint 16.6 quick wins — `sprint/16.6-quick-wins` at `4ba90a2`

Off `sprint/16`, decoupled from 16.1 test path. Visual / model-cleanup only — safe to test alongside 16.1.

- [ ] **Perishable chip background + border colour** on Pantry tab. Items with expiry in the past or today should show tinted-red bg + saturated red border. Items 1–6 days out should show tinted-orange bg + terracotta border. Items 7+ days out should show tinted-green bg + green border. Items with no expiry (staples / almost-always-have) should keep the cream bg + rule border as before.
- [ ] **Existing leading dot still rendered** on perishable chips (8×8 px circle, saturated dot colour). Should look like a small belt-and-braces signal alongside the background tint.
- [ ] **Pantry Builder + Add flows unchanged** — adding an item via the per-tier `+ Add` chip, the builder sheet, and onboarding should all still work. (No code change to those paths, but `PantryMemoryEntry.isCustom` was dropped — sanity check that custom items still appear in the builder.)

### Sprint 16.1.x Auth UX fix — `sprint/16.1-settings-redesign` at `8fbc553`

Local-only commit on top of Sprint 16.1 settings redesign. Awaiting weekend test protocol pass (`docs/strategy/2026-05-07-weekend-test-protocol.html`).

- [ ] **Guest user sees Sign In tile** at the top of AccountScreen → Account section. Tile is hidden when signed in.
- [ ] **Tap Sign In** → pushes EmailLoginScreen → on successful login, lands on AppShell signed in (Pro features unlocked if user is a dev / Pro tester).
- [ ] **Sign Out from signed-in state** → confirm dialog → user lands on AppShell **as a guest, still post-onboarding** (no 15-screen replay). Sign In tile visible again on AccountScreen.
- [ ] **Restart Onboarding tile** appears under About section. Tap → confirm dialog ("This signs you out and walks you through setup again...") → walks through onboarding from screen 1.
- [ ] **Delete Account flow unchanged** — Sprint 17 deletion still wipes onboardingComplete (intentional — account is gone). Verify the existing delete flow still works end-to-end with re-auth dialog.
- [ ] **Restore Purchases + Manage Subscription tiles** still visible to both guest and signed-in users (no Firebase auth needed for either).

### Sprint 16.1 Settings redesign — `sprint/16.1-settings-redesign` through `55a144f`

The 4-section Settings tree + unified dietary plumbing. Weekend test protocol covers the bulk of this.

- [ ] **4-section tree renders** — Household, Preferences, Account, About — with the expected tiles in each.
- [ ] **Inline segmented controls** — Measurement Units (Metric ↔ Imperial) and Region (US ↔ UK) toggle and persist. Switching units propagates to recipe display across the app.
- [ ] **Saver Mode default switch** persists across app restart.
- [ ] **Dietary screen save** — change a dietary toggle → the recipe-generation prompt picks it up on the very next generation (no need to kill the app). Verify the position-1 allergen preamble reflects the change.
- [ ] **Manage Subscription** snackbar — correct copy pointing to Play / App Store.
- [ ] **Restore Purchases** — non-RC build shows the no-op snackbar; RC build pulls down entitlements.
- [ ] **Privacy Policy + Terms of Service** open in-app via LegalDocScreen (markdown render).
- [ ] **Export My Data** — guest sees "Sign in to export" snackbar; signed-in user gets a DataExportService share sheet.
- [ ] **Send Feedback** dialog shows support email + tap-to-copy works.
- [ ] **App Version row** shows the build's semver.
- [ ] **Allergen / dietary safety hardening** (the eight commits on sprint/16): verify allergens stamped on recipe.dietaryTags, post-gen allergen filter, position-1 preamble — covered separately by `docs/strategy/2026-05-06-allergen-testing-procedure.html`.

---

## Recently signed off

(empty — first version of this doc)

---

## Active branches at a glance

| Branch | Tip | Status |
|---|---|---|
| `main` | Sprint 16 rebrand merged + tagged `v0.16.0-rebrand` | stable; not currently touched |
| `sprint/16` (origin) | `4628719` — safety/dietary audit + sprint 16.4 polish + 15.9.x dedup + 15.9.2 warmup | stable base for new sprint branches |
| `sprint/16.1-settings-redesign` | `8fbc553` local (Auth UX fix) on top of `55a144f` origin (settings tree + dietary plumbing) + `d5d9cc9` local (16.7a household sharing spec docs) | awaiting weekend on-device test |
| `sprint/16.6-quick-wins` | `4ba90a2` local | awaiting on-device chip-colour verification |

---

## How to use this doc

When you ship code-side work, add an entry under "Currently pending" with the branch + commit hash and the things to actually look at on-device. When you sit down with a device, work through the unchecked boxes top-to-bottom. Tick them as you go, jot notes inline for anything that's off, and move the whole entry to "Recently signed off" when every box is `[x]`.

I (Claude) will keep this updated each time we ship something testable. You drive the device side; I keep the list honest.
