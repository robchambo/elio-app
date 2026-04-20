// Sprint 16 Phase 2 — HomeScreen is rendered inside AppShell, so build()
// returns only a body widget (Padding/Column). The editorial layout: hero
// heading, eyebrow, Generate button, optional "Plan your week" card for Pro.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_spacing.dart';
import '../../models/elio_models.dart';
import '../../models/recipe_models.dart';
import '../../models/recipe_preferences.dart';
import 'recipe_preferences_screen.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../../services/history_service.dart';
import '../../services/guest_pantry_service.dart';
import '../recipe/recipe_screen.dart';
import '../meal_plan/meal_plan_screen.dart';
import '../paywall/paywall_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/error_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_secondary_card.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;
  /// Pre-filled perishable items from scanning — triggers auto-generation.
  final List<String>? scannedItems;
  const HomeScreen({super.key, this.isGuest = false, this.scannedItems});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestore = FirestoreService();
  final AnalyticsService _analytics = AnalyticsService.instance;
  final EntitlementService _entitlements = EntitlementService.instance;

  // ── Perishables (populated by scannedItems for auto-generation) ──
  final Set<String> _selectedPerishables = {};

  // ── User data ──────────────────────────────────────────────────────────
  List<String> _alwaysHave = [];
  List<String> _almostAlwaysHave = [];
  List<String> _runningLowItems = [];
  List<String> _appliances = [];
  List<String> _perishableDescriptions = [];
  bool _isGenerating = false;
  StreamSubscription<RecipeGenerationStatus>? _generationSub;

  // ── Household profiles (drives active dietary requirements) ────────
  List<Map<String, dynamic>> _householdProfiles = [];
  final Set<String> _deactivatedProfileIds = {};

  // ── Session deduplication memory (last 20 recipe titles) ─────────────
  final List<String> _recentTitles = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Request notification permission on first HomeScreen load (non-blocking)
    if (!widget.isGuest) {
      NotificationService.instance.requestPermissionAndRegister();
    }

    // If scanned items were passed in, pre-fill and auto-generate
    if (widget.scannedItems != null && widget.scannedItems!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedPerishables.addAll(widget.scannedItems!);
        });
        _generateRecipe(const RecipePreferences.any());
      });
    }
  }

  @override
  void dispose() {
    _generationSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // Guest mode: load from SharedPreferences
    if (widget.isGuest) {
      final saved = await GuestPantryService.load();
      if (mounted && saved != null) {
        setState(() {
          _alwaysHave = List<String>.from(saved['alwaysHave'] ?? []);
          _almostAlwaysHave = List<String>.from(saved['almostAlwaysHave'] ?? []);
        });
      }
      return;
    }
    try {
      final data = await _firestore.getUserData();
      if (mounted) {
        // Build perishable descriptions from inventory for Gemini prompt
        final inventoryWithIds = List<Map<String, dynamic>>.from(
          (data['inventoryWithIds'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        final perishableDescs = <String>[];
        for (final item in inventoryWithIds) {
          if (item['tier'] == 'perishable') {
            final name = item['name'] as String? ?? '';
            final rawExpiry = item['expiryDate'] as String?;
            DateTime? expiry;
            if (rawExpiry != null) expiry = DateTime.tryParse(rawExpiry);
            final invItem = InventoryItem(name: name, tier: 'perishable', expiryDate: expiry);
            perishableDescs.add(invItem.geminiDescription);
          }
        }

        setState(() {
          _alwaysHave = List<String>.from(data['alwaysHave'] ?? []);
          _almostAlwaysHave = List<String>.from(data['almostAlwaysHave'] ?? []);
          _runningLowItems = List<String>.from(data['runningLowItems'] ?? []);
          _appliances = List<String>.from(data['appliances'] ?? []);
          _perishableDescriptions = perishableDescs;
          _householdProfiles = List<Map<String, dynamic>>.from(
            (data['householdProfiles'] as List?)?.map((p) => Map<String, dynamic>.from(p as Map)) ?? [],
          );
        });
      }
    } catch (_) {
      // Non-critical — user data will stay empty
    }
  }

  // ── Compute union of dietary requirements from all ACTIVE profiles ──
  List<String> get _activeDietaryRequirements {
    final union = <String>{};
    for (final profile in _householdProfiles) {
      final id = profile['id'] as String;
      if (_deactivatedProfileIds.contains(id)) continue;
      final reqs = List<String>.from(profile['dietaryRequirements'] ?? []);
      union.addAll(reqs);
    }
    return union.toList();
  }

  // ── Launch preferences screen, then generate ─────────────────────
  Future<void> _openPreferencesThenGenerate() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecipePreferencesScreen()),
    );
    if (!mounted) return;
    if (result is RecipePreferences) {
      await _generateRecipe(result);
    }
  }

  // ── Generate recipe ────────────────────────────────────────────────
  Future<void> _generateRecipe(RecipePreferences prefs) async {
    if (_isGenerating) return;

    // Dismiss keyboard before generation/navigation
    FocusScope.of(context).unfocus();

    // Check free tier cap
    if (widget.isGuest) {
      final canGenerate = await EntitlementService.canGuestGenerate();
      if (!canGenerate && mounted) {
        _showUpgradeDialog();
        return;
      }
    } else {
      await _entitlements.refresh();
      if (!_entitlements.canGenerate && mounted) {
        _showUpgradeDialog();
        return;
      }
    }

    setState(() => _isGenerating = true);

    // Load taste profile for adaptive learning (non-blocking, best-effort)
    List<String> likedRecipes = [];
    List<String> dislikedRecipes = [];
    if (!widget.isGuest) {
      try {
        final tasteProfile = await _firestore.getTasteProfile();
        likedRecipes = tasteProfile['liked'] ?? [];
        dislikedRecipes = tasteProfile['disliked'] ?? [];
      } catch (_) {
        // Non-critical — proceed without taste profile
      }
    }

    final request = RecipeGenerationRequest(
      perishables: _selectedPerishables.toList(),
      alwaysHave: _alwaysHave,
      almostAlwaysHave: _almostAlwaysHave,
      dietaryRequirements: _activeDietaryRequirements,
      timePreference: prefs.time,
      stylePreference: prefs.style,
      moodPreference: prefs.mood,
      servings: 2,
      recentTitles: List.from(_recentTitles),
      runningLowItems: List.from(_runningLowItems),
      isLeftoverMode: false,
      leftoverItems: const [],
      likedRecipes: likedRecipes,
      dislikedRecipes: dislikedRecipes,
      appliances: _appliances,
      isSaverMode: false,
      perishableInventoryDescriptions: _perishableDescriptions,
    );

    _generationSub = GeminiService.generateRecipeStream(request).listen(
      (status) {
        if (!mounted) return;
        switch (status) {
          case RecipeGenerating():
            // No UI message to update in the editorial layout.
            break;

          case RecipeComplete():
            final recipe = status.recipe;

            // Track title for deduplication (keep last 20)
            _recentTitles.add(recipe.title);
            if (_recentTitles.length > 20) _recentTitles.removeAt(0);

            // Save to history FIRST so RecipeScreen knows the savedAt
            final savedAt = DateTime.now().toUtc().toIso8601String();
            HistoryService.saveRecipe(SavedRecipe(
              recipe: recipe,
              savedAt: savedAt,
            ));

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecipeScreen(
                  recipe: recipe,
                  originalRequest: request,
                  isGuest: widget.isGuest,
                  savedAt: savedAt,
                ),
              ),
            );

            // Background saves (Firestore, entitlements) — non-blocking
            _performBackgroundSaves(recipe);

            _analytics.logEvent('recipe_generated', {
              'perishable_count': _selectedPerishables.length,
              'is_guest': widget.isGuest,
            });

            setState(() => _isGenerating = false);

          case RecipeError():
            _analytics.logEvent('recipe_generation_failed', {
              'error_type': 'stream_error',
            });
            _showGenerationError(status.message);
            setState(() => _isGenerating = false);
        }
      },
      onError: (e) {
        if (!mounted) return;
        _analytics.logEvent('recipe_generation_failed', {
          'error_type': e.runtimeType.toString(),
        });
        _showGenerationError(e.toString());
        setState(() => _isGenerating = false);
      },
      onDone: () {
        // Stream completed — if still generating, something went wrong
        if (mounted && _isGenerating) {
          setState(() => _isGenerating = false);
        }
      },
    );
  }

  Future<void> _performBackgroundSaves(GeneratedRecipe recipe) async {
    try {
      if (widget.isGuest) {
        await EntitlementService.recordGuestGeneration();
      } else {
        await Future.wait([
          _entitlements.recordGeneration(),
          _firestore.saveRecipe(recipe),
        ]);
      }
    } catch (_) {
      // Firestore save failure is non-critical — recipe is already shown
    }
  }

  void _showGenerationError(String raw) {
    ErrorService.log('recipe_generation', raw);
    if (!mounted) return;
    final String msg;
    if (raw.contains('SocketException') ||
        raw.contains('SocketFailed') ||
        raw.contains('ClientException') ||
        raw.contains('No address associated') ||
        raw.contains('Failed host lookup')) {
      msg = 'No internet connection. Please check your network and try again.';
    } else if (raw.contains('429') || raw.contains('quota') || raw.contains('rate limit')) {
      msg = 'Too many requests. Please wait a moment and try again.';
    } else if (raw.contains('401') || raw.contains('403') || raw.contains('API key') || raw.contains('access denied')) {
      msg = 'Authentication error. Please restart the app.';
    } else {
      msg = 'Something went wrong. Please try again.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ElioColors.navy,
        duration: const Duration(seconds: 5),
      ),
    );
  }

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

  // ─── Sprint 16: Editorial home body ─────────────────────────────────────
  // HomeScreen is rendered inside AppShell, which already provides the
  // top app bar and bottom nav. This build() returns a body widget only.
  @override
  Widget build(BuildContext context) {
    final firstName = _extractFirstName();
    final canGenerate = widget.isGuest || _entitlements.canGenerate;
    final proUnlocked = _entitlements.isPro;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ElioSpacing.screenEdge, ElioSpacing.lg,
          ElioSpacing.screenEdge, ElioSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElioHeroHeading(
            lines: ['hey ${firstName.toLowerCase()}.', 'lets get', 'started'],
            amberLastLine: true,
            showUnderline: true,
          ),
          const SizedBox(height: ElioSpacing.md),
          const ElioEyebrow('your kitchen is ready for elio'),
          const Spacer(),
          ElioBigButton(
            label: 'Generate a recipe',
            trailingIcon: Icons.chevron_right,
            loading: _isGenerating,
            onTap: canGenerate ? _openPreferencesThenGenerate : null,
          ),
          const SizedBox(height: ElioSpacing.md),
          if (proUnlocked)
            ElioSecondaryCard(
              title: 'Plan your week',
              subtitle: '21 meals generated in one tap',
              actionLabel: 'View',
              onAction: _openMealPlanner,
            ),
          const SizedBox(height: ElioSpacing.md),
        ],
      ),
    );
  }

  String _extractFirstName() {
    try {
      final displayName = FirebaseAuth.instance.currentUser?.displayName;
      if (displayName == null || displayName.isEmpty) return 'there';
      return displayName.split(' ').first;
    } catch (_) {
      return 'there';
    }
  }

  void _openMealPlanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MealPlanScreen()),
    );
  }
}
