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
import '../../services/gemini_service.dart';
import '../../services/history_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_chip.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../recipe/recipe_screen.dart';

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

  /// Test injection — defaults to [GeminiService.generateRecipeStream].
  final RecipeStreamFactory? streamFactory;

  const RecipePreferencesScreen({
    super.key,
    required this.buildRequest,
    required this.onRecipeComplete,
    required this.isGuest,
    this.activeDietary = const [],
    this.customStyles = const [],
    this.streamFactory,
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

  // Sprint 16.3 — restored constraint toggles.
  // TODO(sprint-16-polish-bulk-prep): Bulk Prep is intentionally NOT here
  // yet — it routes through `GeminiService.generateBulkRecipeStream`
  // (portions / mealNumber / totalMeals / previousMealTitles) and produces
  // a recipe with bulkPrepInfo. Needs a Kate design pass before wiring
  // (see docs/roadmap.md → "Bulk Prep on the recipe prefs screen").
  bool _isSaverMode = false;
  bool _isLeftoverMode = false;
  final List<String> _leftoverItems = [];
  final TextEditingController _leftoverController = TextEditingController();

  _PrefsPhase _phase = _PrefsPhase.picking;
  int _messageIndex = 0;
  Timer? _messageTimer;
  StreamSubscription<RecipeGenerationStatus>? _generationSub;
  String? _errorMessage;

  @override
  void dispose() {
    _messageTimer?.cancel();
    _generationSub?.cancel();
    _leftoverController.dispose();
    super.dispose();
  }

  // ── Generate ─────────────────────────────────────────────────────
  void _generate() {
    final prefs = RecipePreferences(
      time: _time == 'Any' ? null : _time,
      style: _style == 'Any' ? null : _style,
      mood: _mood == 'Any' ? null : _mood,
      isSaverMode: _isSaverMode,
      isLeftoverMode: _isLeftoverMode,
      leftoverItems: _isLeftoverMode ? List.unmodifiable(_leftoverItems) : const [],
    );

    final request = widget.buildRequest(prefs);
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
                  color: ElioColors.amber, size: 18),
              const SizedBox(width: ElioSpacing.sm),
              Text(
                'Dietary needs',
                style: ElioTextStyles.eyebrow.copyWith(
                  color: ElioColors.navy,
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
                    color: ElioColors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: ElioColors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    req,
                    style: ElioTextStyles.bodySmall.copyWith(
                      color: ElioColors.navy,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Constraints panel: Saver + Leftover (Sprint 16.3) ────────────
  Widget _buildConstraintsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ElioEyebrow('constraints'),
        const SizedBox(height: ElioSpacing.md),
        Wrap(
          spacing: ElioSpacing.sm,
          runSpacing: ElioSpacing.sm,
          children: [
            ElioChip(
              label: 'Saver',
              selected: _isSaverMode,
              onTap: () => setState(() => _isSaverMode = !_isSaverMode),
            ),
            ElioChip(
              label: 'Use up leftovers',
              selected: _isLeftoverMode,
              onTap: () => setState(() => _isLeftoverMode = !_isLeftoverMode),
            ),
          ],
        ),
        if (_isLeftoverMode) ...[
          const SizedBox(height: ElioSpacing.md),
          _buildLeftoverEditor(),
        ],
      ],
    );
  }

  Widget _buildLeftoverEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing items as removable chips.
        if (_leftoverItems.isNotEmpty) ...[
          Wrap(
            spacing: ElioSpacing.sm,
            runSpacing: ElioSpacing.sm,
            children: [
              for (final item in _leftoverItems)
                InputChip(
                  label: Text(item),
                  onDeleted: () => setState(() => _leftoverItems.remove(item)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  backgroundColor: ElioColors.cream,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: const BorderSide(color: ElioColors.amber),
                  ),
                ),
            ],
          ),
          const SizedBox(height: ElioSpacing.sm),
        ],
        // Add-item row.
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _leftoverController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'e.g. roast chicken, rice',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addLeftover(),
              ),
            ),
            const SizedBox(width: ElioSpacing.sm),
            IconButton(
              icon: const Icon(Icons.add_circle, color: ElioColors.amber),
              tooltip: 'Add leftover',
              onPressed: _addLeftover,
            ),
          ],
        ),
      ],
    );
  }

  void _addLeftover() {
    final raw = _leftoverController.text.trim();
    if (raw.isEmpty) return;
    // Cheap dup-guard: case-insensitive exact match.
    final lower = raw.toLowerCase();
    if (_leftoverItems.any((i) => i.toLowerCase() == lower)) {
      _leftoverController.clear();
      return;
    }
    setState(() {
      _leftoverItems.add(raw);
      _leftoverController.clear();
    });
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
          _buildConstraintsSection(),
          const SizedBox(height: ElioSpacing.xxl),
          ElioBigButton(
            label: 'Generate',
            trailingIcon: Icons.auto_awesome,
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
      child: Column(
        children: [
          const Spacer(),
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(ElioColors.amber),
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
              style: ElioTextStyles.heading4.copyWith(color: ElioColors.navy),
            ),
          ),
          const SizedBox(height: ElioSpacing.sm),
          Text(
            "Elio is cooking up something good.",
            textAlign: TextAlign.center,
            style: ElioTextStyles.body.copyWith(
              color: ElioColors.textSecondary,
            ),
          ),
          const Spacer(),
        ],
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
            style: ElioTextStyles.heading4.copyWith(color: ElioColors.navy),
          ),
          const SizedBox(height: ElioSpacing.sm),
          Text(
            _errorMessage ?? 'Please try again.',
            textAlign: TextAlign.center,
            style: ElioTextStyles.body.copyWith(
              color: ElioColors.textSecondary,
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
        backgroundColor: ElioColors.offWhite,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: ElioColors.navy),
          automaticallyImplyLeading: showBack,
        ),
        body: body,
      ),
    );
  }
}
