# Onboarding Screen 14 — Paywall (trial-first)

**Step 14 of ~15** · Archetype: Conversion — 7-day free trial offer
**Status:** Draft v1, awaiting Kate's design

---

## Objective

Convert onboarding users into a 7-day free trial of Elio Pro. This screen fires **immediately after** the user has seen their first generated recipe — the single highest-intent moment in the entire funnel.

The existing paywall infrastructure (`paywall_screen.dart`, `PurchaseService`, RevenueCat) already implements trial-first design. This brief specifies:

1. **A new trigger context** — `first_recipe` — that doesn't exist in the current paywall's context enum.
2. **Per-goal headline variants** for the onboarding-specific entry.
3. **Clarifications on skip/continue-free behaviour**, because the normal post-onboarding paywall triggers are all in-flow feature-gates, whereas this one sits between "recipe demo" and "account gate". Skip behaviour is different.

**Existing paywall behaviour to reuse unchanged:** pricing row, trial duration display (`trialDurationLabel()`), feature comparison, "Restore purchase" link, legal copy, RevenueCat package selection, dry-mode handling.

## Honest design principles

Paywalls are where dark patterns grow. This screen follows three rules:

1. **Trial length and post-trial price visible in the primary CTA area.** No "Start free" alone — always paired with "then £27.99/year" (or equivalent).
2. **Continue-free is a real option, not hidden.** Small but present. Tests show a visible continue-free option *increases* trial conversion (trust lift > friction cost).
3. **No fake scarcity, no countdown timers, no "87% of users upgrade" stats.** We sell Elio on the recipe they just saw, not on manipulative social proof.

## Copy

### Headline (varies by screen 2 goal)

| Goal | Headline |
|---|---|
| Cook with what I've got (#1) | Cook from your pantry. / Every night. *(two-line hero treatment)* |
| Waste less food (#2) | Cut your food waste from week one. |
| Decide dinner faster (#3) | No more 6pm panic. |
| Feed the whole household (#4) | One plan for the whole house. |
| Stop ordering takeaway (#5) | Skip the takeout. *(US-leaning spelling — US is primary launch market)* |
| *(No goal set — shouldn't happen, but fallback)* | Unlimited Elio. Start with 7 days free. |

*(Sprint 16.2 decisions: #3 kept punchier current copy over spec's "Never scroll for a recipe again"; #4 kept tighter current over spec's "One plan that works for the whole house"; #5 swapped "Cheaper than two takeaways a month" to behavioural-and-US-leaning "Skip the takeout".)*

### Subhead (constant across goals)

> Start your 7-day free trial. No charge today — cancel anytime in Settings.

*(Sprint 16.2: current implementation shows a shorter eyebrow "7-day free trial · cancel anytime" below the hero. Longer spec copy kept as intent; Kate to ratify whether to expand the eyebrow — tradeoff is visual cleanliness vs the trust lift of the "No charge today" phrase.)*

### Feature comparison (constant — reuse existing paywall data)

| Feature | Free | **Pro (trial)** |
|---|---|---|
| Recipes per week | 7 | **Unlimited** |
| Meal planner | — | **✓** |
| Shopping list | — | **✓** |
| Recipe import | — | **✓** |
| Scanning (barcodes, receipts) | — | **✓** |
| Household members | Just you | **Up to 6** |
| Recipe history | 20 recipes | **50 recipes** |

*(This table is sourced from the existing `paywall_screen.dart`. Any change here must also land in the post-onboarding paywall.)*

### Plan selection (two plans shown, annual pre-selected)

| Plan | Copy | Price region-aware |
|---|---|---|
| **Annual** (pre-selected, "Best value" badge) | 7-day free trial, then £27.99 / year | £27.99 UK / $29.99 US |
| **Monthly** | 7-day free trial, then £4.49 / month | £4.49 UK / $4.99 US |

*(Pricing pulled from RevenueCat `StoreProduct.introductoryPrice` + `price` at runtime. This brief documents intent; the source of truth is RevenueCat configuration.)*

### CTAs

**Primary (full-width, amber):**
> Start my 7-day free trial

**Secondary (small link, centred, below the button):**
> Continue with Free

**Footer links (tiny, grey):**
> Restore purchase · Terms · Privacy

## Layout

```
┌─────────────────────────────────┐
│                           ✕     │  ← close (returns to screen 13)
│                                 │
│  Cook from your pantry.         │
│  Every night.                   │
│                                 │
│  Start your 7-day free trial.   │
│  No charge today — cancel       │
│  anytime in Settings.           │
│                                 │
│  ┌───────────────────────────┐  │
│  │  Free      │   Elio Pro   │  │
│  │  7 rec/wk  │   Unlimited  │  │
│  │  —         │   Meal plans │  │
│  │  —         │   Shopping   │  │
│  │  —         │   Scanning   │  │
│  │  ...       │   ...        │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ ● Annual   Best value     │  │
│  │   7-day trial, then       │  │
│  │   £27.99 / year           │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ ○ Monthly                 │  │
│  │   7-day trial, then       │  │
│  │   £4.49 / month           │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ Start my 7-day free trial │  │
│  └───────────────────────────┘  │
│                                 │
│      Continue with Free         │
│                                 │
│  Restore · Terms · Privacy      │
└─────────────────────────────────┘
```

## Visual spec

- **No progress bar** on this screen. Paywalls shouldn't feel like a step — they should feel like a choice. Reappear on screen 15.
- **Close (✕) at top-right** instead of a back arrow. Tapping it returns to screen 13 with the recipe still on screen (non-destructive). Reinforces that "close" is available — conversion lift from trust, not friction.
- **Feature comparison** — two-column table, Free on left (muted), Pro on right (amber-tinted column header, bolder values). Reuse styling from the existing in-app paywall.
- **Plan cards** — radio-style, two cards stacked. Selected: amber border + filled dot. "Best value" badge on Annual is a small amber pill in the top-right of the card.
- **Primary CTA** — amber, full-width, bold. Label dynamically matches the selected plan's trial: "Start my 7-day free trial". If user somehow lands on a no-trial plan (RC config quirk), label swaps to "Subscribe — £X/year" per existing `hasFreeTrial()` helper.
- **"Continue with Free"** — small plain-text link. ~14pt, secondary colour. Centred below the CTA with 20pt breathing room. Do NOT style as a ghost button — that reads as equivalent-weight and hurts trial conversion *and* trust.
- **Footer links** — single row, 11pt, grey. Minimal.
- **Animation** — on entry, headline fades in first, then feature table, then plan cards, then CTAs. 120ms staggered. Keeps the screen from dropping all at once.

## Personalisation deep-dive

Only the **headline** varies by goal. Everything else — features, prices, plans, CTAs, footer — is constant.

Why only the headline: the per-goal variants are a copy lever, not a pricing or feature lever. Varying offers by goal is the dark pattern line; we stay well on the right side of it.

### Goal × household combinations

Per the screen 3 brief's personalisation table, household type can override the goal headline:

- **Family with kids + count ≥ 3**, regardless of stated goal → headline becomes "One plan that covers everyone." (The household-led variant overrides whatever the goal-led headline would be.)
- **Just me + count = 1 + Goal = Household** (contradictory state — shouldn't happen, but if it does) → fall back to the default "Unlimited Elio" headline.

All other combinations use the goal-driven headline.

### Perishable-led variant (if screen 12 had Today items)

If the user marked any perishable as "Today" on screen 12 AND their goal is Waste Reduction, the subhead gets a one-line prefix:

> We built tonight's recipe around what needed using. Every day could look like this.
> Start your 7-day free trial. No charge today — cancel anytime in Settings.

Small touch; ties the paywall directly back to the demo.

## Integration — changes to existing paywall code

The existing `paywall_screen.dart` uses a `PaywallTrigger` enum with values `weekly_limit | meal_planner | shopping_list | household | default`. Add:

```dart
enum PaywallTrigger {
  weekly_limit,
  meal_planner,
  shopping_list,
  household,
  first_recipe,   // ← NEW
  default,
}
```

Add a new case to the existing headline-switch that maps `first_recipe` to one of the six goal headlines based on `userGoal` (new field from screen 2). Reads something like:

```dart
String _headlineFor(PaywallTrigger trigger, UserGoal? goal) {
  if (trigger == PaywallTrigger.first_recipe && goal != null) {
    return switch (goal) {
      UserGoal.pantryFirst => 'Cook from your pantry. Every night.',
      UserGoal.wasteReduction => 'Cut your food waste from week one.',
      UserGoal.decisionFatigue => 'Never scroll for a recipe again.',
      UserGoal.household => 'One plan that works for the whole house.',
      UserGoal.takeawayEscape => 'Cheaper than two takeaways a month.',
    };
  }
  // ...existing logic for other triggers
}
```

(Illustrative — implementer to wire through the real `UserGoal` enum once added per screen 2's data-model note.)

## What Kate decides

- **Plan card selected-state visual** — border + filled radio dot only, or amber tint on the card fill too. Rob's default: border + dot. Tint risks reading as "disabled".
- **"Best value" badge position** — top-right pill of the Annual card, or a ribbon across the top. Rob's default: pill.
- **Feature table density** — seven rows, as listed. Drop history row if space is tight (it's the least differentiating). Kate's call.
- **Voice Cooking row** — currently in both Free and Pro per CLAUDE.md. Including it in the comparison table would show "—" in Free and "✓" in Pro side-by-side, which is misleading. Rob's default: omit Voice Cooking from the comparison entirely.
- **Whether the recipe from screen 13 appears here** — e.g. a small thumbnail with the title at the top of the paywall, priming the "unlock more like this" framing. Rob's pick: yes, 60pt thumbnail + title ribbon above the headline. Kate to validate that it doesn't crowd the headline.

## Why these decisions

- **Context is the full moment.** The user has just cooked (metaphorically) their first Elio recipe. The paywall lands on them mid-enthusiasm — the trial offer should feel like "ah, and I get more of that" rather than "first toll gate".
- **Trial-first, not purchase-first.** 7-day free trial is the existing app's lead. Onboarding maintains it for consistency. Purchase-first would feel heavy; trial lowers the emotional commitment to near zero.
- **Annual pre-selected.** Better unit economics for us; better value for the user; mirrors existing app behaviour. Users who want monthly actively select it — the default isn't being hidden from them.
- **"Continue with Free" visible.** Removes the "paywall wall" feeling. Users who can't or won't pay proceed to screen 15 with a functional free plan; they can still retain and convert later.
- **Close button, not Skip.** Close (✕) returns them to the recipe (screen 13). The recipe is their first product experience — we never want to take it away as punishment. Skip would feel punitive; Close feels natural.
- **No countdown timer, no discount.** Elio's long-term pricing is honest: the same trial offer is available post-onboarding. A one-time-only offer would be a lie.
- **Recipe thumbnail at top.** The recipe is the strongest piece of evidence we have. Stripping it away and replacing with a generic paywall hero disconnects the moment from the ask.
- **No progress bar.** Progress bars create a "nearly done" push that pressures the trial decision. Removing it lets the user sit in the offer honestly.

## Edge cases & states

### RevenueCat states

- **RC configured and packages loaded normally:** standard flow. Prices shown, trial language shown.
- **RC in dry-mode** (API key not set — happens in dev + per CLAUDE.md the key isn't in `.env.local` yet): `PurchaseService.getPackages()` returns `[]`. Per the existing `_showTrialState` rule, always show trial UI. Plan cards show placeholder prices ("—") with a helper: "Pricing syncing…". Continue-with-Free still works. Start-trial tap shows a friendly error: "Subscriptions are setting up. Please try again in a moment."
- **RC returns packages but none have `introductoryPrice`:** trial UI hides. CTAs become "Subscribe" (annual/monthly). Onboarding continues to treat it as a valid paywall — the user's decision is still binary.
- **RC returns one plan only** (e.g. annual only, region quirk): monthly card hidden.

### Purchase flow

- **Start-trial tap → Apple/Google purchase sheet:**
  - Success → persist entitlement via RC webhook + local receipt; advance to screen 15 as Pro user.
  - Cancel → stay on this screen. No error.
  - Fail (network / region / age-gated) → inline toast: "Couldn't start the trial. Try again, or Continue with Free."
- **Restore purchase tapped:** runs existing RC restore; on success, advance to screen 15 as Pro. On no-existing-purchase, inline toast "No purchase found."

### Dev account / test user

- Dev accounts (email allowlist in `EntitlementService`) auto-activate Pro. On this screen: show a dev-only banner "Dev account — auto-Pro, tap Continue" and a single CTA "Continue" that bypasses the purchase sheet.

### Navigation

- **Close (✕):** returns to screen 13 with recipe still on screen. Recipe is retained in state; user can regenerate or commit again.
- **Continue with Free:** persist `entitlement = free`, advance to screen 15 (Account gate).
- **Back arrow (system):** there is no system back arrow on this screen — use Close.

### Accessibility

- **Plan cards** announce as "Annual plan, 7-day trial, then £27.99 per year, best value, selected."
- **"Continue with Free"** announced as "Continue with Free plan, text button."
- **Price reads** include currency symbol spelled out ("27 pounds 99 pence per year") for clarity.
- **Reduced Motion:** skip entrance stagger.
- **Dynamic Type:** plan cards grow vertically; prices never truncate.

### Analytics

```
onboarding_paywall_viewed        { goal, trigger: "first_recipe" }
onboarding_paywall_plan_selected { plan: "annual" | "monthly" }
onboarding_paywall_trial_started { plan }
onboarding_paywall_purchase_failed { error }
onboarding_paywall_free_continued
onboarding_paywall_closed         { had_purchase: false }
onboarding_paywall_restored
```

The two highest-signal events: `trial_started` rate and `free_continued` rate. Their ratio is the core onboarding conversion KPI.

## Behaviour

1. On entry: fire `onboarding_paywall_viewed`. Preselect Annual plan. Shimmer price rows until RC packages load.
2. Once packages loaded: render real prices. If dry-mode, render placeholders.
3. User selects a plan → plan card state updates; CTA label reflects the plan's trial status.
4. Tap **Start my 7-day free trial** → invoke `PurchaseService.purchasePackage()`. Show system purchase sheet.
   - On success → fire `trial_started`, advance to screen 15.
   - On cancel → remain.
   - On error → toast.
5. Tap **Continue with Free** → fire `free_continued`, persist entitlement=free, advance to screen 15.
6. Tap **Restore purchase** → invoke RC restore.
7. Tap **Close (✕)** → fire `closed`, return to screen 13.

---

## Flag for implementation

- Reuse `paywall_screen.dart` entirely. Do **not** fork a onboarding-specific paywall screen — it splits future paywall improvements.
- Add `PaywallTrigger.first_recipe` to the enum.
- Extend the headline-switch function with per-goal cases. Guard `userGoal` being null with the fallback headline.
- The recipe thumbnail at the top is optional for v1 if it lengthens the build — but wire the data through so it can ship in a later sprint.
- Pricing row must never hard-code values. All prices come from RevenueCat at runtime. Per CLAUDE.md, **never** treat empty packages as "no trial"; the `_showTrialState` getter handles this correctly today — don't re-implement.
