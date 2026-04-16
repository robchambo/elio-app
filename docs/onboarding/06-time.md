# Onboarding Screen 6 — Time on weeknights

**Step 6 of ~15** · Archetype: Single-select
**Status:** Draft v1, awaiting Kate's design

---

## Objective

Find out how long the user realistically has for a weeknight meal. Feeds a hard cap into the Gemini prompt so the first recipe — and every subsequent one — respects the time budget. This is the single biggest predictor of whether a generated recipe gets cooked or ignored.

Weeknight-specific on purpose. Weekend cooking has different constraints and we don't ask about it here; a user willing to cook for 90 minutes on Saturday still needs 20-minute options on Tuesday.

## Copy

**Headline (large, bold):**
> How long have you got on a weeknight?

**Subhead (one line, lighter weight):**
> We'll keep recipes inside your time budget.

**Options (single-select, vertical cards):**

| # | Label | Subtext | `maxCookTime` (minutes) |
|---|---|---|---|
| 1 | 15 minutes or less | Quick fixes, one pan, done | 15 |
| 2 | About 30 minutes | The weeknight sweet spot | 30 |
| 3 | Up to 45 minutes | Room for something proper | 45 |
| 4 | An hour or more | I enjoy the cooking bit | 75 |

**Primary CTA (full-width, disabled until selection made):**
> Continue

## Layout

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓▓▓▓▓▓▓▓▓░░  ← progress    │
│                                 │
│  How long have you got          │
│  on a weeknight?                │
│                                 │
│  We'll keep recipes inside      │
│  your time budget.              │
│                                 │
│  ┌───────────────────────────┐  │
│  │ ⚡  15 minutes or less     │  │
│  │     Quick fixes, one pan… │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ ⏱️  About 30 minutes       │  │
│  │     The weeknight sweet…  │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 🍳  Up to 45 minutes       │  │
│  │     Room for something…   │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 🍲  An hour or more        │  │
│  │     I enjoy the cooking…  │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │       Continue            │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## Visual spec

- **Cards** — same system as screens 2–4. Full-width, rounded, amber border + tick on select.
- **Icons** — 4 custom icons representing time/effort escalation. Files: `time_15.svg`, `time_30.svg`, `time_45.svg`, `time_60.svg`. Emoji above are v1 stopgap. Kate may prefer an illustrative progression (e.g. a progress-style visual rather than four different metaphors).
- **Subtext tone** — deliberately conversational, not spec-sheet ("the weeknight sweet spot" > "recommended"). Matches the overall conversational British tone from the transformation memory.
- **Selection feedback** — standard amber tick + border. No timer animation or extra flourish; the card works hard enough with copy.

## Personalisation — how this feeds downstream

| Downstream surface | Change |
|---|---|
| **Screen 7 Confidence** | If user picked "15 minutes or less", subhead softens: "We'll lean easy — no fiddly bits." Overriding the user toward "Challenge me" feels wrong given the time budget. |
| **Screen 11 Pantry build** | No change (ingredients aren't time-sensitive). |
| **Screen 13 First recipe** | Gemini prompt receives `maxCookTime: <minutes>` as a hard constraint in the Style/time/mood section. Also informs the generated recipe's `time` meta row. |
| **Ongoing generation** | Default `maxCookTime` for every generation; user can override per-recipe via an existing "I've got more time today" control (if not built, add in a later sprint). |

### Data model

New field on the user doc:

```
users/{uid}.maxCookTime: int         // minutes: 15 | 30 | 45 | 75
```

Check `lib/models/elio_models` and `gemini_service._buildPrompt()` — if there's already a `cookTime`/`timePreference` field, reuse it and map the four options to the existing values. Otherwise add `maxCookTime` and extend the prompt's Style/time/mood section with:

> "The user has about <N> minutes on a weeknight. Keep total recipe time (prep + cook) at or below this."

## What Kate decides

- Icon set for the 4 time brackets — four separate metaphors, or a unified escalating visual (e.g. a clock fill, a flame count).
- Whether the cards have a subtle time-indicator on the right (e.g. "15 min", "30 min") in addition to the label, or whether the label is enough.
- Whether the selected card reveals a preview strip ("Recipes like: 15-minute miso noodles, speedy chilli, …") — nice-to-have for confidence, not required for v1.

## Why these decisions

- **Four options, not a slider.** A slider invites over-precision and analysis paralysis ("is 27 minutes different from 30?"). Four brackets map cleanly to how people actually think about weeknight cooking.
- **Weeknight-specific.** Cooking-time preferences are time-of-week bimodal. Asking a generic "how long?" collapses two different answers into one, producing mediocre recipes for both modes.
- **"An hour or more" capped internally at 75 minutes.** Gives headroom for slow-cook or multi-stage recipes without letting Gemini generate a 3-hour braise that the user never finishes. The label says "an hour or more" to match user mental model; the prompt value (75) is the actual cap.
- **No "Varies" option.** Most users *do* have a typical weeknight budget even if it flexes. Forcing a best-guess here is the right call — we can always expose per-recipe overrides inside the app.
- **Copy centres the user's life, not the recipe.** "How long have you got?" not "Pick a cook time." Every question on every screen should feel like someone asking *you* something, not a form.

## Edge cases & states

- **Change selection before Continue:** standard — new card selected, old deselected, Continue stays active.
- **Back from screen 7:** selection preserved.
- **Accessibility:** each card announces as "<label>, <subtext>, <selected/unselected>, button". Continue announces disabled state until selection made.
- **Reduced Motion:** skip the card entrance stagger; cards appear instantly.
- **Screen entrance:** cards stagger in (30ms rhythm, matching screens 2–4).

## Behaviour

- Tap a card → selection state visible, Continue activates.
- Tap a different card → old deselected, new selected.
- Tap **Continue** → persist `maxCookTime`; advance to screen 7 (Cooking confidence).
- Back arrow → returns to screen 5 (Allergies). Selection preserved.
- No skip option. We need a time budget for every user — the closest to "not applicable" is "an hour or more", which is itself a real answer.
