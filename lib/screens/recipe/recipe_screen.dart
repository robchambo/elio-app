import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../theme/elio_theme.dart';
import '../../models/recipe_models.dart';
import '../../services/gemini_service.dart';
import '../../services/history_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/region_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/analytics_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/shopping_service.dart';

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

  const RecipeScreen({
    super.key,
    required this.recipe,
    this.originalRequest,
    this.isGuest = false,
  });

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  late int _servings;
  bool _handsFreeMode = false;
  int _currentStep = 0;
  final Set<int> _expandedSubstitutions = {};

  // ── Save & Shopping state ───────────────────────────────────────────────────
  bool _isSaved = false;
  bool _isAddingToShop = false;

  // ── Regeneration state ──────────────────────────────────────────────────────────────────────────────
  bool _isRegenerating = false;
  final Set<String> _excludedIngredients = {};
  final FirestoreService _firestore = FirestoreService();
  final AnalyticsService _analytics = AnalyticsService.instance;

  // ── Rating state ──────────────────────────────────────────────────────────────────────────────
  bool? _userRating; // true = liked, false = disliked, null = not rated
  bool _isRating = false;

  // ── Voice control state ────────────────────────────────────────────────────────────────────────
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

  // ── Cost estimate label ────────────────────────────────────────────────────────────────────────────────────────────────
  /// Returns a formatted cost-per-serving string based on device locale.
  /// Delegates to RegionUtils.formatCost() for locale-aware currency selection.
  String? get _costLabel => RegionUtils.formatCost(
    usd: widget.recipe.estimatedCostPerServingUSD,
    gbp: widget.recipe.estimatedCostPerServingGBP,
    suffix: '/serving',
  );

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.servings;
    _initTts();
  }

  @override
  void dispose() {
    _stopListening();
    _feedbackTimer?.cancel();
    _restartTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  // ── TTS setup ──────────────────────────────────────────────────────────────────
  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
    } catch (_) {
      // TTS init failure is non-critical
    }
  }

  Future<void> _speakText(String text) async {
    try {
      await _tts.speak(text);
    } catch (_) {
      // TTS failure is non-critical — silently ignore
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
            content: Text('Voice control unavailable — check microphone permissions.'),
            backgroundColor: ElioColors.navy,
          ),
        );
        return;
      }

      if (mounted) {
        setState(() => _voiceEnabled = true);
        if (!_voiceHelpShown) {
          _showVoiceHelpOverlay();
          _voiceHelpShown = true;
        }
        _startListening();
        // Read step 1 aloud when voice mode first activates
        _speakText(widget.recipe.steps[_currentStep]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice control unavailable — check microphone permissions.'),
            backgroundColor: ElioColors.navy,
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
    } catch (_) {
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
    if (_currentStep < widget.recipe.steps.length - 1) {
      setState(() => _currentStep++);
      _showVoiceFeedback('Got it — next step');
      _speakText(widget.recipe.steps[_currentStep]);
    } else {
      _showVoiceFeedback('Already on the last step');
    }
    _recognisedWords = '';
  }

  void _onVoiceBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _showVoiceFeedback('Got it — previous step');
      _speakText(widget.recipe.steps[_currentStep]);
    } else {
      _showVoiceFeedback('Already on the first step');
    }
    _recognisedWords = '';
  }

  void _onVoiceRepeat() {
    _showVoiceFeedback('Reading step aloud');
    _speakText(widget.recipe.steps[_currentStep]);
    _recognisedWords = '';
  }

  void _onVoiceDone() {
    _showVoiceFeedback('Exiting cooking mode');
    _stopListening();
    setState(() {
      _voiceEnabled = false;
      _handsFreeMode = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _analytics.logEvent('hands_free_exited', {
      'step_reached': _currentStep + 1,
      'total_steps': widget.recipe.steps.length,
      'exit_method': 'voice',
    });
    _recognisedWords = '';
  }

  void _showVoiceHelpOverlay() {
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ElioColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.mic_rounded, color: ElioColors.amber, size: 36),
            const SizedBox(height: 12),
            Text('Voice commands', style: ElioText.headingMedium),
            const SizedBox(height: 16),
            Text(
              "Say 'Hey Elio' followed by:",
              style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _buildVoiceHelpRow('"Hey Elio, next"', 'Go to the next step'),
            const SizedBox(height: 10),
            _buildVoiceHelpRow('"Hey Elio, back"', 'Go to the previous step'),
            const SizedBox(height: 10),
            _buildVoiceHelpRow('"Hey Elio, repeat"', 'Read the current step aloud'),
            const SizedBox(height: 10),
            _buildVoiceHelpRow('"Hey Elio, done"', 'Exit cooking mode'),
            const SizedBox(height: 20),
            Text(
              'Tap the mic button to turn voice control on/off',
              style: ElioText.bodyMedium.copyWith(
                color: ElioColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ElioColors.amber,
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
    );
  }

  Widget _buildVoiceHelpRow(String command, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ElioColors.navy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            command,
            style: ElioText.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: ElioColors.navy,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
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

  void _onExcludeIngredientTap(String ingredientName) {
    // Re-including: instant, no popup needed
    if (_excludedIngredients.contains(ingredientName)) {
      _toggleExclude(ingredientName);
      return;
    }

    // Check if the recipe already has a substitution for this ingredient
    final sub = widget.recipe.substitutions.where((s) {
      final original = s.original.toLowerCase();
      final name = ingredientName.toLowerCase();
      return original.contains(name) || name.contains(original);
    }).firstOrNull;

    if (sub == null) {
      // No substitution available — exclude silently
      _toggleExclude(ingredientName);
      return;
    }

    // Show substitution suggestion
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: ElioColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('No ${sub.original}?', style: ElioText.headingMedium),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
                children: [
                  const TextSpan(text: 'Try '),
                  TextSpan(
                    text: sub.substitute,
                    style: ElioText.bodyLarge.copyWith(
                      color: ElioColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: ' instead. ${sub.tradeOff}'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _toggleExclude(ingredientName);
                },
                child: Text('Got it — exclude ${sub.original}'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Keep it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAnother() async {
    if (_isRegenerating) return;
    final request = widget.originalRequest;
    if (request == null) {
      // No original request context — just pop back to home screen
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _isRegenerating = true);

    try {
      // Build updated request with exclusions and current recipe title as "recent"
      final newRequest = RecipeGenerationRequest(
        perishables: request.perishables,
        alwaysHave: request.alwaysHave,
        almostAlwaysHave: request.almostAlwaysHave,
        dietaryRequirements: request.dietaryRequirements,
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
          widget.recipe.title,
        ],
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
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegenerating = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: ElioColors.navy,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  Future<void> _rateRecipe(bool liked) async {
    if (_isRating || widget.isGuest) return;
    setState(() {
      _userRating = liked;
      _isRating = true;
    });
    _analytics.logEvent('recipe_rated', {
      'direction': liked ? 'up' : 'down',
      'recipe_title': widget.recipe.title,
    });
    try {
      await _firestore.rateRecipe(
        recipeTitle: widget.recipe.title,
        liked: liked,
        cuisineTags: widget.recipe.dietaryTags,
        dietaryTags: widget.recipe.dietaryTags,
      );
    } catch (_) {
      // Rating failure is non-critical — silently ignore
    } finally {
      if (mounted) setState(() => _isRating = false);
    }
  }

  void _showNutritionSheet() {
    final n = widget.recipe.nutrition;
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
                  color: ElioColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Nutrition per serving', style: ElioText.headingMedium),
            const SizedBox(height: 4),
            Text(
              'Based on $_servings serving${_servings == 1 ? '' : 's'}',
              style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
            ),
            const SizedBox(height: 20),
            // Calories — full width
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: ElioColors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ElioColors.amber.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Calories', style: ElioText.headingMedium.copyWith(color: ElioColors.amber)),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${(n.calories * _scaleFactor).round()}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: ElioColors.navy,
                          ),
                        ),
                        const TextSpan(
                          text: ' kcal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: ElioColors.textSecondary,
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
                color: ElioColors.textMuted,
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
              decoration: BoxDecoration(color: ElioColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.info_outline, color: ElioColors.amber, size: 32),
            const SizedBox(height: 12),
            Text('About cost estimates', style: ElioText.headingMedium),
            const SizedBox(height: 8),
            Text(
              "Elio's best estimate based on standard, non-premium ingredients. Actual costs may vary depending on where you shop!",
              style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
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

  Widget _buildRatingRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ElioColors.offWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ElioColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _userRating == null
                  ? 'How was this recipe?'
                  : _userRating == true
                      ? 'Glad you liked it! Elio will remember.'
                      : 'Noted. Elio will improve next time.',
              style: ElioText.bodyMedium.copyWith(
                color: _userRating == null ? ElioColors.textSecondary : ElioColors.navy,
                fontWeight: _userRating == null ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (!widget.isGuest) ...[
            _RatingButton(
              icon: Icons.thumb_up_outlined,
              iconFilled: Icons.thumb_up_rounded,
              isSelected: _userRating == true,
              color: const Color(0xFF2E7D32),
              onTap: () => _rateRecipe(true),
            ),
            const SizedBox(width: 8),
            _RatingButton(
              icon: Icons.thumb_down_outlined,
              iconFilled: Icons.thumb_down_rounded,
              isSelected: _userRating == false,
              color: const Color(0xFFC62828),
              onTap: () => _rateRecipe(false),
            ),
          ] else
            Text(
              'Sign in to rate',
              style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
            ),
        ],
      ),
    );
  }

  // ─── Save recipe ────────────────────────────────────────────────────────────
  Future<void> _saveRecipe() async {
    if (_isSaved) return; // Already saved
    try {
      await HistoryService.saveRecipe(SavedRecipe(
        recipe: widget.recipe,
        savedAt: DateTime.now().toUtc().toIso8601String(),
      ));
      if (mounted) {
        setState(() => _isSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Recipe saved'),
            backgroundColor: ElioColors.navy,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        AnalyticsService.instance.logEvent('recipe_saved', {
          'title': widget.recipe.title,
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

  // ─── Add ingredients to shopping list ──────────────────────────────────────
  Future<void> _addToShoppingList() async {
    if (widget.isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sign in to use the shopping list'),
          backgroundColor: ElioColors.navy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    setState(() => _isAddingToShop = true);
    try {
      final shop = ShoppingService.instance;
      int added = 0;
      for (final ing in widget.recipe.ingredients) {
        // Skip items the user already has in pantry
        if (ing.fromInventory) continue;
        final qty = ing.unit.isEmpty
            ? _scaleQuantity(ing.quantity)
            : '${_scaleQuantity(ing.quantity)} ${ing.unit}';
        await shop.addItem(
          name: ing.name,
          quantity: qty,
          source: ShoppingSource.recipe,
        );
        added++;
      }
      if (mounted) {
        setState(() => _isAddingToShop = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$added item${added == 1 ? '' : 's'} added to shopping list'),
            backgroundColor: ElioColors.navy,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        AnalyticsService.instance.logEvent('recipe_added_to_shopping', {
          'title': widget.recipe.title,
          'item_count': added,
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAddingToShop = false);
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

  void _shareRecipe() {
    final r = widget.recipe;
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
          : '${_scaleQuantity(ing.quantity)} ${ing.unit}';
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

  // ─── Normal mode ─────────────────────────────────────────────────────────────
  Widget _buildNormalMode() {
    return Scaffold(
      backgroundColor: ElioColors.white,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaRow(),
                  const SizedBox(height: 20),
                  _buildServingScaler(),
                  const SizedBox(height: 28),
                  _buildIngredientsSection(),
                  const SizedBox(height: 28),
                  _buildMethodSection(),
                  if (widget.recipe.substitutions.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _buildSubstitutionsSection(),
                  ],
                  const SizedBox(height: 28),
                  _buildRatingRow(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: ElioColors.white,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ElioColors.navy, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        // Save recipe
        IconButton(
          icon: Icon(
            _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: _isSaved ? ElioColors.amber : ElioColors.navy,
            size: 22,
          ),
          tooltip: _isSaved ? 'Saved' : 'Save recipe',
          onPressed: _saveRecipe,
        ),
        // Add ingredients to shopping list
        IconButton(
          icon: _isAddingToShop
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ElioColors.navy),
                )
              : const Icon(Icons.add_shopping_cart_rounded, color: ElioColors.navy, size: 22),
          tooltip: 'Add to shopping list',
          onPressed: _isAddingToShop ? null : _addToShoppingList,
        ),
        // Share
        IconButton(
          icon: const Icon(Icons.ios_share_rounded, color: ElioColors.navy, size: 22),
          tooltip: 'Share recipe',
          onPressed: _shareRecipe,
        ),
        const SizedBox(width: 4),
      ],
      expandedHeight: 0,
      title: Text(
        widget.recipe.title,
        style: GoogleFonts.outfit(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: ElioColors.navy,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMetaRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.recipe.title, style: ElioText.displayMedium),
        const SizedBox(height: 8),
        if (widget.recipe.description.isNotEmpty) ...[
          Text(widget.recipe.description, style: ElioText.bodyLarge),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetaBadge(
              icon: Icons.timer_outlined,
              label: '${widget.recipe.totalTimeMinutes} min',
            ),
            _MetaBadge(
              icon: Icons.restaurant_outlined,
              label: '${widget.recipe.prepTimeMinutes} min prep',
            ),
            if (widget.recipe.dietaryTags.isNotEmpty)
              _MetaBadge(
                icon: Icons.local_dining_outlined,
                label: widget.recipe.dietaryTags.first,
                color: ElioColors.sky,
              ),
            if (widget.recipe.nutrition != null)
              GestureDetector(
                onTap: _showNutritionSheet,
                child: _MetaBadge(
                  icon: Icons.monitor_heart_outlined,
                  label: '${widget.recipe.nutrition!.calories} kcal',
                ),
              ),
            if (_costLabel != null)
              GestureDetector(
                onTap: _showCostInfoSheet,
                child: _MetaBadge(
                  icon: Icons.shopping_basket_outlined,
                  label: _costLabel!,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildServingScaler() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ElioColors.offWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ElioColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_outline, color: ElioColors.navy, size: 20),
          const SizedBox(width: 10),
          Text('Servings', style: ElioText.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: _servings > 1 ? () => setState(() => _servings--) : null,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _servings > 1 ? ElioColors.navy : ElioColors.border,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.remove, color: Colors.white, size: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$_servings',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ElioColors.navy,
              ),
            ),
          ),
          GestureDetector(
            onTap: _servings < 12 ? () => setState(() => _servings++) : null,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _servings < 12 ? ElioColors.navy : ElioColors.border,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canExcludeIngredients => widget.originalRequest != null;

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Ingredients', style: ElioText.headingMedium),
            const Spacer(),
            if (widget.recipe.ingredients.any((i) => i.fromInventory))
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: ElioColors.amber.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      border: Border.all(color: ElioColors.amber, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'from your fridge',
                    style: ElioText.label.copyWith(color: ElioColors.textSecondary),
                  ),
                ],
              ),
          ],
        ),
        if (_canExcludeIngredients) ...[
          if (_excludedIngredients.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Tap ✕ to exclude an ingredient from the next generation.',
              style: ElioText.label.copyWith(color: ElioColors.textMuted),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Tap ✕ on any ingredient to exclude it.',
              style: ElioText.label.copyWith(color: ElioColors.textMuted),
            ),
          ],
        ],
        const SizedBox(height: 10),
        ...widget.recipe.ingredients.map((ingredient) {
          final isExcluded = _excludedIngredients.contains(ingredient.name);
          final isFromInventory = ingredient.fromInventory && !isExcluded;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isExcluded
                  ? const Color(0xFFF5F5F5)
                  : isFromInventory
                      ? ElioColors.amber.withValues(alpha: 0.07)
                      : ElioColors.offWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isExcluded
                    ? ElioColors.border
                    : isFromInventory
                        ? ElioColors.amber.withValues(alpha: 0.4)
                        : ElioColors.border,
              ),
            ),
            child: Row(
              children: [
                // Colour dot
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isExcluded
                        ? ElioColors.border
                        : isFromInventory
                            ? ElioColors.amber
                            : ElioColors.border,
                    shape: BoxShape.circle,
                  ),
                ),
                // Name
                Expanded(
                  child: Text(
                    ingredient.name,
                    style: ElioText.bodyMedium.copyWith(
                      fontWeight: isFromInventory ? FontWeight.w600 : FontWeight.w400,
                      color: isExcluded ? ElioColors.textMuted : ElioColors.textPrimary,
                      decoration: isExcluded ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                // Quantity
                if (!isExcluded)
                  Text(
                    ingredient.unit.isEmpty
                        ? _scaleQuantity(ingredient.quantity)
                        : '${_scaleQuantity(ingredient.quantity)} ${ingredient.unit}',
                    style: ElioText.bodyMedium.copyWith(
                      color: ElioColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                // ✕ exclude button (only when Generate Another is available)
                if (_canExcludeIngredients) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _onExcludeIngredientTap(ingredient.name),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isExcluded
                            ? ElioColors.navy.withValues(alpha: 0.08)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isExcluded ? Icons.add_rounded : Icons.close_rounded,
                        size: 16,
                        color: isExcluded ? ElioColors.navy : ElioColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        if (_canExcludeIngredients && _excludedIngredients.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '${_excludedIngredients.length} ingredient${_excludedIngredients.length == 1 ? '' : 's'} excluded — tap "Generate Another" to apply.',
            style: ElioText.label.copyWith(color: ElioColors.amber),
          ),
        ],
      ],
    );
  }

  Widget _buildMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Method', style: ElioText.headingMedium),
        const SizedBox(height: 12),
        ...widget.recipe.steps.asMap().entries.map((entry) {
          final stepNum = entry.key + 1;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: ElioColors.navy,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$stepNum',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(step, style: ElioText.bodyLarge),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSubstitutionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Substitution tips', style: ElioText.headingMedium),
        const SizedBox(height: 12),
        ...widget.recipe.substitutions.asMap().entries.map((entry) {
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
                color: ElioColors.sky.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ElioColors.sky.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded, color: ElioColors.sky, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Instead of ${sub.original} → ${sub.substitute}',
                          style: ElioText.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: ElioColors.navy,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: ElioColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                  if (isExpanded && sub.tradeOff.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      sub.tradeOff,
                      style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
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

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Generate Another — only when there's original request context
        if (widget.originalRequest != null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateAnother,
              icon: _isRegenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
              label: Text(_isRegenerating ? 'Generating...' : 'Generate Another'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ElioColors.amber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Hands-Free Mode — always available
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _handsFreeMode = true;
                _currentStep = 0;
              });
              _analytics.logEvent('hands_free_started', {
                'step_count': widget.recipe.steps.length,
              });
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            },
            icon: const Icon(Icons.visibility_outlined, size: 20),
            label: const Text('Start Hands-Free Mode'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ElioColors.navy,
              side: const BorderSide(color: ElioColors.navy, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Hands-Free Mode ─────────────────────────────────────────────────────────

  void _exitHandsFreeMode({String exitMethod = 'button'}) {
    _stopListening();
    _tts.stop();
    _analytics.logEvent('hands_free_exited', {
      'step_reached': _currentStep + 1,
      'total_steps': widget.recipe.steps.length,
      'exit_method': exitMethod,
    });
    setState(() {
      _handsFreeMode = false;
      _voiceEnabled = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Widget _buildHandsFreeMode() {
    final steps = widget.recipe.steps;
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == steps.length - 1;

    return Scaffold(
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header row: Exit, mic, title, step counter ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  // Exit button
                  GestureDetector(
                    onTap: () => _exitHandsFreeMode(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: ElioColors.offWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ElioColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.close, size: 16, color: ElioColors.navy),
                          const SizedBox(width: 4),
                          Text('Exit', style: ElioText.label.copyWith(color: ElioColors.navy)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mic button
                  GestureDetector(
                    onTap: _toggleVoiceControl,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _voiceEnabled
                            ? ElioColors.amber.withValues(alpha: 0.15)
                            : ElioColors.offWhite,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _voiceEnabled ? ElioColors.amber : ElioColors.border,
                          width: _voiceEnabled ? 2.0 : 1.0,
                        ),
                        boxShadow: _isListening
                            ? [
                                BoxShadow(
                                  color: ElioColors.amber.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _voiceEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                        size: 20,
                        color: _voiceEnabled ? ElioColors.amber : ElioColors.textMuted,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Recipe title
                  Flexible(
                    child: Text(
                      widget.recipe.title,
                      style: ElioText.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ElioColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Step counter
                  Text(
                    '${_currentStep + 1} / ${steps.length}',
                    style: ElioText.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ElioColors.navy,
                    ),
                  ),
                ],
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
                    color: ElioColors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ElioColors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hearing_rounded, size: 16, color: ElioColors.amber),
                      const SizedBox(width: 8),
                      Text(
                        _voiceFeedback,
                        style: ElioText.bodyMedium.copyWith(
                          color: ElioColors.navy,
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
                        color: i <= _currentStep ? ElioColors.amber : ElioColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // ── Step content ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${_currentStep + 1}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ElioColors.amber,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      steps[_currentStep],
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: ElioColors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Navigation buttons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: OutlinedButton(
                        onPressed: isFirst
                            ? null
                            : () => setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ElioColors.navy,
                          side: BorderSide(
                            color: isFirst ? ElioColors.border : ElioColors.navy,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('← Back'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        onPressed: isLast
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ElioColors.amber,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          isLast ? 'Done ✓' : 'Next →',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
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

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetaBadge({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? ElioColors.navy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  final IconData icon;
  final IconData iconFilled;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _RatingButton({
    required this.icon,
    required this.iconFilled,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : ElioColors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? color : ElioColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Icon(
          isSelected ? iconFilled : icon,
          size: 20,
          color: isSelected ? color : ElioColors.textSecondary,
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
                      color: ElioColors.navy,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: ElioColors.textSecondary,
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
