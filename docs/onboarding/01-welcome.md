# Onboarding Screen 1 — Welcome

**Step 1 of ~15** · Archetype: Welcome / Hook
**Status:** Draft v1, awaiting Kate's design

---

## Objective

Hook the user with the transformation outcome before asking for anything. Replaces the current sign-in gate (which is the single biggest drop-off point in the existing flow). Sign-in moves to screen 15, after the user has experienced value.

## The transformation we're selling

**BEFORE:** It's 6pm. The fridge is half-full of stuff you forgot you bought. You're scrolling recipes that need three things you don't have. Takeaway again.

**AFTER:** Tap what's fresh, get a recipe built around your pantry in seconds. Less waste, less decision fatigue, no 6pm panic.

This screen sells the AFTER state in one glance.

## Copy

**Headline (large, bold):**
> Tonight's dinner, from what you already have.

**Subhead (one line, lighter weight):**
> Recipes built around what's already in your kitchen.

**Primary CTA (full-width button):**
> Get started

**No secondary link.** Log in moves to screen 15 (post-demo soft account gate).

## Layout

```
┌─────────────────────────────────┐
│ ▓▓░░░░░░░░░░░░░░░  ← progress  │
│                                 │
│  Tonight's dinner,              │
│  from what you already have.    │
│                                 │
│  Recipes built around what's    │
│  already in your kitchen.       │
│                                 │
│      ┌─────────────┐            │
│      │             │            │
│      │  [device    │            │
│      │   mockup    │            │
│      │   with      │            │
│      │   recipe    │            │
│      │   card]     │            │
│      │             │            │
│      └─────────────┘            │
│                                 │
│  ┌───────────────────────────┐  │
│  │      Get started          │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## Hero visual spec

A phone mockup containing one recipe card — as if the user just generated it.

### Recipe card content

- **Title:** Lemon & Garlic Chicken Traybake
- **Meta row (small, grey):** 25 min · Serves 4 · Easy
- **Hero photo:** overhead shot of a traybake — chicken thighs, lemon wedges, cherry tomatoes, red onion, herbs. Warm golden lighting. Real photo feel, not stock-y.
- **Section header:** Ingredients
- **Ingredient list (6 items, each with a tag):**

| Ingredient | Tag |
|---|---|
| Chicken thighs | *In your pantry* |
| Cherry tomatoes | *In your pantry* |
| Red onion | *In your pantry* |
| Lemon | *Use today* |
| Garlic | *In your pantry* |
| Olive oil | *Always have* |

### Tag styles (the hero detail)

- **In your pantry** — soft green pill, checkmark icon
- **Use today** — soft amber pill, clock icon *(signals the waste-reduction benefit)*
- **Always have** — soft grey pill, no icon *(staples)*

The tags are what make this screen work — they prove the pantry-first promise at a glance.

## Why this specific recipe

- **Universal appeal:** chicken traybake works for US + UK, families + couples, weeknight + weekend.
- **Visually appetising:** colourful (red, green, yellow), photographable, neither diet-food nor fancy-food.
- **Tells the story in one glance:** mostly pantry-tagged items, one "use today" item showing the wedge, one staple.
- **Fits above the fold:** 6 ingredients leaves room for title and meta row without scrolling.

## What Kate decides

- Device frame style (matches Sprint 16 system)
- Tag pill exact colours (slot into Elio palette)
- Whether to crop the card so it fades at the bottom (suggesting more below) or show it complete
- Photography source: custom shoot, licensed stock, or AI-generated food photo

## Why these decisions

- **Headline sells outcome, not product.** Not "Welcome to Elio" or "AI-powered recipes" — those centre the app, not the user.
- **No sign-in here.** Users see value before being asked to identify themselves. Highest-leverage funnel fix in the redesign.
- **Real recipe, not illustration.** Users trust screenshots over hero illustrations.

## Behaviour

- Tap **Get started** → advance to screen 2 (Goal question)
- Progress bar persists across all subsequent screens, filling proportionally
- No back button (this is screen 1)
