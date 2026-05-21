# Onboarding Screen 10 — Pantry intro

**Step 10 of ~15** · Archetype: Hook / interstitial
**Status:** Draft v1, awaiting Kate's design

---

## Objective

A breather and a set-up. After eight consecutive question screens (2–9), the user needs a moment that isn't another form field. This screen does two things:

1. **Signals a shift.** We're done with preferences; the next step is about *your kitchen, today*.
2. **Sets expectation.** The pantry build (screens 11–12) looks like it could take 10 minutes. This screen promises "a minute, in two quick steps" and delivers the "why" so they don't bail when the grid loads.

No selection, no validation. One CTA. This is the narrative pivot in the flow — from "tell us about you" to "let's use it".

## Copy

*(Default copy; per the screen 2 personalisation matrix, the subhead varies by selected goal — see Personalisation below.)*

**Headline (large, bold):**
> Now, what's already in your kitchen?

**Subhead (one or two lines, lighter weight):**
> This is the bit that makes Elio different — every recipe starts from what you've got. Takes about a minute, in two quick steps.

**Visual (centre-screen hero):**
A simple, illustrative "kitchen peek" — an open fridge or a pantry shelf with a handful of recognisable items (tomato, chicken, eggs, a tin of beans, a lemon). Warm, inviting, not photographic.

**Primary CTA (full-width):**
> Let's have a look

## Layout

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ← progress   │
│                                 │
│  Now, what's already            │
│  in your kitchen?               │
│                                 │
│  This is the bit that makes     │
│  Elio different — every recipe  │
│  starts from what you've got.   │
│  Takes about a minute, in two quick steps.        │
│                                 │
│      ┌───────────────┐          │
│      │               │          │
│      │  [fridge or   │          │
│      │   pantry      │          │
│      │   illustrat-  │          │
│      │   ion, warm]  │          │
│      │               │          │
│      └───────────────┘          │
│                                 │
│  ┌───────────────────────────┐  │
│  │      Let's have a look    │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## Visual spec

- **Hero illustration** — the centrepiece of the screen. Should feel warm and lived-in, not stylised or minimalist. Suggestions Kate to consider:
  - **Option A:** An open fridge viewed from the front — a few shelves with recognisable items (a tomato, a bag of carrots, a lemon, some eggs, a tin). Warm lighting spilling out of the door.
  - **Option B:** A counter-top tableau — a chopping board with an onion, a head of garlic, a bunch of herbs, a jar of olive oil behind.
  - **Option C:** An animated "shelf tour" — items fade in one by one (onion, tin of tomatoes, pasta) as the user reads.
  - Rob's pick: **A**, because "open fridge" is the single most recognisable shorthand for "what have I got tonight" — and it matches the BEFORE story ("fridge is half-full of stuff you forgot").
- **No recipe preview** — that comes in screen 13. This screen is about the pantry itself.
- **Typography** — same headline/subhead system as other screens. Slightly more breathing room around the headline since there's less content.
- **Progress bar** — at screen 10, the user is ~67% through (10/15). Make this visually encouraging; most users give up on long onboardings at the halfway point.
- **No back button?** — we keep the back arrow (consistency) but it's the least-clicked button on this screen.

## Personalisation — how this feeds downstream

### Subhead variant per goal (from screen 2)

| Goal | Subhead |
|---|---|
| Cook with what I've got (#1) | *(default)* This is the bit that makes Elio different — every recipe starts from what you've got. Takes about a minute, in two quick steps. |
| Waste less food (#2) | Let's see what's in your kitchen — especially anything that needs using soon. Takes about a minute, in two quick steps. |
| Decide dinner faster (#3) | Quick tour of your kitchen — then dinner gets a lot faster. Takes about a minute, in two quick steps. |
| Feed the whole household (#4) | Let's stock the kitchen for everyone. Takes about a minute, in two quick steps. |
| Stop ordering takeaway (#5) | Let's see what's in — so you've always got an answer to "what's for dinner?". Takes about a minute, in two quick steps. |

The "about a minute, in two quick steps" time promise stays constant across variants — it's the crucial expectation setter.

### Downstream effect

No data captured here, so no downstream state changes. This is purely a narrative beat.

## What Kate decides

- Hero illustration direction — fridge vs counter vs animated shelf tour. Rob's pick: fridge (option A).
- Whether the illustration is fully illustrated (vector, stylised) or photographic-leaning (closer to the real thing). Brand-art concept suggests illustrative; confirm against `docs/brand-art-concept.md`.
- Whether the CTA is "Let's have a look" (recommended, warm) or "Get started", "Continue", "Show me". Rob's pick: keep it warm; nothing else on this screen is earning its place in tone terms.
- Whether to include a tiny "~1 min" time chip somewhere visible (e.g. next to the progress bar). Risk: feels gamified; reward: the time promise is the single most conversion-relevant thing on the screen.

## Why these decisions

- **Hook screens earn their place by shaping expectation.** Screens 11–12 (the pantry build) are the only screens in the flow that look like "work". Setting expectation ("a minute in two steps, here's why") converts that work into part of the story rather than a wall.
- **No selection means no cognitive load.** After eight questions, the user needs a moment to not decide anything. Hook screens are also where we earn back attention for the pantry screens and the screen 13 demo.
- **The hero is the fridge, not a recipe.** Recipe visual goes on screen 13. Showing it here would dilute that payoff. The fridge also maps nicely: open fridge here → cupboard (staples, screen 11) → fridge (perishables, screen 12).
- **Time promise is load-bearing.** "About a minute, in two quick steps" is the single-most-important phrase on this screen. Users bail at the *anticipation* of long tasks, not at the tasks themselves. A concrete time + the two-step shape converts "how much is this going to ask of me?" into "OK, I'll do a minute".
- **Personalisation via subhead only.** Changing headline or CTA per goal would stretch QA surface area; the subhead is enough to make the screen feel responsive to earlier answers.
- **Screen 10 and screen 13 bracket screens 11–12.** 10 sets up, 13 pays off. The pantry screens are the work between them. Without 10, the pantry build feels abrupt.

## Edge cases & states

- **User rapidly taps the CTA** (common on hook screens): debounce the navigation. No harm done, but avoid multiple screen-11 pushes on the stack.
- **Back arrow from screen 11:** returns here. No state to preserve (no selection on this screen).
- **Accessibility:** headline + subhead read aloud in order; hero illustration has an alt description ("An open fridge with recognisable ingredients — tomatoes, a lemon, eggs, a tin of beans"); CTA announces as "Let's have a look, button".
- **Reduced Motion:** if the hero uses any animation (option C), fall back to a static composition. Entrance animation for the screen itself is fine to keep (standard stagger is gentle).
- **Screen entrance:** headline fades in, subhead follows 100ms later, hero illustration fades in 150ms after that. Adds a tiny cinematic feel that signals this screen is different from the question sequence.

## Behaviour

- Tap **Let's have a look** → advance to screen 11 (Pantry — staples).
- Back arrow → returns to screen 9 (Region & units).
- No state captured or persisted on this screen.
