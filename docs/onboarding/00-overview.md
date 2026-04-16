# Onboarding Redesign — Overview

**Status:** Draft v1, in progress
**Owner:** Rob (copy/spec) + Kate (visual design, Figma)
**Replaces:** Existing 8-screen flow (`lib/screens/onboarding/screen1_dietary` → `screen8_complete`)

---

## Why we're redoing onboarding

The current flow gates the app behind sign-in on screen 1 — our biggest funnel drop-off. It also asks for preferences before the user understands what Elio does, which kills completion rates and hurts the quality of the answers we get.

The new flow:

1. **Sells the outcome first.** User sees the AFTER state before being asked for anything.
2. **Defers sign-in to the end.** Account creation only after the user has experienced value (a generated recipe).
3. **Personalises as it goes.** Each answer changes downstream copy — onboarding becomes a conversation, not a form.
4. **Builds a usable pantry on screens 11–12.** Staples first, then perishables — so screen 13 can demo a real recipe from real ingredients.

## The transformation we're selling

**BEFORE:** It's 6pm. The fridge is half-full of stuff you forgot you bought. You're scrolling recipes that need three things you don't have. The avocado's going soft, the chicken needs using, and you still end up ordering takeaway — again. Meal planning feels like a second job you never signed up for.

**AFTER:** You open Elio, tap what's fresh, and get a recipe built around your pantry in seconds. Less waste, less decision fatigue, no more 6pm panic. Dinner sorted — without the mental load.

## Core benefits (priority order)

1. **Cook what you already have** — recipes built around your pantry, not a shopping list you don't want to do.
2. **Waste 40% less food** — use what's ripe before it's rubbish. *(stat needs WRAP citation before launch)*
3. **Decide dinner in 30 seconds** — no more scrolling, no more "what do you fancy?".
4. **One plan for the whole household** — dietary needs, fussy eaters, and all.
5. **Stop ordering takeaway on autopilot** — eat well, spend less, without the effort.

Every headline, subhead, and CTA in the flow maps to one of these five (or to the BEFORE/AFTER arc).

## Screen flow (15 screens)

| # | Screen | Archetype | Purpose | Status |
|---|---|---|---|---|
| 1 | Welcome | Hook | Sell the AFTER state with a real recipe card | Draft v1 ✅ |
| 2 | Goal | Single-select | What brings you here? Personalises downstream copy | Draft v1 ✅ |
| 3 | Household | Single-select + count | Who are you cooking for? | Draft v1 ✅ |
| 4 | Dietary requirements | Multi-select | Vegan/veggie/pescatarian/none + any household members differ | Draft v1 ✅ |
| 5 | Allergies & exclusions | Multi-select + free-text | Things that must never appear | Draft v1 ✅ |
| 6 | Time on weeknights | Single-select | 15 / 30 / 45 / 60+ min — caps recipe complexity | Draft v1 ✅ |
| 7 | Cooking confidence | Single-select | Easy / mix / challenge me — affects technique | Draft v1 ✅ |
| 8 | Appliances | Multi-select | What you've got — air fryer, slow cooker, etc. | Draft v1 ✅ |
| 9 | Region & units | Single-select | UK/US, metric/imperial — affects ingredients & language | Draft v1 ✅ |
| 10 | Pantry intro | Hook | Sets expectation for the two pantry screens (11–12) | Draft v1 ✅ |
| 11 | Pantry — staples | Multi-select grid | Always-have + almost-always-have items, category-grouped | Draft v1 ✅ |
| 12 | Pantry — perishables | Multi-select grid | What's in right now; drives "use today" tagging | Draft v1 ✅ |
| 13 | First recipe demo | Reward | Generated live, from their pantry, with shimmer streaming | Draft v1 ✅ |
| 14 | Paywall (trial-first) | Conversion | 7-day free trial, context = "first recipe" | Draft v1 ✅ |
| 15 | Soft account gate | Conversion | "Save your pantry & recipe — sign in" (Apple/Google/email) | Draft v1 ✅ |

**Progress bar** persists from screen 1 onward, filling proportionally. **Back button** appears from screen 2 onward (no back from screen 1).

## Format of per-screen briefs

Each `NN-name.md` brief contains:

- **Objective** — what this screen is for
- **Copy** — exact headline, subhead, options, CTA
- **Layout** — ASCII sketch as a starting point (Kate redesigns in Figma)
- **Visual spec** — anything Kate needs to know about hero images, icons, illustration
- **Personalisation** — how this answer changes downstream screens (where applicable)
- **What Kate decides** — open visual decisions
- **Why these decisions** — rationale Rob can defend or push back on
- **Behaviour** — interactions, validation, advance logic

Briefs are designed to be read standalone — Kate can open any single file without context.

## How to use these docs

- **Rob** edits copy/spec in these files. Source of truth for product intent.
- **Kate** designs in Figma against each brief. Adds Figma frame links to the brief once started.
- **Both** treat this `docs/onboarding/` folder as the working draft. Rob shares files locally with Kate (no commit/push needed yet).
- **Sign-off** on each screen happens in the brief — Rob marks `Status: Approved` once Kate's design is locked.

## Open questions

- 40% food waste stat — needs a real source (WRAP report or Elio's own data) before screen 14/launch copy can use it.
- *(Resolved 2026-04-15 — two screens. Staples on 11, perishables on 12. Pantry builder is the core differentiator; splitting gives it the space it deserves.)*
- *(Resolved 2026-04-15 — three peer providers; ordering follows platform convention. iOS: Apple → Google → Email. Android v1: Google → Email (Apple Sign-In deferred to Sprint 19 per CLAUDE.md).)*
