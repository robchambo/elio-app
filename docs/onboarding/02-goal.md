# Onboarding Screen 2 — Goal

**Step 2 of ~15** · Archetype: Single-select question
**Status:** Draft v2, awaiting Kate's design

---

## Objective

Open the conversation. Get the user to self-identify *which* of Elio's five core benefits matters most to them — so every downstream screen, the paywall, and the first recipe can reflect that priority back at them.

This is the first time we ask the user for anything. It must feel light, fast, and obviously about them — not about us.

## Copy

**Headline (large, bold):**
> What brought you to Elio?

**Subhead (one line, lighter weight):**
> Pick what matters most — we'll tailor things to suit.

**Options (single-select, vertical list of cards):**

| # | Label | Subtext | Maps to benefit |
|---|---|---|---|
| 1 | Cook with what I've got | Stop staring at the fridge | #1 Pantry-first |
| 2 | Waste less food | Use it before it goes off | #2 Waste reduction |
| 3 | Decide dinner faster | Skip the scroll, skip the debate | #3 Decision fatigue |
| 4 | Feed the whole household | Fussy eaters and all | #4 Household |
| 5 | Stop ordering takeaway | Eat better, spend less | #5 Takeaway escape |

**Primary CTA (full-width button, disabled until selection made):**
> Continue

**Optional secondary text below CTA:**
> You can change this later in Settings.

## Copy alternatives (for Rob to pick from before Kate locks)

### Headline — 3 variants

| Variant | Tone | When to use |
|---|---|---|
| **A (recommended):** What brought you to Elio? | Conversational, open | Default. Feels like a friendly first question, not a survey. |
| **B:** What's the one thing you want Elio to fix? | Punchier, problem-led | If we want the screen to land harder on pain rather than promise. Risk: heavier emotional load on screen 2. |
| **C:** Where shall we start? | Soft, premise-light | Lowest friction. Risk: doesn't anchor that the answer matters — users may pick at random. |

### Subhead — 3 variants

- **A (recommended):** Pick what matters most — we'll tailor things to suit.
- **B:** Your answer shapes the recipes you'll get. *(more honest about consequence; risk: reads as commitment-heavy)*
- **C:** Just one — there are no wrong answers. *(reassuring; risk: undersells that the answer drives personalisation)*

### Option labels & subtext — alternatives

Recommended copy is the v1 in the table above. Alternatives below if v1 tests flat:

| # | Alt label | Alt subtext |
|---|---|---|
| 1 | Use what's in my kitchen | "What can I make with this?" — sorted |
| 2 | Stop binning food | Cook the chicken before it walks out |
| 3 | Skip the dinner debate | No more "I dunno, what do *you* fancy?" |
| 4 | Cook for everyone at once | One recipe, no separate plates |
| 5 | Eat in more than I order in | The takeaway habit, gently broken |

The alts lean harder into the pain (BEFORE state). Use if v1 feels too neutral once Kate has it on the canvas.

### CTA — alternatives

- **Continue** *(recommended — neutral, low-pressure)*
- **Next** *(more progress-bar-flavoured, risk: feels like a form)*
- **Sounds like me** *(playful, risk: cute can age badly across thousands of users)*

## Layout

```
┌─────────────────────────────────┐
│ ← ▓▓▓▓░░░░░░░░░░░░░  ← progress │
│                                 │
│  What brought you to Elio?      │
│                                 │
│  Pick what matters most — we'll │
│  tailor things to suit.         │
│                                 │
│  ┌───────────────────────────┐  │
│  │ 🍳  Cook with what I've got│  │
│  │     Stop staring at the…  │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ ♻️  Waste less food        │  │
│  │     Use it before it goes…│  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ ⏱️  Decide dinner faster   │  │
│  │     Skip the scroll…      │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 👨‍👩‍👧 Feed the whole household│
│  │     Fussy eaters and all  │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 🥡  Stop ordering takeaway│  │
│  │     Eat better, spend…    │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │       Continue            │  │
│  └───────────────────────────┘  │
│  You can change this later.     │
└─────────────────────────────────┘
```

## Personalisation deep-dive

The selected goal becomes `userGoal` in onboarding state and reshapes copy + behaviour across the rest of the flow. The signal is small but compounds: by screen 14 the user has been "heard" five times, which lifts paywall conversion materially in comparable apps (Cal AI, Noom, Finch).

### Per-goal downstream changes

| Screen | Goal #1 — Pantry-first | Goal #2 — Waste reduction | Goal #3 — Decision fatigue | Goal #4 — Household | Goal #5 — Takeaway escape |
|---|---|---|---|---|---|
| **3 Household intro** | Default copy | Default copy | Default copy | Softer intro: "Tell us about your household" with line "We'll make sure everyone's covered." | Default copy |
| **10 Pantry intro** | "Let's see what's already in your kitchen — that's where every Elio recipe starts." | "Let's see what's in your kitchen — especially anything that needs using soon." | "Quick tour of your kitchen — then dinner gets a lot faster." | "Let's stock the kitchen for everyone." | "Let's see what's in — so you've always got an answer to 'what's for dinner?'" |
| **11 Pantry build** | Default order | Surface "Use today" / perishable prompts first | Default order, but skip the "add 5 more" nudge | Default order | Default order |
| **12 First recipe** | Standard hero ingredient | Hero recipe must include at least one *Use today* tagged ingredient | Show shimmer-streaming front and centre, with a "Generated in 4s" stamp on completion | Recipe scales to household size visibly ("Serves 4 — your household") | Cost-per-portion estimate appears under the recipe card |
| **13 Paywall** | "Unlimited recipes from your pantry" hero | "Cut your food waste from week one" hero | "Never scroll for a recipe again" hero | "One plan that works for the whole house" hero | "Cheaper than two takeaways a month" hero |
| **14 Account gate** | "Save your pantry — sign in." | "Save what you've got — sign in." | "Save your setup — sign in to keep it." | "Save your household — sign in." | "Lock in your trial — sign in." |

### What we DON'T personalise (and why)

- **Recipe quality / model behaviour.** Goal does not change Gemini prompts. The pantry, dietary, allergies, and household answers do that — goal is a copy lever only. Mixing it into the prompt would create silent quality variance we can't debug.
- **Order of subsequent screens.** Every user sees screens 3 → 14 in the same order. Branching the flow itself multiplies QA surface area for marginal lift.
- **Pricing or trial length.** Same offer for every goal. Personalising offers by stated goal is a dark pattern and a regulatory risk.

### How `userGoal` lives after onboarding

- Persisted to `users/{uid}.userGoal` (string enum) on screen 15 sign-in.
- Editable in Settings → "What you wanted from Elio" (low-prominence row).
- Used by `RemoteConfig`-driven empty states (e.g. Recipe Book empty state can echo the goal).
- **Not** used to gate features. Purely a copy hook.

## Edge cases & states

### State machine

| State | Trigger | Visual |
|---|---|---|
| **Default** | Screen first appears | All cards default; Continue disabled (40% opacity amber) |
| **Pressed** | Finger down on a card | Card scales to 0.98, slight shadow lift |
| **Selected** | Tap released on a card | Card gets amber border (2px) + amber tick on right; Continue activates (full amber) |
| **Reselect** | Tap a different card | Previous card returns to default; new card becomes selected; no toast/feedback (the visual change is enough) |
| **Re-tap selected card** | Tap the already-selected card again | No-op. Do **not** deselect — deselection here would let users hit Continue with no answer if Continue's disabled state is misread. |
| **Continue tapped** | User taps active CTA | Save `userGoal`, advance to screen 3. No loading state — local-only. |
| **Back from screen 3** | User backs into this screen | Selection state preserved. Continue active. Cards animated in (no jump). |
| **App backgrounded mid-screen** | OS resume | Onboarding state held in `OnboardingController` (in-memory + SharedPreferences). Selection preserved. |
| **App killed mid-onboarding** | Cold restart | Restore from SharedPreferences — land on the screen they were last on, with their selection. *(Existing `OnboardingState` already does this — verify it persists `userGoal`.)* |

### What can't go wrong here (and confirming why)

- **No network.** Screen is purely local — no API call, no auth, no Firestore write. Works offline.
- **No validation errors.** One required answer, no free text, no format. Continue is the only failure mode and it's prevented by being disabled.
- **No timeout.** No async work on this screen.

### Accessibility

- **VoiceOver / TalkBack** — each card announces as `<icon-label>, <label>, <subtext>, button, <selected/unselected>`. Continue button announces its disabled state ("Dimmed. Select an option to continue.").
- **Dynamic Type / font scaling** — cards must grow vertically; subtext can wrap to two lines at large sizes. Headline must not truncate up to 200% scaling.
- **Reduced Motion** — disable card scale-on-press and tick fade-in. Keep colour change (state still legible).
- **Contrast** — selected amber border on off-white background must hit WCAG AA (4.5:1). Tick icon needs to be legible at 24pt minimum.
- **Tap target** — entire card is tappable, not just the label. Min 64pt height per Apple HIG / 48dp Material.
- **Keyboard / focus** — for future web/landscape support, tab order: cards top-to-bottom, then Continue. Space/Enter selects.

### Localisation notes (not for v1, but flag for Kate's layout)

- US copy may need different option labels ("trash" vs "bin", "groceries" vs "shopping", takeaway vs takeout). Layout must accommodate ~20% string growth without truncation.
- "Cook with what I've got" is shorter than its likely German/French translations — give cards room to wrap label to two lines without breaking the icon's vertical alignment.

## Visual spec for Kate

### States — full breakdown

| State | Card border | Card fill | Text colour | Tick icon | Card shadow |
|---|---|---|---|---|---|
| Default | 1px subtle grey | Off-white `#F7F5F2` | Navy `#1A2744` | Hidden | Soft, low |
| Hover *(future web)* | 1px navy 30% | Off-white | Navy | Hidden | Soft, raised slightly |
| Pressed | 1px navy 30% | Off-white, scale 0.98 | Navy | Hidden | Suppressed |
| Selected | 2px amber `#F08C14` | Off-white *(or amber 5% — Kate's call)* | Navy | Visible, amber, right-aligned | Soft, low |
| Selected + pressed | 2px amber | As above, scale 0.98 | Navy | Visible | Suppressed |
| Disabled | n/a — we don't disable individual cards | | | | |

The Continue button has its own states:
- **Disabled:** amber at 40% opacity, no shadow, label "Continue" in white.
- **Enabled:** full amber `#F08C14`, soft shadow.
- **Pressed:** amber darkens ~10%, shadow suppressed.
- **Transition** from disabled→enabled: 200ms ease; the button fades, doesn't pop.

### Motion

- Card press: 100ms scale to 0.98, 120ms back to 1.0 on release.
- Tick fade-in: 150ms ease-out, with a tiny scale 0.8 → 1.0.
- Continue activation: 200ms colour fade.
- Screen entrance: cards stagger in 30ms apart (50ms each, ease-out, 8px upward translate). Keep total under 300ms or it feels slow on subsequent visits.
- All motion respects Reduced Motion.

### Icon brief

- **Set:** 5 custom icons, one per option. Style should match Sprint 16 brand-art direction (per `docs/brand-art-concept.md`).
- **Style guidance:** rounded, soft, slightly illustrated — not flat utility glyphs. Should feel of-a-piece with the Elio mark.
- **Size:** 32pt artwork, rendered in 40pt container.
- **Colour:** two-tone — primary in navy `#1A2744`, accent detail in amber `#F08C14`. Avoid full-colour illustrations (pulls focus from the option label).
- **Format:** SVG, exported per icon. Naming: `goal_pantry.svg`, `goal_waste.svg`, `goal_decide.svg`, `goal_household.svg`, `goal_takeaway.svg`.
- **v1 stopgap:** if custom icons aren't ready by build, ship with monochrome navy emoji or Material Symbols. Do **not** ship with the colour emoji shown in the layout sketch — they fight the brand palette.

### Spacing & rhythm

- Card height: min 64pt, grows with content.
- Card horizontal padding: 16pt.
- Vertical gap between cards: 12pt.
- Gap between subhead and first card: 24pt.
- Gap between last card and Continue: 32pt.
- Continue button: full width minus 16pt page margin.
- "You can change this later" caption: 12pt below button, secondary text colour, centred.

### Open visual decisions for Kate

- Selected card fill: pure off-white *or* amber 5% wash? Wash is more obvious but risks looking warning-coloured.
- Tick on the right *or* left of the card? Right is conventional but pulls eye away from label; left integrates with the icon zone but creates visual conflict with the goal icon.
- Whether to show a small headline accent (Elio mark, 24pt) above the headline — links the screen to brand without taking space.
- Whether the cards have any imagery beyond the icon — e.g. a faint background illustration on selected state.

## Rationale stress-test

A defence of every choice on this screen, plus the strongest counter-argument I've considered.

### Why this question at all on screen 2?

**Defence:** The five benefits are mutually distinct, and the rest of the funnel is meaningfully better when we know which one the user came for. Personalisation that lands within seconds of arrival raises perceived relevance for every subsequent screen — a documented effect across consumer onboarding (Cal AI, Finch, Noom).

**Counter:** "Just get them to a recipe — every screen before the demo is a tax." True but the demo *itself* is more compelling when it knows the goal (e.g. lead with a "use today" perishable for waste-driven users). Goal is the cheapest screen to raise the demo's hit rate.

**Kill condition:** If A/B shows screen-2-skip variant has higher screen-12 → screen-13 conversion, kill this screen.

### Why single-select, not multi-select?

**Defence:** Multi-select gives us a wishlist, not a priority. The personalisation hooks need a *primary* signal — paywall hero copy can only show one headline. If we let users tick three, we'd default to the first or have to design tie-breakers.

**Counter:** "What if a user genuinely wants two of these equally?" They can change it later in Settings, and the selected one will still be in their top three by definition. Forcing one is a feature, not a flaw.

### Why 5 options, not 3?

**Defence:** Each option maps 1:1 to a confirmed core benefit. Collapsing to 3 forces lossy bucketing — a "waste" user lumped into "cook with what I've got" loses the strongest paywall hook (cost-of-binned-food). The 5 options can be scanned in under 4 seconds (eye-tracking benchmark for vertical-card lists ≤ 6 items).

**Counter:** "More options = more cognitive load = lower completion." True at 7+. At 5, decision fatigue hasn't kicked in, and the subtext lines remove ambiguity. If completion drops vs a 3-option variant, revisit — but don't pre-emptively cap.

### Why subtext under each option?

**Defence:** The label is *what* they want; the subtext is *the pain we know they have*. Pairing them turns a survey into a recognition moment ("oh, that's me"). Apps that do this well (Finch, Headway) report measurable lift over label-only lists.

**Counter:** "Subtext doubles read time." Yes — but read time isn't the bottleneck on this screen, decision confidence is. Subtext speeds the *decision*, not the read.

### Why "You can change this later"?

**Defence:** Removes a tiny but real source of hesitation. Users overrate the permanence of onboarding choices. The line costs nothing and lifts completion in similar flows by 1-3pp.

**Counter:** "It undersells the importance of the answer." Marginal. The personalisation downstream is soft — none of it is locked-in. The user genuinely *can* change it later, so the line is honest.

### Why no "Other" / "Skip" option?

**Defence:** Skip would let the lowest-intent users avoid the question, which is precisely the cohort we most need to personalise for. Other introduces a free-text field that we can't act on at runtime.

**Counter:** "Forcing a choice annoys users who don't see themselves in any option." If our 5 benefits don't cover a reasonable user, the problem is the benefit list, not the screen. None of our user-research interviewees in the Sprint 14 round failed to map cleanly to one of these.

### Why vertical cards instead of a horizontal carousel or grid?

**Defence:** Vertical respects subtext (carousel/grid would force label-only). Vertical also preserves visual hierarchy — option 1 (pantry-first, our wedge) is at the top, where eye lands first.

**Counter:** "Vertical pushes the CTA below the fold on small phones." Correct, and acceptable — the CTA shouldn't be tappable until the user has scanned the options anyway. A sticky bottom Continue solves any reach issue.

### What would change my mind on the whole screen?

- **Completion rate** below 90% (target: 95%+) — strong signal the question is too heavy for screen 2.
- **Time-on-screen** above 12s median — signal the question is hard to answer or options are confusing.
- **Even distribution across all 5** — signal users are picking at random; the personalisation premise is false.
- **Higher screen-12→13 conversion in a no-personalisation control** — kill the personalisation, possibly the screen.

## What Kate decides (summary)

- Custom icon set vs emoji stopgap (see Icon brief above).
- Selected-card treatment: border + tick, optional amber wash, tick position.
- Whether the headline gets a small Elio-mark accent.
- Card press/release motion within the spec'd ranges.

## Behaviour

- Tap a card → selection state visible immediately, Continue button activates.
- Only one selection allowed; tapping another card moves the selection.
- Tap **Continue** → save `userGoal`, advance to screen 3 (Household).
- Back arrow → returns to screen 1 (Welcome). Selection state preserved if user comes back.
- No skip option. The CTA is always "Continue" — we want a real answer here, and the friction is low (one tap).
