// Sprint 16 Phase 2 — HomeScreen is rendered inside AppShell, so build()
// returns only a body widget (Padding/Column). The editorial layout: hero
// heading, eyebrow, Generate button, optional "Plan your week" card for Pro.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_text_styles.dart';
import '../../models/elio_models.dart';
import '../../models/recipe_models.dart';
import '../../models/recipe_preferences.dart';
import 'recipe_preferences_screen.dart';
import '../../services/firestore_service.dart';
import '../../services/guest_pantry_service.dart';
import '../../services/history_service.dart';
import '../meal_plan/meal_plan_screen.dart';
import '../paywall/paywall_screen.dart';
import '../recipe/recipe_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/gemini_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_page_title.dart';
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
  List<String> _perishableInventoryNames = [];

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

  // ── Recent recipes peek (last 3 from local history) ────────────────
  List<SavedRecipe> _recentRecipes = [];

  @override
  void initState() {
    super.initState();
    // Sprint 15.9.2: defensive Gemini pre-warm. main.dart already fires this
    // at app launch, but warm-start scenarios (app backgrounded for 30+ min,
    // OS killed our HTTP/2 connection) leave the next Generate tap paying
    // the full cold-start tax. This re-fires whenever the user lands on
    // Home — fire-and-forget, errors swallowed inside the service.
    GeminiService.prewarmConnection();
    _loadUserData();
    _loadRecentRecipes();
    // Request notification permission on first HomeScreen load (non-blocking)
    if (!widget.isGuest) {
      NotificationService.instance.requestPermissionAndRegister();
      // Sprint 16.4 (Bug 1): kick off an entitlement refresh on first
      // build. EntitlementService starts as 'free' until refresh() loads
      // the proTesters list + queries RevenueCat — without this call,
      // the Plan-your-week card stays hidden on cold start for Pro users
      // and only appears after the user taps Generate (which is what
      // triggers refresh today). setState on completion so the card
      // pops in as soon as the answer is known.
      _entitlements.refresh().then((_) {
        if (mounted) setState(() {});
      });
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
        // Sprint 16.4 (Bug 2): collect perishables WITH their expiry so we
        // can sort the inventory-name list by urgency (earliest first,
        // null-expiry last). The picker uses that order to pre-select the
        // top-N most-urgent items as the default ("auto-select 3").
        final perishablesWithExpiry = <({String name, DateTime? expiry})>[];
        final perishableDescs = <String>[];
        for (final item in inventoryWithIds) {
          if (item['tier'] == 'perishable') {
            final name = item['name'] as String? ?? '';
            final rawExpiry = item['expiryDate'] as String?;
            DateTime? expiry;
            if (rawExpiry != null) expiry = DateTime.tryParse(rawExpiry);
            final invItem = InventoryItem(name: name, tier: 'perishable', expiryDate: expiry);
            perishableDescs.add(invItem.geminiDescription);
            if (name.isNotEmpty) {
              perishablesWithExpiry.add((name: name, expiry: expiry));
            }
          }
        }
        perishablesWithExpiry.sort((a, b) {
          if (a.expiry == null && b.expiry == null) return 0;
          if (a.expiry == null) return 1;
          if (b.expiry == null) return -1;
          return a.expiry!.compareTo(b.expiry!);
        });
        final perishableNames =
            perishablesWithExpiry.map((p) => p.name).toList();

        setState(() {
          _alwaysHave = List<String>.from(data['alwaysHave'] ?? []);
          _almostAlwaysHave = List<String>.from(data['almostAlwaysHave'] ?? []);
          _runningLowItems = List<String>.from(data['runningLowItems'] ?? []);
          _appliances = List<String>.from(data['appliances'] ?? []);
          _perishableDescriptions = perishableDescs;
          _perishableInventoryNames = perishableNames;
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

  // Sprint 15.9.3 SAFETY FIX: union of custom allergens across all
  // ACTIVE profiles. Threaded into RecipeGenerationRequest so the prompt
  // can emit a strong "Allergens — strictly excluded" line. Without
  // this, a peanut-allergy user could be served peanut butter.
  List<String> get _activeAllergens {
    final union = <String>{};
    for (final profile in _householdProfiles) {
      final id = profile['id'] as String;
      if (_deactivatedProfileIds.contains(id)) continue;
      final raw = (profile['allergens'] as List?) ??
          (profile['customAllergens'] as List?) ??
          const <dynamic>[];
      union.addAll(raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty));
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

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipePreferencesScreen(
          buildRequest: _buildRequest,
          onRecipeComplete: _onRecipeComplete,
          isGuest: widget.isGuest,
          activeDietary: _activeDietaryRequirements,
          customStyles: _customStyles,
          perishableInventory: _perishableInventoryNames,
        ),
      ),
    );
    // Refresh recents when the user lands back on Home (after popping
    // RecipeScreen — prefs push-replaces itself with RecipeScreen).
    if (mounted) _loadRecentRecipes();
  }

  Future<void> _loadRecentRecipes() async {
    final history = await HistoryService.getHistory();
    if (!mounted) return;
    setState(() => _recentRecipes = history.take(3).toList());
  }

  void _openRecentRecipe(SavedRecipe r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeScreen(
          recipe: r.recipe,
          isGuest: widget.isGuest,
          savedAt: r.savedAt,
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
    // Prefer perishables explicitly chosen on the prefs picker; fall back to
    // any auto-selected from the post-scan flow.
    final perishablesForRequest = prefs.useUpItems.isNotEmpty
        ? prefs.useUpItems
        : _selectedPerishables.toList();
    return RecipeGenerationRequest(
      perishables: perishablesForRequest,
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
      userRequest: prefs.userRequest,
      // Sprint 15.9.3 SAFETY FIX: thread allergens through so the
      // prompt's Allergens line gets populated. Without this the user's
      // custom allergens (e.g. "peanuts") are completely invisible to
      // Gemini.
      customAllergens: _activeAllergens,
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
      'perishable_count': request.perishables.length,
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

    // Sprint 16.4 (Bug 5): the home body is now scrollable. The
    // above-the-fold block fills exactly one viewport (hero + eyebrow +
    // Spacer + Generate + Plan-your-week). Recent recipes hang BELOW
    // the fold so the prime spot is reserved for Kate's incoming hero
    // image; they're still discoverable via a downward scroll.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ElioSpacing.screenEdge, ElioSpacing.lg,
                      ElioSpacing.screenEdge, ElioSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElioPageTitle('hey ${firstName.toLowerCase()}. lets get started'),
                      const SizedBox(height: ElioSpacing.md),
                      const ElioEyebrow('your kitchen is ready for elio'),
                      const Spacer(),
                      ElioBigButton(
                        label: 'Generate a recipe',
                        onTap: canGenerate ? _openPreferencesThenGenerate : null,
                      ),
                      // Free-tier weekly meter — explains why the CTA is
                      // disabled when the user hits their 7/week limit, and
                      // shows the running count under the cap. Hidden on
                      // Pro and on the guest pre-signin path (the latter
                      // has its own paywall trigger when the guest cap is
                      // hit during recipe-prefs flow).
                      if (!widget.isGuest && _entitlements.isFree) ...[
                        const SizedBox(height: ElioSpacing.sm),
                        _FreeTierMeter(
                          remaining: _entitlements.remainingGenerations,
                          daysUntilReset: _entitlements.daysUntilReset,
                          atLimit: !canGenerate,
                          onUpgrade: _showUpgradeDialog,
                        ),
                      ],
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
                ),
              ),
              if (_recentRecipes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ElioSpacing.screenEdge, ElioSpacing.lg,
                      ElioSpacing.screenEdge, ElioSpacing.lg),
                  child: _buildRecentRecipesPeek(),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Recent recipes peek (Sprint 16.3) ───────────────────────────
  // Compact horizontal row of up to 3 recent generations from local
  // history. Tap → push RecipeScreen. The full book lives on the
  // Recipes tab (AppShell); this is just a one-tap re-entry for
  // "the thing I cooked last night".
  Widget _buildRecentRecipesPeek() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'recent',
          style: ElioTextStyles.eyebrow.copyWith(color: ElioColors.terracotta),
        ),
        const SizedBox(height: ElioSpacing.sm),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recentRecipes.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: ElioSpacing.sm),
            itemBuilder: (_, i) => _buildRecentCard(_recentRecipes[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentCard(SavedRecipe r) {
    return GestureDetector(
      onTap: () => _openRecentRecipe(r),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(ElioSpacing.md),
        decoration: BoxDecoration(
          color: ElioColors.creamDeep,
          borderRadius: BorderRadius.circular(ElioRadii.panel),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              r.recipe.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ElioTextStyles.uiLabelStyle,
            ),
            Row(
              children: [
                const Icon(Icons.schedule,
                    size: 14, color: ElioColors.mocha),
                const SizedBox(width: 4),
                Text(
                  '${r.recipe.totalTimeMinutes} min',
                  style: ElioTextStyles.bodySmallStyle,
                ),
              ],
            ),
          ],
        ),
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

// ─── Free-tier weekly meter ──────────────────────────────────────────
//
// Sits directly under the Generate CTA on Home for signed-in free users.
// Two states:
//   • Under the cap → quiet "N of 7 free recipes left this week" caption.
//   • At the cap   → "You've used your 7 free recipes this week. Resets
//                    in N day(s)." + a small Upgrade-to-Pro text link
//                    that opens the paywall with `weekly_limit` context.
//
// Replaces the old "CTA just greys out with no explanation" UX —
// previously the disabled button looked like a bug.
class _FreeTierMeter extends StatelessWidget {
  final int remaining;
  final int daysUntilReset;
  final bool atLimit;
  final VoidCallback onUpgrade;

  const _FreeTierMeter({
    required this.remaining,
    required this.daysUntilReset,
    required this.atLimit,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    if (atLimit) {
      final daysLabel = daysUntilReset <= 1 ? 'tomorrow' : 'in $daysUntilReset days';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "You've used your 7 free recipes this week. Resets $daysLabel.",
            textAlign: TextAlign.center,
            style: ElioTextStyles.bodySmallStyle.copyWith(color: ElioColors.mocha),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onUpgrade,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Text(
                'Upgrade to Pro',
                style: ElioTextStyles.uiLabelStyle.copyWith(
                  color: ElioColors.terracotta,
                  decoration: TextDecoration.underline,
                  decorationColor: ElioColors.terracotta,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Center(
      child: Text(
        '$remaining of 7 free recipes left this week',
        textAlign: TextAlign.center,
        style: ElioTextStyles.bodySmallStyle.copyWith(color: ElioColors.mocha),
      ),
    );
  }
}
