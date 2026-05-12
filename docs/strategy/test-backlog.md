# Elio — On-Device Test Backlog

**Living doc.** Each entry sits here from "code shipped, awaits on-device verification" through "tested on-device, signed off". Move to a new "Signed off" section (or just delete) once a verification passes. New code-side work adds entries.

**Convention:**
- `[ ]` pending on-device test
- `[~]` tested but issues found (notes follow)
- `[x]` signed off — safe to merge / push / tag

---

## Currently pending (newest first)

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
