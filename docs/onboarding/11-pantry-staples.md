# Onboarding Screen 11 — Pantry (staples)

**Step 11 of ~15** · Archetype: Multi-select grid (tier-aware)
**Status:** Draft v1, awaiting Kate's design

---

## Objective

Capture the user's **stocked staples** — the things they always or almost always have. This is the core of Elio's wedge: every recipe is grounded in what's actually in the kitchen, not a wishlist.

Two tiers captured here:

1. **Always have** — Gemini treats as "definitely available, use freely". Salt, oil, eggs, onions, etc.
2. **Almost always have** — Gemini treats as "probably available, lean on but not every recipe". Things like rice, tinned tomatoes, soy sauce.

Perishables (fresh produce, fresh meat, fresh dairy) are captured separately on screen 12. That split matters: staples rarely change, perishables change weekly. Mixing them would muddle the mental model and waste time on items users don't think of as "kitchen state".

This is the single most differentiating screen in the app. It's the only reason Elio can deliver recipes that respect real-world constraints. Budget it visually and cognitively.

## Copy

**Headline (large, bold):**
> What do you always have in?

**Subhead (one line, lighter weight):**
> Tap what you've usually got. Long-press anything you *always* have — we'll lean on those heavier.

**Legend (small, sits just under the subhead):**
> ◐ Usually in   ·   ✅ Always in

**Category sections** (12, in this order — matches `lib/data/pantry_categories.dart`):

1. Oils & Vinegars
2. Spices & Seasonings
3. Sauces & Condiments
4. Canned & Jarred
5. Grains & Pasta
6. Dairy & Eggs *(staple items only — milk/yoghurt appear on screen 12)*
7. Baking Essentials
8. Frozen Staples
9. Asian Pantry
10. Indian Pantry
11. Mediterranean
12. Mexican & Latin

### Pre-selected defaults on first entry (all marked "Usually in"):

| Category | Default-selected items |
|---|---|
| Oils & Vinegars | Olive oil, Vegetable oil |
| Spices & Seasonings | Salt, Black pepper, Mixed herbs, Paprika |
| Sauces & Condiments | Ketchup, Soy sauce, Mustard, Honey |
| Canned & Jarred | Tinned tomatoes, Chickpeas |
| Grains & Pasta | Rice (white), Oats |
| Dairy & Eggs | Eggs, Butter |
| Baking Essentials | Plain flour, Caster sugar, Baking powder |
| Frozen Staples | Frozen peas |

Covers the median UK household; users add/remove from there.

**Primary CTA (full-width, sticky at bottom):**
> Next

**Button subtext:**
> <N> things in your kitchen

Where `<N>` is the live count of selected items, updating as the user taps.

## Layout

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ← progress │
│                                 │
│  What do you always have in?    │
│                                 │
│  Tap what you've usually got.   │
│  Long-press for *always*.       │
│  ◐ Usually in  ·  ✅ Always in  │
│                                 │
│  Oils & Vinegars          ▾     │
│  ┌────────┐ ┌────────┐          │
│  │◐ Olive │ │◐ Veg   │          │
│  │  oil   │ │  oil   │          │
│  └────────┘ └────────┘          │
│  ┌────────┐ ┌────────┐          │
│  │Sesame  │ │Coconut │          │
│  │oil     │ │oil     │          │
│  └────────┘ └────────┘          │
│  …more                          │
│                                 │
│  Spices & Seasonings      ▾     │
│  ┌────────┐ ┌────────┐          │
│  │◐ Salt  │ │◐ Pepper│          │
│  └────────┘ └────────┘          │
│  ┌────────┐ ┌────────┐ ┌──────┐ │
│  │◐ Mixed │ │◐ Paprika│ │Cumin│ │
│  │ herbs  │ │        │ │     │ │
│  └────────┘ └────────┘ └──────┘ │
│  …more                          │
│                                 │
│  [scroll for more categories]   │
│                                 │
│═════════════════════════════════│
│  ┌───────────────────────────┐  │
│  │  Next                     │  │
│  │  16 things in your kitchen│  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## Visual spec

- **Scrollable screen, sticky CTA.** The category grid scrolls; the Next button + count caption sticks to the bottom so the user always sees progress and can commit at any moment.
- **Category headers** — sticky as the user scrolls, so you always know which category you're looking at. Medium weight, navy, 16pt. Tappable chevron on the right to collapse (power-user feature, Kate to decide if v1).
- **Item tiles** — 2-column grid on mobile, 3-column on tablet. Each tile ~72pt tall. Icon optional (if we have it); label always visible. Text wraps to 2 lines if needed.
- **Tile states:**
  - **Unselected:** off-white fill, subtle navy border, navy text. No leading indicator.
  - **Usually in (◐):** soft amber fill (amber at 15%), amber border, navy text, small `◐` glyph leading. Single tap enters this state from unselected.
  - **Always in (✅):** solid amber fill, white text, `✅` glyph leading. Long-press from Usually-in enters this state, or a second tap cycles through.
  - **Pressed:** slight scale to 0.97, shadow suppressed.
  - **Unselected from Always-in:** third interaction removes. Long-press from unselected skips Usually-in and goes straight to Always.
- **Tap behaviour decision** — we offer two ergonomic paths so users can discover either:
  - Tap cycle: unselected → Usually → Always → unselected.
  - Long-press shortcut: unselected → Always directly; long-press on a selected tile → removes. Long-press is the existing app gesture per `CLAUDE.md`.
- **Legend** — small, one-line, under the subhead. Uses the same glyphs the tiles will show. Non-interactive.
- **Icons** — optional per item. Common staples (Salt, Egg, Milk, Oil) have cute line-art icons; long-tail items (Za'atar, Gochujang) render text-only. Kate to decide scope — icons cost a lot to produce for 150+ items; text-only is acceptable v1.
- **Category colour accent** — a 2px coloured bar on the left of the category header, subtle. Gives visual scanning anchors without colouring tiles themselves. Palette: Kate to derive from existing Sprint 16 category colours in `pantry_categories.dart` if those exist.
- **Search bar** (sticky under the headline, above the first category):
  > `🔍  Search staples…`
  Typing filters across all items in all categories, grouped by category. Tap an item from search → it selects and search clears. Search handles common mis-spellings via the existing `pantry_utils` fuzzy dedup utility (use for duplicate prevention, NOT for toggle matching per the Flutter gotchas in CLAUDE.md).
- **"Add your own" affordance** per category — a final tile in each category grid labelled "+ Add something". Tap opens a small inline input; submit adds a custom item tagged to that category, entering "Usually in" state.

## Personalisation — how earlier answers change this screen

| Earlier answer | Effect on screen 11 |
|---|---|
| **Dietary = Vegan** (screen 4) | Dairy & Eggs category hidden. Defaults drop Eggs and Butter from pre-selection. |
| **Dietary = Vegetarian** | Dairy & Eggs stays; no pre-selection changes. |
| **Dietary = Pescatarian** | No change (staples don't include fresh meat). |
| **Halal / Kosher** | No filtering; all categories shown. *(These are preparation rules, not staple-exclusion rules.)* |
| **Allergies = Peanuts** | "Peanut butter" removed from Canned & Jarred. |
| **Allergies = Wheat / gluten** | Baking Essentials category shown but flour-based items de-prioritised; a gentle banner at category top: "We'll keep these out of your recipes." Still visible because user may bake for others. |
| **Region = US** | Category items use US vocabulary (`Cilantro` not `Coriander`; `Zucchini` not `Courgette`). Driven by existing `region_utils.dart`. |
| **Region = Elsewhere** | Shows UK defaults with US names in brackets on long-tail items (`Coriander (Cilantro)`). |
| **Goal = Waste reduction** (screen 2) | Small helper appears under the legend: "Almost always in? Mark it Usually — so we know not to assume."  |
| **Goal = Cook with what I've got** | No change. |

### Data model

Writes to the existing pantry system on Continue:

```
inventory/{docId} — name, tier, category
  where tier ∈ { 'always', 'usually' }   // Gemini prompt already distinguishes these

users/{uid}.tierMemory/{normalizedName} — tier, lastSeen
  // For the existing tier memory system (already in app) — seed it from onboarding.
```

Uses the existing `_buildPrompt()` "Inventory section" which already distinguishes tiers (pantry staples, usually-have items, perishables). Zero schema change. Onboarding pre-seeds state that post-onboarding pantry builder continues to edit.

### What this screen DOES NOT capture

- **Perishables** (screen 12): fresh veg, fresh meat, fresh dairy with expiry.
- **User-selected hero ingredients** for a specific recipe — that's the "what needs using?" UI inside the app.
- **Exact quantities.** A pantry-first system doesn't need quantities for staples; Gemini assumes "enough for one recipe" unless the user selects a perishable explicitly.

## What Kate decides

- **Tile tap vs long-press ergonomics** — single-tap cycle is discoverable; long-press shortcut is power-user. Both coexist in the spec; Kate to validate that both feel right in Figma.
- **Icon scope** — icons for the top ~30 items vs icons for all 150+. Rob's default: top 30 only, text-only for the rest.
- **Category header style** — sticky vs non-sticky. Sticky is more functional for a long scroll but eats vertical space.
- **Collapsing categories** — whether users can collapse sections. Power-user feature; adds complexity for marginal benefit. Rob's default: no for v1.
- **Defaults visibility** — whether pre-selected items show a subtle "pre-selected" badge or just appear as Usually-in. Rob's default: no badge — treat defaults as indistinguishable from user choices.
- **Search bar** — whether it's always visible, or appears on a tap of a magnifier icon. Rob's default: always visible (saves scrolling on a long list).
- **Add-your-own tile** — whether this is end-of-category (per the spec) or a single global "Can't find it?" row at the bottom of the page.

## Why these decisions

- **Two tiers, not three or one.** Three tiers (e.g. always / usually / sometimes) overflows the mental model and the tap cycle. One tier loses the Gemini signal — "always have salt" and "sometimes have miso" are very different prompt weights. Two is the right split, and matches the existing app.
- **Pre-selected defaults.** ~16 items covers the median UK kitchen. Starting from zero would take 2+ minutes; starting from ~16 means the user's job is "add the extras I actually have" — which is a faster mental task.
- **Category-grouped, not alphabetical.** Categories let users scan "oh, I should think about spices now" rather than browsing 150 items. Matches how people inventory their own kitchen.
- **12 categories shown, not collapsed.** Collapsing hides things users haven't thought about, hurting completeness. Long-scroll is acceptable because we've primed "~1 minute" on screen 10.
- **Free-text "+ Add something" per category.** The preset list covers 90%+ but every household has one weird thing (harissa, laksa paste, marmite). Capturing those is cheap and dramatically lifts personalisation.
- **Count in the button subtext.** "16 things in your kitchen" is a subtle progress signal — "oh, I've built something" — and a light fairness check ("only 16? should I add more?"). The dynamic count makes the screen feel alive.
- **No "Done enough?" escape hatch.** Every tap is progress. Next button is always live from the start (pre-selection is a valid answer), so there's already a one-tap exit.
- **Long-press matches existing app gesture.** Consistency across onboarding and post-onboarding pantry builder. Flutter gotcha in `CLAUDE.md` already solved (`RawGestureDetector` with 300ms `LongPressGestureRecognizer`).
- **Fuzzy matching only for dedup, not toggle state.** Explicit rule from `CLAUDE.md`. If user adds "Olive oil" and "olive oil", normalise case on save; but never "match" them visually on tap — exact matching only.

## Edge cases & states

- **User taps a pre-selected default off:** normal behaviour, item deselects, count decrements.
- **User adds a custom item that matches an existing one** (e.g. types "olive oil" while Olive oil is already selected): prevent with inline helper: "Already in your staples." Fuzzy match via `pantry_utils`.
- **User adds a custom item that's a perishable** (e.g. types "strawberries"): no auto-detection in v1; item goes into whichever category the "+ Add" belongs to. Flagged as a future improvement — the existing `pantry_utils` could classify on save.
- **Vegan user sees a pre-selected Egg:** can't happen — vegan filter removes the default pre-selection for Eggs and Butter before the screen renders.
- **User scrolls fast, accidentally taps an item:** tap registers. Count updates. User can correct with another tap. No undo pattern needed for this speed.
- **Long-press on pressed-but-not-selected tile:** the 300ms long-press threshold means the cycle tap doesn't fire. If the user releases before 300ms, it's a tap; after, it's a long-press. Matches the existing app gesture.
- **Empty state:** if somehow zero items selected, count shows "0 things in your kitchen" and Next still works. Non-blocking but unusual.
- **Back from screen 12:** state preserved exactly, including tiers and custom items.
- **Accessibility:**
  - Tiles announce as `<item>, <usually in | always in | unselected>, button`.
  - Long-press is available via a per-tile action menu (VoiceOver/TalkBack actions) with options "Mark as always in" / "Remove".
  - Screen-reader users get a summary above the grid: "Pantry builder, 12 categories, 16 items pre-selected."
  - Dynamic Type: tiles grow vertically; label wraps to 3 lines max, then truncates with ellipsis + full text on long-press.
  - Colour alone isn't the state signal — glyphs (`◐`, `✅`) differentiate states for colourblind users.
- **Low-memory device:** the full grid is virtualised (existing Flutter `GridView.builder` pattern) so scrolling long lists doesn't OOM on older Android.
- **Reduced Motion:** disable tile scale-on-press; state transition still uses colour change (no fade).

## Behaviour

- On entry: ~16 default items pre-selected in "Usually in" state; all others unselected. Count reads "16 things in your kitchen."
- Tap a tile → cycles state: unselected → Usually in → Always in → unselected.
- Long-press an unselected tile → Always in directly.
- Long-press a selected tile (either tier) → removes.
- Type in search → filters all items across categories, grouped by category. Tap filtered item → selects + clears search.
- Tap "+ Add something" in a category → dialog opens with a text input; submit adds a custom tile in "Usually in" state. Dedup behaviour:
  - **Exact (normalised) match** against any existing pantry item → no new tile; the existing tile is silently promoted to "Usually in". No confirm dialog.
  - **Fuzzy match** (typo / near-duplicate, via `PantryUtils.findDuplicates`) → "Similar item found" confirm dialog: *Cancel* / *Add anyway*.
  - **No match** → append as a custom tile in the user-chosen category, pre-selected at "Usually in".
- Tap **Next** → persist inventory + tierMemory; advance to screen 12 (Perishables).
- Back arrow → returns to screen 10 (Pantry intro). All state preserved on return.
- No skip option. Pre-selected defaults make the minimal-effort path a single Next tap.
