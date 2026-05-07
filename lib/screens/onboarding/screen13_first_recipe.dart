import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../../models/elio_models.dart';
import '../../models/onboarding_state.dart';
import '../../models/recipe_models.dart';
import '../../services/analytics_service.dart';
import '../../services/gemini_service.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_page_title.dart';
import '../../widgets/elio/elio_onboarding_progress_bar.dart';
import '../../widgets/elio/elio_pantry_tag_pill.dart';

// ─────────────────────────────────────────────
// Screen 13 — First recipe demo
//
// The payoff. Streams a real Gemini recipe built from the user's pantry
// + preferences entered on screens 02–12. Three states:
//
//   Generating — shimmer skeleton + rotating subhead.
//   Complete   — recipe card + "Cook this tonight" (primary) + "Show me
//                another" (disabled at 3 regenerates).
//   Error      — "Hmm, let's try that again" + Retry / Skip for now.
//
// The Gemini call is injected via `streamFn` (defaulting to
// GeminiService.streamGenerateContentEphemeral) so the widget can be
// unit-tested with a FakeGeminiService.
//
// Copy, cascade + behaviour: docs/onboarding/13-first-recipe.md.
// ─────────────────────────────────────────────

typedef EphemeralRecipeStreamFn = Stream<RecipeGenerationStatus> Function({
  required List<InventoryItem> pantry,
  required OnboardingState prefs,
  String? heroIngredientName,
  List<String> recentTitles,
});

// ── Hero-ingredient cascade (pure — exported for tests) ────────────────────
//
// Priority:
//   1. Today     — `isRunningLow == true` OR `expiryDate ≈ now`
//   2. ThisWeek  — `expiryDate` within 3 days
//   3. Fresh     — `expiryDate` > 3 days
//   4. Meat tier — any perishable in `Fresh meat & fish`
//   5. Veg tier  — any perishable in `Fresh veg`
//
// Ties broken by insertion order (first match wins).
InventoryItem? pickHeroIngredient(List<InventoryItem> inventory, DateTime now) {
  if (inventory.isEmpty) return null;

  bool isToday(InventoryItem i) {
    if (i.isRunningLow) return true;
    final d = i.expiryDate;
    if (d == null) return false;
    return !d.isAfter(now);
  }

  bool isThisWeek(InventoryItem i) {
    final d = i.expiryDate;
    if (d == null) return false;
    final diff = d.difference(now).inDays;
    return diff > 0 && diff <= 3;
  }

  bool isFresh(InventoryItem i) {
    final d = i.expiryDate;
    if (d == null) return false;
    return d.difference(now).inDays > 3;
  }

  // Tier 1 — Today
  for (final i in inventory) {
    if (i.tier == 'perishable' && isToday(i)) return i;
  }
  // Tier 2 — ThisWeek
  for (final i in inventory) {
    if (i.tier == 'perishable' && isThisWeek(i)) return i;
  }
  // Tier 3 — Fresh meat/fish
  for (final i in inventory) {
    if (i.tier == 'perishable' &&
        isFresh(i) &&
        (i.category ?? '').toLowerCase().contains('meat')) {
      return i;
    }
  }
  // Tier 4 — Fresh veg
  for (final i in inventory) {
    if (i.tier == 'perishable' &&
        isFresh(i) &&
        (i.category ?? '').toLowerCase().contains('veg')) {
      return i;
    }
  }
  // Tier 5 — Any fresh item
  for (final i in inventory) {
    if (i.tier == 'perishable' && isFresh(i)) return i;
  }
  return null;
}

class Screen13FirstRecipe extends StatefulWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;

  /// Injectable stream function for tests. Defaults to the real Gemini
  /// ephemeral entry point.
  final EphemeralRecipeStreamFn? streamFn;

  const Screen13FirstRecipe({
    super.key,
    required this.controller,
    required this.onContinue,
    this.streamFn,
  });

  @override
  State<Screen13FirstRecipe> createState() => _Screen13FirstRecipeState();
}

enum _Phase { generating, complete, error }

class _Screen13FirstRecipeState extends State<Screen13FirstRecipe> {
  _Phase _phase = _Phase.generating;
  GeneratedRecipe? _recipe;
  String _errorMessage = '';
  StreamSubscription<RecipeGenerationStatus>? _sub;
  DateTime _streamStart = DateTime.now();
  Timer? _subheadTimer;
  int _subheadIndex = 0;
  bool _demoStartLogged = false;

  // Titles we've already shown the user on this screen. Forwarded to
  // Gemini as "recent titles — do not return these" so "Show me
  // another" produces a genuinely different recipe instead of looping
  // on the same idea. See docs/onboarding/13-first-recipe.md.
  final List<String> _shownTitles = [];

  static const _subheads = [
    "Working out what to cook with what you've got…",
    'Writing the recipe…',
    'Plating it up…',
  ];

  // Map cookingConfidence (screen 07) → difficulty label in the meta row.
  static String _difficultyLabel(String? confidence) {
    switch (confidence) {
      case 'easy':
        return 'Easy';
      case 'challenge':
        return 'Advanced';
      case 'mixed':
      default:
        return 'Medium';
    }
  }

  EphemeralRecipeStreamFn get _streamFn =>
      widget.streamFn ?? GeminiService.streamGenerateContentEphemeral;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _subheadTimer?.cancel();
    super.dispose();
  }

  void _startStream() {
    _sub?.cancel();
    _subheadTimer?.cancel();
    setState(() {
      _phase = _Phase.generating;
      _recipe = null;
      _subheadIndex = 0;
      _streamStart = DateTime.now();
    });

    // Rotate the subhead at ~2s / ~4s to match spec.
    _subheadTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (!mounted) return;
      if (_subheadIndex < _subheads.length - 1) {
        setState(() => _subheadIndex++);
      }
    });

    final hero = pickHeroIngredient(
      widget.controller.state.inventory,
      DateTime.now(),
    );

    if (!_demoStartLogged) {
      _demoStartLogged = true;
      AnalyticsService.instance.logEvent(
        'onboarding_recipe_demo_started',
        {'hero_ingredient': hero?.name ?? 'none'},
      );
    } else {
      AnalyticsService.instance.logEvent(
        'onboarding_recipe_regenerated',
        {'count': widget.controller.state.regenerateCount},
      );
    }

    final stream = _streamFn(
      pantry: widget.controller.state.inventory,
      prefs: widget.controller.state,
      heroIngredientName: hero?.name,
      recentTitles: List<String>.unmodifiable(_shownTitles),
    );

    _sub = stream.listen((status) {
      if (!mounted) return;
      switch (status) {
        case RecipeGenerating():
          // Keep showing shimmer; subhead timer handles the text.
          break;
        case RecipeComplete():
          _subheadTimer?.cancel();
          setState(() {
            _phase = _Phase.complete;
            _recipe = status.recipe;
            // Remember this title so the next "Show me another" call
            // instructs Gemini not to repeat it.
            _shownTitles.add(status.recipe.title);
          });
        case RecipeError():
          _subheadTimer?.cancel();
          setState(() {
            _phase = _Phase.error;
            _errorMessage = status.message;
          });
      }
    });
  }

  void _onCookThis() {
    final r = _recipe;
    if (r == null) return;
    // firstRecipeId is a local stable id derived from the title + stream
    // start — the real Firestore id is assigned post-migration on screen 15.
    final id =
        '${r.title.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "-")}-'
        '${_streamStart.millisecondsSinceEpoch}';
    widget.controller.setFirstRecipeId(id);
    AnalyticsService.instance.logEvent(
      'onboarding_step_completed',
      const {'step_index': 13, 'step_name': 'first_recipe'},
    );
    widget.onContinue();
  }

  void _onShowMeAnother() {
    if (widget.controller.state.regenerateCount >= 3) return;
    widget.controller.incrementRegenerateCount();
    _startStream();
  }

  void _onSkip() {
    AnalyticsService.instance.logEvent(
      'onboarding_step_completed',
      const {'step_index': 13, 'step_name': 'first_recipe_skipped'},
    );
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ElioSpacing.screenEdge),
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      SizedBox(width: ElioSpacing.sm),
                      Expanded(
                        child: ElioOnboardingProgressBar(value: 13 / 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: ElioSpacing.lg),
                  Expanded(child: _buildBody()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.generating:
        return _buildGenerating();
      case _Phase.complete:
        return _buildComplete();
      case _Phase.error:
        return _buildError();
    }
  }

  Widget _buildGenerating() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ElioPageTitle("tonight's dinner, coming up…"),
        const SizedBox(height: ElioSpacing.md),
        Text(
          _subheads[_subheadIndex],
          style:
              ElioTextStyles.body.copyWith(color: ElioColors.mocha),
        ),
        const SizedBox(height: ElioSpacing.xl),
        const Expanded(child: _ShimmerRecipeCard()),
      ],
    );
  }

  Widget _buildComplete() {
    final r = _recipe!;
    final pantryByName = <String, InventoryItem>{
      for (final i in widget.controller.state.inventory)
        i.name.trim().toLowerCase(): i,
    };
    final now = DateTime.now();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Made just for you. Built from your kitchen.',
            style: ElioTextStyles.bodySmall
                .copyWith(color: ElioColors.mocha),
          ),
          const SizedBox(height: ElioSpacing.md),
          Container(
            padding: const EdgeInsets.all(ElioSpacing.lg),
            decoration: BoxDecoration(
              color: ElioColors.cream,
              borderRadius: BorderRadius.circular(ElioRadii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(r.title, style: ElioTextStyles.heading2),
                const SizedBox(height: ElioSpacing.xs),
                Text(
                  '${r.totalTimeMinutes} min · Serves ${r.servings} · '
                  '${_difficultyLabel(widget.controller.state.cookingConfidence)}',
                  style: ElioTextStyles.bodySmall
                      .copyWith(color: ElioColors.mocha),
                ),
                const SizedBox(height: ElioSpacing.md),
                Text('Ingredients', style: ElioTextStyles.heading5),
                const SizedBox(height: ElioSpacing.sm),
                ...r.ingredients.map((ing) => _IngredientRow(
                      ingredient: ing,
                      tagKind: classifyIngredientTag(
                        pantryByName[ing.name.trim().toLowerCase()],
                        now,
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: ElioSpacing.lg),
          ElioBigButton(
            label: 'Cook this tonight',
            onTap: _onCookThis,
            trailingIcon: Icons.arrow_forward,
          ),
          const SizedBox(height: ElioSpacing.sm),
          Center(
            child: Tooltip(
              message: widget.controller.state.regenerateCount >= 3
                  ? 'Plenty to choose from later'
                  : '',
              child: TextButton(
                onPressed: widget.controller.state.regenerateCount >= 3
                    ? null
                    : _onShowMeAnother,
                child: const Text('Show me another'),
              ),
            ),
          ),
          // Skip-into-app affordance (Sprint 16.2). Rob's on-device
          // smoke test flagged that once a recipe has generated, the
          // user has no way to bail out of the demo without tapping
          // "Cook this tonight" (which commits that recipe as
          // firstRecipeId). Offer an explicit neutral escape hatch.
          Center(
            child: TextButton(
              onPressed: _onSkip,
              child: Text(
                'Skip — take me to the app',
                style: ElioTextStyles.bodySmall.copyWith(
                  color: ElioColors.mocha,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ElioPageTitle("hmm, let's try that again."),
        const SizedBox(height: ElioSpacing.md),
        Text(
          "Couldn't reach Elio right now. Your pantry's saved — tap retry.",
          style:
              ElioTextStyles.body.copyWith(color: ElioColors.mocha),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: ElioSpacing.sm),
          Text(
            _errorMessage,
            style: ElioTextStyles.bodySmall
                .copyWith(color: ElioColors.mocha),
          ),
        ],
        const Spacer(),
        ElioBigButton(label: 'Try again', onTap: _startStream),
        const SizedBox(height: ElioSpacing.sm),
        Center(
          child: TextButton(
            onPressed: _onSkip,
            child: const Text('Skip for now'),
          ),
        ),
      ],
    );
  }
}

// ── Pantry-tag classifier (pure — exported for tests) ──────────────────────
//
// Maps an inventory item (or null for "not in pantry") to the visual tag that
// should render next to the ingredient in the recipe card.
//
//   null                                           → needToBuy     (🛒 grey)
//   tier == 'alwaysHave'                           → alwaysHave    (✅ amber solid)
//   tier == 'almostAlwaysHave'                     → usuallyHave   (◐ amber outline)
//   tier == 'perishable' + runningLow/expires ≤now → useToday      (🔴 coral)
//   tier == 'perishable' + expires within 3 days   → thisWeek      (🟡 amber)
//   tier == 'perishable' otherwise                 → fresh         (🟢 green)
//
// The perishable cascade mirrors `pickHeroIngredient`.
PantryTagKind classifyIngredientTag(InventoryItem? item, DateTime now) {
  if (item == null) return PantryTagKind.needToBuy;
  if (item.tier == 'alwaysHave') return PantryTagKind.alwaysHave;
  if (item.tier == 'almostAlwaysHave') return PantryTagKind.usuallyHave;
  // perishable
  if (item.isRunningLow) return PantryTagKind.useToday;
  final d = item.expiryDate;
  if (d == null) return PantryTagKind.fresh;
  if (!d.isAfter(now)) return PantryTagKind.useToday;
  final diff = d.difference(now).inDays;
  if (diff <= 3) return PantryTagKind.thisWeek;
  return PantryTagKind.fresh;
}

// ── Ingredient row (complete state) ────────────────────────────────────────
class _IngredientRow extends StatelessWidget {
  final RecipeIngredient ingredient;
  final PantryTagKind tagKind;

  const _IngredientRow({required this.ingredient, required this.tagKind});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ingredient.displayString,
              style: ElioTextStyles.body,
            ),
          ),
          const SizedBox(width: ElioSpacing.sm),
          ElioPantryTagPill(kind: tagKind),
        ],
      ),
    );
  }
}

// ── Shimmer-style skeleton (same visual pattern as recipe_screen.dart) ─────
class _ShimmerRecipeCard extends StatelessWidget {
  const _ShimmerRecipeCard();

  Widget _block({required double height, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(ElioRadii.sm),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ElioSpacing.lg),
      decoration: BoxDecoration(
        color: ElioColors.cream.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(ElioRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _block(height: 22, width: 220),
          const SizedBox(height: ElioSpacing.sm),
          _block(height: 14, width: 140),
          const SizedBox(height: ElioSpacing.lg),
          _block(height: 14),
          const SizedBox(height: ElioSpacing.xs),
          _block(height: 14),
          const SizedBox(height: ElioSpacing.xs),
          _block(height: 14, width: 200),
          const SizedBox(height: ElioSpacing.md),
          _block(height: 14),
          const SizedBox(height: ElioSpacing.xs),
          _block(height: 14, width: 180),
        ],
      ),
    );
  }
}
