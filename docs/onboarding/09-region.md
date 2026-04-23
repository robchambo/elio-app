# Onboarding Screen 9 — Region & units

**Step 9 of ~15** · Archetype: Single-select with smart default + override
**Status:** Draft v1, awaiting Kate's design

---

## Objective

Lock in two settings that shape every recipe Elio ever generates:

1. **Region** — changes ingredient vocabulary ("courgette" vs "zucchini", "coriander" vs "cilantro"), suggested cuisine bias, and the default measurement system.
2. **Measurement units** — metric (g, ml, °C) vs imperial (oz, cups, °F). Defaulted from region but overridable in one tap.

Device locale is used to pre-select the likely answer, so most users tap Continue without thinking. A small override for the genuine mixed cases (Brits who grew up on cups, Americans who prefer grams for baking).

## Copy

**Headline (large, bold):**
> Where are you cooking?

**Subhead (one line, lighter weight):**
> So we get the names and measurements right.

### Region options (single-select cards)

| # | Label | Default units |
|---|---|---|
| 1 | United Kingdom | Metric |
| 2 | United States | Imperial |
| 3 | Elsewhere | Metric |

*(Device locale pre-selects one of these on screen entry.)*

### Units override (small toggle row below the cards)

**Label:**
> Measurements

**Toggle / segmented control:**
> `[ Metric ]  [ Imperial ]`  *(one selected, following region default)*

*(The previously-planned post-override helper text — "Got it — we'll use <metric|imperial> across all your recipes." — has been dropped for v1. The toggle's visual state is self-evident; an auto-fading confirmation line adds noise without signal.)*

**Primary CTA (full-width, always enabled — pre-selection is a valid answer):**
> Continue

## Layout

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ← progress    │
│                                 │
│  Where are you cooking?         │
│                                 │
│  So we get the names and        │
│  measurements right.            │
│                                 │
│  ┌───────────────────────────┐  │
│  │ 🇬🇧  United Kingdom   ✓    │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 🇺🇸  United States         │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 🌍  Elsewhere              │  │
│  └───────────────────────────┘  │
│                                 │
│  Measurements                   │
│  ┌──────────┬──────────┐        │
│  │  Metric  │ Imperial │        │
│  └──────────┴──────────┘        │
│                                 │
│  ┌───────────────────────────┐  │
│  │       Continue            │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## Visual spec

- **Region cards** — same card system as screens 2–7. Full-width, rounded, amber border + tick on select.
- **Region icons** — flag-style or neutral-mark. Flags are the most legible (🇬🇧 🇺🇸 🌍 used as v1 stopgap). Kate to decide whether literal flags sit with the brand or whether a more illustrative mark (e.g. a simple globe with a region-accented pin) works better.
- **Pre-selection state** — the region inferred from device locale renders as selected on screen entry (amber border + tick). Visually indistinguishable from a user-selected card. No "default" badge — that would overload the UI.
- **Units toggle** — segmented control style, two pills side by side, the active one filled amber. Label "Measurements" sits 16pt above, same treatment as a form field label.
- **Units defaulting** — on first entry, the toggle follows the selected region's default (UK/Elsewhere → Metric, US → Imperial). If the user switches region, the toggle auto-follows *unless* the user has manually flipped it at least once on this screen (see Edge cases).
- **Helper text** appears briefly (2s auto-fade) only when the user manually changes the toggle away from the region default, so they know the override stuck.

## Personalisation — how this feeds downstream

| Downstream surface | Change |
|---|---|
| **Screen 11 Pantry build** | Category labels and example items localised. UK: "Courgette", "Coriander", "Aubergine". US: "Zucchini", "Cilantro", "Eggplant". Existing `region_utils.dart` likely already handles this — reuse. |
| **Screen 13 First recipe** | Gemini prompt receives both `region` and `measurementUnits` as hard constraints. Ingredient names follow region; quantities follow units. |
| **Recipe display everywhere** | `QuantityUtils.normalizeUnit()` already maps units — driven by `measurementUnits` field. Temperatures display °C or °F accordingly. |
| **Elsewhere option** | Treated as "internationally flexible" — Gemini gets an instruction to use globally-recognised names (e.g. "zucchini" with "(courgette)" in brackets) and metric by default. Not perfect but avoids forcing a user into a wrong regional mould. |

### Data model

Reuses existing fields:

```
users/{uid}.region: String                // "uk" | "us" | "other"
users/{uid}.measurementUnits: String      // "metric" | "imperial"
```

Both already used by `region_utils`, `QuantityUtils.normalizeUnit()`, and `gemini_service._buildPrompt()`. No schema change.

## What Kate decides

- Region icon treatment — flags vs illustrative marks. Flags are clearest but politically heavier.
- Whether "Elsewhere" should expand into a country picker if tapped (probably not for v1 — too much scope for a screen that's meant to be fast).
- Segmented control vs a more playful toggle for the units row. Standard segmented is fastest to build and most legible.
- Whether a small helper example appears next to the toggle (e.g. "e.g. 250 g, 180 °C") so the user sees what they're picking in concrete terms.

## Why these decisions

- **Device locale as a smart default.** Most users (~95%) will pick what we've pre-selected. Making them tap anyway is friction for no signal. Pre-selection + easy override is the right trade.
- **Region drives units by default, but decoupled.** Plenty of UK users learned baking in cups; plenty of US users prefer grams for precision. Units override respects that without cluttering the main question.
- **Three regions, not a full country list.** UK/US are our two primary markets. "Elsewhere" bucket covers everyone else without demanding we localise for every country at launch. Adds one analytic signal (how big is non-core-markets) for later regional expansion decisions.
- **No language toggle.** Language is driven by device OS, not a preference we ask here. Mixing language and region would add complexity for minimal signal.
- **"Elsewhere" uses metric.** Roughly three quarters of non-UK/US users are in metric countries. Safer default than imperial.

## Edge cases & states

- **User flips units toggle manually, then changes region:** the toggle stays on the user's manual choice, not the new region's default. One-time manual override "sticks" for the session.
- **User flips units toggle twice (back to default):** treated as no manual override — future region changes do update the units.
- **Device locale can't be determined:** fall back to UK + Metric as the pre-selected default (UK is the spec market; metric is the safer global default).
- **"Elsewhere" selected:** units toggle defaults to Metric; region-specific ingredient vocabulary falls back to an international-leaning set.
- **Back from screen 10:** selections preserved.
- **Accessibility:** region cards announce as "<country>, <selected/unselected>". Units toggle announces as "Measurement units, <metric/imperial>, selected. Tap to change.". Helper text appears as a live region.
- **Reduced Motion:** skip the helper text fade-in; show it statically for 2s then remove.
- **Screen entrance:** region cards stagger in (30ms rhythm). Units toggle fades in after the cards.

## Behaviour

- On entry: device locale detected → `Platform.localeName`. Mapping: `en_GB` / any `_GB` → UK; `en_US` / any `_US` → US; anything else → Elsewhere. Region card pre-selected. Units toggle pre-set to region default.
- Tap a region card → selection moves. If the user hasn't manually overridden units yet, the units toggle snaps to the new region's default.
- Tap units toggle → manual override set. Helper text appears for 2s.
- Tap **Continue** → persist `region` + `measurementUnits`; advance to screen 10 (Pantry intro).
- Back arrow → returns to screen 8 (Appliances). Selections preserved.
- No skip. Pre-selection is a valid answer.
