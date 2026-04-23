# Onboarding Screen 13 — First recipe demo

**Step 13 of ~15** · Archetype: Reward / live generation
**Status:** Draft v1, awaiting Kate's design

---

## Objective

The payoff. Everything the user has entered on screens 2–12 is now used to generate a real recipe, live on screen, in front of them. Streaming via Gemini. Takes ~4-6 seconds. Ends with a recipe card that feels unmistakably theirs — their household size, their pantry, their time budget, their appliances, their "Today" items.

This is the single most important screen in the flow for conversion. Everything before it was setup. The paywall on screen 14 will land or fail based on how this screen feels.

Two outcomes must happen here for the whole redesign to work:

1. **"Huh, that's actually for me."** Recognition — the recipe visibly uses their Today items, their household count, their vocabulary.
2. **"I could actually make this tonight."** Plausibility — the recipe sits inside their time + confidence + appliances budget, with no ingredients they don't have.

## Copy

### States

**1. Generating state (while streaming):**

**Headline:**
> Tonight's dinner, coming up…

**Subhead (updates as stream progresses):**
> - t+0s: "Working out what to cook with what you've got…"
> - t+2s: "Writing the recipe…"
> - t+4s: "Plating it up…"

**Body:** Shimmer skeleton of the recipe card (same pattern as the home screen's generate flow).

**2. Complete state:**

**Headline (small, above the card):**
> Made just for you. Built from your kitchen.

**Recipe card** (see Visual spec).

**Primary CTA (full-width):**
> Cook this tonight

**Secondary link below:**
> Show me another

**3. Error state** (Gemini timeout / failure):

**Headline:**
> Hmm, let's try that again.

**Subhead:**
> Couldn't reach Elio right now. Your pantry's saved — tap retry.

**Primary CTA:**
> Try again

**Secondary link:**
> Skip for now *(advances to screen 14 with no recipe — edge case, covered below)*

## Layout — Generating state

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ← prog │
│                                 │
│  Tonight's dinner, coming up…   │
│                                 │
│  Writing the recipe…            │
│                                 │
│  ┌───────────────────────────┐  │
│  │ ░░░░░░░░░░░░░░░░░░░░░░░░░ │  │
│  │ ░░░░░░░░░░ shimmer        │  │
│  │ ░░░░░░░░░░░░░░░░░░░       │  │
│  │                           │  │
│  │  ░░░░░░░░░░ ░░░░ ░░░░     │  │
│  │  ░░░░░░░  ░░░░░   ░░      │  │
│  │  ░░░░░░░░░░░░░░░ ░░░      │  │
│  │  ░░░░░░░░░░░░░             │  │
│  └───────────────────────────┘  │
│                                 │
│  (no CTA visible while streaming)│
└─────────────────────────────────┘
```

## Layout — Complete state

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ← prog │
│                                 │
│  Made just for you.             │
│  Built from your kitchen.       │
│                                 │
│  ┌───────────────────────────┐  │
│  │ [hero photo of the dish]  │  │
│  │                           │  │
│  │  Lemon & Garlic Chicken   │  │
│  │  Traybake                 │  │
│  │  25 min · Serves 4 · Easy │  │
│  │                           │  │
│  │  Ingredients              │  │
│  │  • Chicken thighs  ◐      │  │
│  │  • Lemon          🔴      │  │
│  │  • Garlic         ◐       │  │
│  │  • Cherry tomatoes ◐      │  │
│  │  • Red onion      ◐       │  │
│  │  • Olive oil      ✅      │  │
│  │                           │  │
│  │  ⌄ See the steps          │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │     Cook this tonight     │  │
│  └───────────────────────────┘  │
│         Show me another         │
└─────────────────────────────────┘
```

## Visual spec

### Shimmer skeleton

Reuse the existing home-screen shimmer pattern from Sprint 15.3.x — same widget, same timing. Adds instant consistency with the post-onboarding app.

### Recipe card

The card is a live ingredient card, structurally identical to the screen 1 hero card but populated from the real Gemini response:

- **Hero photo** — if Gemini returns an image reference, use it. Otherwise use a generated / stock image based on the recipe title. Fallback: a warm solid-colour card with the recipe title overlaid.
- **Title** — the Gemini-returned recipe title.
- **Meta row** — `<time> · Serves <householdCount> · <difficulty>`. Time matches user's `maxCookTime`; serves matches `householdCount`; difficulty derives from user's `cookingConfidence`.
- **Ingredients** — full list, with pantry tags. Each ingredient shows one of:
  - `✅ Always in` — amber solid
  - `◐ Usually in` — amber outline
  - `🔴 Use today` — coral *(this is the hero label; critical for waste-reduction narrative)*
  - `🟡 Use this week` — amber
  - `🟢 Fresh` — green
  - `+ Shopping list` — grey *(items not in their pantry; Gemini shouldn't generate any unless the pantry is thin)*
- **Expandable steps** — collapsed by default; tap chevron to reveal. Keeps the first-impression tight; full recipe available for the committed user.
- **Small "Why this?"** link at the bottom of the card, optional: opens a mini-sheet with "You had lemon marked 🔴 Use today, and chicken thighs + red onion in your pantry. 25 min fits your weeknight budget."

### CTAs

- **Primary: "Cook this tonight"** — amber, full-width. This is the commitment language; it's also the implicit trigger to save the recipe + advance to the paywall (screen 14).
- **Secondary: "Show me another"** — plain text link under the button. Re-runs Gemini with seed variation to produce a different recipe from the same pantry. Tracked for analytics — high regenerate rate signals a Gemini quality issue.

### Motion

- Card entrance (after streaming completes): a gentle 250ms fade + 8pt translate-up. Not flashy; the content is the thing.
- Shimmer → card swap: the shimmer fades at the same rate the final card fades in, over ~200ms. Feels like the skeleton *becomes* the recipe.
- "Why this?" sheet: standard bottom-sheet spring.

## Personalisation — how every earlier screen flows in here

This screen is where all the signals compound. The Gemini prompt built for this call pulls:

| Earlier screen | Signal used |
|---|---|
| **2 Goal** | Drives hero-ingredient selection strategy (e.g. waste goal prioritises Today items in the hero) + adds a small CTA tag below the recipe title for that goal ("Uses what needs using first"). |
| **3 Household** | `servings` = household count. Shown as "Serves N — your household." |
| **4 Dietary** | Hard constraint. Recipe never contains restricted items. |
| **5 Allergies** | Hard constraint, labelled in the prompt as "(ALLERGY — must never include)". Dislikes labelled "(avoid)". |
| **6 Time** | `maxCookTime` — recipe total time (prep + cook) at or under this. |
| **7 Confidence** | Technique complexity + step language. |
| **8 Appliances** | Hard constraint on methods used. |
| **9 Region & units** | Ingredient vocabulary + measurement system. |
| **11 Staples** | Available ingredient pool (tier-weighted). |
| **12 Perishables** | Fresh ingredient pool; "Today" items get priority weighting as hero ingredients. |

### Hero ingredient selection algorithm (client-side pre-prompt)

Before calling Gemini, determine the intended hero ingredient and pass it as `REQUIRED`:

1. If any perishable is marked **Today** → pick one at random as hero.
2. Else if any perishable is marked **This week** → pick one as hero.
3. Else if any Fresh meat/fish exists → pick one.
4. Else if any Fresh veg exists → pick one.
5. Else fallback to a staples-only recipe. Gemini chooses the hero.

The hero gets the existing `REQUIRED ingredient — you MUST use ALL of these` prompt treatment (per Sprint 15.3.20).

### Per-goal post-recipe treatment

| Goal | Added touch on the complete state |
|---|---|
| Cook with what I've got (#1) | Small line under the recipe title: "100% from your pantry." |
| Waste less food (#2) | Banner above the ingredients: "Rescues: <Today items used>." |
| Decide dinner faster (#3) | "Generated in <X>s" chip next to the meta row, where X is the streaming duration. |
| Feed the whole household (#4) | "Serves <N> — your household" made bolder than default. |
| Stop ordering takeaway (#5) | Small estimate line under the meta row: "About £X / $X per portion — less than a takeaway." *(Cost estimate is tricky; flag as post-v1 if too costly to derive at generation time.)* |

## What Kate decides

- **Shimmer layout** — does the skeleton match the exact geometry of the final card (ingredient rows in the right place) or a generic card shape? Matching exactly feels "truer" but means two variants if recipe layout changes.
- **Pantry-tag treatment on ingredients** — solid chips vs inline text glyphs. Rob's default: inline glyph + muted label, so the ingredient name stays primary.
- **Hero photo fallback** — colour block, simple illustration, or always require a real photo. Rob's default: stock/Gemini-sourced image always; colour block only if all image services fail.
- **Regenerate behaviour** — does "Show me another" fade out and re-stream inline, or push a new screen with the same pattern? Rob's default: inline fade and re-stream. Preserves the narrative beat.
- **"Why this?" sheet** — include in v1 or defer? Adds polish and defends recipe choice; costs engineering time.
- **CTA wording** — "Cook this tonight" vs "Save & continue". Rob's default: "Cook this tonight" — commits the user to the experience, not the flow.
- **Error-state visuals** — same cosy illustration style as screen 10 (fridge), or a purpose-drawn "oops" illustration. Rob's default: a soft line-art "our AI is on a break" mark — keeps tone warm.

## Why these decisions

- **Live generation, not a static pre-baked recipe.** Static recipes are cheaper but can't reflect the user's actual pantry, which kills the entire recognition moment. The 4-6 second wait is acceptable because the shimmer gives the user something to watch.
- **Shimmer skeleton matches the home-screen pattern.** Users who install Elio will see the same loading state every time they generate a recipe. Making the *first* generation feel identical to every future one sets the right expectation.
- **Hero ingredient determinism.** The Today → This week → Fresh cascade guarantees the recipe visibly uses something the user told us about. Without this, Gemini can drift toward "generic weeknight chicken" that doesn't feel personal.
- **"Cook this tonight" is a commitment CTA, not a flow CTA.** "Save & continue" sends the user to the paywall feeling transactional. "Cook this tonight" invites them into the product — and the paywall that follows is framed as "unlock the rest of the experience", not "pay before you can do anything".
- **Regenerate is allowed and tracked.** Some users will tap regenerate once or twice; that's healthy. High regenerate rates are a signal — if median users hit "Show me another" 3+ times, the hero-selection algorithm or prompt needs work.
- **No "Skip" option on the complete state.** Once the recipe's on screen, the user must either commit ("Cook this tonight") or regenerate. Back arrow still works, but the forward action is emotional, not transactional.
- **Error state offers skip.** If Gemini is down, we can't hold the user hostage. "Skip for now" advances to screen 14, the paywall can still fire with generic copy, and the user retains all their onboarding state.
- **Progress bar still visible.** They're 13 of 15 — almost done. Showing progress here keeps the "I'm nearly through" momentum that closes the funnel.

## Edge cases & states

### Streaming behaviour

- **Timeout** (60s per `gemini_service`): trigger error state.
- **Partial stream then disconnect:** treat as error. Do not show a half-card — users will interpret "partial recipe" as a broken product.
- **SSE chunk parsing failures:** `_extractJson()` safety net applies (per CLAUDE.md Gemini section). If JSON is unparseable after stream end, error state.
- **Streaming completes in < 1s** (unlikely but possible via cache): still show shimmer for a minimum 800ms so the reveal feels meaningful rather than jarring. *(Design nicety — not required for v1.)*

### Regenerate

- **Rate limiting:** max 3 regenerate taps in this flow. After 3, the "Show me another" link greys out with tooltip: "Plenty to choose from later". Prevents runaway Gemini calls during onboarding.
- **Regenerate fails:** don't replace the existing recipe with an error; surface a small inline toast "Couldn't regenerate — showing the last one" and keep the current card. Different handling than initial-generation failure.

### Empty or thin pantry

- **User picked 0 staples + 0 perishables** (shouldn't happen — staples has pre-selected defaults — but if a user meticulously unticked everything): Gemini gets a very thin pool. Prompt instructs it to generate the simplest possible recipe from "what would a normal person have in" + the user's region. Falls back gracefully. Card shows "You've got the basics — here's what we'd start with."
- **All selected perishables are "Today":** great case. Hero is picked from them; everything else in the recipe slots in as "use today".

### Navigation

- **Back arrow from this screen:** abort any in-flight Gemini call (cancel the HTTP client call — existing `http.Client` supports cancellation). Return to screen 12 (Perishables) with state preserved. The recipe is not saved.
- **App backgrounded mid-stream:** hold the SSE connection open for up to 10s. On resume within 10s, continue streaming. Beyond 10s, cancel and show a "Welcome back — let's try again" CTA that re-triggers generation.
- **App killed mid-stream:** on relaunch, return user to screen 12 (the last completed screen). They re-tap Continue to come back here; new generation is triggered.

### Forward behaviour

- **"Cook this tonight" → screen 14 (Paywall):** persist the recipe to `recipes/{id}` (existing schema) and to the user's local history. Advance. The paywall can reference the recipe by title in its copy ("Unlock more recipes like Lemon & Garlic Chicken Traybake").
- **"Skip for now" (error state) → screen 14:** advance with no recipe saved. Paywall falls back to generic copy.

### Accessibility

- **Streaming state announced** via a live region: "Generating your recipe." Updates at each subhead change.
- **Card content read top-to-bottom** by screen readers: title, meta, each ingredient with its pantry tag, then the expand-for-steps affordance.
- **Pantry tags are announced** not just colour-coded: "Chicken thighs, usually in your pantry."
- **Regenerate announced** as "Regenerate recipe, button".
- **Reduced Motion:** skip shimmer entrance; swap to a static loading indicator. Card appears instantly on completion.

### Analytics

Minimum events:

```
onboarding_recipe_demo_started
onboarding_recipe_demo_completed      { duration_ms, hero_ingredient, pantry_tags_used }
onboarding_recipe_regenerated          { regenerate_count }
onboarding_recipe_demo_errored         { error_type }
onboarding_recipe_demo_skipped         { had_error: true }
onboarding_recipe_committed            { recipe_id }
```

Regenerate count is the single most important post-launch signal — if median > 1, recipe quality on this screen needs attention.

## Behaviour

1. On entry: trigger Gemini stream with the compiled pantry + preferences prompt. Display shimmer + subhead 1.
2. At t+2s: subhead updates to "Writing the recipe…".
3. At t+4s: subhead updates to "Plating it up…".
4. On stream completion: shimmer fades out, recipe card fades in, headline updates to complete-state headline, primary CTA appears.
5. Tap **Cook this tonight** → persist recipe, advance to screen 14 (Paywall).
6. Tap **Show me another** → re-run Gemini with seed variation. Shimmer returns briefly. Increments `regenerate_count`.
7. On error → show error state. Retry triggers another Gemini call. Skip advances to screen 14 without a saved recipe.
8. Back arrow → cancel in-flight generation, return to screen 12. State preserved.

---

## Flag for implementation

- Reuse `gemini_service.streamGenerateContent` — no new streaming logic.
- Use the existing home-screen shimmer widget.
- Recipe card reuses the existing recipe-card component (do not fork a onboarding-specific variant).
- Hero ingredient selection (the Today → This week → Fresh cascade) belongs client-side, in the onboarding controller — do not bake it into the Gemini prompt builder, which already has its own perishable-urgency logic.
- Do not commit untested Gemini config changes for this screen (per CLAUDE.md rule 6). The existing prompt structure already handles everything we need.
