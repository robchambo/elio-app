# Onboarding Screen 5 — Allergies & exclusions

**Step 5 of ~15** · Archetype: Multi-select + free-text
**Status:** Draft v1, awaiting Kate's design

---

## Objective

Capture two different kinds of "avoid":

1. **Allergies** — medically serious. Gemini must *never* include these, full stop.
2. **Dislikes / exclusions** — soft preferences. "I don't fancy mushrooms." Gemini avoids these in the prompt's existing "Excluded ingredients" section.

Keeping them separate lets the prompt phrase them differently downstream and gives us cleaner data if we ever want to show warnings ("this recipe contains peanuts — you marked this as an allergy").

## Copy

**Headline (large, bold):**
> And anything to avoid?

*(When screen 4 selection was "No restrictions", soften to:)*
> Anything we should avoid?

**Subhead (one line, lighter weight):**
> Allergies first, then anything you just don't fancy.

### Section 1 — Allergies

**Section header:** Any allergies?

**Options (multi-select chips, horizontal-wrap grid):**

| # | Label |
|---|---|
| 1 | Peanuts |
| 2 | Tree nuts |
| 3 | Milk / dairy |
| 4 | Eggs |
| 5 | Fish |
| 6 | Shellfish |
| 7 | Soy |
| 8 | Wheat / gluten |
| 9 | Sesame |

**+ "Other allergy" chip** — tap opens a small inline input, submit adds a custom chip to the list (tagged internally as allergy).

### Section 2 — Dislikes

**Section header:** Anything you just don't fancy?

**Free-text chip input:**
> `[ Start typing… e.g. mushrooms, olives ]`

Typed items become chips below the field. Tap a chip × to remove. No preset list — this is intentionally free-form.

**Primary CTA (full-width, always enabled):**
> Continue

**Secondary link below CTA (small, secondary colour):**
> Nothing to avoid — skip

## Layout

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓▓▓▓▓▓▓░░░░  ← progress    │
│                                 │
│  And anything to avoid?         │
│                                 │
│  Allergies first, then anything │
│  you just don't fancy.          │
│                                 │
│  Any allergies?                 │
│  ┌─────┐ ┌─────┐ ┌───────┐      │
│  │ 🥜 │ │ 🌰  │ │ 🥛    │      │
│  │Peanut│ │Tree n│ │Milk   │   │
│  └─────┘ └─────┘ └───────┘      │
│  ┌─────┐ ┌─────┐ ┌─────┐        │
│  │ 🥚 │ │ 🐟  │ │ 🦐  │        │
│  └─────┘ └─────┘ └─────┘        │
│  ┌─────┐ ┌─────┐ ┌─────┐        │
│  │ 🌱 │ │ 🌾  │ │Sesame│        │
│  └─────┘ └─────┘ └─────┘        │
│  ┌─────────────┐                │
│  │ + Other     │                │
│  └─────────────┘                │
│                                 │
│  ─────────────────────────────  │
│                                 │
│  Anything you just don't fancy? │
│  ┌───────────────────────────┐  │
│  │ Start typing…             │  │
│  └───────────────────────────┘  │
│  ┌────────┐ ┌────────┐          │
│  │Mushroom×│ │Olives×│          │
│  └────────┘ └────────┘          │
│                                 │
│  ┌───────────────────────────┐  │
│  │       Continue            │  │
│  └───────────────────────────┘  │
│     Nothing to avoid — skip     │
└─────────────────────────────────┘
```

## Visual spec

- **Allergy chips** — horizontal-wrap grid (3 per row on most phones). Rounded pill shape. Selected: amber fill with white text + small tick. Unselected: off-white with navy text + subtle border. Small leading icon per allergen.
- **Icons** — 9 custom allergen icons. Files: `allergy_peanut.svg`, `allergy_treenut.svg`, `allergy_milk.svg`, `allergy_egg.svg`, `allergy_fish.svg`, `allergy_shellfish.svg`, `allergy_soy.svg`, `allergy_gluten.svg`, `allergy_sesame.svg`. Style consistent with onboarding icon set. Emoji above are v1 stopgap.
- **"Other allergy" chip** — same shape as allergy chips but with `+` prefix and no icon. Tap expands an inline input below; submit creates a chip above with same style as preset allergens (amber if added).
- **Section divider** — full-width hairline between the allergy section and the dislikes section. Allergies are a medical thing; dislikes are not. The divider reinforces that distinction.
- **Dislikes input** — single-line text field, standard look. Comma or Enter commits the current token into a chip. Chips underneath sit in a wrap grid, each with a × to remove.
- **Chip shape consistency** — both selected allergies and dislikes chips use the same shape. Colour is the differentiator: allergies amber, dislikes a cooler neutral (Kate to pick — sky `#4A90D9` at low saturation is a candidate).
- **Skip link** — small, secondary text. Not a button. Treats the skip as low-status but still present for users who genuinely have nothing to add.

## Personalisation — how this feeds downstream

| Downstream surface | Change |
|---|---|
| **Screen 11 Pantry build** | Allergens are hard-filtered out of the ingredient list. Dislikes are not filtered (user may have them in their pantry for others in the household) but are flagged visually. |
| **Screen 13 First recipe** | Gemini prompt receives both arrays in its existing `Excluded ingredients (do NOT use)` section. Allergy items are labelled "(ALLERGY — must never include)", dislikes labelled "(disliked — avoid)". |
| **Recipe detail screens (ongoing)** | If a recipe somehow contains an allergen (shouldn't happen post-onboarding, but if imported), show a red warning banner "Contains <allergen> — you marked this as an allergy". |
| **Shopping list / pantry scanning** | If a user scans a barcode for an allergen item, show a warning before adding. |

### Data model

New fields on the user doc:

```
users/{uid}.allergies: List<String>         // e.g. ["peanuts", "shellfish", "mustard"]
users/{uid}.dislikes: List<String>          // e.g. ["mushrooms", "olives"]
```

The existing Gemini `_buildPrompt()` already has an "Excluded ingredients (do NOT use)" section — extend it to include both arrays, with the allergy/dislike labelling described above.

## What Kate decides

- Icon set for the 9 preset allergens (custom vs emoji stopgap).
- Chip shape and selected-state treatment (fill vs border vs both).
- Colour differentiator for dislikes chips (sky, neutral, or something else).
- Whether the "Other allergy" chip stays inline or opens a bottom sheet with a dedicated input.
- Whether dislikes show a subtle suggestion list as the user types (popular dislikes: mushrooms, olives, coriander, blue cheese) — nice-to-have, not required for v1.

## Why these decisions

- **Allergies and dislikes separated.** Different severity, different downstream treatment. A shellfish allergy demands a hard block; disliking olives is a soft nudge. Same data shape would lose that distinction.
- **Preset list for allergies, free-text for dislikes.** The top 9 allergens cover ~95% of medically relevant cases. Dislikes are inherently personal and long-tail — a preset list would feel arbitrary and wouldn't catch "coriander" or "goat's cheese".
- **"Other allergy" as an escape hatch.** For less common allergens (mustard, celery, sulphites, mollusc, lupin). Adds signal without bloating the default UI.
- **Skip link explicit.** Some users genuinely have no allergies and no dislikes. Making them tap Continue feels less honest than offering "skip" — and we capture analytics on skip rate, which is a useful signal for how real our "everyone has preferences" assumption is.
- **Chip grid, not vertical cards.** Nine allergens in vertical cards would balloon the screen. Chips fit the short-label pattern and scan fast.
- **No severity toggle** ("mild / severe"). Adds complexity for marginal value. We treat every declared allergy as "never include".

## Edge cases & states

- **User types a dislike that matches a preset allergen (e.g. types "peanuts" in the dislikes field):** inline helper appears: "Peanuts is a common allergen — move to Allergies?" with a one-tap move button.
- **User adds 10+ dislikes:** input still works but we show a gentle "That's a lot — recipes may be hard to generate" hint after 8. Non-blocking.
- **Other-allergy input left empty on submit:** just dismiss the input, no chip created.
- **Duplicate entry** (e.g. selects Peanuts twice, or types "mushroom" and "mushrooms"): normalise case + singular/plural on the dislike side; ignore duplicate taps on the preset side.
- **Skip link tapped:** persist empty arrays for both, advance. Track event.
- **Back from screen 6:** all chips and selections preserved.
- **Accessibility:** chips announce as "<label>, allergen, <selected/unselected>, button". Free-text input labelled "Foods you don't fancy, add one at a time". Skip link labelled "Skip — nothing to avoid".
- **Very long custom allergen** (e.g. a user types a 30-char name): chip truncates with ellipsis at ~20 chars, full text on long-press tooltip.
- **Keyboard handling:** on small phones, opening the dislikes keyboard should scroll the screen so the input + recently-added chips stay visible above the keyboard.

## Behaviour

- Tap an allergy chip → toggles selection. Added to `allergies` array.
- Tap "Other allergy" → expands inline input. Submit → adds to `allergies` array as a custom entry, tagged internally so it renders with the same amber treatment.
- Type in dislikes field + Enter/comma → adds chip to `dislikes` array. Tap chip × → removes.
- Tap **Continue** → persist both arrays; advance to screen 6 (Time on weeknights).
- Tap **Nothing to avoid — skip** → persist empty arrays; advance. Fires `onboarding_allergies_skipped` analytics event.
- Back arrow → returns to screen 4 (Dietary). All chips preserved on return.
