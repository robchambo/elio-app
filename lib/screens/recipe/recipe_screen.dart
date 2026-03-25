import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/elio_theme.dart';
import '../../models/recipe_models.dart';
import '../../services/gemini_service.dart';
import '../../services/history_service.dart';
import '../../services/firestore_service.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // ── Regeneration state ──────────────────────────────────────────────────────────────────────────────
  bool _isRegenerating = false;
  final Set<String> _excludedIngredients = {};
  final FirestoreService _firestore = FirestoreService();

  // ── Rating state ──────────────────────────────────────────────────────────────────────────────
  bool? _userRating; // true = liked, false = disliked, null = not rated
  bool _isRating = false;

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.servings;
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
          _firestore.incrementDailyGenerations(),
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
        Row(
          children: [
            _MetaBadge(
              icon: Icons.timer_outlined,
              label: '${widget.recipe.totalTimeMinutes} min',
            ),
            const SizedBox(width: 8),
            _MetaBadge(
              icon: Icons.restaurant_outlined,
              label: '${widget.recipe.prepTimeMinutes} min prep',
            ),
            if (widget.recipe.dietaryTags.isNotEmpty) ...[
              const SizedBox(width: 8),
              _MetaBadge(
                icon: Icons.local_dining_outlined,
                label: widget.recipe.dietaryTags.first,
                color: ElioColors.sky,
              ),
            ],
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
                // ✕ exclude button
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _toggleExclude(ingredient.name),
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
            ),
          );
        }),
        if (_excludedIngredients.isNotEmpty) ...[
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
        // Generate Another — primary action
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.originalRequest != null ? _generateAnother : null,
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
        // Hands-Free Mode — secondary action
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _handsFreeMode = true;
                _currentStep = 0;
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
  Widget _buildHandsFreeMode() {
    final steps = widget.recipe.steps;
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == steps.length - 1;

    return Scaffold(
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => _handsFreeMode = false);
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                    },
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
                  Text(
                    widget.recipe.title,
                    style: ElioText.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ElioColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                                setState(() => _handsFreeMode = false);
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
    final c = color ?? ElioColors.navy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c,
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
