import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/elio_theme.dart';
import '../../models/elio_models.dart';
import '../../models/recipe_models.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../../services/history_service.dart';
import '../../services/guest_pantry_service.dart';
import '../recipe/recipe_screen.dart';
import '../history/history_screen.dart';
import '../meal_plan/meal_plan_screen.dart';
import '../profile/profile_screen.dart';
import '../paywall/paywall_screen.dart';
import '../add/add_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/analytics_service.dart';
import '../../services/entitlement_service.dart';

// ─────────────────────────────────────────────
// HomeScreen
// Design philosophy: approachable utility.
// Single-purpose screen: tell Elio what's fresh,
// optionally set a mood, then tap Generate.
//
// Layout:
//   • Elio wordmark header + profile avatar
//   • Active dietary filter strip (household union)
//   • "What's fresh today?" dual-mode input
//   • Mood chips (Time / Style / Mood rows)
//   • Large amber Generate button
//   • Recent recipes list (below fold)
// ─────────────────────────────────────────────

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
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();

  // ── Perishables state ──────────────────────────────────────────────
  final Set<String> _selectedPerishables = {};

  // ── Mood chips state ───────────────────────────────────────────────
  String? _selectedTime;
  String? _selectedStyle;
  String? _selectedMood;

  // ── User data ──────────────────────────────────────────────────────────
  List<String> _stylePreferences = [];
  List<String> _alwaysHave = [];
  List<String> _almostAlwaysHave = [];
  List<String> _runningLowItems = []; // items flagged as running low
  List<String> _appliances = [];
  List<String> _perishableDescriptions = [];
  int _expiringItemCount = 0;
  bool _showExpiryBanner = true;
  bool _saverMode = false;
  bool _isLoading = true;
  bool _isGenerating = false;

  // ── Household profiles for dietary filter strip ────────────────────
  // Each entry: { 'id': String, 'name': String, 'dietaryRequirements': List<String>, 'isOwner': bool }
  List<Map<String, dynamic>> _householdProfiles = [];
  // Set of profile IDs that are currently DEACTIVATED for this session
  final Set<String> _deactivatedProfileIds = {};

  // ── Recent history ─────────────────────────────────────────────────
  List<SavedRecipe> _recentRecipes = [];

  // ── Saved meal plan ──────────────────────────────────────────────
  bool _hasSavedMealPlan = false;

  // ── Session deduplication memory (last 10 recipe titles) ─────────────
  final List<String> _recentTitles = [];

  // ── Recent custom styles (persisted in SharedPreferences) ────────
  List<String> _recentCustomStyles = [];

  // ── Leftover mode ─────────────────────────────────────────────────
  bool _isLeftoverMode = false;
  final Set<String> _leftoverItems = {};
  final TextEditingController _leftoverController = TextEditingController();
  static const List<String> _commonLeftovers = [
    'Roast chicken', 'Cooked rice', 'Pasta', 'Roast vegetables',
    'Mashed potato', 'Cooked salmon', 'Bread', 'Cooked lentils',
    'Bolognese', 'Soup', 'Steak', 'Cooked beans',
  ];

  // ── Common quick-tap perishables ───────────────────────────────────
  static const List<String> _commonPerishables = [
    'Chicken breast', 'Eggs', 'Spinach', 'Tomatoes', 'Bell peppers',
    'Broccoli', 'Salmon', 'Minced beef', 'Mushrooms', 'Courgette',
    'Sweet potato', 'Avocado', 'Lemon', 'Greek yoghurt', 'Bacon',
    'Prawns', 'Tofu', 'Aubergine', 'Kale', 'Carrots',
  ];

  // ── Time chips ─────────────────────────────────────────────────────
  static const List<String> _timeChips = [
    'Quick (under 20 min)', '30 minutes', 'No rush',
  ];

  // ── Mood chips ─────────────────────────────────────────────────────
  static const List<String> _moodChips = [
    'Something hearty', 'Light bite', 'Impress someone', 'Use everything up',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRecentHistory();
    _checkSavedMealPlan();
    // Custom styles are session-only — not loaded from storage

    // If scanned items were passed in, pre-fill and auto-generate
    if (widget.scannedItems != null && widget.scannedItems!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedPerishables.addAll(widget.scannedItems!);
        });
        _generateRecipe();
      });
    }
  }

  Future<void> _loadRecentHistory() async {
    final all = await HistoryService.getHistory();
    if (mounted) setState(() => _recentRecipes = all.take(3).toList());
  }

  Future<void> _checkSavedMealPlan() async {
    if (widget.isGuest) return;
    try {
      final plan = await _firestore.loadMealPlan();
      if (mounted) setState(() => _hasSavedMealPlan = plan != null);
    } catch (_) {}
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();
    _leftoverController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // Guest mode: load from SharedPreferences
    if (widget.isGuest) {
      final saved = await GuestPantryService.load();
      if (mounted) {
        setState(() {
          if (saved != null) {
            _alwaysHave = List<String>.from(saved['alwaysHave'] ?? []);
            _almostAlwaysHave = List<String>.from(saved['almostAlwaysHave'] ?? []);
            _stylePreferences = List<String>.from(saved['stylePreferences'] ?? []);
          }
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final data = await _firestore.getUserData();
      if (mounted) {
        // Build perishable descriptions from inventory
        final inventoryWithIds = List<Map<String, dynamic>>.from(
          (data['inventoryWithIds'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        final perishableDescs = <String>[];
        int expiringCount = 0;
        for (final item in inventoryWithIds) {
          if (item['tier'] == 'perishable') {
            final name = item['name'] as String? ?? '';
            final rawExpiry = item['expiryDate'] as String?;
            DateTime? expiry;
            if (rawExpiry != null) expiry = DateTime.tryParse(rawExpiry);
            final invItem = InventoryItem(name: name, tier: 'perishable', expiryDate: expiry);
            perishableDescs.add(invItem.geminiDescription);
            if (expiry != null) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
              final diff = expiryDay.difference(today).inDays;
              if (diff <= 1) expiringCount++;
            }
          }
        }

        setState(() {
          _stylePreferences = List<String>.from(data['stylePreferences'] ?? []);
          _alwaysHave = List<String>.from(data['alwaysHave'] ?? []);
          _almostAlwaysHave = List<String>.from(data['almostAlwaysHave'] ?? []);
          _runningLowItems = List<String>.from(data['runningLowItems'] ?? []);
          _appliances = List<String>.from(data['appliances'] ?? []);
          _perishableDescriptions = perishableDescs;
          _expiringItemCount = expiringCount;
          _householdProfiles = List<Map<String, dynamic>>.from(
            (data['householdProfiles'] as List?)?.map((p) => Map<String, dynamic>.from(p as Map)) ?? [],
          );
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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

  // ── All dietary constraints across all profiles (for display) ──────
  // Returns a list of { 'label': String, 'profileName': String, 'profileId': String }
  List<Map<String, String>> get _allDietaryConstraints {
    final seen = <String>{};
    final result = <Map<String, String>>[];
    for (final profile in _householdProfiles) {
      final id = profile['id'] as String;
      final name = profile['name'] as String;
      final reqs = List<String>.from(profile['dietaryRequirements'] ?? []);
      for (final req in reqs) {
        final key = '${id}_$req';
        if (!seen.contains(key)) {
          seen.add(key);
          result.add({'label': req, 'profileName': name, 'profileId': id});
        }
      }
    }
    return result;
  }

  void _saveCustomStyle(String style) {
    final trimmed = style.trim();
    if (trimmed.isEmpty) return;
    _recentCustomStyles.remove(trimmed);
    _recentCustomStyles.insert(0, trimmed);
    if (_recentCustomStyles.length > 10) {
      _recentCustomStyles = _recentCustomStyles.sublist(0, 10);
    }
  }

  void _showCustomStyleSheet() {
    final controller = TextEditingController();

    void submitStyle(String value, StateSetter setSheetState) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      Navigator.of(context).pop();
      setState(() => _selectedStyle = trimmed);
      _saveCustomStyle(trimmed);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Custom style', style: ElioText.headingMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Describe what you\'re in the mood for',
                    style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'e.g. Korean street food, comfort pasta...',
                      hintStyle: TextStyle(color: ElioColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (v) => submitStyle(v, setSheetState),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => submitStyle(controller.text, setSheetState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ElioColors.amber,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Use this style →',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Recent custom styles as quick-reuse chips
                  if (_recentCustomStyles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Recent',
                      style: ElioText.label.copyWith(color: ElioColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _recentCustomStyles.map((style) {
                        return GestureDetector(
                          onTap: () {
                            controller.text = style;
                            submitStyle(style, setSheetState);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: ElioColors.offWhite,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: ElioColors.border),
                            ),
                            child: Text(
                              style,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: ElioColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Style chips: user's preferences + recent custom + Custom... ──
  List<String> get _styleChips {
    final chips = List<String>.from(_stylePreferences);
    if (!chips.contains('Surprise me')) chips.add('Surprise me');
    // Cap base styles at 8 for readability
    final base = chips.take(8).toList();
    // Add recent custom styles that aren't already in the list
    for (final custom in _recentCustomStyles) {
      if (!base.contains(custom)) base.add(custom);
    }
    // Always end with "Custom..."
    base.add('Custom...');
    return base;
  }

  // ── Add item from text field ───────────────────────────────────────
  void _addFromText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _selectedPerishables.add(text);
      _textController.clear();
    });
    _textFocus.requestFocus();
  }

  void _removePerishable(String item) {
    setState(() => _selectedPerishables.remove(item));
  }

  // ── Generate recipe ────────────────────────────────────────────────
  Future<void> _generateRecipe() async {
    if (_isGenerating) return;

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

    try {
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
        perishables: _isLeftoverMode ? [] : _selectedPerishables.toList(),
        alwaysHave: _alwaysHave,
        almostAlwaysHave: _almostAlwaysHave,
        dietaryRequirements: _activeDietaryRequirements,
        timePreference: _selectedTime,
        stylePreference: _selectedStyle,
        moodPreference: _selectedMood,
        servings: 2,
        recentTitles: List.from(_recentTitles),
        runningLowItems: List.from(_runningLowItems),
        isLeftoverMode: _isLeftoverMode,
        leftoverItems: _isLeftoverMode ? _leftoverItems.toList() : [],
        likedRecipes: likedRecipes,
        dislikedRecipes: dislikedRecipes,
        appliances: _appliances,
        isSaverMode: _saverMode,
        perishableInventoryDescriptions: _isLeftoverMode ? [] : _perishableDescriptions,
      );

      final recipe = await GeminiService.generateRecipe(request);

      // ── Navigate to recipe immediately — don't let saves block display ──
      // Track title for deduplication (keep last 10)
      _recentTitles.add(recipe.title);
      if (_recentTitles.length > 20) _recentTitles.removeAt(0);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecipeScreen(
              recipe: recipe,
              originalRequest: request,
              isGuest: widget.isGuest,
            ),
          ),
        );
      }

      // ── Background saves — non-blocking, best-effort ──
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

      // Always save to local history (works offline and for guests)
      await HistoryService.saveRecipe(SavedRecipe(
        recipe: recipe,
        savedAt: DateTime.now().toUtc().toIso8601String(),
      ));

      _loadRecentHistory();

      _analytics.logEvent('recipe_generated', {
        'style': _selectedStyle ?? 'none',
        'time': _selectedTime ?? 'none',
        'mood': _selectedMood ?? 'none',
        'is_leftover_mode': _isLeftoverMode,
        'is_saver_mode': _saverMode,
        'perishable_count': _selectedPerishables.length,
        'is_guest': widget.isGuest,
      });
    } catch (e) {
      _analytics.logEvent('recipe_generation_failed', {
        'error_type': e.runtimeType.toString(),
      });
      if (mounted) {
        final raw = e.toString();
        final String msg;
        if (raw.contains('SocketException') ||
            raw.contains('SocketFailed') ||
            raw.contains('ClientException') ||
            raw.contains('No address associated') ||
            raw.contains('Failed host lookup')) {
          msg = 'No internet connection. Please check your network and try again.';
        } else if (raw.contains('429') || raw.contains('quota')) {
          msg = 'Too many requests. Please wait a moment and try again.';
        } else if (raw.contains('401') || raw.contains('403') || raw.contains('API key')) {
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
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showUpgradeDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PaywallScreen(trigger: PaywallTrigger.capReached),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────
            _buildAppBar(),

            // ── Scrollable content ───────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: ElioColors.amber))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          // ── Featured Selection hero card ──────────
                          _buildFeaturedCard(),
                          const SizedBox(height: 24),
                          // ── Intelligence Report Card ──────────────
                          _buildIntelligenceCard(),
                          const SizedBox(height: 48),
                          // ── Pantry Alerts ─────────────────────────
                          _buildPantryAlertsSection(),
                          const SizedBox(height: 48),
                          // ── Fresh Recommendations ─────────────────
                          _buildFreshRecommendationsSection(),
                          const SizedBox(height: 48),
                          // ── Expiry banner ─────────────────────────
                          if (_expiringItemCount > 0 && _showExpiryBanner)
                            _buildExpiryBanner(),
                          // ── Active dietary filter strip ──────────
                          if (!widget.isGuest && _allDietaryConstraints.isNotEmpty)
                            _buildDietaryFilterStrip(),
                          const SizedBox(height: 20),
                          _buildPerishablesSection(),
                          const SizedBox(height: 24),
                          _buildMoodChipsSection(),
                          const SizedBox(height: 24),
                          _buildGenerateButton(),
                          const SizedBox(height: 16),
                          _buildMealPlannerBanner(),
                          const SizedBox(height: 24),
                          _buildRecentSection(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── App bar ─────────────────────────────────────────────────────────────────
  // Vibrant Editorial — cardSurface bar, lowercase "elio" wordmark in heroOrange,
  // hamburger menu left, profile icon right.
  Widget _buildAppBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: ElioColors.cardSurface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: menu icon + "elio" wordmark
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen(initialTab: 0)),
                  ).then((_) => _loadUserData());
                },
                child: const Icon(Icons.menu, color: ElioColors.dark, size: 22),
              ),
              const SizedBox(width: 16),
              Text(
                'elio',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: ElioColors.heroOrange,
                  letterSpacing: -1.2,
                ),
              ),
            ],
          ),
          // Right: profile icon
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ).then((_) => _loadUserData());
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.person_outline, color: ElioColors.dark, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Featured Selection hero card ────────────────────────────────────────────
  // Vibrant Editorial hero card. Uses the most recent saved recipe if available;
  // falls back to a placeholder when history is empty (e.g. fresh install / guest).
  Widget _buildFeaturedCard() {
    final recipe = _recentRecipes.isNotEmpty ? _recentRecipes.first : null;
    final title = recipe?.recipe.title ?? 'Something\nDelicious\nAwaits';

    return GestureDetector(
      onTap: recipe != null
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecipeScreen(recipe: recipe.recipe),
                ),
              )
          : null,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 280),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: ElioColors.warmOrange,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Geometric overlay decorations ─────────────────────
            Positioned(
              top: -64,
              right: -64,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              right: 20,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: ElioColors.peach.withOpacity(0.45),
                    width: 28,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // ── Card content ──────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "FEATURED SELECTION" pill label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    'FEATURED SELECTION',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Recipe title — large editorial display
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 40,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    letterSpacing: -1.2,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 28),
                // "Start Cooking" CTA button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: ElioColors.dark.withOpacity(0.08),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Start Cooking',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: ElioColors.heroOrange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.arrow_forward,
                        color: ElioColors.heroOrange,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Intelligence Report Card ────────────────────────────────────────────────
  // Vibrant Editorial bento card — pantry analytics summary with mini bar chart.
  Widget _buildIntelligenceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ElioColors.cardSurface,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading
          Text(
            'Weekly Consumption\nIntelligence Report',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: ElioColors.textPrimary,
              letterSpacing: -0.6,
              height: 1.33,
            ),
          ),
          const SizedBox(height: 16),
          // Body
          Text(
            'Your waste reduction is up 14% this week. We\'ve identified 3 pantry items reaching peak flavour profiles.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: ElioColors.textPrimary.withOpacity(0.7),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          // Mini bar chart
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(0.40),
                const SizedBox(width: 6),
                _buildBar(0.65),
                const SizedBox(width: 6),
                _buildBar(0.45),
                const SizedBox(width: 6),
                _buildBar(0.85),
                const SizedBox(width: 6),
                _buildBar(1.0),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // "View Full Analysis" outlined button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: ElioColors.heroOrange, width: 2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                'View Full Analysis',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: ElioColors.heroOrange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double heightFraction) {
    return Expanded(
      child: FractionallySizedBox(
        heightFactor: heightFraction,
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            color: ElioColors.warmOrange.withOpacity(heightFraction),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ),
      ),
    );
  }

  // ─── Pantry Alerts section ────────────────────────────────────────────────────
  // Vibrant Editorial — shows low stock and depleted pantry items.
  Widget _buildPantryAlertsSection() {
    // Build alert items from _runningLowItems if available, otherwise use placeholders
    final alerts = _runningLowItems.isNotEmpty
        ? _runningLowItems
            .take(3)
            .map((item) => _PantryAlertItem(
                  name: item,
                  status: 'LOW STOCK',
                  statusColor: ElioColors.darkAmber,
                  iconBg: const Color(0xFFFFDCBB),
                  progress: 0.15,
                ))
            .toList()
        : const [
            _PantryAlertItem(
              name: 'Extra Virgin Oil',
              status: 'LOW STOCK',
              statusColor: ElioColors.darkAmber,
              iconBg: Color(0xFFFFDCBB),
              progress: 0.15,
            ),
            _PantryAlertItem(
              name: 'Carnaroli Rice',
              status: 'LOW STOCK',
              statusColor: ElioColors.taupe,
              iconBg: Color(0xFFFFDBCB),
              progress: 0.22,
            ),
            _PantryAlertItem(
              name: 'Maldon Sea Salt',
              status: 'DEPLETED',
              statusColor: ElioColors.error,
              iconBg: Color(0xFFFFF0EE),
              progress: 0.02,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pantry Alerts',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 30,
                    fontWeight: FontWeight.w400,
                    color: ElioColors.textPrimary,
                    letterSpacing: -0.75,
                    height: 1.2,
                  ),
                ),
                Text(
                  'Critical stock levels',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: ElioColors.textPrimary.withOpacity(0.6),
                    height: 1.5,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen(initialTab: 0)),
              ).then((_) => _loadUserData()),
              child: Row(
                children: [
                  Text(
                    'View Inventory',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: ElioColors.heroOrange,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, color: ElioColors.heroOrange, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Alert cards
        ...alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildAlertCard(alert),
            )),
      ],
    );
  }

  Widget _buildAlertCard(_PantryAlertItem alert) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: ElioColors.dark.withOpacity(0.06),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon area
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: alert.iconBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.inventory_2_outlined, size: 24, color: ElioColors.taupe),
          ),
          const SizedBox(width: 24),
          // Text + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  alert.status,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: alert.statusColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: ElioColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(9999),
                  child: SizedBox(
                    width: 128,
                    height: 6,
                    child: LinearProgressIndicator(
                      value: alert.progress,
                      backgroundColor: ElioColors.cardSurface,
                      valueColor: AlwaysStoppedAnimation<Color>(alert.statusColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Fresh Recommendations section ───────────────────────────────────────────
  // Vibrant Editorial asymmetric layout — illustration card + editorial headline.
  Widget _buildFreshRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Illustration card — "seasonal harvest."
        Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            color: ElioColors.cardSurface,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Stack(
            children: [
              // Decorative geometric shapes
              Positioned(
                top: 24,
                right: 24,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: ElioColors.warmOrange.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                top: 60,
                right: 60,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: ElioColors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  transform: Matrix4.rotationZ(0.785),
                ),
              ),
              // "seasonal harvest." text overlay
              Positioned(
                left: 32,
                bottom: 32,
                child: Text(
                  'seasonal\nharvest.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: ElioColors.textPrimary,
                    letterSpacing: -1.8,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Editorial headline
        RichText(
          text: TextSpan(
            style: GoogleFonts.plusJakartaSans(
              fontSize: 48,
              fontWeight: FontWeight.w600,
              color: ElioColors.textPrimary,
              letterSpacing: -2.4,
              height: 1.25,
            ),
            children: [
              const TextSpan(text: 'Your taste,\nscientifically\n'),
              TextSpan(
                text: 'curated',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  color: ElioColors.warmOrange,
                  letterSpacing: -2.4,
                  height: 1.25,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Body text
        Text(
          'We\'ve analysed your consumption patterns and local harvest schedules to suggest ingredients that maximise nutritional value and minimise ecological footprint.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: ElioColors.textPrimary.withOpacity(0.7),
            height: 1.55,
          ),
        ),
        const SizedBox(height: 24),
        // Stat boxes
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ElioColors.cardSurface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutrient\nDensity',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: ElioColors.heroOrange,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+24%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: ElioColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ElioColors.cardSurface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local\nSourcing',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: ElioColors.heroOrange,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '88%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: ElioColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Expiry banner ──────────────────────────────────────────────────────────
  Widget _buildExpiryBanner() {
    final label = _expiringItemCount == 1
        ? '1 item expiring soon'
        : '$_expiringItemCount items expiring soon';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ElioColors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFE65100)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: ElioText.bodyMedium.copyWith(
                  color: const Color(0xFFE65100),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen(initialTab: 0)),
                ).then((_) => _loadUserData());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ElioColors.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'View',
                  style: ElioText.label.copyWith(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _showExpiryBanner = false),
              child: const Icon(Icons.close, size: 16, color: Color(0xFFE65100)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Active dietary filter strip ─────────────────────────────────────────────
  // Shows each dietary constraint as a pill with the profile name as a tooltip.
  // Tapping ✕ on a profile deactivates ALL of that profile's constraints for the session.
  Widget _buildDietaryFilterStrip() {
    // Group constraints by profile for display
    final activeProfiles = _householdProfiles
        .where((p) => !_deactivatedProfileIds.contains(p['id'] as String))
        .toList();
    final deactivatedProfiles = _householdProfiles
        .where((p) => _deactivatedProfileIds.contains(p['id'] as String))
        .toList();

    // Collect unique active constraints
    final activeConstraints = <Map<String, String>>[];
    final seen = <String>{};
    for (final profile in activeProfiles) {
      final id = profile['id'] as String;
      final name = profile['name'] as String;
      final reqs = List<String>.from(profile['dietaryRequirements'] ?? []);
      for (final req in reqs) {
        if (!seen.contains(req)) {
          seen.add(req);
          activeConstraints.add({'label': req, 'profileName': name, 'profileId': id});
        }
      }
    }

    final hasRunningLow = _runningLowItems.isNotEmpty;

    if (activeConstraints.isEmpty && deactivatedProfiles.isEmpty && !hasRunningLow) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_outlined, size: 13, color: ElioColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              'Active filters',
              style: ElioText.label.copyWith(color: ElioColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            // Active constraint pills
            ...activeConstraints.map((c) {
              final profileId = c['profileId']!;
              // Find if this profile has other members with same constraint
              final profileName = c['profileName']!;
              return _DietaryPill(
                label: c['label']!,
                profileName: profileName,
                isActive: true,
                onDeactivate: () {
                  setState(() => _deactivatedProfileIds.add(profileId));
                },
              );
            }),
            // Running low warning pills
            ..._runningLowItems.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFB300), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFE65100)),
                  const SizedBox(width: 4),
                  Text(
                    item,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ],
              ),
            )),
            // Deactivated profile restore chips
            ...deactivatedProfiles.map((p) {
              final name = p['name'] as String;
              final reqs = List<String>.from(p['dietaryRequirements'] ?? []);
              if (reqs.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () => setState(() => _deactivatedProfileIds.remove(p['id'] as String)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ElioColors.border, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline, size: 12, color: ElioColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '$name\'s filters',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: ElioColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  //   // ─── Perishables section ────────────────────────────────────────────
  Widget _buildPerishablesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Mode toggle row ─────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                _isLeftoverMode ? 'Use up leftovers' : "What's fresh today?",
                style: ElioText.displayMedium,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _isLeftoverMode = !_isLeftoverMode;
                _leftoverItems.clear();
                _leftoverController.clear();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isLeftoverMode ? ElioColors.amber.withValues(alpha: 0.15) : ElioColors.offWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isLeftoverMode ? ElioColors.amber : ElioColors.border,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🍱', style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      'Leftovers',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isLeftoverMode ? ElioColors.amber : ElioColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _isLeftoverMode
              ? 'Tell Elio what you have left over to use up.'
              : 'Tap what you have, or type anything else.',
          style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
        ),
        const SizedBox(height: 16),

        if (_isLeftoverMode) ...[
          // ── Leftover quick-tap chips ─────────────────────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _commonLeftovers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final item = _commonLeftovers[i];
                final isSelected = _leftoverItems.contains(item);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) { _leftoverItems.remove(item); }
                    else { _leftoverItems.add(item); }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? ElioColors.amber : ElioColors.offWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? ElioColors.amber : ElioColors.border,
                      ),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : ElioColors.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Free-text input for leftovers
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _leftoverController,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Add a leftover...',
                    hintStyle: TextStyle(color: ElioColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (v) {
                    final trimmed = v.trim();
                    if (trimmed.isNotEmpty) {
                      setState(() => _leftoverItems.add(trimmed));
                      _leftoverController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final trimmed = _leftoverController.text.trim();
                  if (trimmed.isNotEmpty) {
                    setState(() => _leftoverItems.add(trimmed));
                    _leftoverController.clear();
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ElioColors.navy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          if (_leftoverItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _leftoverItems.map((item) => _SelectedTag(
                label: item,
                onRemove: () => setState(() => _leftoverItems.remove(item)),
              )).toList(),
            ),
          ],
        ] else ...[
        // ── Quick-tap chips (normal mode) ─────────────────────────────────────────────────
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _commonPerishables.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final item = _commonPerishables[i];
              final isSelected = _selectedPerishables.contains(item);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedPerishables.remove(item);
                  } else {
                    _selectedPerishables.add(item);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? ElioColors.amber : ElioColors.offWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? ElioColors.amber : ElioColors.border,
                    ),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : ElioColors.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // ── Free-text input ──────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _textFocus,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Add anything else...',
                  hintStyle: TextStyle(color: ElioColors.textMuted),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _addFromText(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addFromText,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ElioColors.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            // Open AddScreen (scan receipt / snap photo / manual entry hub)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddScreen()),
              ).then((_) => _loadUserData()),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ElioColors.warmOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),

        // ── Selected perishable tags ───────────────────────────────────────────────
        if (_selectedPerishables.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedPerishables.map((item) => _SelectedTag(
              label: item,
              onRemove: () => _removePerishable(item),
            )).toList(),
          ),
        ],
        ], // end else (normal mode)
      ],
    );
  }

  // ─── Mood chips section ───────────────────────────────────────────────────────
  Widget _buildMoodChipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time row
        _buildChipRow(
          label: 'Time',
          chips: _timeChips,
          selected: _selectedTime,
          onSelect: (v) => setState(() => _selectedTime = _selectedTime == v ? null : v),
        ),
        const SizedBox(height: 12),

        // Style row — populated from onboarding preferences + custom
        if (_styleChips.isNotEmpty) ...[
          _buildChipRow(
            label: 'Style',
            chips: _styleChips,
            selected: _selectedStyle,
            onSelect: (v) {
              if (v == 'Custom...') {
                _showCustomStyleSheet();
              } else {
                setState(() => _selectedStyle = _selectedStyle == v ? null : v);
              }
            },
          ),
          const SizedBox(height: 12),
        ],

        // Mood row
        _buildChipRow(
          label: 'Mood',
          chips: _moodChips,
          selected: _selectedMood,
          onSelect: (v) => setState(() => _selectedMood = _selectedMood == v ? null : v),
        ),
      ],
    );
  }

  Widget _buildChipRow({
    required String label,
    required List<String> chips,
    required String? selected,
    required void Function(String) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ElioText.label.copyWith(
            color: ElioColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final chip = chips[i];
              final isCustomTrigger = chip == 'Custom...';
              final isSelected = selected == chip;
              return GestureDetector(
                onTap: () => onSelect(chip),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCustomTrigger
                        ? Colors.transparent
                        : (isSelected ? ElioColors.navy.withValues(alpha: 0.08) : Colors.transparent),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isCustomTrigger
                          ? ElioColors.textMuted
                          : (isSelected ? ElioColors.navy : ElioColors.border),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCustomTrigger)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.add, size: 14, color: ElioColors.textMuted),
                        ),
                      Text(
                        chip,
                        style: TextStyle(fontSize: 13,
                          fontWeight: isCustomTrigger
                              ? FontWeight.w500
                              : (isSelected ? FontWeight.w700 : FontWeight.w500),
                          color: isCustomTrigger
                              ? ElioColors.textMuted
                              : (isSelected ? ElioColors.navy : ElioColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Generate button ──────────────────────────────────────────────────────────
  Widget _buildGenerateButton() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          // Saver toggle
          GestureDetector(
            onTap: () {
              setState(() => _saverMode = !_saverMode);
              _analytics.logEvent('saver_mode_toggled', {'enabled': _saverMode});
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Saver',
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _saverMode ? ElioColors.amber : ElioColors.navy,
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  height: 32,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Switch.adaptive(
                      value: _saverMode,
                      activeTrackColor: ElioColors.amber,
                      onChanged: (value) {
                        setState(() => _saverMode = value);
                        _analytics.logEvent('saver_mode_toggled', {'enabled': value});
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Generate button
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateRecipe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ElioColors.amber,
                  disabledBackgroundColor: ElioColors.amber.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isGenerating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _isLeftoverMode ? 'Use These Leftovers →' : 'Generate Recipe →',
                        style: const TextStyle(fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Meal planner banner ─────────────────────────────────────────────────────
  Widget _buildMealPlannerBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MealPlanScreen()),
        ).then((_) => _checkSavedMealPlan()); // Refresh saved plan state on return
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ElioColors.navy,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasSavedMealPlan ? 'Your meal plan' : 'Plan your week',
                    style: ElioText.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hasSavedMealPlan
                        ? 'Tap to view your saved plan'
                        : '21 meals generated in one tap',
                    style: ElioText.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: ElioColors.amber,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _hasSavedMealPlan ? 'View →' : 'Open →',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Recent recipes section ───────────────────────────────────────────────────
  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent recipes', style: ElioText.headingMedium),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
              child: Text(
                'View all',
                style: ElioText.bodyMedium.copyWith(color: ElioColors.sky, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentRecipes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ElioColors.offWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text('🍳', style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  'Your recipes will appear here',
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Column(
            children: _recentRecipes.map((saved) => _RecentRecipeCard(
              saved: saved,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecipeScreen(
                    recipe: saved.recipe,
                    isGuest: widget.isGuest,
                  ),
                ),
              ),
            )).toList(),
          ),
      ],
    );
  }
}

// ─── Dietary filter pill widget ───────────────────────────────────────────────
class _DietaryPill extends StatelessWidget {
  final String label;
  final String profileName;
  final bool isActive;
  final VoidCallback onDeactivate;

  const _DietaryPill({
    required this.label,
    required this.profileName,
    required this.isActive,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$profileName\'s requirement',
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 4, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: ElioColors.navy.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ElioColors.navy.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ElioColors.navy,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDeactivate,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: ElioColors.navy.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 10, color: ElioColors.navy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Selected perishable tag ──────────────────────────────────────────────────
class _SelectedTag extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _SelectedTag({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: ElioColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ElioColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ElioColors.amber,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: ElioColors.amber),
          ),
        ],
      ),
    );
  }
}

// ─── Recent recipe card ───────────────────────────────────────────────────────
class _RecentRecipeCard extends StatelessWidget {
  final SavedRecipe saved;
  final VoidCallback onTap;

  const _RecentRecipeCard({required this.saved, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final recipe = saved.recipe;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ElioColors.offWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ElioColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: ElioText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${recipe.prepTimeMinutes} min · ${recipe.servings} servings',
                    style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: ElioColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Data class for pantry alert items ───────────────────────────────────────
class _PantryAlertItem {
  final String name;
  final String status;
  final Color statusColor;
  final Color iconBg;
  final double progress;

  const _PantryAlertItem({
    required this.name,
    required this.status,
    required this.statusColor,
    required this.iconBg,
    required this.progress,
  });
}
