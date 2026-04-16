# Onboarding Screen 12 — Pantry (perishables)

**Step 12 of ~15** · Archetype: Multi-select grid with freshness states
**Status:** Draft v1, awaiting Kate's design

---

## Objective

Capture what's **fresh and in the kitchen right now** — the produce, meat, fish, fresh dairy, and herbs that are going to drive tonight's recipe. This is the "use today" mechanic that separates Elio from every shopping-list-driven competitor.

Three freshness states captured per item:

1. **Fresh** — just bought, good for the week. Gemini treats as "available, no urgency".
2. **Use this week** — getting towards the edge. Gemini prefers it over Fresh items.
3. **Use today** — on its last legs. Gemini *must* feature it in the hero recipe.

The "Use today" state is the single most powerful signal in the whole app. It directly drives the waste-reduction benefit. Users who engage with it get a fundamentally different product than users who ignore it — so making it easy to set during onboarding is high-leverage.

## Copy

**Headline (large, bold):**
> And what's fresh right now?

**Subhead (one line, lighter weight):**
> Tap what you've got in. Tap again if it needs using sooner.

**Legend (under the subhead):**
> 🟢 Fresh   ·   🟡 This week   ·   🔴 Today

### Categories (4, in this order):

1. **Fresh veg**
2. **Fresh fruit**
3. **Fresh meat & fish**
4. **Fresh dairy & herbs**

### Pre-selected defaults

**None.** Fresh items change weekly; pre-selecting wastes taps and primes users to leave stale state in the system. The user starts from an empty grid and taps what's actually in.

### Suggested items per category

| Category | Items shown |
|---|---|
| Fresh veg | Onion, Garlic, Carrot, Potato, Tomato, Red pepper, Yellow pepper, Courgette *(US: Zucchini)*, Aubergine *(US: Eggplant)*, Spinach, Broccoli, Cauliflower, Mushroom, Cucumber, Avocado, Spring onion, Leek, Sweet potato, Lettuce, Celery |
| Fresh fruit | Lemon, Lime, Apple, Banana, Berries, Orange |
| Fresh meat & fish | Chicken breast, Chicken thighs, Mince (beef), Mince (pork), Bacon, Sausages, Salmon, White fish, Prawns, Steak |
| Fresh dairy & herbs | Milk, Yoghurt, Double cream, Parsley, Coriander *(US: Cilantro)*, Basil, Mint, Chives, Dill |

*(Region-aware via `region_utils.dart`. Halal/Kosher user: pork/bacon hidden.)*

**Primary CTA (full-width, sticky at bottom):**
> Let's make something!

**Button subtext (dynamic):**
> <N> fresh items · <M> need using today

## Layout

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ← prog.  │
│                                 │
│  And what's fresh right now?    │
│                                 │
│  Tap what you've got in.        │
│  Tap again if it needs using    │
│  sooner.                        │
│                                 │
│  🟢 Fresh · 🟡 This week · 🔴   │
│                        Today    │
│                                 │
│  Fresh veg                      │
│  ┌────────┐ ┌────────┐          │
│  │🟢 Onion│ │🟡 Tomato│         │
│  └────────┘ └────────┘          │
│  ┌────────┐ ┌────────┐ ┌──────┐ │
│  │🔴 Lemon│ │ Carrot │ │Spinach│ │
│  └────────┘ └────────┘ └──────┘ │
│  …more                          │
│                                 │
│  Fresh fruit                    │
│  ┌────────┐ ┌────────┐          │
│  │ Apple  │ │🟡 Banana│         │
│  └────────┘ └────────┘          │
│                                 │
│  Fresh meat & fish              │
│  ┌────────┐ ┌────────┐          │
│  │🟢 Chick │ │ Mince  │          │
│  │ breast │ │        │          │
│  └────────┘ └────────┘          │
│                                 │
│  Fresh dairy & herbs            │
│  ┌────────┐ ┌────────┐          │
│  │🟢 Milk │ │ Parsley│          │
│  └────────┘ └────────┘          │
│                                 │
│═════════════════════════════════│
│  ┌───────────────────────────┐  │
│  │  Let's make something!    │  │
│  │  8 fresh · 2 today        │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## Visual spec

- **Scrollable grid, sticky CTA.** Same pattern as screen 11. Category headers sticky as the user scrolls.
- **Item tiles** — same 2-column grid pattern as screen 11, but with a 3-state cycle instead of a 2-tier cycle.
- **Tile states:**
  - **Unselected:** off-white fill, subtle navy border.
  - **Fresh (🟢):** soft green fill + border, navy text, small `🟢` / checkmark glyph. First tap enters this state.
  - **This week (🟡):** soft amber fill + border, navy text, `🟡` / clock glyph. Second tap enters.
  - **Use today (🔴):** soft red fill + border, navy text, `🔴` / flame or urgency glyph. Third tap enters.
  - **Back to unselected:** fourth tap removes.
  - **Pressed:** scale 0.97, shadow suppressed.
- **Tap cycle:** unselected → Fresh → This week → Today → unselected. Every state reachable by repeated tapping. Long-press brings up an action sheet: "Mark as Fresh / This week / Today / Remove" (shortcut for screen-reader users and those who want to skip the cycle).
- **Category headers** — sticky, same style as screen 11.
- **Icons** — optional per item, same policy as screen 11 (top ~20 fresh items get icons; rest text-only).
- **Search bar** — sticky under the subhead, filters across all perishables.
- **"+ Add something" tile** — per category, adds a custom perishable in Fresh state.
- **Sticky CTA visual** — the button subtext shows two counts: total fresh items + how many are marked "today". When `today > 0`, the subtext colour shifts to urgent red. Small but reinforces the core mechanic.
- **Colour palette** — the three freshness states use the existing Elio palette where possible:
  - Fresh: a soft green *(new — not in current palette; Kate to derive, must be distinct from the amber/navy)*
  - This week: amber (existing `#F08C14`) at ~15% fill
  - Today: red/coral *(new — Kate to derive; must feel urgent but not alarm-harsh)*

## Personalisation — how earlier answers change this screen

| Earlier answer | Effect on screen 12 |
|---|---|
| **Goal = Waste less food** (screen 2) | Subhead becomes: "Anything on its last legs? Tap it twice — we'll build tonight's recipe around it." Micro-hint next to the Today legend: "Tap twice from unselected to mark Today ↓". |
| **Goal = Cook with what I've got** | Default subhead. Most natural fit for this screen. |
| **Goal = Decide dinner faster** | Subhead: "What's in the fridge? Tap the first few things you see." Primes speed. |
| **Goal = Household** | No subhead change. |
| **Goal = Takeaway escape** | Subhead: "A few fresh things and we're sorted — no takeaway tonight." |
| **Dietary = Vegetarian** | "Fresh meat & fish" category hidden. |
| **Dietary = Vegan** | "Fresh meat & fish" hidden; "Fresh dairy & herbs" shows herbs only (Milk/Yoghurt/Cream removed from the suggested list). |
| **Dietary = Pescatarian** | Meat items hidden from "Fresh meat & fish", fish kept. |
| **Halal / Kosher** | Pork/Bacon hidden from the suggested list. |
| **Allergies = Shellfish** | Prawns hidden. |
| **Allergies = Fish** | White fish, Salmon hidden. |
| **Allergies = Milk/dairy** | Fresh dairy items hidden; herbs kept. |
| **Region = US** | Category items use US vocabulary (Cilantro, Zucchini, Eggplant). |

### Data model

Writes to the existing perishable system:

```
inventory/{docId} — name, tier, category, expiryDate?, runningLow?
  where tier = 'perishable'
  and expiryDate is derived from the selected state:
    Fresh        → today + 7 days
    This week    → today + 3 days
    Today        → today + 0 days
  runningLow = true when state is "Today"
```

The existing `inventory/{docId}` doc already has `expiryDate` and `runningLow`. We pre-fill `expiryDate` based on the tapped state. Users can edit precise expiry dates in the post-onboarding pantry/scanner flows.

Gemini's existing prompt logic already handles "perishable items with urgency descriptions" (per CLAUDE.md's prompt structure). User-selected perishables for a specific recipe use the `REQUIRED` prompt rule from Sprint 15.3.20. Onboarding's "Today" items pre-fill the suggestion that gets shown on the first recipe screen.

### What this screen DOES NOT capture

- **Exact expiry dates.** "Today / This week / Fresh" is enough signal for Gemini; precise dates come from post-onboarding (manual edit, receipt scan, barcode scan).
- **Quantities.** Same as screen 11 — not needed for recipe generation.
- **Packaging / brand.** Out of scope — Elio works from ingredient identity, not brand.

## What Kate decides

- **Three freshness colours.** Green and red need to fit alongside the existing navy/amber palette without clashing. Kate to derive two new tones.
- **State glyphs.** Are circular coloured dots enough, or do we want literal icons (leaf, clock, flame)? Rob's default: coloured dots + text label below count — glyphs add noise.
- **Tap cycle vs always-on action sheet.** The tap cycle is fastest for power users; the long-press sheet is discoverable for everyone else. Both live in the spec; Kate may want to simplify to one approach in Figma.
- **Category breadth.** Four categories keeps it focused. Kate may argue for splitting "Fresh dairy & herbs" — Rob's default: keep them together to keep the category count low.
- **Sticky subtext** colour for "X today" — red-tinted when > 0, grey otherwise. Kate to pick the exact red so it reads urgent, not alarming.
- **Whether the CTA label changes** based on perishables — e.g. if `today > 0`, the CTA could become "Let's rescue something tasty" to reinforce the waste mechanic. Rob's default: keep "Let's make something!" consistent — don't overload the CTA.

## Why these decisions

- **Three freshness states, not two.** Two states (fresh / use-today) miss the middle ground most of the fridge lives in. Four (hours / today / days / week) is over-precise and drains taps. Three is the natural mental model: "it's fine / getting old / rescue it".
- **No pre-selected defaults.** Unlike staples, perishables change weekly. Pre-selecting would either train bad habits ("Elio always says I have tomatoes") or require users to uncheck things. Starting empty matches the real mental model: "what's in the fridge?"
- **Cycle on tap.** Splitting the freshness choice into a secondary step (e.g. tap then pick a state) doubles taps. The cycle is fast, discoverable (the legend shows the three states), and matches the existing app's pantry tier cycle pattern.
- **Pre-filled expiry dates.** Users can refine later — but we need *some* date for Gemini's urgency prompt to work. Rough is better than missing.
- **"Use today" is not a skip.** Forcing three taps for the most urgent state is deliberate friction — it reduces accidental "today" tags and makes the ones that land feel deliberate. If onboarding users under-tap "today", the downstream waste mechanic still works via in-app edits.
- **Count in the button subtext, with a split.** "8 fresh · 2 today" tells the user what they've built *and* primes the demo: they're about to see a recipe that starts with those 2 today-items. That's the core "moment of truth" of the app.
- **No skip.** A user who taps nothing gets an empty pantry and a weak first recipe. Friction here is good. Pre-selected count from screen 11 means Gemini can still generate *something*, but the perishable screen is where the recipe gets its specificity.
- **Four categories, not five.** Collapsing dairy + herbs keeps the vertical list short. Herbs are few, dairy in the fresh sense is few; together they make one sensibly-sized category.
- **Tile state shown both with colour and glyph.** Colour alone fails for colourblind users. The 🟢/🟡/🔴 glyph or an equivalent text/shape distinguishes regardless of colour perception.

## Edge cases & states

- **User taps 0 fresh items and hits Continue:** allowed. Count shows "0 fresh". The first recipe demo (screen 13) falls back to staples only. Flagged via `onboarding_no_perishables` analytics event.
- **User marks 20+ things Today:** allowed — some people genuinely have a fridge-cleanout week. No upper limit, but subtext colour treatment only kicks in between 1-9 (sensible urgency); 10+ treats all as a general "big shop going off".
- **User adds a custom perishable that's actually a staple** (e.g. types "flour"): no auto-detection in v1. Item saves as a perishable with Fresh state. Post-onboarding the user can re-tier via Settings → Pantry.
- **User double-taps too fast** (accidental cycle past intended state): current behaviour is "cycle continues to next state". Consider a debounce (200ms) to prevent accidental triple-cycles. Kate to validate in Figma.
- **User has Allergies + Dietary restrictions** that would hide 90% of the suggested items: the category still renders with whatever's left + the "+ Add something" tile. If a category would be completely empty, suppress the category header entirely.
- **Back from screen 13 (recipe demo):** selections + states preserved exactly.
- **Reduced Motion:** state transitions use instant colour swap, no fade.
- **Accessibility:**
  - Tiles announce as `<item>, <fresh | this week | today | unselected>, button`.
  - Long-press action sheet is announced and navigable via screen-reader actions.
  - Colour + glyph + text state — never colour alone.
  - Dynamic Type: tiles grow vertically; state glyphs stay inline with the label.
- **Low-memory device:** virtualised grid (existing `GridView.builder` pattern).

## Behaviour

- On entry: zero items selected. Count reads "0 fresh · 0 today". CTA active (zero is a valid state).
- Tap a tile → cycles state: unselected → Fresh → This week → Today → unselected.
- Long-press a tile → action sheet: "Mark as Fresh / This week / Today / Remove".
- Type in search → filters all items across categories.
- Tap "+ Add something" in a category → inline input; submit adds custom tile in Fresh state.
- Tap **Let's make something!** → persist perishables with derived `expiryDate` and `runningLow`; advance to screen 13 (First recipe demo).
- Back arrow → returns to screen 11 (Staples). All state preserved.
- No skip option. CTA is always live.

---

## Flag for implementation

When building this screen in Flutter, **do not use `showModalBottomSheet` inside the long-press action sheet** if the underlying screen is itself hosted inside a bottom sheet (unlikely here — onboarding is full-screen). Use `showDialog` for the long-press menu per the Flutter gotcha in `CLAUDE.md`. Long-press gesture should use `RawGestureDetector` with `LongPressGestureRecognizer(duration: Duration(milliseconds: 300))` — the existing pattern from the pantry builder.
