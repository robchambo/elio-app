# Onboarding Screen 3 — Household

**Step 3 of ~15** · Archetype: Single-select + count
**Status:** Draft v1, awaiting Kate's design

---

## Objective

Find out who the user is actually cooking for. Two things captured here: **household type** (shape) and **total count** (portions). Feeds recipe portion sizing, the paywall's "one plan for the whole house" angle, and the tone of downstream screens (a solo cook gets different language than a family of five).

Kept deliberately light. Individual household members (names, differing dietary needs) are captured later — screen 4 asks "does anyone else differ?" — so this screen stays at two taps.

## Copy

**Headline (large, bold):**
> Who are you cooking for?

**Subhead (one line, lighter weight):**
> We'll size recipes and plan around your household.

**Household type (single-select, vertical cards):**

| # | Label | Subtext | Default count |
|---|---|---|---|
| 1 | Just me | Solo cooking, one plate to please | 1 |
| 2 | Me and my partner | Two adults, one kitchen | 2 |
| 3 | Family with kids | Little ones, teens, or a mix | 4 |
| 4 | Flatmates or housemates | Shared kitchen, shared shopping | 3 |
| 5 | Something else | Tell us the headcount and we'll sort the rest | 2 |

**Count (appears once a type is selected):**
> How many in total?
> `[ − ]   3   [ + ]`   *(range 1–10)*

**Primary CTA (full-width, disabled until type + count valid):**
> Continue

*(Personalisation note for "Feed the whole household" goal from screen 2: the subhead becomes "We'll make sure everyone's covered." per the overview matrix.)*

## Layout

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓▓▓░░░░░░░░░  ← progress   │
│                                 │
│  Who are you cooking for?       │
│                                 │
│  We'll size recipes and plan    │
│  around your household.         │
│                                 │
│  ┌───────────────────────────┐  │
│  │ 🧍  Just me                │  │
│  │     Solo cooking, one…    │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 👥  Me and my partner      │  │
│  │     Two adults, one…      │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 👨‍👩‍👧 Family with kids      │  │
│  │     Little ones, teens…   │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 🏠  Flatmates or housemates│  │
│  │     Shared kitchen…       │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ ✨  Something else         │  │
│  │     Tell us the headcount…│  │
│  └───────────────────────────┘  │
│                                 │
│  How many in total?             │
│    ┌─────┐  ┌───┐  ┌─────┐      │
│    │  −  │  │ 3 │  │  +  │      │
│    └─────┘  └───┘  └─────┘      │
│                                 │
│  ┌───────────────────────────┐  │
│  │       Continue            │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## Visual spec

- **Cards** — same system as screen 2 (full-width, rounded, amber border + tick on select).
- **Icons** — 5 custom icons matching screen 2's set. Style: `household_solo.svg`, `household_couple.svg`, `household_family.svg`, `household_flat.svg`, `household_other.svg`. Emoji above are v1 stopgap.
- **Count stepper** — appears beneath the selected card with a 200ms fade+slide; before any selection it's hidden entirely. Large touch targets on − and +; the number in the middle is read-only (no text input). Min 1, max 10.
- **Stepper states** — − disabled at 1, + disabled at 10. Disabled state: 40% opacity, no press effect.
- **Default count** populated from the type's default (see table) when the card is first tapped. If the user changes type, count re-defaults — unless they've manually edited it, in which case preserve their number (see Edge cases).

## Personalisation — how this feeds downstream

| Downstream screen | Change based on household |
|---|---|
| **Screen 4 Dietary** | If count > 1, add "Does anyone else in your household have different needs?" toggle. If count = 1, skip that question. |
| **Screen 11 Pantry build** | Quantity defaults (e.g. "pack of chicken thighs" vs "two packs") scale loosely with count. |
| **Screen 13 First recipe** | Recipe `servings` field set to household count. Visible as "Serves 3 — your household" on the card. |
| **Screen 14 Paywall** | For `Family with kids` + count ≥ 3: lead with "One plan that covers everyone." For `Just me` + count = 1: lead with the goal-matched headline instead (household isn't a pain point). |
| **Ongoing recipe generation** | `servings` defaults to household count for every generation; user can still override per-recipe. |

Household state persists as:

```
users/{uid}.householdType: enum        // solo | couple | family | flat | other
users/{uid}.householdCount: int        // 1-10
```

No `householdProfiles/` subdocs are created yet — those come later (post-onboarding, if the user opts into differing-needs flow on screen 4).

## What Kate decides

- Icon set for the 5 types (custom vs emoji stopgap).
- Stepper visual treatment — pill buttons, rounded squares, or tight inline style. Should feel tactile without dominating the screen.
- Whether the count section has a subtle divider above it, or floats free.
- Whether selecting a type animates the stepper in from directly beneath the selected card, or always appears in a fixed position below the list.

## Why these decisions

- **Type + count on one screen, not two.** Splitting them would burn a screen for a question nobody struggles with. Two taps total is the bar.
- **Five types, not "just a count."** Type gives us qualitative signal for downstream copy (e.g. "family" unlocks meaningful changes on screens 11–14) that a raw number can't. A count-only screen would feel like a form field.
- **Default counts per type.** Removes a tap for the common case — "Me and my partner" shouldn't require the user to also set 2.
- **Max 10.** Covers realistic households; anything higher is a catering-scale edge case not worth handling in v1. User can override `servings` per recipe if needed.
- **"Something else" instead of hiding behind "Other".** Warmer, less formful. Keeps the screen conversational.
- **No "Prefer not to say".** We need a count to size recipes. Declining isn't actionable.

## Edge cases & states

- **Change type after editing count manually:** If the user manually edits the count (e.g. picked "Family" → 4, then edited to 5), and *then* changes type to "Flatmates" (default 3), keep their manual count of 5. Only apply the new type's default if they haven't manually edited.
- **Type selected but count somehow invalid** (shouldn't happen — stepper is bounded): Continue stays disabled with helper text "Pick a number between 1 and 10".
- **Back from screen 4:** type + count preserved.
- **Accessibility:** Stepper − and + buttons announce as "Decrease household count, currently 3" / "Increase household count, currently 3". Count number announces live on change.
- **Reduced Motion:** stepper appears instantly rather than fading in.
- **Screen entrance:** cards stagger in (same 30ms-apart rhythm as screen 2).

## Behaviour

- Tap a type card → card becomes selected; stepper appears with that type's default count; Continue activates.
- Tap a different type card → new card selected; count updates to new default (unless manually edited, per above).
- Tap − / + on stepper → count changes, stays within 1–10. Sets a `countManuallyEdited` flag internally.
- Tap **Continue** → persist `householdType` + `householdCount` to onboarding state; advance to screen 4 (Dietary).
- Back arrow → returns to screen 2 (Goal). Type + count preserved on return.
