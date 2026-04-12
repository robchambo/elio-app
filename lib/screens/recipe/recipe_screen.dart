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

  // ── Mutable recipe (supports in-place ingredient swaps) ────────────────────
  late GeneratedRecipe _currentRecipe;
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
    usd: _currentRecipe.estimatedCostPerServingUSD,
    gbp: _currentRecipe.estimatedCostPerServingGBP,
    suffix: '/serving',
  );

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.servings;
    _currentRecipe = widget.recipe;
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
        _speakText(_currentRecipe.steps[_currentStep]);
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
    _showVoiceFeedback('Exiting cooking mode');
    _stopListening();
    setState(() {
      _voiceEnabled = false;
      _handsFreeMode = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _analytics.logEvent('hands_free_exited', {
      'step_reached': _currentStep + 1,
      'total_steps': _currentRecipe.steps.length,
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Swapped ${ingredient.name} → ${result.substitute}'),
              backgroundColor: ElioColors.navy,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 3),
            ),
          );
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
          backgroundColor: ElioColors.navy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
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
    try {
      final qty = ingredient.unit.isEmpty
          ? _scaleQuantity(ingredient.quantity)
          : '${_scaleQuantity(ingredient.quantity)} ${ingredient.unit}';
      await ShoppingService.instance.addItem(
        name: ingredient.name,
        quantity: qty,
        source: ShoppingSource.recipe,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ingredient.name} added to shopping list'),
            backgroundColor: ElioColors.navy,
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
          _currentRecipe.title,
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
        recipe: _currentRecipe,
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
      for (final ing in _currentRecipe.ingredients) {
        // Skip items the user already has, and universal staples
        if (ing.fromInventory) continue;
        if (_isShoppingExclusion(ing.name)) continue;
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
          'title': _currentRecipe.title,
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
      backgroundColor: ElioColors.scaffold,
      bottomNavigationBar: _buildMarkAsCookedBar(),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          // Hero illustration
          SliverToBoxAdapter(child: _buildHeroSection()),
          // Title, stats and content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaRow(),
                  const SizedBox(height: 28),
                  _buildServingScaler(),
                  const SizedBox(height: 40),
                  _buildIngredientsSection(),
                  const SizedBox(height: 40),
                  _buildMethodSection(),
                  if (_currentRecipe.substitutions.isNotEmpty) ...[
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

  // ─── Hero illustration section ────────────────────────────────────────────────
  // Vibrant Editorial — warmOrange full-width hero with abstract pasta bowl shapes.
  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      height: 300,
      color: ElioColors.warmOrange,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Glow behind bowl
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 220,
                height: 80,
                decoration: BoxDecoration(
                  color: ElioColors.amber.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
          ),
          // Bowl base
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 200,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(80),
                    bottomRight: Radius.circular(80),
                  ),
                ),
              ),
            ),
          ),
          // Pasta strands (abstract pill shapes)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 180,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: 0.21,
                      child: Container(height: 14, width: 128, decoration: BoxDecoration(color: const Color(0xFFFFDBCB), borderRadius: BorderRadius.circular(9999))),
                    ),
                    Transform.translate(
                      offset: const Offset(0, 22),
                      child: Transform.rotate(
                        angle: -0.10,
                        child: Container(height: 14, width: 96, decoration: BoxDecoration(color: const Color(0xFFE2BFB0), borderRadius: BorderRadius.circular(9999))),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, 42),
                      child: Transform.rotate(
                        angle: 0.05,
                        child: Container(height: 14, width: 144, decoration: BoxDecoration(color: const Color(0xFFFFDBCB), borderRadius: BorderRadius.circular(9999))),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, 60),
                      child: Transform.rotate(
                        angle: -0.21,
                        child: Container(height: 14, width: 112, decoration: BoxDecoration(color: const Color(0xFFFFDCBB), borderRadius: BorderRadius.circular(9999))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Lemon wedge — top right
          Positioned(
            top: 36,
            right: 72,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ElioColors.amber,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
              ),
            ),
          ),
          // Lemon wedge — smaller, left
          Positioned(
            top: 72,
            left: 80,
            child: Transform.rotate(
              angle: -0.52,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ElioColors.amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mark as Cooked bottom bar ────────────────────────────────────────────────
  Widget _buildMarkAsCookedBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      color: ElioColors.scaffold,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.check_circle_outline, size: 20, color: Colors.white),
          label: Text(
            'Mark as Cooked',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: ElioColors.heroOrange,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: ElioColors.cardSurface,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      expandedHeight: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ElioColors.dark, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'elio',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: ElioColors.heroOrange,
          letterSpacing: -1.2,
        ),
      ),
      actions: [
        // Save / heart
        IconButton(
          icon: Icon(
            _isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: _isSaved ? ElioColors.heroOrange : ElioColors.dark,
            size: 22,
          ),
          tooltip: _isSaved ? 'Saved' : 'Save recipe',
          onPressed: _saveRecipe,
        ),
        // Share
        IconButton(
          icon: const Icon(Icons.ios_share_rounded, color: ElioColors.dark, size: 22),
          tooltip: 'Share recipe',
          onPressed: _shareRecipe,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMetaRow() {
    // Difficulty derived from dietary tags or defaulted to "Easy"
    final difficulty = _currentRecipe.dietaryTags.isNotEmpty
        ? _currentRecipe.dietaryTags.first
        : 'Easy';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: ElioColors.cardSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "RECIPE OF THE DAY" amber pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: ElioColors.amber,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              'RECIPE OF THE DAY',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF663C00),
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Large editorial title — lowercase, heroOrange
          Text(
            _currentRecipe.title.toLowerCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 56,
              fontWeight: FontWeight.w700,
              color: ElioColors.heroOrange,
              letterSpacing: -3.0,
              height: 0.9,
            ),
          ),
          const SizedBox(height: 32),
          // Stats bento grid — TIME · SERVINGS · DIFFICULTY
          Row(
            children: [
              Expanded(child: _buildStatCard(
                label: 'TIME',
                value: '${_currentRecipe.totalTimeMinutes}m',
                icon: Icons.timer_outlined,
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(
                label: 'SERVINGS',
                value: '$_servings',
                icon: Icons.people_outline,
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(
                label: 'DIFFICULTY',
                value: difficulty,
                icon: Icons.star_outline_rounded,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ElioColors.scaffold,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ElioColors.textPrimary.withOpacity(0.4)),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: ElioColors.textPrimary.withOpacity(0.4),
              letterSpacing: 1.0,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: ElioColors.textPrimary,
            ),
          ),
        ],
      ),
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
            if (_currentRecipe.ingredients.any((i) => i.fromInventory))
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
        const SizedBox(height: 4),
        Text(
          'Tap any ingredient for options',
          style: ElioText.label.copyWith(color: ElioColors.textMuted),
        ),
        const SizedBox(height: 24),
        ..._currentRecipe.ingredients.map((ingredient) {
          final isExcluded = _excludedIngredients.contains(ingredient.name);
          final isFromInventory = ingredient.fromInventory && !isExcluded;
          return GestureDetector(
            onTap: () => _showIngredientOptions(ingredient),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circle outline bullet — Figma style
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isExcluded
                              ? ElioColors.border
                              : isFromInventory
                                  ? ElioColors.amber
                                  : ElioColors.heroOrange,
                          width: 2,
                        ),
                        color: isExcluded ? ElioColors.border.withOpacity(0.2) : Colors.transparent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Name + quantity + hint
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                ingredient.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: isFromInventory ? FontWeight.w600 : FontWeight.w400,
                                  color: isExcluded ? ElioColors.textMuted : ElioColors.textPrimary,
                                  decoration: isExcluded ? TextDecoration.lineThrough : null,
                                  height: 1.55,
                                ),
                              ),
                            ),
                            if (!isExcluded)
                              Text(
                                ingredient.unit.isEmpty
                                    ? _scaleQuantity(ingredient.quantity)
                                    : '${_scaleQuantity(ingredient.quantity)} ${ingredient.unit}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: ElioColors.textPrimary.withOpacity(0.6),
                                ),
                              ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _showIngredientOptions(ingredient),
                              child: Icon(
                                isExcluded ? Icons.add_rounded : Icons.close_rounded,
                                size: 16,
                                color: ElioColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

  // ─── Method section ──────────────────────────────────────────────────────────
  // Vibrant Editorial — large warmOrange step numbers, editorial typography.
  Widget _buildMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section heading
        Text(
          'Method',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ElioColors.taupe,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        ..._currentRecipe.steps.asMap().entries.map((entry) {
          final stepNum = entry.key + 1;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Divider line above each step
                Container(
                  height: 1,
                  color: ElioColors.taupe.withOpacity(0.15),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Large editorial step number
                    Text(
                      '$stepNum',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        color: ElioColors.warmOrange,
                        height: 0.85,
                        letterSpacing: -3,
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Step text
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          step,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: ElioColors.dark.withOpacity(0.80),
                            height: 1.55,
                          ),
                        ),
                      ),
                    ),
                  ],
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
                textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
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
                'step_count': _currentRecipe.steps.length,
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
                      _currentRecipe.title,
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
                      style: GoogleFonts.plusJakartaSans(
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
                          style: GoogleFonts.plusJakartaSans(
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
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
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
                color: ElioColors.border,
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
    final qty = ing.unit.isEmpty ? ing.quantity : '${ing.quantity} ${ing.unit}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Don't have this?", style: ElioText.headingMedium),
        const SizedBox(height: 4),
        Text(
          '${ing.name}${qty.isNotEmpty ? ' — $qty' : ''}',
          style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
        ),
        if (ing.fromInventory) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ElioColors.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'This is from your pantry',
                style: ElioText.label.copyWith(color: ElioColors.textSecondary),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // Option 1: Suggest substitution
        _buildOptionTile(
          icon: Icons.swap_horiz_rounded,
          iconColor: ElioColors.sky,
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
              iconColor: ElioColors.amber,
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
          iconColor: ElioColors.navy,
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
          color: ElioColors.offWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ElioColors.border),
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
                      color: locked ? ElioColors.textMuted : ElioColors.textPrimary,
                    ),
                  ),
                  Text(
                    locked ? 'Sign in to use' : subtitle,
                    style: ElioText.label.copyWith(color: ElioColors.textMuted),
                  ),
                ],
              ),
            ),
            if (locked)
              const Icon(Icons.lock_outline_rounded, size: 18, color: ElioColors.textMuted)
            else
              const Icon(Icons.chevron_right_rounded, size: 20, color: ElioColors.textMuted),
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
                color: ElioColors.amber,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Finding a substitution...',
              style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final r = _result!;
    final qty = r.unit.isEmpty ? r.adjustedQuantity : '${r.adjustedQuantity} ${r.unit}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: ElioColors.sky, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Instead of ${widget.ingredient.name}',
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ElioColors.sky.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ElioColors.sky.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.substitute,
                style: ElioText.headingMedium.copyWith(color: ElioColors.navy),
              ),
              if (qty.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(qty, style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary)),
              ],
              if (r.tradeOff.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(r.tradeOff, style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary)),
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
              backgroundColor: ElioColors.navy,
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
              side: const BorderSide(color: ElioColors.border),
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
          style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _requestSubstitution,
            style: ElevatedButton.styleFrom(
              backgroundColor: ElioColors.navy,
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
              side: const BorderSide(color: ElioColors.border),
            ),
            child: const Text('Dismiss'),
          ),
        ),
      ],
    );
  }
}
