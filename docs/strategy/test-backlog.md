# Elio — On-Device Test Backlog

**Active integration branch:** `sprint/16-integration`
**Current build to test:** `releases/elio-sprint-integration.apk` (canonical filename — always the latest)
**Build tag:** see `git tag --list 'build/sprint-integration*'` (each rebuild stamps a tag with the commit hash)

**Convention:**
- `[ ]` pending on-device test
- `[~]` tested, issue found (notes follow inline)
- `[x]` signed off — safe to merge / push / tag

When a section is fully `[x]`, move it to the **Signed off** section at the bottom (or just delete).

---

## Currently pending (one APK, one list)

This is the consolidated list of everything not yet verified against the current `elio-sprint-integration.apk` build. Grouped by area for scannability, **not** by commit / sub-branch. New on-device work-items land here.

### A. Auth + onboarding

Bugs originally reported on the pre-merge APK that were testing OLD auth code. **Auth UX fix is now in this build** (commit `8fbc553`, merged in via `e23c0d4`).

- [ ] **Open the app cold.** If you've completed onboarding before, you should land directly on the AppShell — no 15-screen replay. (If you're not signed in, the data-on-install behaviour is separate; see footnote.)
- [ ] **Sign In tile is visible on AccountScreen when guest.** Top of the Account section.
- [ ] **Tap Sign In tile** → pushes EmailLoginScreen → log in → lands on AppShell signed in.
- [ ] **Sign Out from signed-in state** → confirm dialog → user lands on AppShell **still post-onboarding, as a guest** (no 15-screen replay). Sign In tile visible again.
- [ ] **Restart Onboarding tile** under About → confirm dialog → walks through onboarding from screen 1.
- [ ] **Delete Account flow unchanged** — re-auth dialog works, account wipes correctly (existing Sprint 17 behaviour preserved).

### B. Settings tree (Sprint 16.1)

- [ ] **4-section tree renders:** Household, Preferences, Account, About — expected tiles in each.
- [ ] **Inline Measurement Units segmented control** (Metric ↔ Imperial) toggles, persists, and propagates to recipe display.
- [ ] **Inline Region segmented control** (US ↔ UK) toggles, persists.
- [ ] **Saver Mode default switch** persists across app restart.
- [ ] **Manage Subscription** tile → correct snackbar pointing to Play / App Store.
- [ ] **Privacy Policy** + **Terms of Service** open in-app via `LegalDocScreen` (markdown render).
- [ ] **Export My Data** — guest sees "Sign in to export" snackbar; signed-in user gets DataExportService share sheet.
- [ ] **Send Feedback** dialog — support email shown, tap-to-copy works.
- [ ] **App Version row** shows the build's semver.

### C. Dietary + allergen safety (retests on the new APK)

Most of these were originally failing on the pre-merge APK. Four merged commits target them: `f8ce971` (unify dietary plumbing), `7f322ab` (force-refresh singleton at every generation entry point), `7c5b33f` (canonicalise tokens), `616eb35` (verify-after-save read-back). Should now pass.

- [ ] **Dietary change reflects in the very next generation.** Open AccountScreen → Dietary → toggle a new allergen on (e.g., Peanut-free) → back → generate a new recipe. The position-1 allergen preamble in the prompt must include the new constraint immediately. **No need to kill the app**.
- [ ] **Allergens stamped on recipe.dietaryTags.** Generated recipe's data should include the allergen tag (e.g., "Peanut-free"). Backed by commit `a5570b6`.
- [ ] **Allergen pill displayed on the recipe.** Currently the stat-badge area only shows `r.dietaryTags.first` — if peanut-free isn't the first tag, it won't appear. **If the pill is missing, this is a UI fix on top.** Flag what you see.
- [ ] **Position-1 allergen preamble** in the Gemini prompt — already covered by `docs/strategy/2026-05-06-allergen-testing-procedure.html`. Run that protocol separately and tick this when it passes.

### D. Household members

- [ ] **Add a household member** via Settings → Household → Add member. Member appears immediately in the list (no need to sign out and back in).
- [ ] **Remove a household member** via the same flow. Member disappears immediately.
- [ ] **Member edits** (name + dietary) save and reflect immediately.
- [ ] **Free-tier user** tapping Add member sees the Pro paywall.

> Originally reported on the pre-merge APK. The dietary-plumbing rewrite may have either fixed or accidentally regressed this surface. Retest from scratch.

### E. Pantry tab

- [ ] **Hundreds of duplicates from legacy data** → **long-press "what did you pick up?"** page title → snackbar reports "Cleaned up N duplicates" with N > 0 (was zero on the old APK — bug fixed in commit `b7e1820`). Duplicates disappear from the list.
- [ ] **Perishable chip urgency colours:** items with expiry in the past or today show **tinted-red background + saturated red border + red dot**. Items 1–6 days out show **tinted-orange background + terracotta border + orange dot**. Items 7+ days out show **tinted-green background + green border + green dot**. Items with no expiry keep cream background + rule border + no dot.
- [ ] **Existing 8×8 leading dot still renders** on perishable chips alongside the new background (belt-and-braces signal for colour-blind accessibility).
- [ ] **Pantry Builder + Add chip** per-tier still works. Custom items persist across reopens.
- [ ] **Per-tier + Add chip** (the "+" pill leading each tier section) still works (Sprint 16.4 affordance).

### F. Recipe screen — cooking timers (Sprint 16.6)

- [ ] **Open any saved/generated recipe with cookable times** (e.g. "Bake for 25 minutes"). The time text inside the step prose renders as a small terracotta pill. Steps without parseable times render plain — no layout break.
- [ ] **Tap an inline time pill** → bottom-sheet picker opens with the matched duration pre-selected.
- [ ] **Tap "Start 25-minute timer"** → sheet dismisses, sticky terracotta timer bar appears at top of body.
- [ ] **Timer counts down VISIBLY at 1-second cadence** — chip text updates each second (mm:ss format). This was broken on the previous APK; fixed in `b7e1820`.
- [ ] **Tap the running chip** → pauses (chip turns mocha-grey, dot disappears, countdown freezes).
- [ ] **Tap the paused chip** → resumes from the frozen remaining time (not a fresh start).
- [ ] **Long-press a chip** → confirm dialog → "Cancel timer" removes chip; "Keep" leaves it running.
- [ ] **Multi-timer:** start two timers on different steps → both visible at the top.
- [ ] **Max-concurrent cap:** start 5 timers → trying a 6th → snackbar "You have the maximum number of timers running."
- [ ] **Expiry alert (foreground):** timer hits zero → haptic buzz, TTS speaks "Step N timer done", snackbar appears with OK button → OK removes chip.
- [ ] **Custom duration:** tap "custom…" chip → Material time picker (24h mode) → pick a non-standard duration → returns to picker → Start works.
- [ ] **Range "2–3 minutes" is deliberately skipped** — no pill rendered for ambiguous ranges. By design (not a bug).
- [ ] **No regressions:** servings adjust, ingredient swap, side dish gen, hands-free voice, share, bookmark, generate-another, feedback bar — all still work.

### G. Wakelock while cooking timers active

- [ ] **Screen stays on while a timer is active.** Start a timer → leave phone untouched past your auto-lock threshold → screen does NOT lock.
- [ ] **Cancel last timer** → wait past auto-lock → screen locks normally.
- [ ] **Navigate away from RecipeScreen** while a timer is running → wait past auto-lock → screen locks (wakelock dropped on screen leave).

### H. Shopping list

- [ ] **"N items added" snackbar dismisses cleanly.** Add ingredients from a recipe → toast appears → it should dismiss when its duration elapses AND on tapping View AND when you navigate to a different screen. (Originally persisted across screens on the pre-merge APK — fixed by commit `c24ae94`.)
- [ ] **Aisle grouping** of items still works.
- [ ] **Share** button still works.
- [ ] **Pantry → Shopping list "Restock" bridge** (Sprint 16.6.x). Open Pantry tab → expand a tier → long-press a chip → pick **Mark running low**. Snackbar confirms. Chip now shows a small terracotta **Low** badge. Open Shopping tab → the item is there with a **Restock** pill (no quantity text). Long-press the same chip again → **Unmark running low** removes the chip's Low badge AND clears the matching Restock entry from the shopping list.

### I. Scanner

- [ ] **Receipt scanning** with a real grocery receipt — items extracted correctly with appropriate tier guesses.
- [ ] **Tax-form / non-receipt scan** → returns "no food items found" copy. Currently terse — flag if the copy needs softening to "this doesn't look like a grocery receipt".
- [ ] **Barcode scanning** of a food product → metadata pulled from Open Food Facts.

---

## Feature requests (post-test cleanup)

Things Rob asked for that aren't regressions — track separately so the bug list stays a bug list.

- [ ] **Small X to delete pantry items.** Re-add an explicit small X icon on each pantry chip so deletion is a one-tap-on-a-small-target action rather than long-press → SimpleDialog → Remove. Different from the Sprint 16.4 single-tap-removed pattern (which deleted the whole chip on a stray tap on the chip body); a small X is its own hit-target and doesn't conflict with long-press or chip-area gestures.

---

## Signed off

(empty — first build of the consolidated era)

---

## How to use this doc

When you sit down with the device, work through "Currently pending" top-to-bottom. Tick boxes as you go. For any `[~]` (tested, issue found), jot the symptom inline below the line — that's what I work from to fix it. When a whole section is `[x]`, move it down to **Signed off** or delete.

I (Claude) update this doc every time we ship something testable so it always represents what's on the current APK. The HTML mirror at `docs/strategy/2026-05-11-test-list.html` is the shareable / printable view of the same content — use whichever surface you prefer.

---

> **Footnote on data-on-install:** if `adb install` doesn't preserve app data between builds (e.g. signing-key mismatch from building on a different machine, or you manually uninstall first), `SharedPreferences.onboardingComplete` gets wiped and you'll be sent through onboarding on first open. The auth UX fix can't help with that — it only fixes the within-install case (signing out and signing back in). The proper fix for cross-install data persistence is a release keystore + consistent `--install` behaviour, which is Sprint 17 launch-readiness work.
