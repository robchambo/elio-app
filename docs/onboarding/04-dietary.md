# Onboarding Screen 4 — Dietary

**Step 4 of ~15** · Archetype: Multi-select (with smart exclusions)
**Status:** Draft v1, awaiting Kate's design

---

## Objective

Capture the user's dietary *pattern* — the hard rules that govern what Elio will ever put in a recipe. Ethical, religious, and lifestyle-based (vegan, halal, pescatarian etc.). Allergies and one-off excludes are handled separately on screen 5 — that separation is deliberate (different mental model, different default for "None").

If the household has more than one person (screen 3 count > 1), we also ask whether anyone *else* has different needs. Per-person capture is deferred to post-onboarding; here we just set a flag so the app can prompt for it later.

## Copy

**Headline (large, bold):**
> Any dietary rules we should follow?

**Subhead (one line, lighter weight):**
> Pick all that apply. Allergies come next.

**Options (multi-select, vertical chips or cards):**

| # | Label | Subtext | Exclusion behaviour |
|---|---|---|---|
| 1 | No restrictions | Anything goes | Deselects all other options when picked |
| 2 | Vegetarian | No meat or fish | Mutually exclusive with Vegan and Pescatarian |
| 3 | Vegan | No animal products at all | Auto-includes Vegetarian; mutually exclusive with Pescatarian |
| 4 | Pescatarian | Fish, yes. Meat, no. | Mutually exclusive with Vegetarian and Vegan |
| 5 | Halal | Halal-compliant only | Stackable with any of 2-4 |
| 6 | Kosher | Kosher-compliant only | Stackable with any of 2-4 |

**If household count > 1, a conditional row appears below:**

> **Does anyone else in your household eat differently?**
> `[ Toggle: off/on ]`
>
> *(toggle subtext when on:)* We'll ask you about them inside the app — no need to do it here.

**Primary CTA (full-width, always enabled after at least one option OR "No restrictions" is picked):**
> Continue

## Layout

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓▓▓▓▓░░░░░░░  ← progress   │
│                                 │
│  Any dietary rules we should    │
│  follow?                        │
│                                 │
│  Pick all that apply.           │
│  Allergies come next.           │
│                                 │
│  ┌───────────────────────────┐  │
│  │ ✓  No restrictions         │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 🥬  Vegetarian             │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 🌱  Vegan                  │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 🐟  Pescatarian            │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ ☪️  Halal                  │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ ✡️  Kosher                 │  │
│  └───────────────────────────┘  │
│                                 │
│  ─────────────────────────────  │
│  Does anyone else in your       │
│  household eat differently?     │
│                      [ ○ off ]  │
│                                 │
│  ┌───────────────────────────┐  │
│  │       Continue            │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## Visual spec

- **Option cards** — same system as screens 2–3, but multi-select: selected state shows a filled amber tick; no mutual-exclusion UI treatment (exclusion happens silently when tapped).
- **Icons** — 6 custom icons, consistent with the rest of the onboarding set. Files: `diet_none.svg`, `diet_vegetarian.svg`, `diet_vegan.svg`, `diet_pescatarian.svg`, `diet_halal.svg`, `diet_kosher.svg`. Religious symbols (Halal/Kosher) should be handled respectfully — Kate's call on whether to use the literal symbols or neutral iconography.
- **No-subtext pattern** — unlike screen 2, subtext lines here are short enough to sit inline with the label. Kate may drop them entirely on the card and put them in a helper tooltip. Either direction works.
- **Household toggle row** — visually distinct from the dietary cards (divider line above, no icon, a standard iOS/Material toggle). Appears only when `householdCount > 1`.
- **Section divider** — subtle horizontal rule between diet options and the household toggle, so the toggle doesn't read as a 7th diet option.

## Personalisation — how this feeds downstream

| Downstream surface | Change |
|---|---|
| **Screen 5 Allergies** | If "No restrictions" picked here, screen 5 headline softens to "Anything we should avoid?" rather than "And any allergies?" |
| **Screen 11 Pantry build** | Categories filtered — e.g. Vegan hides all meat/dairy/egg categories; Pescatarian hides meat but keeps fish; Halal/Kosher don't filter (just tag). |
| **Screen 13 First recipe** | Gemini prompt receives the dietary array in its existing `dietary` field. Enforced as hard constraints (existing behaviour). |
| **Post-onboarding nudge** | If the household-differs toggle was ON, show a one-time home-screen card: "Tell us about the others in your household → Add profile." Opens existing household profile flow. |

### Data model

Persists to onboarding state, then to Firestore on sign-in:

```
users/{uid}.dietary: List<String>        // e.g. ["vegetarian", "halal"]
users/{uid}.householdHasDifferingDiet: bool
```

Reuses the existing `dietary` field on `users/{uid}` — no schema change. The `householdHasDifferingDiet` flag is new; triggers the post-onboarding nudge.

## What Kate decides

- Icon treatment for Halal/Kosher (literal religious symbol, or a neutral mark with text only).
- Whether subtext lives on the card, in a tooltip, or is dropped entirely.
- Visual style of the household toggle row — divider weight, spacing, label hierarchy.
- Whether "No restrictions" is visually distinct (e.g. a lighter card) to signal it's the "none of the below" option.

## Why these decisions

- **Dietary separated from allergies.** Dietary is an identity ("I am a vegetarian"); allergy is a constraint ("I will die if I eat nuts"). Collapsing them confuses "none" — a user with no diet but a nut allergy would have to tick "none" and then separately note the allergy. Two screens, cleanly scoped.
- **Multi-select with silent exclusions.** Most users pick one. The small number who stack (e.g. vegetarian + halal) shouldn't be blocked. Mutual exclusions (vegan vs veg vs pesc) are resolved silently by the UI — tapping Vegan while Vegetarian is selected is fine (vegan implies veg, so we keep both); tapping Pescatarian while Vegetarian is selected deselects Vegetarian. Zero error messaging, just responsive state.
- **"No restrictions" as a real option, not a skip.** Makes the answer explicit. Users actively confirming "I eat everything" is cleaner signal than interpreting an empty array.
- **Defer per-person detail.** Asking "who in your household eats differently and what do they eat?" during onboarding would balloon the flow by 2-3 screens and most users would bail. A flag + a home-screen nudge gets us the same outcome without the tax.
- **No "Other / free-text"** on dietary. The space of dietary *rules* is small and well-defined. "I avoid red meat" isn't a dietary pattern — it belongs on the Allergies / excludes screen.

## Edge cases & states

- **"No restrictions" tapped with others already selected:** deselect everything else, select "No restrictions" only.
- **Any other option tapped while "No restrictions" is selected:** deselect "No restrictions", select the new option.
- **Vegan tapped while Vegetarian selected:** add Vegan, keep Vegetarian (vegan is a strict subset — user likely wants both flagged for clarity).
- **Pescatarian tapped while Vegetarian or Vegan selected:** deselect the conflicting option, select Pescatarian.
- **All options manually deselected:** Continue stays enabled but defaults to `dietary: []` with no "No restrictions" flag. A single hint appears: "No restrictions? Tap above to confirm." *(non-blocking.)*
- **Household count = 1:** household-differs row is hidden entirely.
- **Back from screen 5:** selections preserved.
- **Accessibility:** each card announces as "<label>, <selected/unselected>, button". Silent exclusion changes are announced via live region ("Vegetarian deselected" when Pescatarian replaces it).
- **Screen entrance:** cards stagger in (same rhythm as screens 2–3). Household toggle row fades in after a 100ms delay.

## Behaviour

- Tap a card → toggles its selected state, applying the exclusion rules above.
- Tap household toggle → flips `householdHasDifferingDiet`. No follow-up screen in this flow.
- Tap **Continue** → persist `dietary` array + `householdHasDifferingDiet`; advance to screen 5 (Allergies).
- Back arrow → returns to screen 3 (Household). All selections preserved on return.
- No skip option. Continue is always available after first interaction; users who want no restrictions must tap "No restrictions" explicitly.
