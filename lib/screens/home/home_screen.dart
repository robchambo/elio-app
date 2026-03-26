import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/elio_theme.dart';
import '../../models/recipe_models.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../../services/history_service.dart';
import '../recipe/recipe_screen.dart';
import '../history/history_screen.dart';
import '../meal_plan/meal_plan_screen.dart';
import '../profile/profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';

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
  const HomeScreen({super.key, this.isGuest = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestore = FirestoreService();
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
  bool _isLoading = true;
  bool _isGenerating = false;

  // ── Household profiles for dietary filter strip ────────────────────
  // Each entry: { 'id': String, 'name': String, 'dietaryRequirements': List<String>, 'isOwner': bool }
  List<Map<String, dynamic>> _householdProfiles = [];
  // Set of profile IDs that are currently DEACTIVATED for this session
  final Set<String> _deactivatedProfileIds = {};

  // ── Recent history ─────────────────────────────────────────────────
  List<SavedRecipe> _recentRecipes = [];

  // ── Session deduplication memory (last 10 recipe titles) ─────────────
  final List<String> _recentTitles = [];

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
  }

  Future<void> _loadRecentHistory() async {
    final all = await HistoryService.getHistory();
    if (mounted) setState(() => _recentRecipes = all.take(3).toList());
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();
    _leftoverController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // Guest mode: skip Firestore, use empty defaults
    if (widget.isGuest) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final data = await _firestore.getUserData();
      if (mounted) {
        setState(() {
          _stylePreferences = List<String>.from(data['stylePreferences'] ?? []);
          _alwaysHave = List<String>.from(data['alwaysHave'] ?? []);
          _almostAlwaysHave = List<String>.from(data['almostAlwaysHave'] ?? []);
          _runningLowItems = List<String>.from(data['runningLowItems'] ?? []);
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

  // ── Style chips: user's preferences + Surprise me ─────────────────
  List<String> get _styleChips {
    final chips = List<String>.from(_stylePreferences);
    if (!chips.contains('Surprise me')) chips.add('Surprise me');
    // Cap at 8 for readability
    return chips.take(8).toList();
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

  // ── Guest cap: device-local daily counter ─────────────────────────
  static const String _guestCapKey = 'guest_daily_generations';
  static const String _guestCapDateKey = 'guest_daily_generations_date';

  Future<bool> _canGuestGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toUtc();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final savedDate = prefs.getString(_guestCapDateKey) ?? '';
    if (savedDate != todayStr) {
      // New day — reset counter
      await prefs.setInt(_guestCapKey, 0);
      await prefs.setString(_guestCapDateKey, todayStr);
      return true;
    }
    final count = prefs.getInt(_guestCapKey) ?? 0;
    return count < 3;
  }

  Future<void> _incrementGuestGenerations() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_guestCapKey) ?? 0;
    await prefs.setInt(_guestCapKey, current + 1);
  }

  // ── Generate recipe ────────────────────────────────────────────────
  Future<void> _generateRecipe() async {
    if (_isGenerating) return;

    // Check free tier cap
    if (widget.isGuest) {
      final canGenerate = await _canGuestGenerate();
      if (!canGenerate && mounted) {
        _showUpgradeDialog();
        return;
      }
    } else {
      final canGenerate = await _firestore.canGenerateRecipe();
      if (!canGenerate && mounted) {
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
      );

      final recipe = await GeminiService.generateRecipe(request);

      if (widget.isGuest) {
        // Increment device-local guest cap
        await _incrementGuestGenerations();
      } else {
        // Increment daily cap and save to Firestore in parallel
        await Future.wait([
          _firestore.incrementDailyGenerations(),
          _firestore.saveRecipe(recipe),
        ]);
      }

      // Always save to local history (works offline and for guests)
      await HistoryService.saveRecipe(SavedRecipe(
        recipe: recipe,
        savedAt: DateTime.now().toUtc().toIso8601String(),
      ));

      // Track title for deduplication (keep last 10)
      _recentTitles.add(recipe.title);
      if (_recentTitles.length > 10) _recentTitles.removeAt(0);

      _loadRecentHistory();

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
    } catch (e) {
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ElioColors.amber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: ElioColors.amber, size: 28),
            ),
            const SizedBox(height: 16),
            Text("You've cooked up 3 today!", style: ElioText.headingMedium, textAlign: TextAlign.center),
          ],
        ),
        content: Text(
          'Free accounts get 3 recipe generations per day. Upgrade to Elio Pro for unlimited recipes, weekly meal plans, and more.',
          style: ElioText.bodyLarge,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Subscription coming soon!')),
                    );
                  },
                  child: const Text('Upgrade to Pro — £2.99/mo'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Maybe tomorrow',
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.white,
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
                          const SizedBox(height: 16),
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
  Widget _buildAppBar() {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    final initials = widget.isGuest
        ? 'G'
        : (user?.displayName ?? 'U')
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ELiO wordmark
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: 'EL', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: ElioColors.navy)),
                TextSpan(text: 'i', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: ElioColors.sky)),
                TextSpan(text: 'O', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: ElioColors.navy)),
              ],
            ),
          ),
          // Profile avatar
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ).then((_) => _loadUserData()); // Refresh data when returning
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: ElioColors.navy,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
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
                    if (isSelected) _leftoverItems.remove(item);
                    else _leftoverItems.add(item);
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
        Text(
          'Anything in mind?',
          style: ElioText.headingMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'All optional — Elio will figure it out if you skip these.',
          style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
        ),
        const SizedBox(height: 16),

        // Time row
        _buildChipRow(
          label: 'Time',
          chips: _timeChips,
          selected: _selectedTime,
          onSelect: (v) => setState(() => _selectedTime = _selectedTime == v ? null : v),
        ),
        const SizedBox(height: 12),

        // Style row — populated from onboarding preferences
        if (_styleChips.isNotEmpty) ...[
          _buildChipRow(
            label: 'Style',
            chips: _styleChips,
            selected: _selectedStyle,
            onSelect: (v) => setState(() => _selectedStyle = _selectedStyle == v ? null : v),
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
              final isSelected = selected == chip;
              return GestureDetector(
                onTap: () => onSelect(chip),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? ElioColors.navy.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? ElioColors.navy : ElioColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    chip,
                    style: TextStyle(fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? ElioColors.navy : ElioColors.textPrimary,
                    ),
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
      width: double.infinity,
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
    );
  }

  // ─── Meal planner banner ─────────────────────────────────────────────────────
  Widget _buildMealPlannerBanner() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MealPlanScreen()),
      ),
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
                    'Plan your week',
                    style: ElioText.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '21 meals generated in one tap',
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
              child: const Text(
                'Open →',
                style: TextStyle(
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
