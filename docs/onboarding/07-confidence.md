# Onboarding Screen 7 — Cooking confidence

**Step 7 of ~15** · Archetype: Single-select
**Status:** Draft v1, awaiting Kate's design

---

## Objective

Calibrate the technique level of generated recipes. Time (screen 6) tells Gemini *how long*; confidence tells Gemini *how ambitious*. A 30-minute budget covers everything from a traybake to a risotto — confidence decides which end we lean toward.

Also a quiet signal for copy tone downstream: a "keep it easy" user gets softer language around steps ("slide the tray in"), while a "challenge me" user gets permission for technique words ("deglaze", "temper").

## Copy

**Headline (large, bold):**
> How do you feel about cooking?

**Subhead (one line, lighter weight):**
> Helps us pick how adventurous to go.

**Options (single-select, vertical cards):**

| # | Label | Subtext | Internal value |
|---|---|---|---|
| 1 | Keep it simple | One pan, few ingredients, nothing fiddly | `easy` |
| 2 | A bit of both | Easy most nights, happy to branch out | `mixed` |
| 3 | Bring on the technique | Teach me something new — I like learning | `challenge` |

**Primary CTA (full-width, disabled until selection made):**
> Continue

## Layout

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓▓▓▓▓▓▓▓▓▓░  ← progress    │
│                                 │
│  How do you feel about cooking? │
│                                 │
│  Tells us how adventurous       │
│  to get with techniques.        │
│                                 │
│  ┌───────────────────────────┐  │
│  │ 🫕  Keep it simple         │  │
│  │     One pan, few ingred…  │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 🥘  A bit of both          │  │
│  │     Easy most nights, h…  │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 🔥  Challenge me           │  │
│  │     Teach me something…   │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │       Continue            │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## Visual spec

- **Cards** — same system as screens 2–6. Full-width, rounded, amber border + tick on select.
- **Icons** — 3 custom icons representing escalating technique. Files: `confidence_easy.svg`, `confidence_mixed.svg`, `confidence_challenge.svg`. Style consistent with onboarding set. Kate may prefer a unified metaphor (e.g. one, two, three flames) rather than three distinct illustrations.
- **Card hierarchy** — label in Outfit semibold; subtext one line in Quicksand secondary. No visual ranking suggested (no numbers, no "recommended" badge).
- **Selection** — standard amber tick + border. No extra flourish.

## Personalisation — how this feeds downstream

| Downstream surface | Change |
|---|---|
| **Screen 11 Pantry build** | No change (ingredient categories aren't confidence-sensitive). |
| **Screen 13 First recipe** | Gemini prompt receives a confidence instruction in the Style/time/mood section: `easy` → "Use simple techniques, short ingredient lists, minimal equipment. Avoid cheffy language in the steps." / `mixed` → "Mix easy recipes with the occasional technique-led dish. Default to familiar dishes." / `challenge` → "Lean into technique — deglazing, braising, emulsifying are welcome. Explain new terms briefly inline." |
| **Step-level copy** | `challenge` users see technique words unglossed ("deglaze the pan"); `easy` users see plain-language equivalents ("pour a splash of wine in and scrape the bottom"). Gemini handles this via the instruction above — no separate post-processing. |
| **Recipe meta row** | No visible label (we don't want to classify recipes as "easy" or "hard" to the user — that's our problem, not theirs). |

### Data model

New field on the user doc:

```
users/{uid}.cookingConfidence: String      // "easy" | "mixed" | "challenge"
```

Check `users/{uid}.stylePreferences` (already exists per CLAUDE.md) — if it's a flexible string array, confidence can be folded in as one of its values. If `stylePreferences` is strictly for flavour/cuisine style, keep `cookingConfidence` as a separate field to avoid semantic overload.

## What Kate decides

- Icon set — three distinct illustrations vs a unified escalating metaphor (flames, stars, knife difficulty).
- Whether to show a subtle preview under the selected card ("You'll see recipes like: …") — nice-to-have, not required.
- Whether "Challenge me" gets a warmer visual treatment (it's the aspirational pick and reads a touch cold in copy alone).

## Why these decisions

- **Three levels, not five.** Five introduces bucketing anxiety ("am I a 3 or a 4?") with no meaningful output difference downstream. Three maps to a clear prompt change.
- **No "I'm a complete beginner" option.** Reads as infantilising. "Keep it simple" covers the same ground without making the user self-label.
- **"A bit of both" as the middle, not "Intermediate".** "Intermediate" is spec language. "A bit of both" is how people actually describe themselves.
- **Confidence is a separate screen from Time.** They interact (a 15-minute "Challenge me" is a narrower space than a 45-minute one) but conflating them loses the signal — time is a *constraint*, confidence is a *preference*. Asking them together would force a matrix grid and burn more cognitive load than two clean questions.
- **Copy tone hook included.** The prompt doesn't just affect *what* recipes get generated, but *how* the steps read. That's a real lift on perceived quality — a cheffy phrase in an "easy" user's recipe reads as tone-deaf.
- **No skip.** Every user has a confidence level; there's no neutral "not applicable" answer.

## Edge cases & states

- **Time = 15 min + Challenge me:** no friction warning. A 15-minute challenge is still a thing (a sharp knife skill, a fast emulsion) — we let Gemini handle the narrower space rather than blocking the combination.
- **Change selection before Continue:** standard — old card deselected, new selected.
- **Back from screen 8:** selection preserved.
- **Accessibility:** each card announces as "<label>, <subtext>, <selected/unselected>, button".
- **Reduced Motion:** skip card entrance stagger.
- **Screen entrance:** cards stagger in (30ms rhythm, matching screens 2–6).

## Behaviour

- Tap a card → selection visible, Continue activates.
- Tap a different card → old deselected, new selected.
- Tap **Continue** → persist `cookingConfidence`; advance to screen 8 (Appliances).
- Back arrow → returns to screen 6 (Time). Selection preserved.
- No skip option.
