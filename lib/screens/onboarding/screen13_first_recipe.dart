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
import '../../widgets/elio/elio_hero_heading.dart';
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

  static const _subheads = [
    "Working out what to cook with what you've got…",
    'Writing the recipe…',
    'Nearly there…',
  ];

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
      backgroundColor: ElioColors.offWhite,
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
        const ElioHeroHeading(
          lines: ["Tonight's dinner, coming up…"],
          amberLastLine: false,
        ),
        const SizedBox(height: ElioSpacing.md),
        Text(
          _subheads[_subheadIndex],
          style:
              ElioTextStyles.body.copyWith(color: ElioColors.textSecondary),
        ),
        const SizedBox(height: ElioSpacing.xl),
        const Expanded(child: _ShimmerRecipeCard()),
      ],
    );
  }

  Widget _buildComplete() {
    final r = _recipe!;
    final pantryNames = widget.controller.state.inventory
        .map((i) => i.name.trim().toLowerCase())
        .toSet();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Made just for you. Built from your kitchen.',
            style: ElioTextStyles.bodySmall
                .copyWith(color: ElioColors.textSecondary),
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
                  '${r.totalTimeMinutes} min · Serves ${r.servings}',
                  style: ElioTextStyles.bodySmall
                      .copyWith(color: ElioColors.textSecondary),
                ),
                const SizedBox(height: ElioSpacing.md),
                Text('Ingredients', style: ElioTextStyles.heading5),
                const SizedBox(height: ElioSpacing.sm),
                ...r.ingredients.map((ing) => _IngredientRow(
                      ingredient: ing,
                      inPantry:
                          pantryNames.contains(ing.name.trim().toLowerCase()),
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
            child: TextButton(
              onPressed: widget.controller.state.regenerateCount >= 3
                  ? null
                  : _onShowMeAnother,
              child: const Text('Show me another'),
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
        const ElioHeroHeading(
          lines: ["Hmm, let's try that again."],
          amberLastLine: false,
        ),
        const SizedBox(height: ElioSpacing.md),
        Text(
          "We couldn't reach our kitchen AI. Your pantry's saved — let's retry.",
          style:
              ElioTextStyles.body.copyWith(color: ElioColors.textSecondary),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: ElioSpacing.sm),
          Text(
            _errorMessage,
            style: ElioTextStyles.bodySmall
                .copyWith(color: ElioColors.textSecondary),
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

// ── Ingredient row (complete state) ────────────────────────────────────────
class _IngredientRow extends StatelessWidget {
  final RecipeIngredient ingredient;
  final bool inPantry;

  const _IngredientRow({required this.ingredient, required this.inPantry});

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
          if (inPantry) ...[
            const SizedBox(width: ElioSpacing.sm),
            const ElioPantryTagPill(kind: PantryTagKind.inYourPantry),
          ],
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
