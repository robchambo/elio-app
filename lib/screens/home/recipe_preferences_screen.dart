// lib/screens/home/recipe_preferences_screen.dart
//
// Sprint 16.3 — Recipe Preferences sits between Home's Generate CTA and the
// Recipe Screen. The user picks Mood / Style / Time (chips) and taps
// "Generate". This screen now owns the entire generation phase: it streams
// from GeminiService, displays rotating friendly status messages, and on
// completion replaces itself with RecipeScreen — so the user never sees Home
// flicker between prefs and the recipe.
//
// Sprint 16.2 regression context: the editorial Home rebuild dropped the
// streaming progress UI entirely (`// No UI message to update`). Restoring
// it here, on prefs, avoids the prior flicker problem and keeps generation
// logic encapsulated. Home still owns request-building (so it can fold in
// pantry/dietary/appliance state) and post-completion bookkeeping (recent
// titles, analytics, background Firestore saves) via callbacks.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/recipe_models.dart';
import '../../models/recipe_preferences.dart';
import '../../services/entitlement_service.dart';
import '../../services/gemini_service.dart';
import '../../services/history_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_chip.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../paywall/paywall_screen.dart';
import '../recipe/recipe_screen.dart';
import 'bulk_prep_results_screen.dart';
import 'perishables_picker_screen.dart';

/// Builds a generation request from the prefs the user picked. Lives on
/// Home so it can fold in pantry, dietary, appliance, recent-titles state.
typedef BuildRequestFn =
    RecipeGenerationRequest Function(RecipePreferences prefs);

/// Called when the stream emits [RecipeComplete]. Home uses it to update
/// recent titles, fire analytics, and kick off background Firestore saves.
typedef OnRecipeCompleteFn =
    void Function(GeneratedRecipe recipe, RecipeGenerationRequest request);

/// Test seam — production passes [GeminiService.generateRecipeStream].
typedef RecipeStreamFactory =
    Stream<RecipeGenerationStatus> Function(RecipeGenerationRequest);

class RecipePreferencesScreen extends StatefulWidget {
  /// Builds the full request from the user's chip picks plus Home-owned
  /// state (pantry, dietary, appliances, recent titles, etc.).
  final BuildRequestFn buildRequest;

  /// Side-effects Home wants to run when a recipe completes successfully.
  /// History save + navigation are handled here on prefs; this callback is
  /// for the things only Home knows about (analytics, dedup, etc.).
  final OnRecipeCompleteFn onRecipeComplete;

  /// Forwarded to [RecipeScreen] on push-replacement after generation.
  final bool isGuest;

  /// Read-only union of dietary requirements across all active household
  /// profiles, shown as an info strip near the top of the picker so the
  /// user can see what's being applied. Empty list = no strip.
  final List<String> activeDietary;

  /// User-saved custom food styles (from Account → Food Style). When
  /// non-empty, they render as a "your styles" row above the built-in
  /// style chips so the user can pick a saved style with one tap.
  final List<String> customStyles;

  /// Names of perishable inventory items pulled from Firestore — passed
  /// to the Perishables Picker so the user can quick-select them as
  /// "use up these items" inputs.
  final List<String> perishableInventory;

  /// Test injection — defaults to [GeminiService.generateRecipeStream].
  final RecipeStreamFactory? streamFactory;

  /// Test injection — overrides [EntitlementService.instance.isPro] for the
  /// Bulk cook gate so widget tests can exercise the slider dialog without
  /// touching Firebase. Production callers leave this null.
  ///
  /// Renamed from `proOverride` to avoid colliding with the retired
  /// Sprint 17 `subscription.proOverride` Firestore field. This flag is
  /// purely a widget-level test seam; it does not grant Pro to any user.
  final bool? proOverrideForTest;

  const RecipePreferencesScreen({
    super.key,
    required this.buildRequest,
    required this.onRecipeComplete,
    required this.isGuest,
    this.activeDietary = const [],
    this.customStyles = const [],
    this.perishableInventory = const [],
    this.streamFactory,
    this.proOverrideForTest,
  });

  @override
  State<RecipePreferencesScreen> createState() =>
      _RecipePreferencesScreenState();
}

enum _PrefsPhase { picking, generating, error }

class _RecipePreferencesScreenState extends State<RecipePreferencesScreen> {
  static const _timeOptions = <String>[
    'Quick (< 15 min)',
    'Standard (< 30 min)',
    'Slow (< 60 min)',
    'Any',
  ];
  // Style on this screen = descriptive direction the user wants the
  // dish to feel (Comfort / Healthy / Hearty / Spicy / Fresh).
  // Deliberately distinct from the cuisine-based pivot list in the
  // post-regen-failure dialog at recipe_screen.dart:_alternativeStyles
  // (Italian / Asian / Mexican / etc.) — those are offered AFTER this
  // choice didn't land, specifically to "mix it up" along a different
  // axis. Don't unify the two lists; they're complementary.
  static const _styleOptions = <String>[
    'Comfort',
    'Healthy',
    'Light',
    'Hearty',
    'Spicy',
    'Fresh',
    'Any',
  ];
  static const _moodOptions = <String>[
    'Easy',
    'Impressive',
    'Kid-friendly',
    'Date night',
    'Meal prep',
    'Any',
  ];

  /// Rotated every [_messageInterval] while generating, looping at the end.
  /// Voice-aligned with the brand: friendly, present-tense, no jargon.
  static const _streamingMessages = <String>[
    'Browsing your pantry…',
    'Choosing flavours…',
    'Building the recipe…',
    'Making it delicious…',
  ];
  static const _messageInterval = Duration(milliseconds: 1500);

  String _time = 'Any';
  String _style = 'Any';
  String _mood = 'Any';

  // Sprint 16.3 — Saver + Bulk cook live as the top-of-screen toggle row
  // (above the chip sections). Bulk cook is Pro-gated and opens a slider
  // dialog (meals 1-3, portions 4-12) on enable; tapping the right side
  // of the row while enabled re-opens the dialog to tweak the values.
  bool _isSaverMode = false;
  bool _bulkCookEnabled = false;
  int _bulkMeals = 2;
  int _bulkPortions = 6;

  // Sprint 16.3 (later) — replaced the leftover chip-editor with two
  // distinct affordances:
  //   • _cravingController — free-text "what do you fancy?" at the top of
  //     the picker. Wired to RecipeGenerationRequest.userRequest as a
  //     high-priority soft preference.
  //   • _useUpItems — selections returned by PerishablesPickerScreen.
  //     Mapped onto request.perishables (REQUIRED ingredients) when present.
  final TextEditingController _cravingController = TextEditingController();
  List<String> _useUpItems = const [];

  _PrefsPhase _phase = _PrefsPhase.picking;
  int _messageIndex = 0;
  Timer? _messageTimer;
  StreamSubscription<RecipeGenerationStatus>? _generationSub;
  String? _errorMessage;

  @override
  void dispose() {
    _messageTimer?.cancel();
    _generationSub?.cancel();
    _cravingController.dispose();
    super.dispose();
  }

  // ── Generate ─────────────────────────────────────────────────────
  void _generate() {
    final craving = _cravingController.text.trim();
    final prefs = RecipePreferences(
      time: _time == 'Any' ? null : _time,
      style: _style == 'Any' ? null : _style,
      mood: _mood == 'Any' ? null : _mood,
      isSaverMode: _isSaverMode,
      // Legacy leftover-mode flag retained on the value object for callers
      // that still consume it; the new picker drives [useUpItems] directly.
      isLeftoverMode: false,
      leftoverItems: const [],
      userRequest: craving.isEmpty ? null : craving,
      useUpItems: List.unmodifiable(_useUpItems),
    );

    final request = widget.buildRequest(prefs);

    // Bulk cook routes through a separate multi-meal generation flow
    // (GeminiService.generateBulkRecipeStream) and pushes BulkPrepResultsScreen
    // when finished. The standard single-recipe stream path is below.
    if (_bulkCookEnabled) {
      _generateBulk(request);
      return;
    }

    setState(() {
      _phase = _PrefsPhase.generating;
      _messageIndex = 0;
      _errorMessage = null;
    });
    _startMessageRotation();

    final factory = widget.streamFactory ?? GeminiService.generateRecipeStream;
    _generationSub = factory(request).listen(
      (status) => _handleStatus(status, request),
      onError: (Object e) {
        if (!mounted) return;
        _showError(e.toString());
      },
      onDone: () {
        // If we never saw a complete or error, treat as failure.
        if (!mounted) return;
        if (_phase == _PrefsPhase.generating) {
          _showError(
            'Generation ended unexpectedly. Please try again.',
          );
        }
      },
    );
  }

  void _handleStatus(
    RecipeGenerationStatus status,
    RecipeGenerationRequest request,
  ) {
    if (!mounted) return;
    switch (status) {
      case RecipeGenerating():
        // Rotating messages drive the UI — no per-event work needed.
        break;
      case RecipeComplete():
        _handleComplete(status.recipe, request);
      case RecipeError():
        _showError(status.message);
    }
  }

  void _handleComplete(GeneratedRecipe recipe, RecipeGenerationRequest request) {
    // Save to history FIRST so RecipeScreen knows the savedAt and bookmark
    // toggling treats it as already-saved (mirrors the prior Home behaviour).
    final savedAt = DateTime.now().toUtc().toIso8601String();
    HistoryService.saveRecipe(SavedRecipe(recipe: recipe, savedAt: savedAt));

    // Let Home update recent titles, fire analytics, and kick off
    // background Firestore saves while we navigate.
    widget.onRecipeComplete(recipe, request);

    _messageTimer?.cancel();
    _generationSub?.cancel();

    // pushReplacement keeps Home off the visible stack — when the user pops
    // RecipeScreen they land back on Home, never seeing prefs again.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RecipeScreen(
          recipe: recipe,
          originalRequest: request,
          isGuest: widget.isGuest,
          savedAt: savedAt,
        ),
      ),
    );
  }

  // ── Bulk cook generation flow ───────────────────────────────────
  // Loops over the user's chosen meal count, streaming each recipe via
  // [GeminiService.generateBulkRecipeStream] (which scales for portions
  // and dedupes against the previously generated meals in the batch).
  // On success we push BulkPrepResultsScreen with the collected recipes;
  // on failure we surface the error in the standard error phase.
  Future<void> _generateBulk(RecipeGenerationRequest request) async {
    setState(() {
      _phase = _PrefsPhase.generating;
      _messageIndex = 0;
      _errorMessage = null;
    });
    _startMessageRotation();

    final completed = <GeneratedRecipe>[];
    final previousTitles = <String>[];

    for (int meal = 1; meal <= _bulkMeals; meal++) {
      if (!mounted) return;
      GeneratedRecipe? result;
      String? errorMsg;
      try {
        await for (final status in GeminiService.generateBulkRecipeStream(
          request,
          portions: _bulkPortions,
          mealNumber: meal,
          totalMeals: _bulkMeals,
          previousMealTitles: previousTitles,
        )) {
          if (!mounted) return;
          switch (status) {
            case RecipeGenerating():
              break;
            case RecipeComplete():
              result = status.recipe;
            case RecipeError():
              errorMsg = status.message;
          }
        }
      } on Object catch (e) {
        // Stream itself threw (transport / parse failure). Without this
        // catch the exception bubbles uncaught and the user is stuck in
        // the generating phase with the message rotation running forever.
        if (!mounted) return;
        _showError(e.toString());
        return;
      }
      if (errorMsg != null) {
        _showError(errorMsg);
        return;
      }
      if (result != null) {
        completed.add(result);
        previousTitles.add(result.title);
        // Save to history immediately so it's available before the user
        // taps a card on the results screen (mirrors the single-recipe path).
        HistoryService.saveRecipe(SavedRecipe(
          recipe: result,
          savedAt: DateTime.now().toUtc().toIso8601String(),
        ));
        // Let Home update recent titles / analytics / background saves.
        widget.onRecipeComplete(result, request);
      }
    }

    if (!mounted) return;
    _messageTimer?.cancel();
    if (completed.isEmpty) {
      _showError('Bulk cook ended unexpectedly. Please try again.');
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BulkPrepResultsScreen(
          recipes: completed,
          originalRequest: request,
          isGuest: widget.isGuest,
        ),
      ),
    );
  }

  void _showError(String message) {
    _messageTimer?.cancel();
    setState(() {
      _phase = _PrefsPhase.error;
      _errorMessage = message;
    });
  }

  void _retry() {
    _generationSub?.cancel();
    setState(() {
      _phase = _PrefsPhase.picking;
      _errorMessage = null;
    });
  }

  void _startMessageRotation() {
    _messageTimer?.cancel();
    _messageTimer = Timer.periodic(_messageInterval, (_) {
      if (!mounted) return;
      setState(() {
        _messageIndex = (_messageIndex + 1) % _streamingMessages.length;
      });
    });
  }

  // ── UI ───────────────────────────────────────────────────────────
  Widget _section({
    required String eyebrow,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElioEyebrow(eyebrow),
        const SizedBox(height: ElioSpacing.md),
        Wrap(
          spacing: ElioSpacing.sm,
          runSpacing: ElioSpacing.sm,
          children: [
            for (final opt in options)
              ElioChip(
                label: opt,
                selected: selected == opt,
                onTap: () => onSelect(opt),
              ),
          ],
        ),
      ],
    );
  }

  // ── Active dietary strip: read-only summary (Sprint 16.3) ────────
  // Surfaces the household-union dietary requirements so the user can see
  // what's being baked into every generation. Editing happens elsewhere
  // (Account → Dietary / Household), not on this screen — this strip is
  // info-only so the picker stays focused on the per-recipe picks.
  Widget _buildDietaryStrip() {
    return Container(
      padding: const EdgeInsets.all(ElioSpacing.md),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_outlined,
                  color: ElioColors.terracotta, size: 18),
              const SizedBox(width: ElioSpacing.sm),
              Text(
                'Dietary needs',
                style: ElioTextStyles.eyebrow.copyWith(
                  color: ElioColors.espresso,
                ),
              ),
            ],
          ),
          const SizedBox(height: ElioSpacing.sm),
          Wrap(
            spacing: ElioSpacing.sm,
            runSpacing: ElioSpacing.sm,
            children: [
              for (final req in widget.activeDietary)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ElioSpacing.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ElioColors.cream,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: ElioColors.terracotta.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    req,
                    style: ElioTextStyles.bodySmall.copyWith(
                      color: ElioColors.espresso,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Top toggles row: Saver + Bulk cook (Sprint 16.3) ─────────────
  // Promoted from the old "constraints" chip strip into a top-of-screen
  // row of switch tiles. Saver flips a flag the prompt already honours;
  // Bulk cook is Pro-gated and opens [_showBulkCookDialog] on enable to
  // capture meals × portions, which feed the dedicated bulk Gemini path.
  Widget _buildTopToggles() {
    return Column(
      children: [
        _buildToggleTile(
          icon: Icons.savings_outlined,
          title: 'Saver mode',
          subtitle: 'Budget-friendly recipes',
          value: _isSaverMode,
          onChanged: (v) => setState(() => _isSaverMode = v),
        ),
        const SizedBox(height: ElioSpacing.sm),
        _buildToggleTile(
          icon: Icons.kitchen_outlined,
          title: 'Bulk cook',
          subtitle: _bulkCookEnabled
              ? '$_bulkMeals meals × $_bulkPortions portions'
              : 'Freezer-friendly meals in one go',
          value: _bulkCookEnabled,
          onChanged: (v) async {
            if (v) {
              if (!_isProActive) {
                await _showBulkPaywall();
                return;
              }
              final accepted = await _showBulkCookDialog();
              if (!accepted) return;
            }
            if (!mounted) return;
            setState(() => _bulkCookEnabled = v);
          },
          trailingTap: _bulkCookEnabled ? () => _showBulkCookDialog() : null,
        ),
      ],
    );
  }

  bool get _isProActive {
    if (widget.proOverrideForTest != null) return widget.proOverrideForTest!;
    return EntitlementService.instance.isPro;
  }

  Future<void> _showBulkPaywall() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => const PaywallScreen(triggerContext: 'bulk_cook'),
      ),
    );
    // Re-evaluate after the user returns. If they upgraded, open the dialog
    // straight away and commit on accept.
    if (!mounted) return;
    if (_isProActive) {
      final accepted = await _showBulkCookDialog();
      if (!mounted || !accepted) return;
      setState(() => _bulkCookEnabled = true);
    }
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    VoidCallback? trailingTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(ElioSpacing.md),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(ElioRadii.card),
        border: Border.all(
          color: value
              ? ElioColors.terracotta
              : ElioColors.rule,
          width: value ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? ElioColors.terracotta : ElioColors.espresso,
            size: 22,
          ),
          const SizedBox(width: ElioSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ElioTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ElioColors.espresso,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: ElioTextStyles.bodySmall.copyWith(
                    color: ElioColors.mocha,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: ElioColors.terracotta,
          ),
        ],
      ),
    );
    if (trailingTap == null) return card;
    return InkWell(
      onTap: trailingTap,
      borderRadius: BorderRadius.circular(ElioRadii.card),
      child: card,
    );
  }

  /// Slider dialog for Bulk cook: meals (1-3) and portions per meal (4-12),
  /// with a live helper line. Returns true if the user committed values.
  Future<bool> _showBulkCookDialog() async {
    int meals = _bulkMeals;
    int portions = _bulkPortions;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.kitchen_outlined,
                  color: ElioColors.terracotta, size: 20),
              const SizedBox(width: 8),
              Text('Bulk cook', style: ElioTextStyles.heading4),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Meals: $meals',
                  style: ElioTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600)),
              Slider(
                value: meals.toDouble(),
                min: 1,
                max: 3,
                divisions: 2,
                activeColor: ElioColors.terracotta,
                label: '$meals',
                onChanged: (v) =>
                    setDialogState(() => meals = v.round()),
              ),
              const SizedBox(height: 8),
              Text('Portions per meal: $portions',
                  style: ElioTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600)),
              Slider(
                value: portions.toDouble(),
                min: 4,
                max: 12,
                divisions: 8,
                activeColor: ElioColors.terracotta,
                label: '$portions',
                onChanged: (v) =>
                    setDialogState(() => portions = v.round()),
              ),
              const SizedBox(height: 12),
              Text(
                'Elio will generate $meals freezer-friendly '
                '${meals == 1 ? "meal" : "meals"}, each scaled for '
                '$portions portions when you generate.',
                style: ElioTextStyles.bodySmall.copyWith(
                  color: ElioColors.mocha,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: ElioColors.mocha)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ElioColors.terracotta,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      setState(() {
        _bulkMeals = meals;
        _bulkPortions = portions;
      });
      return true;
    }
    return false;
  }

  // ── Free-text "craving" field (Sprint 16.3 later) ─────────────────
  // Sits at the top of the picker so it shapes the dish category before
  // the chips layer on. Subtle by design — not amber, no eyebrow shouting,
  // just a friendly nudge that the user can describe what they want.
  Widget _buildCravingField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(ElioRadii.card),
      ),
      child: TextField(
        controller: _cravingController,
        textInputAction: TextInputAction.done,
        style: ElioTextStyles.body,
        decoration: InputDecoration(
          hintText: 'Got a craving? Tell me about it',
          hintStyle: ElioTextStyles.body.copyWith(
            color: ElioColors.mocha,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── "Use up" picker entry point (Sprint 16.3 later) ───────────────
  // Replaces the inline leftover chip-editor. Pushes
  // PerishablesPickerScreen which returns the user's selections.
  Widget _buildUseUpRow() {
    final count = _useUpItems.length;
    final hasSelection = count > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ElioEyebrow('use up'),
        const SizedBox(height: ElioSpacing.sm),
        InkWell(
          onTap: _openPerishablesPicker,
          borderRadius: BorderRadius.circular(ElioRadii.card),
          child: Container(
            padding: const EdgeInsets.all(ElioSpacing.md),
            decoration: BoxDecoration(
              color: ElioColors.cream,
              borderRadius: BorderRadius.circular(ElioRadii.card),
              border: Border.all(
                color: hasSelection
                    ? ElioColors.terracotta
                    : ElioColors.rule,
                width: hasSelection ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.eco_outlined,
                  color:
                      hasSelection ? ElioColors.terracotta : ElioColors.espresso,
                  size: 20,
                ),
                const SizedBox(width: ElioSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasSelection
                            ? 'Using $count item${count == 1 ? '' : 's'}'
                            : 'Got something to use up?',
                        style: ElioTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: ElioColors.espresso,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasSelection
                            ? _useUpItems.join(', ')
                            : 'Pick perishables or add leftovers',
                        style: ElioTextStyles.bodySmall.copyWith(
                          color: ElioColors.mocha,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: ElioColors.mocha,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPerishablesPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => PerishablesPickerScreen(
          perishableInventory: widget.perishableInventory,
          initialSelection: _useUpItems,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _useUpItems = result);
  }

  Widget _buildPickingBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ElioSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ElioHeroHeading(
            lines: ['set the', 'mood'],
            amberLastLine: true,
            showUnderline: true,
          ),
          if (widget.activeDietary.isNotEmpty) ...[
            const SizedBox(height: ElioSpacing.lg),
            _buildDietaryStrip(),
          ],
          const SizedBox(height: ElioSpacing.xl),
          _buildCravingField(),
          const SizedBox(height: ElioSpacing.xl),
          _buildTopToggles(),
          const SizedBox(height: ElioSpacing.xl),
          _section(
            eyebrow: 'time',
            options: _timeOptions,
            selected: _time,
            onSelect: (v) => setState(() => _time = v),
          ),
          const SizedBox(height: ElioSpacing.xl),
          if (widget.customStyles.isNotEmpty) ...[
            _section(
              eyebrow: 'your styles',
              options: widget.customStyles,
              selected: _style,
              onSelect: (v) => setState(() => _style = v),
            ),
            const SizedBox(height: ElioSpacing.lg),
          ],
          _section(
            eyebrow: 'style',
            options: _styleOptions,
            selected: _style,
            onSelect: (v) => setState(() => _style = v),
          ),
          const SizedBox(height: ElioSpacing.xl),
          _section(
            eyebrow: 'mood',
            options: _moodOptions,
            selected: _mood,
            onSelect: (v) => setState(() => _mood = v),
          ),
          const SizedBox(height: ElioSpacing.xl),
          _buildUseUpRow(),
          const SizedBox(height: ElioSpacing.xxl),
          ElioBigButton(
            label: 'Generate',
            onTap: _generate,
          ),
          const SizedBox(height: ElioSpacing.md),
        ],
      ),
    );
  }

  Widget _buildGeneratingBody() {
    return Padding(
      padding: const EdgeInsets.all(ElioSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(ElioColors.terracotta),
              ),
            ),
            const SizedBox(height: ElioSpacing.xl),
            // AnimatedSwitcher gives a soft cross-fade between messages.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(
                _streamingMessages[_messageIndex],
                key: ValueKey<int>(_messageIndex),
                textAlign: TextAlign.center,
                style: ElioTextStyles.heading4.copyWith(color: ElioColors.espresso),
              ),
            ),
            const SizedBox(height: ElioSpacing.sm),
            Text(
              "Elio is cooking up something good.",
              textAlign: TextAlign.center,
              style: ElioTextStyles.body.copyWith(
                color: ElioColors.mocha,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBody() {
    return Padding(
      padding: const EdgeInsets.all(ElioSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(
            Icons.error_outline,
            size: 48,
            color: ElioColors.error,
          ),
          const SizedBox(height: ElioSpacing.lg),
          Text(
            'Something went wrong.',
            textAlign: TextAlign.center,
            style: ElioTextStyles.heading4.copyWith(color: ElioColors.espresso),
          ),
          const SizedBox(height: ElioSpacing.sm),
          Text(
            _errorMessage ?? 'Please try again.',
            textAlign: TextAlign.center,
            style: ElioTextStyles.body.copyWith(
              color: ElioColors.mocha,
            ),
          ),
          const Spacer(),
          ElioBigButton(
            label: 'Try again',
            trailingIcon: Icons.refresh,
            onTap: _retry,
          ),
          const SizedBox(height: ElioSpacing.md),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // While generating, suppress the back arrow — leaving mid-stream would
    // orphan the subscription and confuse the user. The user can still
    // retry on error or wait for completion to push-replace to RecipeScreen.
    final showBack = _phase != _PrefsPhase.generating;

    Widget body;
    switch (_phase) {
      case _PrefsPhase.picking:
        body = _buildPickingBody();
      case _PrefsPhase.generating:
        body = _buildGeneratingBody();
      case _PrefsPhase.error:
        body = _buildErrorBody();
    }

    return PopScope(
      canPop: showBack,
      child: Scaffold(
        backgroundColor: ElioColors.cream,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: ElioColors.espresso),
          automaticallyImplyLeading: showBack,
        ),
        body: body,
      ),
    );
  }
}
