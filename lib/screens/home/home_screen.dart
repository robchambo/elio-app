// Sprint 16 Phase 2 — HomeScreen is rendered inside AppShell, so build()
// returns only a body widget (Padding/Column). The editorial layout: hero
// heading, eyebrow, Generate button, optional "Plan your week" card for Pro.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/elio_spacing.dart';
import '../../models/elio_models.dart';
import '../../models/recipe_models.dart';
import '../../models/recipe_preferences.dart';
import 'recipe_preferences_screen.dart';
import '../../services/firestore_service.dart';
import '../../services/guest_pantry_service.dart';
import '../meal_plan/meal_plan_screen.dart';
import '../paywall/paywall_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/entitlement_service.dart';
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

  // ── Household profiles (drives active dietary requirements) ────────
  List<Map<String, dynamic>> _householdProfiles = [];
  final Set<String> _deactivatedProfileIds = {};

  // ── Session deduplication memory (last 20 recipe titles) ─────────────
  final List<String> _recentTitles = [];

  // ── Taste profile (loaded eagerly so _buildRequest stays sync) ──────
  List<String> _likedRecipes = [];
  List<String> _dislikedRecipes = [];

  // ── Saved custom food styles (e.g. "Mediterranean") ────────────────
  List<String> _customStyles = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Request notification permission on first HomeScreen load (non-blocking)
    if (!widget.isGuest) {
      NotificationService.instance.requestPermissionAndRegister();
    }

    // If scanned items were passed in, pre-fill and open prefs (which then
    // owns the generation phase). User taps Generate from prefs as normal —
    // the auto-fire-on-mount behaviour was dropped with the editorial
    // rebuild because the user expects to confirm Time/Style/Mood first.
    if (widget.scannedItems != null && widget.scannedItems!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedPerishables.addAll(widget.scannedItems!);
        });
        _openPreferencesThenGenerate();
      });
    }
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
          _customStyles = List<String>.from(data['stylePreferences'] ?? []);
        });
      }
    } catch (_) {
      // Non-critical — user data will stay empty
    }

    // Taste profile (best-effort, signed-in only) — used by _buildRequest
    if (!widget.isGuest) {
      try {
        final tasteProfile = await _firestore.getTasteProfile();
        if (mounted) {
          setState(() {
            _likedRecipes = List<String>.from(tasteProfile['liked'] ?? []);
            _dislikedRecipes = List<String>.from(tasteProfile['disliked'] ?? []);
          });
        }
      } catch (_) {
        // Non-critical — proceed without taste profile
      }
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

  // ── Launch preferences screen — prefs now owns the generation phase ──
  // Sprint 16.3: gate the entitlement check here (before pushing prefs) so
  // the user never sees the prefs picker if they're already capped. The
  // prefs screen calls back into [_buildRequest] / [_onRecipeComplete] for
  // the request build + post-completion bookkeeping.
  Future<void> _openPreferencesThenGenerate() async {
    FocusScope.of(context).unfocus();

    // Free-tier cap check up front
    if (widget.isGuest) {
      final canGenerate = await EntitlementService.canGuestGenerate();
      if (!mounted) return;
      if (!canGenerate) {
        _showUpgradeDialog();
        return;
      }
    } else {
      await _entitlements.refresh();
      if (!mounted) return;
      if (!_entitlements.canGenerate) {
        _showUpgradeDialog();
        return;
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipePreferencesScreen(
          buildRequest: _buildRequest,
          onRecipeComplete: _onRecipeComplete,
          isGuest: widget.isGuest,
          activeDietary: _activeDietaryRequirements,
          customStyles: _customStyles,
        ),
      ),
    );
  }

  // ── Build the full RecipeGenerationRequest from chip prefs + Home state ──
  // Called synchronously by RecipePreferencesScreen when the user taps
  // Generate. Taste profile is fetched best-effort (signed-in only).
  RecipeGenerationRequest _buildRequest(RecipePreferences prefs) {
    // Note: taste profile is loaded eagerly in [_loadUserData] in a future
    // pass; for now we keep the prior best-effort behaviour but make the
    // request-build sync. If the eager load lands later this stays correct
    // (just reads the cached value).
    return RecipeGenerationRequest(
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
      isLeftoverMode: prefs.isLeftoverMode,
      leftoverItems: prefs.leftoverItems,
      likedRecipes: _likedRecipes,
      dislikedRecipes: _dislikedRecipes,
      appliances: _appliances,
      isSaverMode: prefs.isSaverMode,
      perishableInventoryDescriptions: _perishableDescriptions,
    );
  }

  // ── Post-completion bookkeeping (called from RecipePreferencesScreen) ──
  void _onRecipeComplete(
    GeneratedRecipe recipe,
    RecipeGenerationRequest request,
  ) {
    if (!mounted) return;
    // Track title for deduplication (keep last 20)
    _recentTitles.add(recipe.title);
    if (_recentTitles.length > 20) _recentTitles.removeAt(0);

    _analytics.logEvent('recipe_generated', {
      'perishable_count': _selectedPerishables.length,
      'is_guest': widget.isGuest,
    });

    // Background saves (Firestore, entitlements) — non-blocking
    _performBackgroundSaves(recipe);
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
