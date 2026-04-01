# Elio Product Guide

**Version:** Sprint 15.2 | **Date:** 31 March 2026 | **Status:** Pre-launch

---

## What is Elio?

Elio is an AI-powered recipe generator that knows your kitchen. Unlike generic recipe apps, Elio builds a living pantry inventory during onboarding and uses it — along with your dietary needs, cooking style, household members, and available appliances — to generate recipes grounded in what you actually have at home.

**Core principle:** Remove friction. Every interaction should be quick, minimal taps, zero frustration. Simplicity over completeness.

**Target platforms:** Android (primary), iOS (scaffolded)
**Target markets:** United States (primary), United Kingdom (secondary)

---

## Feature Overview

### 1. Smart Pantry System

Your pantry is the foundation of everything Elio does. Items are organised into three tiers:

| Tier | Purpose | Examples |
|------|---------|----------|
| **Always Have** | Staples you never run out of | Salt, olive oil, rice, flour |
| **Almost Always Have** | Usually stocked, occasionally low | Butter, eggs, onions |
| **Perishable** | Fresh items with limited shelf life | Chicken breast, spinach, milk |

**Key features:**
- **Collapsible sections** — Each tier collapses/expands with a tap. Item count shown when collapsed.
- **Group by Category** — Optional toggle to organise items within each tier by category (Spices, Dairy, Grains, etc.). 12 categories with automatic assignment.
- **Running Low flags** — Mark items you're almost out of. Recipes will avoid heavy reliance on these.
- **Expiry tracking** — Perishables can have expiry dates. Colour-coded badges (green = 3+ days, amber = 1–3 days, red = today/expired). Expiring items get priority in recipe generation.

### 2. Pantry Builder

A categorised browser for quickly stocking your pantry without typing. Accessed from a button at the bottom of the Pantry tab.

- **12 curated categories:** Spices & Seasonings, Asian Pantry, Indian Pantry, Mexican & Latin, Mediterranean, Oils & Vinegars, Dairy & Eggs, Canned & Jarred, Grains & Pasta, Baking Essentials, Sauces & Condiments, Frozen Staples
- **Tap to add** — Adds to Always Have tier by default
- **Long-press** — Choose which tier to add to
- **Search** — Real-time filtering across all categories
- **Visual feedback** — Items already in your pantry show a check mark and amber highlight
- **Custom input preserved** — The manual text input at the top of the Pantry tab still exists for anything not in the builder

### 3. AI Recipe Generation

The core experience. Powered by Google Gemini 2.5 Flash.

**How it works:**
1. Select which perishables to use (pre-populated from your pantry)
2. Optionally choose a mood, cooking style, or time constraint
3. Tap Generate — a full recipe appears in seconds

**What the AI considers:**
- All dietary restrictions across your household
- Your style preferences (comfort food, healthy, adventurous, etc.)
- Available appliances (air fryer, slow cooker, etc.)
- Perishable expiry urgency (prioritises items about to expire)
- Items flagged as running low (avoids overusing them)
- Your recipe history (avoids repeating recent meals)
- Your likes and dislikes (learns your taste over time)
- Budget/saver mode (cheaper ingredient choices)
- Regional pricing and measurement conventions

**Recipe output includes:**
- Title, description, and cuisine type
- Prep time, cook time, servings, difficulty
- Full ingredient list with quantities
- Step-by-step instructions
- Nutrition estimate (calories, protein, carbs, fat)
- Cost estimate (regional)

### 4. Ingredient Substitution

Tap any ingredient in a recipe to get options:

- **Substitute** — AI suggests an alternative from your pantry with adjusted quantity and a brief explanation of how it changes the dish
- **Remove & Regenerate** — Excludes the ingredient and generates a fresh recipe
- **Add to Shopping List** — Sends the ingredient straight to your shopping list

Substitutions happen in-place — no need to regenerate the entire recipe.

### 5. Recipe Book

Located in the Profile section, the Recipe Book has two views:

- **Saved** — Recipes you've bookmarked. Manually saving a recipe from the recipe screen automatically bookmarks it. You can also toggle the bookmark from history.
- **History** — All previously generated recipes, newest first. Free tier: 20 recipes. Pro tier: 50 recipes.

Both views show recipe cards with title, cuisine, time, difficulty, and nutrition. Tap to view the full recipe. Swipe left to delete with undo.

### 6. Voice-Controlled Cooking

Hands-free mode for when you're actually cooking.

- **Wake word:** "Hey Elio"
- **Commands:** Next step, previous step, repeat/read current step, done/exit
- **Text-to-speech** reads each step aloud
- **Continuous listening** with auto-restart on silence
- Toggle via the microphone button on the recipe screen

### 7. Scanning

Two scanning modes for quickly adding items to your pantry:

**Barcode Scanner:**
- Scan any product barcode
- Looks up the product via Open Food Facts API
- Returns product name and brand
- Auto-assigns a tier based on tier memory, heuristics, or user choice

**Receipt Scanner:**
- Take a photo of a grocery receipt
- AI extracts item names and prices
- Non-food items filtered automatically
- Bulk-add to pantry with tier assignment
- Receipts also feed into cost estimation

After scanning, you can generate a recipe immediately from the scanned items.

### 8. Meal Planner (Pro)

A full 7-day, 3-meals-per-day planner generated by AI.

- Phase 1: Generates meal titles and brief descriptions (fast)
- Phase 2: Tap any meal to lazy-load full recipe details (steps, nutrition, ingredients)
- Considers your full pantry, dietary needs, and variety across the week

### 9. Shopping List (Pro)

A persistent, cloud-synced shopping list with multiple input sources:

- **Manual** — Add items directly
- **From recipes** — Add missing ingredients from any recipe
- **From meal plans** — Aggregated shopping list from your weekly plan
- **Restock** — Items flagged as running low

Items can be checked off and are synced across devices.

### 10. Household Profiles (Pro)

Manage up to 6 household members, each with their own dietary requirements and allergens. All dietary constraints are merged when generating recipes, so every meal works for everyone.

Free tier: Owner profile only.

### 11. Onboarding

An 8-screen guided setup that builds your kitchen profile:

1. Welcome
2. Dietary requirements
3. Kitchen presets (quick-start pantry packs like "Asian Kitchen", "Mediterranean Kitchen")
4. Pantry inventory (add individual items + packs)
5. Household members
6. Cooking style preferences
7. Kitchen appliances
8. Measurement units and region

### 12. Settings

Accessible from the Profile section:

- **Household management** — Add/remove members, edit dietary needs
- **Dietary & Allergens** — Your own dietary requirements and custom allergens
- **Kitchen Appliances** — Select what you own from 12 common appliances
- **Measurement Units** — Metric (g, ml, °C) or Imperial (oz, cups, °F)
- **Region** — United States or United Kingdom (affects pricing, language, defaults)
- **Notification preferences** — Weekly reminders, restock alerts, tips & updates

---

## Monetisation

**Model:** Freemium subscription, no ads.

| Feature | Free | Pro | Guest |
|---------|------|-----|-------|
| Recipes per week | 7 | Unlimited | 3 |
| Recipe history | 20 | 50 | 20 (local) |
| Household members | Owner only | Up to 6 | None |
| Meal planner | No | Yes | No |
| Shopping list | No | Yes | No |
| Scanning | Yes | Yes | No |
| Pantry Builder | Yes | Yes | Yes (local) |
| Voice cooking | Yes | Yes | Yes |
| Substitution | Yes | Yes | Yes |
| Recipe import (photo or manual) | No | Yes | No |

**Pricing:**
- US: $4.99/month or $29.99/year
- UK: £4.49/month or £27.99/year
- 7-day free trial (no card required), shown at end of onboarding

**Payment processing:** RevenueCat SDK (runs in dry mode if no API key configured).

---

## Guest Mode

Users can try Elio without creating an account:

- 3 recipes per week
- 20 recipe history (stored locally via SharedPreferences)
- Pantry stored locally (not synced)
- No scanning, meal planning, shopping list, or household features
- Prompted to sign up when hitting limits or accessing Pro features

---

## Planned Features (Post-Launch)

- iOS production build with Apple Sign-In
- Accurate cost estimation via supermarket API integration
- Grocery affiliate integration (shopping list to delivery)
- Social sharing (recipe card as shareable image)
- Multilingual support
- Regional language localisation (courgette vs zucchini, coriander vs cilantro)
