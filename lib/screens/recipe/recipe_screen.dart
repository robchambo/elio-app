import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../models/recipe_models.dart';
import '../../services/gemini_service.dart';
import '../../services/history_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/pantry_utils.dart';
import '../../utils/region_utils.dart';
import '../../services/analytics_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/error_service.dart';
import '../../services/cooking_timer_service.dart';
import '../../services/shopping_service.dart';
import '../../services/user_settings_service.dart';
import '../../utils/friendly_error.dart';
import '../../utils/snackbar_helpers.dart';
import '../../utils/quantity_utils.dart';
import '../../utils/time_parser.dart';
import '../../utils/recipe_variation.dart';
import '../../widgets/elio/elio_duration_picker_sheet.dart';
import '../../widgets/elio/elio_page_title.dart';
import '../../widgets/elio/elio_section_heading.dart';
import '../../widgets/elio/elio_stat_badge.dart';
import '../../widgets/elio/elio_servings_control.dart';
import '../../widgets/elio/elio_ingredient_row.dart';
import '../../widgets/elio/elio_pantry_icon.dart';
import '../../widgets/elio/elio_method_step.dart';
import '../../widgets/elio/elio_feedback_bar.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_timer_chip.dart';
import '../paywall/paywall_screen.dart';
import '../shopping/shopping_list_screen.dart';

// ─────────────────────────────────────────────
// RecipeScreen — Sprint 4 patch
// Design philosophy: approachable utility.
//
// New in this patch:
//   • ✕ button on each ingredient row → adds to session exclusion list
//   • "Generate Another" button → regenerates with same inputs + exclusions
//   • Recent title memory passed through to prevent duplicates
// ─────────────────────────────────────────────

class RecipeScreen extends StatefulWidget {
  final GeneratedRecipe recipe;
  final RecipeGenerationRequest? originalRequest;
  final bool isGuest;

  /// The savedAt timestamp from history — enables bookmark toggling
  /// instead of creating duplicates. Import + Generate flows now pre-
  /// save the recipe and pass the resulting `savedAt` in (was
  /// previously a separate `autoSave` flag with a fire-and-forget save
  /// in initState — removed 16 May 2026 because the race against
  /// pushReplacement caused stale Saved/Home recents on Android).
  final String? savedAt;

  /// Tracks how many times "Generate Another" has been tapped across
  /// screen replacements. After 3, a preference adjustment dialog appears.
  final int regenCount;

  /// True when this RecipeScreen renders a generated side dish (pushed
  /// from a main recipe's "Suggest a side dish" CTA). When true:
  ///   - the secondary CTA at the bottom reads "Generate another" (not
  ///     "Suggest a side dish") because the user is already on one;
  ///   - that CTA regenerates a fresh side dish against the SAME main
  ///     recipe context using [sideDishMainTitle] / [sideDishMainIngredientNames]
  ///     / [sideDishMainDietaryTags] (not against the current side
  ///     dish itself, which would compound).
  ///   - the new side dish replaces this screen rather than pushing
  ///     deeper, so back goes straight to the main recipe.
  final bool isSideDish;
  final String? sideDishMainTitle;
  final List<String>? sideDishMainIngredientNames;
  final List<String>? sideDishMainDietaryTags;

  const RecipeScreen({
    super.key,
    required this.recipe,
    this.originalRequest,
    this.isGuest = false,
    this.savedAt,
    this.regenCount = 0,
    this.isSideDish = false,
    this.sideDishMainTitle,
    this.sideDishMainIngredientNames,
    this.sideDishMainDietaryTags,
  });

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  late int _servings;

  // ── Mutable recipe (supports in-place ingredient swaps) ────────────────────
  late GeneratedRecipe _currentRecipe;
  bool _handsFreeMode = false;
  int _currentStep = 0;
  final Set<int> _expandedSubstitutions = {};
  bool _bulkPrepExpanded = true;

  // ── Save & Shopping state ───────────────────────────────────────────────────
  bool _isSaved = false;
  bool _isAddingToShop = false;
  String? _savedAt; // history timestamp — set when recipe is from history

  // ── Regeneration state ──────────────────────────────────────────────────────────────────────────────
  bool _isRegenerating = false;
  bool _isGeneratingSideDish = false;
  bool _sideDishGenerated = false;

  @visibleForTesting
  void debugMarkSideDishGenerated() {
    setState(() => _sideDishGenerated = true);
  }

  /// Builds the [RecipeGenerationRequest] used by "Generate another".
  ///
  /// Carries forward every field from [base] and overlays:
  ///   • exclusions accumulated in this session (`_excludedIngredients`)
  ///   • the current recipe's title appended to `recentTitles`
  ///   • dietary + custom-allergen lists re-read from
  ///     [UserSettingsService] so mid-screen Settings edits are honoured
  ///     (Sprint 16.1 belt-and-braces, see git log on this file).
  ///
  /// **Iron rule:** every other field — including the free-text
  /// `userRequest` craving, `mealType`, and the variation FIFOs
  /// (`recentHeroIngredients`/`recentCookware`) — MUST be threaded
  /// through. Dropping any of them silently makes "Generate another"
  /// regress to a generic generation that ignores the user's stated
  /// intent. This was Sprint 16.3 bug: `userRequest` was being lost.
  ///
  /// **Variation FIFOs are extended in-place by this method.** Home
  /// owns the FIFO across separate generations, but home never sees a
  /// regen happen on this screen, so the hero + cookware of
  /// [_currentRecipe] are appended here (capped at the same window of
  /// 3 home enforces). Without this the 2nd, 3rd, 4th... regen all see
  /// the SAME stale variation memory and rotation breaks (Notion bug
  /// row "4th recipe should pivot", 16 May 2026). User-required
  /// perishables are excluded from the hero FIFO using the same rule
  /// as [HomeScreen._onRecipeComplete] (matches HomeScreen's
  /// `_isUserRequiredPerishable`).
  ///
  /// Exposed for test reach. Pure with respect to widget state — does
  /// not mutate.
  @visibleForTesting
  RecipeGenerationRequest debugBuildRegenRequest(
    RecipeGenerationRequest base,
  ) {
    final settings = UserSettingsService.instance;

    // Variation FIFO updates — append current recipe's hero/cookware
    // before regen so successive regens actually see rotation. Cap at
    // window of 3 (matches HomeScreen._variationWindow).
    const variationWindow = 3;
    final updatedHeroes = List<String>.from(base.recentHeroIngredients);
    final hero = RecipeVariation.heroIngredient(_currentRecipe);
    if (hero != null && !_isUserRequiredPerishable(hero, base)) {
      updatedHeroes.add(hero);
      while (updatedHeroes.length > variationWindow) {
        updatedHeroes.removeAt(0);
      }
    }
    final updatedCookware = List<String>.from(base.recentCookware);
    final cookware = RecipeVariation.cookware(_currentRecipe);
    if (cookware != null) {
      updatedCookware.add(cookware);
      while (updatedCookware.length > variationWindow) {
        updatedCookware.removeAt(0);
      }
    }

    return RecipeGenerationRequest(
      perishables: base.perishables,
      alwaysHave: base.alwaysHave,
      almostAlwaysHave: base.almostAlwaysHave,
      dietaryRequirements: settings.hydrated
          ? settings.dietaryRequirements
          : base.dietaryRequirements,
      timePreference: base.timePreference,
      stylePreference: base.stylePreference,
      moodPreference: base.moodPreference,
      mealType: base.mealType,
      servings: base.servings,
      excludedIngredients: [
        ...base.excludedIngredients,
        ..._excludedIngredients,
      ],
      recentTitles: [
        ...base.recentTitles,
        _currentRecipe.title,
      ],
      recentHeroIngredients: updatedHeroes,
      recentCookware: updatedCookware,
      runningLowItems: base.runningLowItems,
      isLeftoverMode: base.isLeftoverMode,
      leftoverItems: base.leftoverItems,
      likedRecipes: base.likedRecipes,
      dislikedRecipes: base.dislikedRecipes,
      appliances: base.appliances,
      isSaverMode: base.isSaverMode,
      perishableInventoryDescriptions: base.perishableInventoryDescriptions,
      userRequest: base.userRequest,
      customAllergens:
          settings.hydrated ? settings.allergies : base.customAllergens,
    );
  }

  /// Mirrors HomeScreen's `_isUserRequiredPerishable` — keeps the hero
  /// FIFO clean of user-chosen required perishables (chicken every
  /// recipe because the user said "use up chicken" isn't model
  /// repetition, so shouldn't poison variety memory).
  bool _isUserRequiredPerishable(
      String hero, RecipeGenerationRequest request) {
    if (request.perishables.isEmpty) return false;
    final h = hero.toLowerCase().trim();
    if (h.isEmpty) return false;
    for (final p in request.perishables) {
      final pl = p.toLowerCase().trim();
      if (pl.isEmpty) continue;
      if (pl == h || pl.contains(h) || h.contains(pl)) return true;
    }
    return false;
  }

  late int _regenCount;
  final Set<String> _excludedIngredients = {};
  // Visual-only "ticked off" state for ingredient rows (Sprint 16).
  final Set<int> _checkedIngredientIndices = {};
  final FirestoreService _firestore = FirestoreService();
  final AnalyticsService _analytics = AnalyticsService.instance;

  // ── Pantry membership lookup (full inventory, normalised names) ──────────
  // Used by ElioPantryIcon to render green/red on each ingredient row.
  // Populated from a live Firestore subscription on the user's inventory
  // sub-collection (staples + perishables together).
  @visibleForTesting
  Set<String> normalizedInventoryNames = <String>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inventorySub;

  // ── Rating state ──────────────────────────────────────────────────────────────────────────────
  bool _isRating = false;

  // ── Voice control state ────────────────────────────────────────────────────────────────────────
  static const _audioChannel = MethodChannel('com.elio/audio');
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _voiceEnabled = false;
  bool _isListening = false;
  bool _isSpeaking = false; // TTS is mid-utterance — gates STT restart
  bool _speechAvailable = false;
  bool _voiceHelpShown = false;
  String _voiceFeedback = '';
  // 19 May 2026 (19may-c) — on-screen diagnostic strip for the Cook
  // Mode voice path. Rob's 19may-b feedback was "still not working"
  // and the Crashlytics `voice_stt_heard` non-fatal route depends on
  // dashboard access. The strip surfaces what the STT engine is
  // actually delivering, in one screenshot, so we can disambiguate
  // (a) mic / engine not running at all, (b) running but not
  // transcribing the user's voice, (c) transcribing fine but the
  // matcher isn't firing.
  String _lastHeardWords = '';
  // 21 May 2026 (19may-g) — separated from `_lastHeardWords` so the
  // diagnostic strip doesn't render "Last heard: 'STT error: …'"
  // (Kate's 19may-f screenshots). The error path now writes here;
  // the heard path writes to `_lastHeardWords`. Both can be shown,
  // visually distinct.
  String _lastSttError = '';
  // 20 May 2026 (20may-b) — last raw STT status event from the plugin
  // (e.g. 'listening', 'notListening', 'done'). Surfaced in the
  // diagnostic strip so we can see which terminal events the Android
  // engine on Kate's device actually fires. Different OEM
  // implementations send different status names; this lets us confirm
  // rather than guess.
  String _lastSttStatus = '';
  Timer? _feedbackTimer;
  Timer? _restartTimer;
  // 21 May 2026 (19may-g) — auto-clear the error display after a brief
  // delay so transient `error_speech_timeout` / `error_no_match` events
  // don't pile up in the strip and look like the engine is broken.
  Timer? _errorClearTimer;
  // 20 May 2026 (20may-b) — Rob: Android's green mic-in-use dot
  // disappears after ~4s and the auto-restart isn't firing. The
  // status-name-based restart only fires on `'done'`, but on Kate's
  // device the session-end may fire as `'notListening'` (engine
  // dependent — varies by OEM). The heartbeat sidesteps the status
  // name entirely: every 2s, if we think we should be listening
  // (`_voiceEnabled && !_isSpeaking`) but the plugin says we aren't
  // (`!_speech.isListening`), restart. Belt-and-braces against any
  // engine that doesn't fire the status we expect.
  Timer? _heartbeatTimer;

  // ── Cooking timer state (Sprint 16.6) ─────────────────────────────────────
  /// Multi-timer service driving the sticky timer bar + inline pill taps.
  /// Wall-clock end-times so backgrounding the app doesn't lose accuracy.
  /// The ticker is started in initState and stopped in dispose. Expiry
  /// fires HapticFeedback + SystemSound via [_onTimerExpired].
  late final CookingTimerService _timerService;

  // ── Cost estimate label ────────────────────────────────────────────────────────────────────────────────────────────────
  /// Returns a formatted cost-per-serving string based on device locale.
  /// Delegates to RegionUtils.formatCost() for locale-aware currency selection.
  String? get _costLabel => RegionUtils.formatCost(
    usd: _currentRecipe.estimatedCostPerServingUSD,
    gbp: _currentRecipe.estimatedCostPerServingGBP,
    suffix: '/serving',
  );

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.servings;
    _currentRecipe = widget.recipe;
    _savedAt = widget.savedAt;
    _regenCount = widget.regenCount;
    // Sprint 16.6: cooking timer. Start the 1-second ticker so chips
    // visibly count down. Backgrounded delivery (sound when app is in
    // the background) is a follow-up via flutter_local_notifications;
    // v1 fires HapticFeedback + SystemSound while app is foreground.
    _timerService = CookingTimerService(onExpire: _onTimerExpired)
      ..startTicker()
      ..addListener(_onTimerStateChange);
    _initTts();
    _subscribeInventory();
    if (_savedAt != null) {
      // Opened from history OR pre-saved by Import/Generate flow —
      // either way it's in history, so it's "saved". Check bookmark
      // state for the toggle indicator.
      _isSaved = true;
      _checkBookmarkStatus();
    }
  }

  Future<void> _checkBookmarkStatus() async {
    final bookmarked = await HistoryService.isBookmarked(_savedAt!);
    if (mounted) setState(() => _isSaved = bookmarked);
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    _stopListening();
    _feedbackTimer?.cancel();
    _restartTimer?.cancel();
    _errorClearTimer?.cancel();
    _heartbeatTimer?.cancel();
    _tts.stop();
    // Always restore audio in case voice was active
    try { _audioChannel.invokeMethod('restoreBeep'); } catch (_) {}
    // Sprint 16.6: cooking timer teardown.
    _timerService.removeListener(_onTimerStateChange);
    _timerService.dispose();
    // Drop the wakelock unconditionally on screen leave — don't want
    // it leaking past navigation away from the recipe.
    if (_wakelockHeld) {
      WakelockPlus.disable().catchError((_) {});
      _wakelockHeld = false;
    }
    super.dispose();
  }

  // ── Cooking timer handlers (Sprint 16.6) ─────────────────────────────────

  /// Tracks whether wakelock is currently enabled so we only toggle it
  /// on real edges (active ↔ inactive) — not on every chip countdown
  /// tick. WakelockPlus.enable()/disable() do platform-channel work.
  bool _wakelockHeld = false;

  void _onTimerStateChange() {
    if (!mounted) return;
    setState(() {});

    // Sprint 16.6: hold the wakelock while at least one timer is
    // running or paused. Drop it the moment everything is done /
    // cancelled / dismissed. Edge-triggered so we don't re-call the
    // platform channel on every 1-second tick.
    //
    // 21 May 2026 — 21may-a tried OR-combining `_handsFreeMode ||
    // _timerService.hasActiveTimers` so the wakelock would also be
    // held for the duration of Cook Mode. That shipped a white-
    // screen-on-Cook-Mode-entry regression that we couldn't root-
    // cause inline. Reverted to the original timer-only logic
    // pending a safer approach. The Cook-Mode-screen-timeout fix is
    // re-queued as a Sprint 17 row.
    final shouldHold = _timerService.hasActiveTimers;
    if (shouldHold == _wakelockHeld) return;
    _wakelockHeld = shouldHold;
    // Fire-and-forget; errors are non-fatal (e.g. unsupported
    // platform during tests).
    if (shouldHold) {
      WakelockPlus.enable().catchError((_) {});
    } else {
      WakelockPlus.disable().catchError((_) {});
    }
  }

  /// Fires when any timer hits zero. Audible signal via TTS (Android's
  /// SystemSound.alert is a no-op), haptic buzz, plus a contextual
  /// snackbar. Backgrounded delivery via local notifications is a
  /// follow-up (flutter_local_notifications).
  ///
  /// Sprint 16.6.x: swapped SystemSound.play(SystemSoundType.alert)
  /// for `_speakText(...)`. SystemSound.alert is documented as iOS/
  /// macOS-only and is silent on Android, so the timer was firing
  /// only haptic with no audio cue. TTS reuses the existing flutter_tts
  /// dep wired up for voice cooking — no new packages. flutter_tts
  /// queues internally, so a timer expiring mid-step during hands-free
  /// mode is read after the current utterance.
  void _onTimerExpired(CookingTimer timer) {
    HapticFeedback.heavyImpact();
    _speakText('${timer.label} timer done');
    if (!mounted) return;
    // Sprint 16.7c — withTimer enforces the 6s dismiss even when
    // accessibleNavigation is true (Flutter would otherwise suppress
    // its own timer because of the OK action).
    ScaffoldMessenger.of(context).showSnackBarWithTimer(
      SnackBar(
        content: Text('${timer.label} timer done'),
        backgroundColor: ElioColors.terracotta,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => _timerService.dismiss(timer.id),
        ),
      ),
    );
  }

  /// Tap on an inline time pill in a method step. Opens the duration
  /// picker pre-filled with the detected duration; starts a timer
  /// labelled by step number.
  Future<void> _onMethodTimeTap(int stepIndex, TimeMatch match) async {
    // showModalBottomSheet fails silently inside immersiveSticky
    // (CLAUDE.md Flutter gotcha), so when Cook Mode is active we
    // briefly drop back to edge-to-edge while the picker is open.
    final wasImmersive = _handsFreeMode;
    if (wasImmersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    final picked = await ElioDurationPickerSheet.show(
      context,
      initialDuration: match.duration,
      contextLabel:
          'Step ${stepIndex + 1} · we detected ${match.matchedText} '
          'in the instruction',
    );
    if (wasImmersive && mounted && _handsFreeMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (picked == null || !mounted) return;
    try {
      _timerService.start(
        label: 'Step ${stepIndex + 1}',
        duration: picked,
      );
    } on StateError catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You have the maximum number of timers running. Cancel one to start another.',
          ),
        ),
      );
    }
  }

  /// Tap on a timer chip → toggle pause / resume / dismiss (done).
  void _onTimerChipTap(CookingTimer t) {
    switch (t.status) {
      case TimerStatus.running:
        _timerService.pause(t.id);
        break;
      case TimerStatus.paused:
        _timerService.resume(t.id);
        break;
      case TimerStatus.done:
        _timerService.dismiss(t.id);
        break;
    }
  }

  /// Long-press → cancel with confirm.
  Future<void> _onTimerChipLongPress(CookingTimer t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.cream,
        title: const Text('Cancel timer?'),
        content: Text('Stop the "${t.label}" timer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancel timer',
              style: TextStyle(color: ElioColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) _timerService.cancel(t.id);
  }

  /// Sticky timer bar rendered just under the AppBar. Only visible
  /// when at least one timer exists.
  ///
  /// Sprint 16.7d: horizontal scroll instead of Wrap. With the cap
  /// raised from 5 → 10, a Sunday-roast chip stack could push the
  /// timer bar to two rows and steal vertical space from the step.
  /// Single-row scroll keeps the bar a consistent height regardless
  /// of timer count.
  Widget _buildTimerBar() {
    final timers = _timerService.timers;
    if (timers.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ElioColors.cream.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: ElioColors.rule),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 4),
              child: Text(
                'TIMERS',
                style: ElioTextStyles.eyebrowStyle.copyWith(
                  color: ElioColors.mocha,
                ),
              ),
            ),
            for (final t in timers) ...[
              ElioTimerChip(
                key: ValueKey(t.id),
                timer: t,
                now: now,
                onTap: () => _onTimerChipTap(t),
                onLongPress: () => _onTimerChipLongPress(t),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  // ── Inventory subscription ───────────────────────────────────────────────
  // Streams the user's full pantry (staples + perishables) so ingredient
  // rows can show a green pantry icon when matched and red when missing.
  // Uses exact normalised-name match (PantryUtils.normalise) — fuzzy
  // matching is reserved for add-item dedup per CLAUDE.md.
  void _subscribeInventory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('inventory');
    _inventorySub = query.snapshots().listen((snap) {
      if (!mounted) return;
      final names = <String>{};
      for (final doc in snap.docs) {
        final name = (doc.data()['name'] as String?) ?? '';
        if (name.isEmpty) continue;
        names.add(PantryUtils.normalise(name));
      }
      setState(() => normalizedInventoryNames = names);
    });
  }

  /// Whether the recipe ingredient is already in the user's live pantry.
  ///
  /// Sprint 16.6 (Notion XX bug 2): the raw recipe name carries prep
  /// words ("Diced onion", "Large eggs", "Chopped garlic, peeled") and
  /// size adjectives that the pantry doesn't. Comparing raw names misses
  /// the match — the green/red pantry indicator showed red AND the
  /// "Add to shopping list" path skipped its dedup branch, re-adding
  /// items the user already had.
  ///
  /// Cleaning via [ShoppingService.cleanForShopping] strips comma
  /// clauses with prep words, parentheticals with prep words, and
  /// leading size adjectives. Then [PantryUtils.normalise] handles
  /// plurals + variant synonyms. Cleaning is idempotent on already-
  /// clean pantry-style names (no-op for "Onion").
  bool _isInPantry(RecipeIngredient ing) {
    final cleaned = ShoppingService.cleanForShopping(ing.name);
    final norm = PantryUtils.normalise(cleaned);
    return normalizedInventoryNames.contains(norm);
  }

  // ── TTS setup ──────────────────────────────────────────────────────────────────
  //
  // Sprint 16 cook-mode audit (19 May 2026) fixed three classes of bug here:
  //
  //   1. **First-word clipping** — flutter_tts grabs the audio session
  //      lazily on the first `speak()`, which swallows ~300 ms on iOS.
  //      `setSharedInstance(true)` + `setIosAudioCategory(playback, ...)`
  //      pre-allocates the session, so utterances start cleanly.
  //
  //   2. **TTS / STT collisions mid-utterance** — the STT listener was
  //      running while TTS spoke, ducking the speech output. We now
  //      serialise: `_speakText` stops listening, marks `_isSpeaking`,
  //      and only the completion handler restarts the listener (and
  //      only if voice control is still enabled).
  //
  //   3. **TTS never fires on step entry / Next/Back** — the screen used
  //      to call `_speakText` only from voice-command callbacks, so
  //      tapping Next never read the new step aloud. The Cook-Mode
  //      entry point (`_startHandsFree`) and the Next/Back buttons now
  //      call `_speakText` directly, independent of mic state.
  Future<void> _initTts() async {
    try {
      // iOS audio session — silently no-op on Android.
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );

      // `awaitSpeakCompletion(true)` makes the future returned by
      // `_tts.speak(...)` resolve only when the utterance finishes —
      // we use that to bracket the STT pause/resume reliably.
      await _tts.awaitSpeakCompletion(true);

      // Lifecycle handlers — `_isSpeaking` is the gate that prevents
      // the STT auto-restart loop from clawing the mic back while we
      // talk. The completion handler restarts listening once we're done.
      _tts.setStartHandler(() {
        if (mounted) setState(() => _isSpeaking = true);
      });
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
        // Resume listening if voice control is still on. Small delay
        // gives the audio session time to release before STT re-acquires.
        if (_voiceEnabled && mounted) {
          _restartTimer?.cancel();
          _restartTimer = Timer(const Duration(milliseconds: 200), () {
            if (_voiceEnabled && mounted && !_isSpeaking) _startListening();
          });
        }
      });
      _tts.setErrorHandler((msg) {
        if (mounted) setState(() => _isSpeaking = false);
        ErrorService.log('voice_tts_runtime', msg);
      });

      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
    } catch (e) {
      ErrorService.log('voice_tts_init', e);
    }
  }

  Future<void> _speakText(String text) async {
    if (text.trim().isEmpty) return;
    try {
      // Stop listening BEFORE we speak so the mic doesn't duck our own
      // output (and so we don't recognise our own voice as a command).
      // The completion handler in `_initTts` re-arms the listener.
      if (_isListening) {
        _restartTimer?.cancel();
        await _speech.stop();
        if (mounted) setState(() => _isListening = false);
      }
      // Cancel any in-flight utterance — prevents queuing two steps if
      // the user mashes Next. The completion handler may or may not fire
      // for a cancelled utterance (engine-dependent on Android), so we
      // also defensively reset `_isSpeaking` here. Otherwise a stuck
      // `true` would block the STT auto-restart loop forever.
      await _tts.stop();
      if (mounted && _isSpeaking) {
        setState(() => _isSpeaking = false);
      }
      await _tts.speak(text);
      // `awaitSpeakCompletion(true)` means the future resolves only when
      // the utterance ends, so by the time we get here the user has
      // heard the whole step. Belt-and-braces: also clear `_isSpeaking`
      // here in case the completion handler missed (race between the
      // platform fire and our setState bind).
      if (mounted && _isSpeaking) {
        setState(() => _isSpeaking = false);
      }
      // Belt-and-braces: also kick the listener restart here. The
      // completion handler should have done this on its own, but if it
      // didn't fire (cancelled utterance, engine quirk) the user would
      // be stuck — TTS done but mic never resumed. Idempotent against
      // the handler's own restart attempt thanks to the
      // `if (_voiceEnabled && !_isSpeaking && !_isListening)` gate
      // inside `_startListening`.
      if (mounted && _voiceEnabled && !_isListening) {
        _restartTimer?.cancel();
        _restartTimer = Timer(const Duration(milliseconds: 200), () {
          if (_voiceEnabled && mounted && !_isSpeaking && !_isListening) {
            _startListening();
          }
        });
      }
    } catch (e) {
      if (mounted && _isSpeaking) {
        setState(() => _isSpeaking = false);
      }
      ErrorService.log('voice_tts_speak', e);
    }
  }

  // ── Speech recognition ─────────────────────────────────────────────────────────

  /// Map raw Android STT error codes to human-readable diagnostic
  /// text. `error_speech_timeout` and `error_no_match` are the two
  /// most common transient ones and we surface them in soft language
  /// so users don't think the engine is broken.
  String _friendlySttError(String code) {
    switch (code) {
      case 'error_speech_timeout':
        return 'Didn\'t hear anything — try saying it again.';
      case 'error_no_match':
        return 'Didn\'t catch that — try saying it again.';
      case 'error_network':
        return 'Speech recognition needs a network connection.';
      case 'error_network_timeout':
        return 'Network timed out — check connection.';
      case 'error_audio':
        return 'Audio error — check the microphone.';
      case 'error_server':
        return 'Speech-recognition server error — try again.';
      case 'error_client':
        return 'Speech-recognition client error — try again.';
      case 'error_insufficient_permissions':
        return 'Microphone permission missing.';
      default:
        return 'STT: $code';
    }
  }

  /// Explicit RECORD_AUDIO permission check + recovery flow. Returns
  /// the resolved state. Side-effects: surfaces the right UI for
  /// denied / permanently-denied cases (snackbar with retry, snackbar
  /// with "Open Settings" action), and writes a diagnostic string to
  /// the on-screen `_lastHeardWords` strip so a screenshot from the
  /// user tells us the exact permission state without needing
  /// Crashlytics access.
  Future<_MicPermissionResult> _ensureMicPermission() async {
    var status = await Permission.microphone.status;

    // First-time / previously-denied — request now. On Android 13+
    // this is the only way to surface the system prompt; the
    // implicit request inside `_speech.initialize()` is often a no-op
    // if the user previously dismissed it.
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    if (status.isGranted || status.isLimited) {
      return _MicPermissionResult.granted;
    }

    if (status.isPermanentlyDenied) {
      ErrorService.log('voice_mic_perm', 'permanentlyDenied');
      if (mounted) {
        setState(() => _lastHeardWords =
            'Mic permission permanently denied — tap "Open Settings"');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Microphone permission is permanently denied. Open Settings to enable it.',
            ),
            backgroundColor: ElioColors.espresso,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Open Settings',
              textColor: Colors.white,
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
      }
      return _MicPermissionResult.permanentlyDenied;
    }

    // status.isDenied / .isRestricted — surface the reason and let the
    // user retry. Diagnostic strip carries the state so we can see it
    // in screenshots.
    ErrorService.log('voice_mic_perm', status.toString());
    if (mounted) {
      setState(() => _lastHeardWords =
          'Mic permission denied (${status.toString().split('.').last}) — tap mic to retry');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Voice control needs microphone permission. Tap the mic again to retry.",
          ),
          backgroundColor: ElioColors.espresso,
          duration: Duration(seconds: 4),
        ),
      );
    }
    return _MicPermissionResult.denied;
  }

  /// Bulletproof "are we still actually listening?" check.
  ///
  /// Status-name-based restarts (`'done'`) only catch session-ends on
  /// engines that fire that specific event. On Kate's 20may-a test the
  /// Android mic-in-use dot disappeared after ~4s and the auto-restart
  /// didn't fire — almost certainly because her engine sends
  /// `'notListening'` (or similar) as terminal. Different OEM
  /// implementations send different status names.
  ///
  /// The heartbeat sidesteps the issue entirely by asking the plugin
  /// directly. Every 2s while voice is enabled, if `_speech.isListening`
  /// is false but we expected it to be true, restart.
  void _startVoiceHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      if (!_voiceEnabled) return;
      if (_isSpeaking) return; // TTS owns the session right now
      // 20 May 2026 (20may-d) — skip if a restart is already
      // scheduled. The status handler (on 'done') and the error
      // handler both queue `_restartTimer` with sensible backoffs
      // (400ms / 800ms / 1000ms depending on cause); having the
      // heartbeat fire a SECOND restart on top of that means we
      // hammer the engine and provoke `error_busy`. Defer to whoever
      // queued first.
      if (_restartTimer?.isActive ?? false) return;
      if (!_speech.isListening) {
        // 20 May 2026 (20may-c) — reset the local flag too so the
        // diagnostic strip's top line stops claiming "Listening"
        // when the engine has actually ended the session. The plugin
        // is the source of truth; this catches up our mirror.
        if (_isListening) {
          setState(() => _isListening = false);
        }
        // Plugin says we're not listening, no other restart is
        // pending. Kick one.
        _startListening();
      }
    });
  }

  void _stopVoiceHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _initVoiceControl() async {
    // 19 May 2026 (19may-d) — Rob: "tapping the mic doesn't pause TTS".
    // Pre-19may-a TTS only fired AFTER mic was enabled, so this couldn't
    // happen. Now TTS auto-plays on Cook Mode entry, so the user can
    // (and does) tap mic mid-utterance to talk over the directions —
    // that's the voice-assistant convention (Siri / Alexa / Google all
    // cancel their response when interrupted). Cancel any in-progress
    // speech up-front so the listener can take the audio session.
    try {
      await _tts.stop();
    } catch (_) {}
    if (mounted && _isSpeaking) {
      setState(() => _isSpeaking = false);
    }

    // 20 May 2026 (19may-e) — explicit RECORD_AUDIO permission check
    // BEFORE `_speech.initialize()`. Kate's 19may-d failure mode:
    // diagnostic strip says "Listening" but no "Last heard:" populates
    // when she talks → engine is "running" but not actually
    // transcribing. `speech_to_text.initialize()` requests permission
    // implicitly on init AND returns true if Speech-to-Text is
    // available at all, even if RECORD_AUDIO is denied. On Android
    // 13+ the permission request can be silently auto-denied (system
    // setting / previous "Don't allow"), and the engine then runs
    // visually but captures no audio.
    //
    // Explicit `permission_handler` check gives us three resolvable
    // states: granted (proceed), denied (request + retry), or
    // permanentlyDenied (route to app settings). The diagnostic strip
    // surfaces the denial reason so a screenshot tells us the exact
    // permission state.
    final permStatus = await _ensureMicPermission();
    if (permStatus != _MicPermissionResult.granted) {
      return; // _ensureMicPermission already surfaced the right UI
    }

    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          // 21 May 2026 (19may-g) — Kate's 19may-f screenshots showed
          // `error_speech_timeout` and `error_no_match` rendering as
          // "Last heard: 'STT error: …'" which made it look like the
          // engine was completely broken. They're actually expected
          // transient events:
          //   - `error_speech_timeout`: engine listened, heard no
          //     speech within the pauseFor window. Restart immediately.
          //   - `error_no_match`: engine heard audio but couldn't
          //     transcribe it. Restart immediately; user can try again.
          //   - Other errors: still worth surfacing, restart with a
          //     small backoff.
          // The error now writes to `_lastSttError` (separate from
          // `_lastHeardWords`) so the strip can show both states
          // distinctly + auto-clear the error after a short delay so
          // the user isn't permanently staring at "STT error".
          // 20 May 2026 (20may-d) — three buckets, not two. Rob's
          // 20may-c screenshots showed the engine cycling through
          // `error_busy` and `error_client` after we restarted too
          // fast — Android STT was rejecting our 100ms restart
          // because the previous session hadn't finished releasing.
          //
          //   - **Transient** (50ms retry): `error_speech_timeout`,
          //     `error_no_match`. These aren't really errors — engine
          //     just didn't hear / couldn't match. Safe to restart
          //     immediately.
          //   - **Busy** (1000ms retry): `error_busy`,
          //     `error_recognizer_busy`. Engine is literally telling
          //     us "I'm not ready yet — back off." Hammering it with
          //     a fast retry just gets another busy error.
          //   - **Hard** (800ms retry): anything else
          //     (`error_client`, `error_network`, `error_audio`, …).
          //     Real failure, give the system a beat to recover.
          final code = error.errorMsg;
          final isTransient =
              code == 'error_speech_timeout' || code == 'error_no_match';
          final isBusy =
              code == 'error_busy' || code == 'error_recognizer_busy';
          final restartDelayMs = isTransient
              ? 50
              : isBusy
                  ? 1000
                  : 800;
          if (mounted) {
            setState(() => _lastSttError = code);
            _errorClearTimer?.cancel();
            _errorClearTimer = Timer(
              Duration(seconds: isTransient ? 2 : 5),
              () {
                if (mounted) setState(() => _lastSttError = '');
              },
            );
          }
          ErrorService.log('voice_stt_error', code);
          // On error, attempt restart if voice is still enabled — but
          // not mid-utterance (TTS completion handler owns that).
          if (_voiceEnabled && mounted && !_isSpeaking) {
            _restartTimer?.cancel();
            _restartTimer = Timer(
              Duration(milliseconds: restartDelayMs),
              () {
                if (_voiceEnabled && mounted && !_isSpeaking) {
                  _startListening();
                }
              },
            );
          }
        },
        onStatus: (status) {
          // 20 May 2026 (20may-b) — surface the raw status name to the
          // strip + log to Crashlytics. Different Android engines send
          // different terminal status names ('done' on Pixel, often
          // 'notListening' on Samsung), and the status-name-based
          // restart was missing whichever name Kate's device uses.
          // The heartbeat (below) catches the gap regardless, but the
          // visibility helps confirm the cause.
          if (mounted) {
            setState(() => _lastSttStatus = status);
          }
          ErrorService.log('voice_stt_status', status);
          // 19 May 2026 (19may-d) — ONLY restart on `done` (terminal
          // session state). The previous code also restarted on
          // `notListening`, but on Android `notListening` fires
          // *transiently* between captures inside a single session
          // (during silence-detection processing). Restarting on that
          // killed the in-progress recognition before any words were
          // returned — which is the most likely reason voice commands
          // appeared to never work at all. Trust the engine to manage
          // its own in-session state; only restart when the session
          // truly ends.
          //
          // 20 May 2026 (20may-a) — tightened the restart delay from
          // 300ms to 100ms. The 300ms was a guard against rapid-fire
          // platform errors but in practice 100ms is fine and shortens
          // the perceptible gap between sessions to near-zero, which
          // is what makes "always listening" actually feel always-on.
          //
          // 20 May 2026 (20may-b) — the status-name restart stays as
          // the fast path, but the heartbeat is now the bulletproof
          // safety net for engines that fire something other than
          // 'done'.
          //
          // 20 May 2026 (20may-c) — CRITICAL: reset our `_isListening`
          // flag here. The engine ended the session, the plugin's
          // `isListening` is false, but we never cleared our own
          // tracking flag — which meant `_startListening`'s
          // `if (_isListening) return;` early-return blocked every
          // subsequent restart attempt (both this one AND the
          // heartbeat). Rob's 20may-b screenshot: "STT status: done"
          // visible on the strip, top line still says "Listening",
          // and the green mic-dot is gone. The flag was stale.
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
            }
          }
          if (status == 'done') {
            if (_voiceEnabled && mounted && !_isSpeaking) {
              _restartTimer?.cancel();
              // 20 May 2026 (20may-d) — bumped from 100ms to 400ms.
              // 100ms was firing the restart before the engine had
              // finished releasing the previous session, which
              // triggered `error_busy` ("recognizer is already in
              // use") on Rob's device. 400ms gives Android STT room
              // to clean up. Still imperceptible to the user vs.
              // the 8s `pauseFor` window.
              _restartTimer = Timer(const Duration(milliseconds: 400), () {
                if (_voiceEnabled && mounted && !_isSpeaking) {
                  _startListening();
                }
              });
            }
          }
        },
      );

      if (!_speechAvailable && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice control unavailable — microphone permission was denied. Grant it in Settings → Apps → Elio → Permissions.'),
            backgroundColor: ElioColors.espresso,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      if (mounted) {
        setState(() => _voiceEnabled = true);
        // Mute beep streams for entire voice session
        try { await _audioChannel.invokeMethod('muteBeep'); } catch (_) {}
        // Start the heartbeat — restarts the listener if the engine
        // silently ends a session without firing a status name we
        // handle. See `_startVoiceHeartbeat` for the rationale.
        _startVoiceHeartbeat();
        if (!_voiceHelpShown) {
          // Show help first — listening starts after "Got It"
          _showVoiceHelpOverlay();
          _voiceHelpShown = true;
        } else {
          // 19 May 2026 (19may-d): just start listening. The previous
          // path called `_speakText(currentStep)` here, which re-spoke
          // the step every time the user toggled the mic on — annoying,
          // and on Cook Mode entry the step has already been read once.
          // Worse, before the muteBeep fix in MainActivity.kt this also
          // played silently because STREAM_MUSIC had just been zeroed.
          _startListening();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice control unavailable — check microphone permissions.'),
            backgroundColor: ElioColors.espresso,
          ),
        );
      }
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable || !_voiceEnabled || !mounted) return;
    // Don't claw the mic back while TTS is mid-utterance — the
    // completion handler will re-arm us. Without this guard the STT
    // auto-restart loop fights the speech output for the audio session.
    if (_isSpeaking) return;
    // Don't redundantly start a session that's already running. Both
    // the completion handler AND the belt-and-braces tail of
    // `_speakText` schedule a 200ms restart; without this guard they'd
    // both fire and the second `_speech.listen(...)` would throw.
    //
    // 20 May 2026 (20may-c) — trust the plugin's `isListening` getter
    // (source of truth) instead of our local `_isListening` flag.
    // The flag was getting stuck `true` after engine-side session-ends
    // that didn't reset it, which blocked every restart attempt — see
    // the onStatus handler comment for the full story. Asking the
    // plugin directly removes that whole class of state-drift bug.
    if (_speech.isListening) return;
    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.toLowerCase();
          if (result.finalResult && words.isNotEmpty) {
            ErrorService.log('voice_stt_heard', 'words="$words"');
          }
          if (words.isNotEmpty && mounted) {
            setState(() {
              _lastHeardWords = words;
              // 19may-g — clear any stale error once we get a real
              // recognition; otherwise the dimmer error line lingers
              // alongside the new "Last heard:" line.
              _lastSttError = '';
            });
            _errorClearTimer?.cancel();
          }
          _processVoiceCommand(words);
        },
        // 20 May 2026 (20may-a) — Rob: "I struggle to see how hands-
        // free is effective if it has any time limit." Pushed the
        // session cap to a wall-clock value bigger than any realistic
        // Cook Mode session. Android's `SpeechRecognizer` will end
        // sessions on its own well before this (typically 30–60s
        // depending on the device), and the auto-restart on `done`
        // (200ms below) takes over — so this just stops US from
        // imposing a redundant ceiling on top of the platform's.
        //
        // `pauseFor: 8s` (from 19may-g) — forgiving silence window
        // after TTS finishes describing a step. The user often takes
        // a beat to process before speaking; pre-`pauseFor: 4s` ran
        // out in that gap and fired `error_speech_timeout`.
        //
        // Note (battery): continuous STT listening is power-hungry.
        // For Cook Mode that's the right trade — the user has
        // explicitly turned it on and is mid-recipe. If we ever
        // surface "always-on" voice outside Cook Mode, revisit.
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 8),
        listenOptions: stt.SpeechListenOptions(
          // 19may-d — explicit `partialResults: true` (defaults to true
          // but be explicit). `ListenMode.dictation` was iOS-only per
          // the plugin docs — dropped, it did nothing on Android and
          // misled the reader into thinking we'd configured the engine
          // for long-form on Android. `cancelOnError: false` so a
          // transient error doesn't kill the whole session (the
          // onError handler restarts manually instead).
          partialResults: true,
          cancelOnError: false,
        ),
      );
      if (mounted) setState(() => _isListening = true);
    } catch (e) {
      ErrorService.log('voice_start_listening', e);
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _stopListening() async {
    _restartTimer?.cancel();
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) setState(() => _isListening = false);
  }

  void _toggleVoiceControl() {
    if (_voiceEnabled) {
      _stopListening();
      _stopVoiceHeartbeat();
      setState(() => _voiceEnabled = false);
      // Restore audio streams when voice control is turned off
      try { _audioChannel.invokeMethod('restoreBeep'); } catch (_) {}
    } else {
      _initVoiceControl();
    }
  }

  void _processVoiceCommand(String words) {
    // Sprint 16 cook-mode audit (19 May 2026): we used to require the
    // literal substring "hey elio" before any command would fire, which
    // never worked reliably — `speech_to_text` doesn't keep partials
    // across a 5s silence and there's no real wake-word engine bundled.
    //
    // Option (b) from the audit: drop the wake-word fiction. While
    // Cook Mode is open the user has unambiguously asked for voice
    // control, so we accept bare commands ("next", "back", "repeat",
    // "done"). TTS↔STT is now serialised, so we don't recognise our
    // own utterance — the only words in the buffer come from the user.
    //
    // Word-boundary matching so we don't fire on substrings inside
    // longer words (e.g. "context" → not "next"). Also short-circuit
    // when speaking, in case a stale partial sneaks through.
    if (_isSpeaking) return;
    if (words.isEmpty) return;

    bool hasWord(String w) => RegExp(r'\b' + w + r'\b').hasMatch(words);

    if (hasWord('next')) {
      _onVoiceNext();
    } else if (hasWord('back') || hasWord('previous')) {
      _onVoiceBack();
    } else if (hasWord('repeat') || hasWord('read')) {
      _onVoiceRepeat();
    } else if (hasWord('done') || hasWord('exit') || hasWord('stop')) {
      _onVoiceDone();
    }
  }

  void _showVoiceFeedback(String message) {
    _feedbackTimer?.cancel();
    setState(() => _voiceFeedback = message);
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _voiceFeedback = '');
    });
  }

  void _onVoiceNext() {
    if (_currentStep < _currentRecipe.steps.length - 1) {
      setState(() => _currentStep++);
      _showVoiceFeedback('Got it — next step');
      _speakText(_currentRecipe.steps[_currentStep]);
    } else {
      _showVoiceFeedback('Already on the last step');
    }
  }

  void _onVoiceBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _showVoiceFeedback('Got it — previous step');
      _speakText(_currentRecipe.steps[_currentStep]);
    } else {
      _showVoiceFeedback('Already on the first step');
    }
  }

  void _onVoiceRepeat() {
    _showVoiceFeedback('Reading step aloud');
    _speakText(_currentRecipe.steps[_currentStep]);
  }

  void _onVoiceDone() {
    _showVoiceFeedback('Voice control off');
    _stopListening();
    _stopVoiceHeartbeat();
    setState(() {
      _voiceEnabled = false;
    });
    // Restore audio streams
    try { _audioChannel.invokeMethod('restoreBeep'); } catch (_) {}
    _analytics.logEvent('voice_control_stopped', {
      'step_reached': _currentStep + 1,
      'total_steps': _currentRecipe.steps.length,
      'exit_method': 'voice',
    });
  }

  void _showVoiceHelpOverlay() {
    // Use showDialog instead of showModalBottomSheet — bottom sheets
    // fail silently inside hands-free / immersive mode.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic_rounded, color: ElioColors.terracotta, size: 36),
              const SizedBox(height: 12),
              Text('Voice commands', style: ElioText.headingMedium),
              const SizedBox(height: 16),
              Text(
                'Just say:',
                style: ElioText.bodyLarge.copyWith(color: ElioColors.mocha),
              ),
              const SizedBox(height: 16),
              _buildVoiceHelpRow('"Next"', 'Go to the next step'),
              const SizedBox(height: 10),
              _buildVoiceHelpRow('"Back"', 'Go to the previous step'),
              const SizedBox(height: 10),
              _buildVoiceHelpRow('"Repeat"', 'Read the current step aloud'),
              const SizedBox(height: 10),
              _buildVoiceHelpRow('"Done"', 'Turn off voice control'),
              const SizedBox(height: 20),
              Text(
                'Tap the mic button to turn voice control on/off',
                style: ElioText.bodyMedium.copyWith(
                  color: ElioColors.mocha,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // 19 May 2026 (19may-d): just start listening. The
                    // step has already been spoken on Cook Mode entry
                    // (and was being re-spoken silently here pre-19may-d
                    // because STREAM_MUSIC had been muted by the
                    // `muteBeep` call in `_initVoiceControl`).
                    _startListening();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ElioColors.terracotta,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceHelpRow(String command, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ElioColors.espresso.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            command,
            style: ElioText.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: ElioColors.espresso,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
          ),
        ),
      ],
    );
  }

  double get _scaleFactor => _servings / widget.recipe.servings;

  void _toggleExclude(String ingredientName) {
    setState(() {
      if (_excludedIngredients.contains(ingredientName)) {
        _excludedIngredients.remove(ingredientName);
      } else {
        _excludedIngredients.add(ingredientName);
      }
    });
  }

  void _showIngredientOptions(RecipeIngredient ingredient) {
    // If already excluded, just re-include on tap
    if (_excludedIngredients.contains(ingredient.name)) {
      _toggleExclude(ingredient.name);
      return;
    }

    _analytics.logEvent('ingredient_options_opened', {
      'ingredient': ingredient.name,
      'from_inventory': ingredient.fromInventory,
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _IngredientOptionsSheet(
        ingredient: ingredient,
        recipe: _currentRecipe,
        originalRequest: widget.originalRequest,
        isGuest: widget.isGuest,
        scaleFactor: _scaleFactor,
        onSubstituted: (result) {
          // In-place swap: replace ingredient with substitute
          final newIngredients = _currentRecipe.ingredients.map((i) {
            if (i.name == ingredient.name) {
              return RecipeIngredient(
                name: result.substitute,
                quantity: result.adjustedQuantity,
                unit: result.unit,
                fromInventory: false,
              );
            }
            return i;
          }).toList();

          final newSubs = [
            ..._currentRecipe.substitutions,
            RecipeSubstitution(
              original: ingredient.name,
              substitute: result.substitute,
              tradeOff: result.tradeOff,
            ),
          ];

          setState(() {
            _currentRecipe = _currentRecipe.copyWith(
              ingredients: newIngredients,
              substitutions: newSubs,
            );
          });

          // The sheet pops itself before calling this callback (see
          // _IngredientOptionsSheet "Use this instead" button). The
          // dismiss animation runs ~300ms; firing showSnackBar inside
          // that window would render the floating snackbar behind the
          // still-animating sheet. Defer until the sheet is gone.
          // Same pattern documented in CLAUDE.md for showDialog after
          // a bottom-sheet pop.
          final messenger = ScaffoldMessenger.of(context);
          Future.delayed(const Duration(milliseconds: 350), () {
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(
                content:
                    Text('Swapped ${ingredient.name} → ${result.substitute}'),
                backgroundColor: ElioColors.espresso,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 3),
              ),
            );
          });
          _analytics.logEvent('ingredient_substituted', {
            'original': ingredient.name,
            'substitute': result.substitute,
          });
        },
        onExcludeAndRegenerate: () {
          _toggleExclude(ingredient.name);
          _generateAnother();
        },
        onAddToShoppingList: () {
          _addSingleToShoppingList(ingredient);
        },
      ),
    );
  }

  Future<void> _addSingleToShoppingList(RecipeIngredient ingredient) async {
    if (_isShoppingExclusion(ingredient.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${ingredient.name} — you probably already have this!"),
          backgroundColor: ElioColors.espresso,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    if (widget.isGuest) {
      // Sprint 16.1: explicit duration + hide-current so the toast
      // doesn't follow the user across navigation.
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Sign in to use the shopping list'),
          backgroundColor: ElioColors.espresso,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    try {
      final cleanName = ShoppingService.cleanForShopping(ingredient.name);
      final qty = ingredient.unit.isEmpty
          ? _scaleQuantity(ingredient.quantity)
          : '${_scaleQuantity(ingredient.quantity)} ${QuantityUtils.normalizeUnit(ingredient.unit)}';
      await ShoppingService.instance.addItem(
        name: cleanName,
        quantity: qty,
        source: ShoppingSource.recipe,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$cleanName added to shopping list'),
            backgroundColor: ElioColors.espresso,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        _analytics.logEvent('ingredient_added_to_shopping', {
          'ingredient': ingredient.name,
          'recipe': _currentRecipe.title,
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not add to shopping list'),
            backgroundColor: ElioColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _generateAnother() async {
    if (_isRegenerating) return;
    final request = widget.originalRequest;
    if (request == null) {
      // No original request context — just pop back to home screen
      if (mounted) Navigator.of(context).pop();
      return;
    }

    _regenCount++;

    // After 3 failed regenerations, show preference adjustment dialog
    if (_regenCount >= 3) {
      final adjustedRequest = await _showPreferenceAdjustmentDialog(request);
      if (adjustedRequest == null) {
        // User cancelled — don't generate
        return;
      }
      // Reset count and generate with adjusted preferences
      _regenCount = 0;
      await _executeGeneration(adjustedRequest);
      return;
    }

    await _executeGeneration(request);
  }

  /// Executes the actual regeneration with the given base request.
  Future<void> _executeGeneration(RecipeGenerationRequest request) async {
    setState(() => _isRegenerating = true);

    // Sprint 17 — free-tier cap check up front. The home screen gates
    // first-generation here (HomeScreen._openPreferencesThenGenerate),
    // but the regen path on this screen previously skipped the check
    // entirely. Both guests over their 3/week limit and signed-in
    // non-Pro users over the weekly cap could hammer "Generate
    // another" until Gemini / the prompt path crashed with a raw
    // null-check error toast (Kate's 26 May guest-account repro).
    // Now we route to the standard paywall instead.
    if (widget.isGuest) {
      final canGenerate = await EntitlementService.canGuestGenerate();
      if (!mounted) return;
      if (!canGenerate) {
        setState(() => _isRegenerating = false);
        _showUpgradeDialog();
        return;
      }
    } else {
      await EntitlementService.instance.refresh();
      if (!mounted) return;
      if (!EntitlementService.instance.canGenerate) {
        setState(() => _isRegenerating = false);
        _showUpgradeDialog();
        return;
      }
    }

    // Sprint 16.1: force-refresh dietary/allergens fresh-from-server
    // BEFORE building the regen request. Belt-and-braces against any
    // missed listener propagation since the original generation —
    // mid-recipe-screen settings edits MUST be honoured by the next
    // Generate Another.
    await UserSettingsService.instance.refresh();

    try {
      final newRequest = debugBuildRegenRequest(request);

      final newRecipe = await GeminiService.generateRecipe(newRequest);

      if (widget.isGuest) {
        // Sprint 17 — count the regen against the guest's 3/week cap.
        // Previously only first-generation incremented (via
        // HomeScreen), so guests could regen unbounded after the
        // first recipe of the week.
        await EntitlementService.recordGuestGeneration();
      } else {
        await Future.wait([
          EntitlementService.instance.recordGeneration(),
          _firestore.saveRecipe(newRecipe),
        ]);
      }

      await HistoryService.saveRecipe(SavedRecipe(
        recipe: newRecipe,
        savedAt: DateTime.now().toUtc().toIso8601String(),
      ));

      if (mounted) {
        // Replace current recipe screen with the new one
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RecipeScreen(
              recipe: newRecipe,
              originalRequest: newRequest,
              isGuest: widget.isGuest,
              regenCount: _regenCount,
            ),
          ),
        );
      }
    } catch (e) {
      ErrorService.log('recipe_regeneration', e);
      if (mounted) {
        setState(() => _isRegenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: ElioColors.espresso,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  /// Pushes the standard cap-reached paywall. Mirrors
  /// HomeScreen._showUpgradeDialog so the regen path and the
  /// first-generation path lead users to the same screen.
  void _showUpgradeDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PaywallScreen(
          triggerContext: 'weekly_limit',
          trigger: PaywallTrigger.capReached,
        ),
      ),
    );
  }

  // ── Side dish generation ────────────────────────────────────────────────────
  Future<void> _generateSideDish() async {
    if (_isGeneratingSideDish) return;

    // Pro-only feature
    if (!EntitlementService.instance.isPro) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaywallScreen(triggerContext: 'side_dish'),
          ),
        );
      }
      return;
    }

    setState(() => _isGeneratingSideDish = true);

    try {
      // When the current screen is itself a side dish, generate
      // against the ORIGINAL main recipe context so we don't spiral
      // into side-dishes-of-side-dishes. Fall back to the current
      // recipe when this is a main-recipe screen.
      final mainTitle = widget.isSideDish
          ? (widget.sideDishMainTitle ?? _currentRecipe.title)
          : _currentRecipe.title;
      final ingredientNames = widget.isSideDish
          ? (widget.sideDishMainIngredientNames ??
              _currentRecipe.ingredients.map((i) => i.name).toList())
          : _currentRecipe.ingredients.map((i) => i.name).toList();
      final dietaryTags = widget.isSideDish
          ? (widget.sideDishMainDietaryTags ?? _currentRecipe.dietaryTags)
          : _currentRecipe.dietaryTags;

      final sideDish = await GeminiService.generateSideDish(
        mainRecipeTitle: mainTitle,
        mainIngredientNames: ingredientNames,
        dietaryTags: dietaryTags,
        servings: _servings,
      );

      _analytics.logEvent('side_dish_generated', {
        'main_recipe': mainTitle,
        'side_dish': sideDish.title,
      });

      if (mounted) {
        setState(() => _sideDishGenerated = true);
        // When already on a side dish, REPLACE the screen so back
        // returns to the main recipe (not a stack of side dishes).
        // Pass the main-recipe context through so the next "Generate
        // another" keeps anchoring on the same main.
        final route = MaterialPageRoute(
          builder: (_) => RecipeScreen(
            recipe: sideDish,
            isGuest: widget.isGuest,
            isSideDish: true,
            sideDishMainTitle: mainTitle,
            sideDishMainIngredientNames: ingredientNames,
            sideDishMainDietaryTags: dietaryTags,
            // No originalRequest — "Generate Another" (main-recipe
            // regen) is not relevant on a side dish.
          ),
        );
        if (widget.isSideDish) {
          Navigator.of(context).pushReplacement(route);
        } else {
          Navigator.of(context).push(route);
        }
      }
    } catch (e) {
      ErrorService.log('side_dish_generation', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: ElioColors.espresso,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSideDish = false);
    }
  }

  /// Shows a dialog letting the user adjust style/time/mood preferences
  /// after multiple unsuccessful "Generate Another" attempts.
  /// Returns a modified [RecipeGenerationRequest] or null if cancelled.
  Future<RecipeGenerationRequest?> _showPreferenceAdjustmentDialog(
    RecipeGenerationRequest request,
  ) async {
    String? selectedStyle = request.stylePreference;
    String? selectedTime = request.timePreference;
    String? selectedMood = request.moodPreference;

    // Cuisine-based pivot list — deliberately distinct from the
    // descriptive style options on recipe_preferences_screen.dart
    // (Comfort / Healthy / Hearty / etc.). This dialog opens AFTER
    // the user's original style pick didn't land, so we offer a
    // different axis ("mix it up") rather than re-presenting the
    // same list. Don't unify the two lists; they're complementary.
    const alternativeStyles = [
      'Italian', 'Asian', 'Mexican', 'Mediterranean',
      'Indian', 'American', 'British', 'One-pot', 'Quick & Easy',
    ];

    return showDialog<RecipeGenerationRequest>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildRemovableChip(String label, String? value, void Function() onRemove) {
              if (value == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: InputChip(
                  label: Text(
                    label,
                    style: ElioTextStyles.uiLabelStyle.copyWith(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: ElioColors.terracotta,
                  deleteIconColor: Colors.white.withValues(alpha: 0.8),
                  onDeleted: () {
                    setDialogState(onRemove);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide.none,
                ),
              );
            }

            return AlertDialog(
              backgroundColor: ElioColors.cream,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              title: Text(
                'Not finding what you want?',
                style: ElioTextStyles.sectionHeadingStyle.copyWith(
                  fontSize: 20,
                  color: ElioColors.espresso,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adjust your preferences and try again',
                      style: ElioTextStyles.bodySmallStyle.copyWith(
                        color: ElioColors.espresso.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Current selections
                    if (selectedStyle != null || selectedTime != null || selectedMood != null) ...[
                      Text(
                        'Current selections:',
                        style: ElioTextStyles.uiLabelStyle.copyWith(
                          fontSize: 14,
                          color: ElioColors.espresso,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        children: [
                          buildRemovableChip(
                            selectedStyle ?? '',
                            selectedStyle,
                            () => selectedStyle = null,
                          ),
                          buildRemovableChip(
                            selectedTime ?? '',
                            selectedTime,
                            () => selectedTime = null,
                          ),
                          buildRemovableChip(
                            selectedMood ?? '',
                            selectedMood,
                            () => selectedMood = null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Alternative styles
                    Text(
                      'Try something different:',
                      style: ElioTextStyles.uiLabelStyle.copyWith(
                        fontSize: 14,
                        color: ElioColors.espresso,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: alternativeStyles.map((style) {
                        final isSelected = selectedStyle == style;
                        return ChoiceChip(
                          label: Text(
                            style,
                            style: ElioTextStyles.bodySmallStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : ElioColors.espresso,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() {
                              selectedStyle = selected ? style : null;
                            });
                          },
                          selectedColor: ElioColors.terracotta,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? ElioColors.terracotta
                                  : ElioColors.espresso.withValues(alpha: 0.2),
                            ),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final adjusted = RecipeGenerationRequest(
                            perishables: request.perishables,
                            alwaysHave: request.alwaysHave,
                            almostAlwaysHave: request.almostAlwaysHave,
                            dietaryRequirements: request.dietaryRequirements,
                            timePreference: selectedTime,
                            stylePreference: selectedStyle,
                            moodPreference: selectedMood,
                            mealType: request.mealType,
                            servings: request.servings,
                            excludedIngredients: request.excludedIngredients,
                            recentTitles: request.recentTitles,
                            recentHeroIngredients: request.recentHeroIngredients,
                            recentCookware: request.recentCookware,
                            runningLowItems: request.runningLowItems,
                            isLeftoverMode: request.isLeftoverMode,
                            leftoverItems: request.leftoverItems,
                            likedRecipes: request.likedRecipes,
                            dislikedRecipes: request.dislikedRecipes,
                            appliances: request.appliances,
                            isSaverMode: request.isSaverMode,
                            perishableInventoryDescriptions: request.perishableInventoryDescriptions,
                            userRequest: request.userRequest,
                            customAllergens: request.customAllergens,
                          );
                          Navigator.of(dialogContext).pop(adjusted);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ElioColors.terracotta,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: ElioTextStyles.uiLabelStyle.copyWith(fontSize: 15),
                          elevation: 0,
                        ),
                        child: const Text('Generate with these'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(null),
                        child: Text(
                          'Cancel',
                          style: ElioTextStyles.bodyStyle.copyWith(
                            color: ElioColors.espresso.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _rateRecipe(bool liked) async {
    if (_isRating || widget.isGuest) return;
    setState(() {
      _isRating = true;
    });
    _analytics.logEvent('recipe_rated', {
      'direction': liked ? 'up' : 'down',
      'recipe_title': _currentRecipe.title,
    });
    try {
      await _firestore.rateRecipe(
        recipeTitle: _currentRecipe.title,
        liked: liked,
        cuisineTags: _currentRecipe.dietaryTags,
        dietaryTags: _currentRecipe.dietaryTags,
      );
    } catch (_) {
      // Rating failure is non-critical — silently ignore
    } finally {
      if (mounted) setState(() => _isRating = false);
    }
  }

  void _showNutritionSheet() {
    final n = _currentRecipe.nutrition;
    if (n == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ElioColors.rule,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Nutrition per serving', style: ElioText.headingMedium),
            const SizedBox(height: 4),
            Text(
              'Based on $_servings serving${_servings == 1 ? '' : 's'}',
              style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
            ),
            const SizedBox(height: 20),
            // Calories — full width
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: ElioColors.terracotta.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ElioColors.terracotta.withValues(alpha: 0.25)),
              ),
              // 21 May 2026 — Rob: "the calorie total is for the entire
              // meal. It needs to be per serving." Gemini's prompt
              // already asks for per-serving values (gemini_service.dart
              // line 1431) — the rendering was multiplying by
              // `_scaleFactor = currentServings / originalServings`, so
              // increasing the serving stepper from 2 → 4 doubled the
              // displayed calories. That's "total for N servings"
              // semantics, not per-serving. Per-serving is invariant of
              // serving count; only ingredient quantities should scale.
              // Removed the `* _scaleFactor` multiplications on
              // nutrition values and added an explicit "per serving"
              // label so the user knows what they're looking at.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Calories', style: ElioText.headingMedium.copyWith(color: ElioColors.terracotta)),
                      Text(
                        'per serving',
                        style: ElioTextStyles.bodySmallStyle.copyWith(
                          color: ElioColors.mocha,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${n.calories}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: ElioColors.espresso,
                          ),
                        ),
                        const TextSpan(
                          text: ' kcal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: ElioColors.mocha,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Macros row — per-serving (see Calories block above).
            Row(
              children: [
                _NutritionTile(
                  label: 'PROTEIN',
                  value: '${n.proteinG.round()}',
                  unit: 'g',
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 10),
                _NutritionTile(
                  label: 'CARBS',
                  value: '${n.carbsG.round()}',
                  unit: 'g',
                  color: const Color(0xFF2196F3),
                ),
                const SizedBox(width: 10),
                _NutritionTile(
                  label: 'FAT',
                  value: '${n.fatG.round()}',
                  unit: 'g',
                  color: const Color(0xFFFF9800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Fibre — per-serving.
            Row(
              children: [
                _NutritionTile(
                  label: 'FIBRE',
                  value: '${n.fibreG.round()}',
                  unit: 'g',
                  color: const Color(0xFF9C27B0),
                ),
                const SizedBox(width: 10),
                const Expanded(child: SizedBox()),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Estimates only — actual values may vary.',
              style: ElioText.bodyMedium.copyWith(
                color: ElioColors.mocha,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCostInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: ElioColors.rule, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.info_outline, color: ElioColors.terracotta, size: 32),
            const SizedBox(height: 12),
            Text('About cost estimates', style: ElioText.headingMedium),
            const SizedBox(height: 8),
            Text(
              "Elio's best estimate based on standard, non-premium ingredients. Actual costs may vary depending on where you shop!",
              style: ElioText.bodyLarge.copyWith(color: ElioColors.mocha),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bulk Prep / Freezing & Storage ─────────────────────────────────────────
  Widget _buildBulkPrepSection() {
    final info = _currentRecipe.bulkPrepInfo!;
    return Container(
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ElioColors.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header toggle
          GestureDetector(
            onTap: () => setState(() => _bulkPrepExpanded = !_bulkPrepExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: Colors.transparent,
              child: Row(
                children: [
                  Icon(Icons.ac_unit_rounded, size: 20, color: ElioColors.mocha),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Freezing & Storage',
                      style: ElioText.bodyMedium.copyWith(
                        color: ElioColors.mocha,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _bulkPrepExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 22,
                      color: ElioColors.mocha,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Body
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _buildBulkPrepRow(Icons.kitchen_outlined, 'Portions', '${info.totalPortions} portions'),
                  _buildBulkPrepRow(Icons.ac_unit_rounded, 'Freezing', info.freezingInstructions),
                  _buildBulkPrepRow(Icons.microwave_outlined, 'Reheating', info.reheatingInstructions),
                  _buildBulkPrepRow(Icons.calendar_today_outlined, 'Storage', info.storageLife),
                  _buildBulkPrepRow(Icons.inventory_2_outlined, 'Container', info.containerSuggestion),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _bulkPrepExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkPrepRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ElioColors.mocha),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: ElioText.bodyMedium.copyWith(color: ElioColors.espresso),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Save recipe (toggle bookmark) ──────────────────────────────────────────
  Future<void> _saveRecipe() async {
    try {
      if (_savedAt != null) {
        // Recipe is from history — toggle bookmark
        await HistoryService.toggleBookmark(_savedAt!);
        final nowBookmarked = !_isSaved;
        if (mounted) {
          setState(() => _isSaved = nowBookmarked);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(nowBookmarked ? 'Recipe saved' : 'Bookmark removed'),
              backgroundColor: ElioColors.espresso,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      // New recipe — save fresh
      final now = DateTime.now().toUtc().toIso8601String();
      await HistoryService.saveRecipe(SavedRecipe(
        recipe: _currentRecipe,
        savedAt: now,
        isBookmarked: true,
      ));
      if (mounted) {
        setState(() {
          _isSaved = true;
          _savedAt = now; // Now it's in history — future taps toggle
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Recipe saved'),
            backgroundColor: ElioColors.espresso,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        AnalyticsService.instance.logEvent('recipe_saved', {
          'title': _currentRecipe.title,
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not save recipe'),
            backgroundColor: ElioColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ─── Shopping list staple filter ────────────────────────────────────────────
  /// Items everyone has — never add these to a shopping list.
  static const _shoppingExclusions = {
    'water', 'tap water', 'cold water', 'warm water', 'hot water', 'boiling water',
    'ice', 'ice cubes',
    'salt', 'sea salt', 'table salt', 'kosher salt',
    'pepper', 'black pepper', 'ground pepper', 'ground black pepper',
  };

  bool _isShoppingExclusion(String name) {
    return _shoppingExclusions.contains(name.toLowerCase().trim());
  }

  // ─── Add ingredients to shopping list (via confirmation dialog) ─────────────
  Future<void> _addToShoppingList() async {
    if (widget.isGuest) {
      // Sprint 16.1: explicit duration + hide-current.
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Sign in to use the shopping list'),
          backgroundColor: ElioColors.espresso,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Build editable item list from recipe ingredients
    final items = <_RecipeShoppingItem>[];
    for (final ing in _currentRecipe.ingredients) {
      // Sprint 16.7c — pantry-truth check via _isInPantry only. Gemini's
      // fromInventory flag is a snapshot from generation time, so it
      // lies after the user mutates their pantry: a recipe generated
      // when sausages were in the pantry will keep `fromInventory: true`
      // on the sausage ingredient even after the user × deletes
      // sausages, which had us silently dropping the just-removed item
      // from "Add to shopping list" (Bug 2b, 13 May 2026). The live
      // _isInPantry check below is the only source of truth.
      if (_isInPantry(ing)) continue;
      if (_isShoppingExclusion(ing.name)) continue;
      final cleanName = ShoppingService.cleanForShopping(ing.name);
      if (ShoppingService.instance.isStaplePublic(cleanName.toLowerCase().trim())) continue;
      final qty = ing.unit.isEmpty
          ? _scaleQuantity(ing.quantity)
          : '${_scaleQuantity(ing.quantity)} ${QuantityUtils.normalizeUnit(ing.unit)}';
      items.add(_RecipeShoppingItem(name: cleanName, quantity: qty));
    }

    if (items.isEmpty) {
      // Sprint 16.1: explicit duration + hide-current.
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('All ingredients are already in your pantry!'),
          backgroundColor: ElioColors.espresso,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _RecipeShoppingDialog(items: items),
    );

    if (confirmed == true && mounted) {
      setState(() => _isAddingToShop = true);
      try {
        final shop = ShoppingService.instance;
        int addedCount = 0;
        for (final item in items) {
          if (!item.included) continue;
          final result = await shop.addItem(
            name: item.name.trim(),
            quantity: item.quantity.trim(),
            source: ShoppingSource.recipe,
          );
          if (result != null) addedCount++;
        }
        if (mounted) {
          setState(() => _isAddingToShop = false);
          // Sprint 16.1: explicit short duration + hide-current-first.
          // Default SnackBar duration is 4s but with floating + the
          // root ScaffoldMessenger, the snackbar follows you across
          // navigation; without an explicit duration Rob saw it stuck
          // on the Shopping List tab long after the original action.
          // The View tap also dismisses so we don't have it lingering
          // behind the destination route.
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          // Sprint 16.7c — withTimer enforces the 3s dismiss even when
          // accessibleNavigation is true.
          messenger.showSnackBarWithTimer(
            SnackBar(
              content: Text('$addedCount item${addedCount == 1 ? '' : 's'} added to shopping list'),
              backgroundColor: ElioColors.espresso,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              action: SnackBarAction(
                label: 'View',
                textColor: ElioColors.terracotta,
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ShoppingListPage()),
                  );
                },
              ),
            ),
          );
          _analytics.logEvent('recipe_added_to_shopping', {
            'title': _currentRecipe.title,
            'item_count': addedCount,
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isAddingToShop = false);
          // Sprint 16.1: explicit duration + hide-current.
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Could not add to shopping list'),
              backgroundColor: ElioColors.espresso,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  void _shareRecipe() {
    final r = _currentRecipe;
    final buffer = StringBuffer();
    buffer.writeln('🍽️ ${r.title}');
    buffer.writeln();
    buffer.writeln(r.description);
    buffer.writeln();
    buffer.writeln('⏱ ${r.totalTimeMinutes} min  •  $_servings servings');
    buffer.writeln();
    buffer.writeln('INGREDIENTS');
    for (final ing in r.ingredients) {
      final qty = ing.unit.isEmpty
          ? _scaleQuantity(ing.quantity)
          : '${_scaleQuantity(ing.quantity)} ${QuantityUtils.normalizeUnit(ing.unit)}';
      buffer.writeln('• ${ing.name}${qty.isNotEmpty ? " — $qty" : ""}');
    }
    buffer.writeln();
    buffer.writeln('METHOD');
    for (int i = 0; i < r.steps.length; i++) {
      buffer.writeln('${i + 1}. ${r.steps[i]}');
    }
    buffer.writeln();
    buffer.writeln('Generated by ELiO — AI Recipe Generator');
    Share.share(buffer.toString(), subject: r.title);
  }

  String _scaleQuantity(String quantity) {
    if (quantity.isEmpty) return quantity;
    final num = double.tryParse(quantity);
    if (num == null) return quantity;
    final scaled = num * _scaleFactor;
    if (scaled == scaled.roundToDouble()) {
      return scaled.toInt().toString();
    }
    return scaled.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    if (_handsFreeMode) {
      return _buildHandsFreeMode();
    }
    return _buildNormalMode();
  }

  // ─── Normal mode — Sprint 16 typographic layout ─────────────────────────────
  Widget _buildNormalMode() {
    final r = _currentRecipe;
    final isStreaming = r.title.isEmpty;
    final costLabel = _costLabel;
    // 21 May 2026 — per-serving (invariant of serving count). Pre-fix
    // this multiplied by `_scaleFactor` and was effectively "total
    // calories for N servings"; see the Calories block in
    // `_buildNutritionCard` for the full rationale.
    final kcalLabel = r.nutrition != null
        ? '${r.nutrition!.calories} kcal'
        : null;

    return Scaffold(
      backgroundColor: ElioColors.cream,
      appBar: _buildTopBar(),
      body: Column(
        children: [
          // Sprint 16.6: sticky timer bar — only renders when a timer
          // exists. The ListView below scrolls underneath; the bar
          // stays pinned just under the AppBar.
          _buildTimerBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: ElioSpacing.screenEdge,
                vertical: ElioSpacing.lg,
              ),
              children: [
          // ── Title / description (streaming-aware) ─────────────────────
          if (isStreaming) ...[
            _shimmerBlock(height: 48, width: double.infinity),
            const SizedBox(height: ElioSpacing.md),
            _shimmerBlock(height: 16, width: double.infinity),
            const SizedBox(height: 8),
            _shimmerBlock(height: 16, width: 220),
          ] else ...[
            ElioPageTitle(r.title),
            if (r.description.isNotEmpty) ...[
              const SizedBox(height: ElioSpacing.md),
              Text(r.description, style: ElioTextStyles.ledeStyle),
            ],
          ],
          const SizedBox(height: ElioSpacing.lg),

          // ── Stat pills ────────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElioStatBadge(
                icon: Icons.schedule,
                value: '${r.totalTimeMinutes}m',
              ),
              ElioStatBadge(
                icon: Icons.restaurant,
                value: '${r.prepTimeMinutes}m prep',
              ),
              if (costLabel != null)
                GestureDetector(
                  onTap: _showCostInfoSheet,
                  child: ElioStatBadge(
                    icon: Icons.attach_money,
                    value: costLabel,
                  ),
                ),
              if (kcalLabel != null)
                GestureDetector(
                  onTap: _showNutritionSheet,
                  child: ElioStatBadge(
                    icon: Icons.local_fire_department,
                    value: kcalLabel,
                  ),
                ),
              // 16 May 2026 (Notion dietaryTags row): render ONE chip
              // per active constraint, not just `.first`. The pre-fix
              // code shipped a single-pill summary because Sprint 16.1
              // only cared about making the first tag honest. With the
              // request->dietaryTags merge in gemini_service (lines
              // 113-121), the list now reliably contains every active
              // constraint (e.g. ["Gluten-Free", "Dairy-Free"]), so
              // we iterate. Wrap handles overflow to a second row.
              for (final tag in r.dietaryTags)
                ElioStatBadge(
                  icon: Icons.local_dining_outlined,
                  value: tag,
                ),
            ],
          ),
          const SizedBox(height: ElioSpacing.lg),

          // ── Servings ─────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.people_outline, color: ElioColors.espresso),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Servings', style: ElioTextStyles.uiLabelStyle),
              ),
              ElioServingsControl(
                value: _servings,
                onChanged: (v) => setState(() => _servings = v),
              ),
            ],
          ),
          const SizedBox(height: ElioSpacing.xl),

          // ── Ingredients ──────────────────────────────────────────────
          ElioSectionHeading('Ingredients'),
          const SizedBox(height: ElioSpacing.md),
          for (int i = 0; i < r.ingredients.length; i++)
            _buildIngredientRow(i, r.ingredients[i]),

          const SizedBox(height: ElioSpacing.xl),

          // ── Method ───────────────────────────────────────────────────
          ElioSectionHeading('Method'),
          const SizedBox(height: ElioSpacing.md),
          for (int i = 0; i < r.steps.length; i++)
            ElioMethodStep(
              stepNumber: i + 1,
              title: '',
              body: r.steps[i],
              // Sprint 16.6: inline tappable time pills. The handler
              // opens the duration picker pre-filled with the detected
              // duration and starts a step-labelled timer.
              onTimeTap: (match) => _onMethodTimeTap(i, match),
            ),

          // ── Substitution tips (preserved) ───────────────────────────
          if (r.substitutions.isNotEmpty) ...[
            const SizedBox(height: ElioSpacing.md),
            _buildSubstitutionsSection(),
          ],

          // ── Bulk prep (preserved) ───────────────────────────────────
          if (r.bulkPrepInfo != null) ...[
            const SizedBox(height: ElioSpacing.lg),
            _buildBulkPrepSection(),
          ],

          const SizedBox(height: ElioSpacing.xl),

          // ── Feedback bar (thumbs up/down → existing rating handler) ─
          if (!widget.isGuest)
            ElioFeedbackBar(onRated: _rateRecipe)
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ElioColors.cream,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Sign in to rate this recipe',
                style: ElioTextStyles.bodySmall,
              ),
            ),

          const SizedBox(height: ElioSpacing.md),

          // ── Generate another (regenerate with exclusions) ───────────
          if (widget.originalRequest != null) ...[
            ElioBigButton(
              label: 'Generate another',
              trailingIcon: Icons.all_inclusive,
              loading: _isRegenerating,
              onTap: _generateAnother,
            ),
            const SizedBox(height: ElioSpacing.md),
          ],

          // ── Secondary actions: side dish + hands-free ───────────────
          // Sprint 16.6.x: dropped the `!_sideDishGenerated` gate that
          // hid this button after a successful generation. Rob reported
          // that after popping back from a generated side dish, only
          // hands-free remained — the button was gone with no way to
          // suggest a different side. Keeping it always tappable lets
          // the user iterate (label flips to "another"). Re-entrancy
          // protection is already covered by `_isGeneratingSideDish`.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isGeneratingSideDish ? null : _generateSideDish,
              icon: _isGeneratingSideDish
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: ElioColors.terracotta),
                    )
                  : const Icon(Icons.restaurant_menu_rounded, size: 20),
              // Sprint 16.7 (14 May 2026): when the current screen is
              // itself a side dish (`widget.isSideDish`), the CTA reads
              // "Generate another" — semantically clearer than
              // "Suggest a side dish" when you're already on one. The
              // action still calls `_generateSideDish`, which detects
              // the side-dish context and regenerates against the
              // original main recipe (not the current side dish).
              label: Text(_isGeneratingSideDish
                  ? (widget.isSideDish
                      ? 'Finding another...'
                      : 'Finding a side dish...')
                  : (widget.isSideDish
                      ? 'Generate another'
                      : (_sideDishGenerated
                          ? 'Suggest another side dish'
                          : 'Suggest a side dish'))),
              style: OutlinedButton.styleFrom(
                foregroundColor: ElioColors.terracotta,
                side: const BorderSide(color: ElioColors.terracotta, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: ElioSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _startHandsFree,
              icon: const Icon(Icons.soup_kitchen_outlined, size: 20),
              // Sprint 16.7c (14 May 2026): renamed from "Start hands-free
              // mode" — the feature is more than voice (bigger step UI,
              // wakelock, simplified layout). "Cook Mode" matches the
              // industry convention (Paprika / SideChef / Allrecipes) and
              // anchors on the use case rather than the input method.
              label: const Text('Start Cook Mode'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ElioColors.espresso,
                side: const BorderSide(color: ElioColors.espresso, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: ElioSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Cook Mode entry point (also used by the soup-kitchen icon in the
  // top bar). Method name kept as `_startHandsFree` to avoid churn
  // across the wider voice/TTS plumbing that still uses "hands-free"
  // internally — only user-facing copy + icons rebranded 14 May 2026.
  void _startHandsFree() {
    setState(() {
      _handsFreeMode = true;
      _currentStep = 0;
    });
    _analytics.logEvent('hands_free_started', {
      'step_count': _currentRecipe.steps.length,
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Read the first step aloud immediately — TTS no longer waits for
    // the user to engage voice control. The mic stays off by default;
    // voice commands are opt-in via the mic toggle.
    _speakText(_currentRecipe.steps[_currentStep]);
  }

  // Shimmer-style placeholder for streaming state.
  Widget _shimmerBlock({required double height, required double width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  // Build a single ingredient row with tap → check, long-press → substitution.
  Widget _buildIngredientRow(int index, RecipeIngredient ing) {
    final isExcluded = _excludedIngredients.contains(ing.name);
    final isChecked = _checkedIngredientIndices.contains(index);
    final qty = ing.unit.isEmpty
        ? _scaleQuantity(ing.quantity)
        : '${_scaleQuantity(ing.quantity)} ${QuantityUtils.normalizeUnit(ing.unit)}';
    final detailParts = <String>[
      if (qty.isNotEmpty) qty,
      if (isExcluded) 'excluded — tap Generate Another',
    ];

    // RawGestureDetector with LongPressGestureRecognizer so long-press
    // isn't stolen by the ListView scroll gesture (CLAUDE.md gotcha).
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            duration: const Duration(milliseconds: 300),
          ),
          (instance) {
            instance.onLongPress = () => _showIngredientOptions(ing);
          },
        ),
      },
      behavior: HitTestBehavior.opaque,
      child: ElioIngredientRow(
        name: ing.name,
        detail: detailParts.isEmpty ? null : detailParts.join(' • '),
        checked: isChecked,
        trailing: ElioPantryIcon(inStock: _isInPantry(ing)),
        onChanged: (v) {
          setState(() {
            if (v) {
              _checkedIngredientIndices.add(index);
            } else {
              _checkedIngredientIndices.remove(index);
            }
          });
        },
      ),
    );
  }

  // ─── Minimal top bar — back + action icons ──────────────────────────────────
  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      backgroundColor: ElioColors.cream,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: ElioColors.espresso, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        // Cook Mode entry (renamed from "voice / hands-free" 14 May 2026 —
        // see _startHandsFree button below for rationale).
        IconButton(
          icon: const Icon(Icons.soup_kitchen_outlined,
              color: ElioColors.espresso, size: 22),
          tooltip: 'Cook Mode',
          onPressed: _startHandsFree,
        ),
        // Save / bookmark
        IconButton(
          icon: Icon(
            _isSaved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: _isSaved ? ElioColors.terracotta : ElioColors.espresso,
            size: 22,
          ),
          tooltip: _isSaved ? 'Saved' : 'Save recipe',
          onPressed: _saveRecipe,
        ),
        // Add to shopping list
        IconButton(
          icon: _isAddingToShop
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: ElioColors.espresso),
                )
              : const Icon(Icons.add_shopping_cart_rounded,
                  color: ElioColors.espresso, size: 22),
          tooltip: 'Add to shopping list',
          onPressed: _isAddingToShop ? null : _addToShoppingList,
        ),
        // Share
        IconButton(
          icon: const Icon(Icons.ios_share_rounded,
              color: ElioColors.espresso, size: 22),
          tooltip: 'Share recipe',
          onPressed: _shareRecipe,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ─── Substitution tips (preserved from legacy layout) ──────────────────────
  Widget _buildSubstitutionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Substitution tips', style: ElioText.headingMedium),
        const SizedBox(height: 12),
        ..._currentRecipe.substitutions.asMap().entries.map((entry) {
          final i = entry.key;
          final sub = entry.value;
          final isExpanded = _expandedSubstitutions.contains(i);
          return GestureDetector(
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedSubstitutions.remove(i);
              } else {
                _expandedSubstitutions.add(i);
              }
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ElioColors.peach.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ElioColors.mocha.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded,
                          color: ElioColors.mocha, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Instead of ${sub.original} → ${sub.substitute}',
                          style: ElioText.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: ElioColors.espresso,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: ElioColors.mocha,
                        size: 20,
                      ),
                    ],
                  ),
                  if (isExpanded && sub.tradeOff.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      sub.tradeOff,
                      style: ElioText.bodyMedium
                          .copyWith(color: ElioColors.mocha),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── Hands-Free Mode ─────────────────────────────────────────────────────────

  void _exitHandsFreeMode({String exitMethod = 'button'}) {
    _stopListening();
    _tts.stop();
    // Restore audio streams muted for beep suppression
    try { _audioChannel.invokeMethod('restoreBeep'); } catch (_) {}
    _analytics.logEvent('hands_free_exited', {
      'step_reached': _currentStep + 1,
      'total_steps': _currentRecipe.steps.length,
      'exit_method': exitMethod,
    });
    setState(() {
      _handsFreeMode = false;
      _voiceEnabled = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Widget _buildHandsFreeMode() {
    final steps = _currentRecipe.steps;
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == steps.length - 1;

    return Scaffold(
      backgroundColor: ElioColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // ── Chrome row: Back, title, Exit ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  // Back button (top-left)
                  _HandsFreeCircleButton(
                    icon: Icons.arrow_back,
                    onTap: isFirst
                        ? null
                        : () {
                            setState(() => _currentStep--);
                            _speakText(_currentRecipe.steps[_currentStep]);
                          },
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      _currentRecipe.title,
                      style: ElioTextStyles.bodySmall.copyWith(
                        color: ElioColors.mocha,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  // Exit button (top-right)
                  _HandsFreeCircleButton(
                    icon: Icons.close,
                    onTap: () => _exitHandsFreeMode(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── Step counter eyebrow ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'STEP ${_currentStep + 1} / ${steps.length}',
                  style: ElioTextStyles.eyebrow,
                ),
              ),
            ),
            // ── Voice feedback toast ──
            if (_voiceFeedback.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: ElioColors.terracotta.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ElioColors.terracotta.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hearing_rounded, size: 16, color: ElioColors.terracotta),
                      const SizedBox(width: 8),
                      Text(
                        _voiceFeedback,
                        style: ElioText.bodyMedium.copyWith(
                          color: ElioColors.espresso,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // 19may-c diagnostic strip — visible only while voice control
            // is enabled in Cook Mode. Shows the current STT state +
            // the last words the engine delivered. Lets Rob/Kate (or
            // me, via screenshot) see at a glance whether the engine
            // is delivering anything at all, without needing
            // Crashlytics dashboard access. Will be hidden by a
            // settings toggle in Sprint 17 once the path is stable.
            if (_voiceEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ElioColors.cream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ElioColors.rule.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isSpeaking
                                ? Icons.volume_up_rounded
                                : _isListening
                                    ? Icons.mic_rounded
                                    : Icons.mic_off_rounded,
                            size: 14,
                            color: _isListening
                                ? ElioColors.terracotta
                                : ElioColors.mocha,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isSpeaking
                                ? 'Speaking…'
                                : _isListening
                                    ? 'Listening — say next / back / repeat / done'
                                    : 'Mic idle',
                            style: ElioTextStyles.bodySmallStyle.copyWith(
                              color: ElioColors.mocha,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (_lastHeardWords.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          "Last heard: '$_lastHeardWords'",
                          style: ElioTextStyles.bodySmallStyle.copyWith(
                            color: ElioColors.mocha,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // 21 May 2026 (19may-g) — error path renders
                      // separately, dimmer, so transient
                      // `error_speech_timeout` / `error_no_match`
                      // events don't stomp the actual recognition
                      // line and don't look like permanent failure.
                      if (_lastSttError.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _friendlySttError(_lastSttError),
                          style: ElioTextStyles.bodySmallStyle.copyWith(
                            color: ElioColors.mocha.withValues(alpha: 0.6),
                            fontSize: 10.5,
                            letterSpacing: 0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // 20 May 2026 (20may-b) — raw last STT status
                      // event. Confirms which terminal name the
                      // engine on this device uses ('done' vs
                      // 'notListening'). The heartbeat catches both;
                      // this is for visibility only.
                      if (_lastSttStatus.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'STT status: $_lastSttStatus',
                          style: ElioTextStyles.bodySmallStyle.copyWith(
                            color: ElioColors.mocha.withValues(alpha: 0.45),
                            fontSize: 10,
                            letterSpacing: 0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            // ── Progress bar ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                children: List.generate(steps.length, (i) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _currentStep ? ElioColors.terracotta : ElioColors.rule,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Sprint 16.7d: parity with regular recipe view — sticky
            // timer bar so running timers are visible/manageable from
            // Cook Mode. Renders nothing when no timers are active.
            _buildTimerBar(),
            // ── Step content ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Big amber step numeral
                    Text(
                      '${_currentStep + 1}',
                      style: ElioTextStyles.stepNumeral,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Recipe step',
                      style: ElioTextStyles.heading2,
                    ),
                    const SizedBox(height: 16),
                    // Sprint 16.7d: inline tappable time pills (parity
                    // with regular recipe view). Pill text scales to
                    // the 18pt cook-mode prose via baseStyle.
                    ElioMethodStepBody(
                      body: steps[_currentStep],
                      baseStyle: ElioTextStyles.body
                          .copyWith(fontSize: 18, height: 1.5),
                      onTimeTap: (match) =>
                          _onMethodTimeTap(_currentStep, match),
                    ),
                  ],
                ),
              ),
            ),
            // ── Bottom chrome: Next (big) + centred Mic toggle ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: ElioBigButton(
                label: isLast ? 'Done' : 'Next step',
                trailingIcon: isLast ? Icons.check : Icons.chevron_right,
                onTap: isLast
                    ? () {
                        _analytics.logEvent('hands_free_completed', {
                          'step_count': steps.length,
                        });
                        _stopListening();
                        _tts.stop();
                        setState(() {
                          _handsFreeMode = false;
                          _voiceEnabled = false;
                        });
                        SystemChrome.setEnabledSystemUIMode(
                            SystemUiMode.edgeToEdge);
                      }
                    : () {
                        setState(() => _currentStep++);
                        _speakText(_currentRecipe.steps[_currentStep]);
                      },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _HandsFreeMicButton(
                enabled: _voiceEnabled,
                listening: _isListening,
                onTap: _toggleVoiceControl,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _HandsFreeCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _HandsFreeCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ElioColors.cream,
          shape: BoxShape.circle,
          border: Border.all(color: ElioColors.rule),
        ),
        child: Icon(
          icon,
          size: 20,
          color: disabled ? ElioColors.mocha : ElioColors.espresso,
        ),
      ),
    );
  }
}

class _HandsFreeMicButton extends StatelessWidget {
  final bool enabled;
  final bool listening;
  final VoidCallback onTap;
  const _HandsFreeMicButton({
    required this.enabled,
    required this.listening,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: enabled ? ElioColors.terracotta : ElioColors.rule,
            shape: BoxShape.circle,
            boxShadow: listening
                ? [
                    BoxShadow(
                      color: ElioColors.terracotta.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            enabled ? Icons.mic_rounded : Icons.mic_off_rounded,
            size: 32,
            color: enabled ? Colors.white : ElioColors.mocha,
          ),
        ),
      ),
    );
  }
}

class _NutritionTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _NutritionTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: ElioColors.espresso,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: ElioColors.mocha,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ingredient options bottom sheet ────────────────────────────────────────

class _IngredientOptionsSheet extends StatefulWidget {
  final RecipeIngredient ingredient;
  final GeneratedRecipe recipe;
  final RecipeGenerationRequest? originalRequest;
  final bool isGuest;
  final double scaleFactor;
  final void Function(IngredientSubstitutionResult) onSubstituted;
  final VoidCallback onExcludeAndRegenerate;
  final VoidCallback onAddToShoppingList;

  const _IngredientOptionsSheet({
    required this.ingredient,
    required this.recipe,
    required this.originalRequest,
    required this.isGuest,
    required this.scaleFactor,
    required this.onSubstituted,
    required this.onExcludeAndRegenerate,
    required this.onAddToShoppingList,
  });

  @override
  State<_IngredientOptionsSheet> createState() => _IngredientOptionsSheetState();
}

class _IngredientOptionsSheetState extends State<_IngredientOptionsSheet> {
  // States: 'options', 'loading', 'result', 'error'
  String _state = 'options';
  IngredientSubstitutionResult? _result;
  String _errorMessage = '';

  Future<void> _requestSubstitution() async {
    setState(() => _state = 'loading');
    try {
      final otherNames = widget.recipe.ingredients
          .where((i) => i.name != widget.ingredient.name)
          .map((i) => i.name)
          .toList();

      final result = await GeminiService.generateSubstitution(
        ingredientName: widget.ingredient.name,
        ingredientQuantity: widget.ingredient.quantity,
        ingredientUnit: widget.ingredient.unit,
        recipeTitle: widget.recipe.title,
        otherIngredients: otherNames,
        dietaryRequirements: widget.recipe.dietaryTags,
      );

      if (mounted) {
        setState(() {
          _result = result;
          _state = 'result';
        });
      }
    } catch (e) {
      ErrorService.log('substitution_generation', e);
      if (mounted) {
        setState(() {
          // 14 May 2026 (Notion XX-2 #2/#3): route through friendly
          // error so network failures show "You're offline" + scrub
          // the API key from any URL embedded in the exception text.
          _errorMessage = friendlyError(e);
          _state = 'error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ElioColors.rule,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Content based on state
          if (_state == 'options') _buildOptions(),
          if (_state == 'loading') _buildLoading(),
          if (_state == 'result') _buildResult(),
          if (_state == 'error') _buildError(),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    final ing = widget.ingredient;
    final qty = ing.unit.isEmpty ? ing.quantity : '${ing.quantity} ${QuantityUtils.normalizeUnit(ing.unit)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Don't have this?", style: ElioText.headingMedium),
        const SizedBox(height: 4),
        Text(
          '${ing.name}${qty.isNotEmpty ? ' — $qty' : ''}',
          style: ElioText.bodyLarge.copyWith(color: ElioColors.mocha),
        ),
        if (ing.fromInventory) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ElioColors.terracotta,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'This is from your pantry',
                style: ElioText.label.copyWith(color: ElioColors.mocha),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // Option 1: Suggest substitution
        _buildOptionTile(
          icon: Icons.swap_horiz_rounded,
          iconColor: ElioColors.mocha,
          title: 'Suggest a substitution',
          subtitle: 'AI-powered, instant',
          onTap: _requestSubstitution,
        ),
        const SizedBox(height: 8),

        // Option 2: Remove & Regenerate (only if we have original request)
        if (widget.originalRequest != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildOptionTile(
              icon: Icons.refresh_rounded,
              iconColor: ElioColors.terracotta,
              title: 'Remove & regenerate',
              subtitle: 'New recipe without this ingredient',
              onTap: () {
                Navigator.of(context).pop();
                widget.onExcludeAndRegenerate();
              },
            ),
          ),

        // Option 3: Add to shopping list
        _buildOptionTile(
          icon: Icons.add_shopping_cart_rounded,
          iconColor: ElioColors.espresso,
          title: 'Add to shopping list',
          subtitle: 'Buy it for next time',
          onTap: widget.isGuest
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onAddToShoppingList();
                },
          locked: widget.isGuest,
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool locked = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: ElioColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ElioColors.rule),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ElioText.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: locked ? ElioColors.mocha : ElioColors.espresso,
                    ),
                  ),
                  Text(
                    locked ? 'Sign in to use' : subtitle,
                    style: ElioText.label.copyWith(color: ElioColors.mocha),
                  ),
                ],
              ),
            ),
            if (locked)
              const Icon(Icons.lock_outline_rounded, size: 18, color: ElioColors.mocha)
            else
              const Icon(Icons.chevron_right_rounded, size: 20, color: ElioColors.mocha),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: ElioColors.terracotta,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Finding a substitution...',
              style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final r = _result!;
    final qty = r.unit.isEmpty ? r.adjustedQuantity : '${r.adjustedQuantity} ${QuantityUtils.normalizeUnit(r.unit)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: ElioColors.mocha, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Instead of ${widget.ingredient.name}',
                style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ElioColors.peach.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ElioColors.mocha.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.substitute,
                style: ElioText.headingMedium.copyWith(color: ElioColors.espresso),
              ),
              if (qty.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(qty, style: ElioText.bodyLarge.copyWith(color: ElioColors.mocha)),
              ],
              if (r.tradeOff.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(r.tradeOff, style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onSubstituted(r);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ElioColors.espresso,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Use this instead'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: ElioColors.rule),
            ),
            child: const Text('Never mind'),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Couldn't find a substitution", style: ElioText.headingMedium),
        const SizedBox(height: 8),
        Text(
          _errorMessage,
          style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _requestSubstitution,
            style: ElevatedButton.styleFrom(
              backgroundColor: ElioColors.espresso,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Try again'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: ElioColors.rule),
            ),
            child: const Text('Dismiss'),
          ),
        ),
      ],
    );
  }
}

// ─── Recipe shopping item model ──────────────────────────────────────────────

class _RecipeShoppingItem {
  String name;
  String quantity;
  bool included = true;

  _RecipeShoppingItem({
    required this.name,
    required this.quantity,
  });
}

// ─── Recipe shopping confirmation dialog ─────────────────────────────────────

class _RecipeShoppingDialog extends StatefulWidget {
  final List<_RecipeShoppingItem> items;

  const _RecipeShoppingDialog({required this.items});

  @override
  State<_RecipeShoppingDialog> createState() => _RecipeShoppingDialogState();
}

class _RecipeShoppingDialogState extends State<_RecipeShoppingDialog> {
  late List<_RecipeShoppingItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
  }

  int get _includedCount => _items.where((i) => i.included).length;

  void _toggleAll(bool include) {
    setState(() {
      for (final item in _items) {
        item.included = include;
      }
    });
  }

  void _editItem(int index) {
    final item = _items[index];
    final nameController = TextEditingController(text: item.name);
    final qtyController = TextEditingController(text: item.quantity);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit item', style: ElioText.headingMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Item name'),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                item.name = nameController.text.trim().isEmpty ? item.name : nameController.text.trim();
                item.quantity = qtyController.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: Text('Save', style: ElioText.bodyMedium.copyWith(
              color: ElioColors.espresso,
              fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
    );
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ElioColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add to shopping list', style: ElioText.headingMedium),
                  const SizedBox(height: 4),
                  Text(
                    '$_includedCount of ${_items.length} items selected',
                    style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleAll(true),
                        child: Text(
                          'Select all',
                          style: ElioText.label.copyWith(
                            color: ElioColors.mocha,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _toggleAll(false),
                        child: Text(
                          'Deselect all',
                          style: ElioText.label.copyWith(
                            color: ElioColors.mocha,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Item list ─────────────────────────────────────
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _items.length,
                itemBuilder: (ctx, i) {
                  final item = _items[i];
                  return GestureDetector(
                    onTap: () => setState(() => item.included = !item.included),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: item.included ? Colors.transparent : ElioColors.cream.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: item.included ? ElioColors.espresso : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.included ? ElioColors.espresso : ElioColors.rule,
                                width: 1.5,
                              ),
                            ),
                            child: item.included
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _capitalise(item.name),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: item.included
                                        ? ElioColors.espresso
                                        : ElioColors.mocha,
                                    decoration: item.included
                                        ? null
                                        : TextDecoration.lineThrough,
                                    decorationColor: ElioColors.mocha,
                                  ),
                                ),
                                if (item.quantity.isNotEmpty)
                                  Text(
                                    item.quantity,
                                    style: ElioText.label.copyWith(
                                      color: ElioColors.mocha,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _editItem(i),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.edit_outlined, size: 16, color: ElioColors.mocha),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Buttons ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _includedCount > 0
                          ? () => Navigator.pop(context, true)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ElioColors.terracotta,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: ElioColors.rule,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: Text(
                        _includedCount > 0
                            ? 'Add $_includedCount item${_includedCount == 1 ? '' : 's'} to shopping list'
                            : 'No items selected',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context, false);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ShoppingListPage()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'View shopping list',
                        style: ElioText.bodyMedium.copyWith(
                          color: ElioColors.mocha,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resolved RECORD_AUDIO permission state for Cook Mode voice control.
/// `_ensureMicPermission` returns one of these so the caller can fast-
/// exit on denial; the side-effect UI (snackbar with retry / Open
/// Settings, diagnostic-strip text) is handled inside the helper.
enum _MicPermissionResult { granted, denied, permanentlyDenied }
