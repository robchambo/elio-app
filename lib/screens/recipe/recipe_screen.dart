import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
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

  /// When true, the recipe is auto-saved as bookmarked on first open.
  /// Used by recipe import to avoid double-saves.
  /// When true, the recipe is auto-saved as bookmarked on first open.
  /// Used by recipe import to avoid double-saves.
  final bool autoSave;

  /// The savedAt timestamp from history — enables bookmark toggling
  /// instead of creating duplicates.
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
    this.autoSave = false,
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
  bool _speechAvailable = false;
  bool _voiceHelpShown = false;
  String _voiceFeedback = '';
  Timer? _feedbackTimer;
  Timer? _restartTimer;
  String _recognisedWords = '';

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
    if (widget.autoSave) {
      _isSaved = true;
      // Save in background — recipe was just imported
      final saved = SavedRecipe.fromRecipe(widget.recipe, bookmarked: true);
      _savedAt = saved.savedAt; // Capture so bookmark toggle works
      HistoryService.saveRecipe(saved);
    } else if (_savedAt != null) {
      // Opened from history — check if bookmarked
      _isSaved = true; // It's in history, so it's "saved"
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
  Widget _buildTimerBar() {
    final timers = _timerService.timers;
    if (timers.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: ElioColors.cream.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: ElioColors.rule),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 2, top: 4),
            child: Text(
              'TIMERS',
              style: ElioTextStyles.eyebrowStyle.copyWith(
                color: ElioColors.mocha,
              ),
            ),
          ),
          for (final t in timers)
            ElioTimerChip(
              key: ValueKey(t.id),
              timer: t,
              now: now,
              onTap: () => _onTimerChipTap(t),
              onLongPress: () => _onTimerChipLongPress(t),
            ),
        ],
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
  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
    } catch (e) {
      ErrorService.log('voice_tts_init', e);
    }
  }

  Future<void> _speakText(String text) async {
    try {
      await _tts.speak(text);
    } catch (e) {
      ErrorService.log('voice_tts_speak', e);
    }
  }

  // ── Speech recognition ─────────────────────────────────────────────────────────
  Future<void> _initVoiceControl() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          // On error, attempt restart if voice is still enabled
          if (_voiceEnabled && mounted) {
            _restartTimer?.cancel();
            _restartTimer = Timer(const Duration(milliseconds: 500), () {
              if (_voiceEnabled && mounted) _startListening();
            });
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (_voiceEnabled && mounted) {
              _restartTimer?.cancel();
              _restartTimer = Timer(const Duration(milliseconds: 300), () {
                if (_voiceEnabled && mounted) _startListening();
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
        if (!_voiceHelpShown) {
          // Show help first — TTS + listening start after "Got It"
          _showVoiceHelpOverlay();
          _voiceHelpShown = true;
        } else {
          _startListening();
          _speakText(_currentRecipe.steps[_currentStep]);
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
    try {
      await _speech.listen(
        onResult: (result) {
          _recognisedWords = result.recognizedWords.toLowerCase();
          _processVoiceCommand(_recognisedWords);
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
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
      setState(() => _voiceEnabled = false);
      // Restore audio streams when voice control is turned off
      try { _audioChannel.invokeMethod('restoreBeep'); } catch (_) {}
    } else {
      _initVoiceControl();
    }
  }

  void _processVoiceCommand(String words) {
    // Look for "hey elio" wake word followed by a command
    final wakeIndex = words.lastIndexOf('hey elio');
    if (wakeIndex == -1) return;

    final afterWake = words.substring(wakeIndex + 8).trim();
    if (afterWake.isEmpty) return;

    if (afterWake.contains('next')) {
      _onVoiceNext();
    } else if (afterWake.contains('back') || afterWake.contains('previous')) {
      _onVoiceBack();
    } else if (afterWake.contains('repeat') || afterWake.contains('read')) {
      _onVoiceRepeat();
    } else if (afterWake.contains('done') || afterWake.contains('exit') || afterWake.contains('stop')) {
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
    _recognisedWords = '';
  }

  void _onVoiceBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _showVoiceFeedback('Got it — previous step');
      _speakText(_currentRecipe.steps[_currentStep]);
    } else {
      _showVoiceFeedback('Already on the first step');
    }
    _recognisedWords = '';
  }

  void _onVoiceRepeat() {
    _showVoiceFeedback('Reading step aloud');
    _speakText(_currentRecipe.steps[_currentStep]);
    _recognisedWords = '';
  }

  void _onVoiceDone() {
    _showVoiceFeedback('Voice control off');
    _stopListening();
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
    _recognisedWords = '';
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
                "Say 'Hey Elio' followed by:",
                style: ElioText.bodyLarge.copyWith(color: ElioColors.mocha),
              ),
              const SizedBox(height: 16),
              _buildVoiceHelpRow('"Hey Elio, next"', 'Go to the next step'),
              const SizedBox(height: 10),
              _buildVoiceHelpRow('"Hey Elio, back"', 'Go to the previous step'),
              const SizedBox(height: 10),
              _buildVoiceHelpRow('"Hey Elio, repeat"', 'Read the current step aloud'),
              const SizedBox(height: 10),
              _buildVoiceHelpRow('"Hey Elio, done"', 'Turn off voice control'),
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
                    // Start listening + read step 1 after dialog closes
                    _startListening();
                    _speakText(_currentRecipe.steps[_currentStep]);
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

    // Sprint 16.1: force-refresh dietary/allergens fresh-from-server
    // BEFORE building the regen request. Belt-and-braces against any
    // missed listener propagation since the original generation —
    // mid-recipe-screen settings edits MUST be honoured by the next
    // Generate Another.
    await UserSettingsService.instance.refresh();

    try {
      // Build updated request — carry forward ALL fields, add exclusions + title.
      //
      // Sprint 16.1: dietaryRequirements + customAllergens are the
      // EXCEPTION to "carry forward". They're re-read from
      // UserSettingsService at regen time so a Settings → Dietary edit
      // made between the original Generate and a Generate Another tap
      // is honoured. Every other field is legitimately frozen at first-
      // generation time (perishables, taste profile, time/style/mood
      // selections, recent titles, exclusions accumulated this session).
      final settings = UserSettingsService.instance;
      final newRequest = RecipeGenerationRequest(
        perishables: request.perishables,
        alwaysHave: request.alwaysHave,
        almostAlwaysHave: request.almostAlwaysHave,
        dietaryRequirements: settings.hydrated
            ? settings.dietaryRequirements
            : request.dietaryRequirements,
        timePreference: request.timePreference,
        stylePreference: request.stylePreference,
        moodPreference: request.moodPreference,
        servings: request.servings,
        excludedIngredients: [
          ...request.excludedIngredients,
          ..._excludedIngredients,
        ],
        recentTitles: [
          ...request.recentTitles,
          _currentRecipe.title,
        ],
        runningLowItems: request.runningLowItems,
        isLeftoverMode: request.isLeftoverMode,
        leftoverItems: request.leftoverItems,
        likedRecipes: request.likedRecipes,
        dislikedRecipes: request.dislikedRecipes,
        appliances: request.appliances,
        isSaverMode: request.isSaverMode,
        perishableInventoryDescriptions: request.perishableInventoryDescriptions,
        // Sprint 15.9.3 SAFETY FIX: must propagate on regenerate too —
        // otherwise the second/third recipe could lose the allergen
        // constraint and serve peanut butter to a peanut-allergy user.
        // Sprint 16.1: read fresh from singleton (see comment above).
        customAllergens:
            settings.hydrated ? settings.allergies : request.customAllergens,
      );

      final newRecipe = await GeminiService.generateRecipe(newRequest);

      if (!widget.isGuest) {
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
                            servings: request.servings,
                            excludedIngredients: request.excludedIngredients,
                            recentTitles: request.recentTitles,
                            runningLowItems: request.runningLowItems,
                            isLeftoverMode: request.isLeftoverMode,
                            leftoverItems: request.leftoverItems,
                            likedRecipes: request.likedRecipes,
                            dislikedRecipes: request.dislikedRecipes,
                            appliances: request.appliances,
                            isSaverMode: request.isSaverMode,
                            perishableInventoryDescriptions: request.perishableInventoryDescriptions,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Calories', style: ElioText.headingMedium.copyWith(color: ElioColors.terracotta)),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${(n.calories * _scaleFactor).round()}',
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
            // Macros row
            Row(
              children: [
                _NutritionTile(
                  label: 'PROTEIN',
                  value: '${(n.proteinG * _scaleFactor).round()}',
                  unit: 'g',
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 10),
                _NutritionTile(
                  label: 'CARBS',
                  value: '${(n.carbsG * _scaleFactor).round()}',
                  unit: 'g',
                  color: const Color(0xFF2196F3),
                ),
                const SizedBox(width: 10),
                _NutritionTile(
                  label: 'FAT',
                  value: '${(n.fatG * _scaleFactor).round()}',
                  unit: 'g',
                  color: const Color(0xFFFF9800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Fibre
            Row(
              children: [
                _NutritionTile(
                  label: 'FIBRE',
                  value: '${(n.fibreG * _scaleFactor).round()}',
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
    final kcalLabel = r.nutrition != null
        ? '${(r.nutrition!.calories * _scaleFactor).round()} kcal'
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
              if (r.dietaryTags.isNotEmpty)
                ElioStatBadge(
                  icon: Icons.local_dining_outlined,
                  value: r.dietaryTags.first,
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
                        : () => setState(() => _currentStep--),
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
                    : () => setState(() => _currentStep++),
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
