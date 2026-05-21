# Onboarding Screen 8 — Appliances

**Step 8 of ~15** · Archetype: Multi-select with smart defaults
**Status:** Draft v1, awaiting Kate's design

---

## Objective

Find out what cooking gear the user actually has. Feeds the Gemini prompt's existing "Appliance constraints" section so we never generate an air-fryer recipe for someone without one, and — equally important — *do* generate air-fryer recipes for someone who loves theirs.

The three near-universal appliances (oven, hob, microwave) are pre-selected. Everything else is opt-in. This removes friction for the ~90% case without presuming the rest.

## Copy

**Headline (large, bold):**
> What's in your kitchen?

**Subhead (one line, lighter weight):**
> Tick what you've got. We'll only suggest recipes that fit.

### Options

**Pre-selected by default** (core three):

| # | Label | Default |
|---|---|---|
| 1 | Oven | ✅ |
| 2 | Hob / stove | ✅ |
| 3 | Microwave | ✅ |

**Opt-in** (tap to add):

| # | Label |
|---|---|
| 4 | Air fryer |
| 5 | Slow cooker |
| 6 | Pressure cooker / Instant Pot |
| 7 | Blender |
| 8 | Food processor |
| 9 | Stand mixer |
| 10 | Rice cooker |
| 11 | BBQ / grill |

**Helper text above the grid (small, secondary):**
> We've ticked the usuals — untick if you don't have one.

**Primary CTA (full-width, always enabled):**
> Continue

## Layout

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓▓▓▓▓▓▓▓▓▓▓░ ← progress   │
│                                 │
│  What's in your kitchen?        │
│                                 │
│  Tick everything you'll         │
│  actually use.                  │
│                                 │
│  We've ticked the usuals —      │
│  untick if you don't have one.  │
│                                 │
│  ┌──────────┐ ┌──────────┐      │
│  │ ✅ Oven  │ │ ✅ Hob   │      │
│  └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐      │
│  │✅Microwave│ │ Air fryer│     │
│  └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐      │
│  │Slow cook │ │Pressure  │      │
│  └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐      │
│  │ Blender  │ │Food proc │      │
│  └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐      │
│  │Stand mix │ │Rice cook │      │
│  └──────────┘ └──────────┘      │
│  ┌──────────┐                   │
│  │ BBQ/grill│                   │
│  └──────────┘                   │
│                                 │
│  ┌───────────────────────────┐  │
│  │       Continue            │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## Visual spec

- **3-column grid** of appliance tiles, not vertical cards. Eleven items in vertical cards would demand too much scroll; a compact grid reads in a glance. Tiles use `childAspectRatio: 0.9` so two-line labels (e.g. "Pressure cooker / Instant Pot") wrap without clipping.
- **Tile shape** — square-ish rounded tile with an icon on top, label below. Height ~96pt. Selected state: amber border + amber tick in the corner; fill stays off-white (not amber — selected items are the default, coloured fill on 3+ tiles would overload the screen).
- **Icons** — 11 custom appliance icons. Files: `appliance_oven.svg`, `appliance_hob.svg`, `appliance_microwave.svg`, `appliance_airfryer.svg`, `appliance_slowcooker.svg`, `appliance_pressure.svg`, `appliance_blender.svg`, `appliance_processor.svg`, `appliance_mixer.svg`, `appliance_ricecooker.svg`, `appliance_bbq.svg`. Line-art style consistent with the rest of the onboarding set.
- **Pre-selected state** — visually identical to any user-selected tile (amber border + tick). The helper text above the grid explains the pre-selection; no need for a separate visual treatment.
- **Helper text** — small, secondary colour, sits just above the grid. Plain text, not a banner or card.

## Personalisation — how this feeds downstream

| Downstream surface | Change |
|---|---|
| **Screen 11 Pantry build** | No direct change — pantry is ingredients, not equipment. |
| **Screen 13 First recipe** | Gemini prompt receives the `appliances` array in its existing Appliance constraints section. Recipes can only use listed appliances; if user picked air fryer, the hero recipe can optionally lean into it. |
| **Ongoing generation** | Same as above — permanent constraint on every recipe unless the user changes it in Settings. |
| **Appliance-specific recipe mode** (future, flag only) | If user has an air fryer, enable a "Air fryer tonight" shortcut on the home screen (already exists or easy to add). Ditto slow cooker. |

### Data model

Reuses the existing field:

```
users/{uid}.appliances: List<String>    // e.g. ["oven", "hob", "microwave", "airfryer"]
```

No schema change. String keys match the existing convention in `gemini_service._buildPrompt()` appliance section.

## What Kate decides

- Whether tiles show icon + label (recommended), or icon alone with label on selected-only. Icon-only risks ambiguity (food processor vs blender visually).
- Whether "Something else?" / "+ Other" tile is needed. Current thinking: no — the 11 listed cover 95% of home kitchens, and free-text appliances don't translate to Gemini constraints well. Kate to push back if she disagrees.
- Whether selected tiles show a small badge ("Your favourite?") when a user has more than 5 selected — nudges users toward declaring a *primary* appliance. Probably post-v1.

## Why these decisions

- **Pre-selection of the core three.** Oven/hob/microwave are in ~98% of UK + US home kitchens. Asking users to tap all three adds friction for no signal value. Opting out is still one tap.
- **Grid, not vertical cards.** Eleven items would create a long scroll; appliances are visually distinct (unlike dietary labels), so an icon-led tile works.
- **No free-text "Other".** Appliance constraints need to map to Gemini prompt tokens. Arbitrary strings ("my panini press") wouldn't change recipe generation and would create noise in the `appliances` field.
- **Always-enabled Continue.** Unlike screens 2–7, here it's acceptable to proceed with only the pre-selected three — that *is* a valid answer.
- **No confidence-on-appliance link.** We don't gate air fryer recipes on cooking confidence; Gemini handles the complexity calibration separately.

## Edge cases & states

- **User unticks all three defaults:** save an empty `appliances` array. Gemini falls back to its safe default ("Assume a basic kitchen with oven, hob, microwave"). Non-blocking — the user may genuinely have none (e.g. a dorm user with only a microwave) and we don't want to force a choice.
- **User has already been through onboarding** (returning / editing in Settings): pre-selection logic is suppressed; existing selections are shown as-is. This is a Settings screen concern, but flag it so the shared tile component handles both contexts.
- **Accessibility:** each tile announces as "<label>, <selected/unselected>, button". Pre-selected announcements on screen entry: "Oven, selected (default). Hob, selected (default). Microwave, selected (default)."
- **Screen entrance:** tiles stagger in row-by-row (not tile-by-tile) to keep it quick on a longer list.
- **Reduced Motion:** skip stagger.
- **Back from screen 9:** selections preserved exactly, including any defaults the user unticked.

## Behaviour

- Screen loads with Oven, Hob, Microwave pre-selected.
- Tap a tile → toggles its selection state. No constraint on how many can be selected.
- Tap **Continue** → persist `appliances` array (minus any defaults the user unticked); advance to screen 9 (Region & units).
- Back arrow → returns to screen 7 (Confidence). Selections preserved.
- No skip option. Continue is always enabled.
