import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../models/meal_plan_models.dart';
import '../../services/meal_plan_service.dart';
import '../../services/firestore_service.dart';
import '../recipe/recipe_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/shopping_service.dart';
import '../paywall/paywall_screen.dart';
import '../profile/profile_screen.dart';
import '../../utils/quantity_utils.dart';

// ─────────────────────────────────────────────
// MealPlanScreen
// Design: approachable utility.
//
// Layout:
//   • Header with "Generate Week" CTA
//   • Horizontal day selector (Mon–Sun tabs)
//   • 3-card column for Breakfast / Lunch / Dinner
//   • Each card: title, time badge, regenerate ↺ button
//   • Tap a card to open a detail bottom sheet
//   • "Shopping List" FAB at bottom
//
// State machine:
//   idle → generating (full week) → ready
//   ready → regenerating single meal → ready
// ─────────────────────────────────────────────

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestore = FirestoreService();
  final AnalyticsService _analytics = AnalyticsService.instance;
  final EntitlementService _entitlements = EntitlementService.instance;

  // ── State ──────────────────────────────────────────────────────────
  MealPlan? _plan;
  bool _isGenerating = false;
  // _selectedDayIndex removed — TabBarView drives day rendering via _tabController

  // Track which individual slots are regenerating
  final Set<String> _regeneratingSlots = {}; // "dayIndex_mealType"

  // ── Plan configuration (set on empty state) ────────────────────────
  final Set<String> _selectedDays = {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'};
  final Set<MealType> _selectedMealTypes = {MealType.breakfast, MealType.lunch, MealType.dinner};

  // ── User data (loaded once) ────────────────────────────────────────
  List<String> _dietaryRequirements = [];
  List<String> _alwaysHave = [];
  List<String> _almostAlwaysHave = [];
  List<String> _runningLowItems = [];
  List<String> _stylePreferences = [];
  bool _dataLoaded = false;

  // ── Day tab controller ─────────────────────────────────────────────
  late TabController _tabController;

  static const List<String> _dayAbbreviations = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final dataFuture = _firestore.getUserData();
      final planFuture = _firestore.loadMealPlan();
      final data = await dataFuture;
      final savedPlan = await planFuture;
      if (mounted) {
        setState(() {
          _dietaryRequirements = List<String>.from(data['dietaryRequirements'] ?? []);
          _alwaysHave = List<String>.from(data['alwaysHave'] ?? []);
          _almostAlwaysHave = List<String>.from(data['almostAlwaysHave'] ?? []);
          _runningLowItems = List<String>.from(data['runningLowItems'] ?? []);
          _stylePreferences = List<String>.from(data['stylePreferences'] ?? []);
          _plan = savedPlan;
          _dataLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dataLoaded = true);
    }
  }

  Future<void> _savePlan() async {
    if (_plan == null) return;
    try {
      await _firestore.saveMealPlan(_plan!);
    } catch (_) {
      // Non-critical — plan is already in memory
    }
  }

  Future<void> _generateWeeklyPlan() async {
    if (_isGenerating) return;

    // Pro-only feature gate
    await _entitlements.refresh();
    if (!_entitlements.canUseMealPlanner) {
      if (mounted) _showProRequiredSnack('Meal planning');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final orderedDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
          .where((d) => _selectedDays.contains(d))
          .toList();
      final orderedTypes = MealType.values
          .where((t) => _selectedMealTypes.contains(t))
          .toList();
      final plan = await MealPlanService.generateWeeklyPlan(
        dietaryRequirements: _dietaryRequirements,
        alwaysHave: _alwaysHave,
        almostAlwaysHave: _almostAlwaysHave,
        stylePreferences: _stylePreferences,
        selectedDays: orderedDays,
        selectedMealTypes: orderedTypes,
      );
      if (mounted) {
        setState(() {
          _plan = plan;
          _tabController.animateTo(0);
        });
        _savePlan();
        _analytics.logEvent('meal_plan_generated', {
          'days': orderedDays.length,
          'meal_types': orderedTypes.length,
          'total_meals': orderedDays.length * orderedTypes.length,
        });
      }
    } catch (e) {
      _analytics.logEvent('meal_plan_generation_failed', {
        'error_type': e.runtimeType.toString(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: ElioColors.navy,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _regenerateMeal(int dayIndex, MealType mealType) async {
    if (_plan == null) return;
    final slotKey = '${dayIndex}_${mealType.name}';
    if (_regeneratingSlots.contains(slotKey)) return;

    setState(() => _regeneratingSlots.add(slotKey));

    try {
      final existingTitles = <String>[];
      for (final day in _plan!.days) {
        for (final meal in day.meals.values) {
          if (meal != null) existingTitles.add(meal.title);
        }
      }

      final newMeal = await MealPlanService.regenerateMeal(
        dayName: _plan!.days[dayIndex].dayName,
        mealType: mealType,
        dietaryRequirements: _dietaryRequirements,
        alwaysHave: _alwaysHave,
        almostAlwaysHave: _almostAlwaysHave,
        existingTitles: existingTitles,
      );

      if (mounted) {
        setState(() {
          final updatedDay = _plan!.days[dayIndex].copyWithMeal(mealType, newMeal);
          _plan = _plan!.copyWithDay(dayIndex, updatedDay);
        });
        _savePlan();
        _analytics.logEvent('meal_plan_meal_regenerated', {
          'meal_type': mealType.name,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: ElioColors.navy,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _regeneratingSlots.remove(slotKey));
    }
  }

  Future<void> _showAddToShoppingDialog() async {
    if (_plan == null) return;
    await _entitlements.refresh();
    if (!mounted) return;
    if (!_entitlements.canUseShoppingList) {
      _showProRequiredSnack('Shopping lists');
      return;
    }

    // Build ingredient list from meal plan, excluding pantry items
    final haveSet = [..._alwaysHave, ..._almostAlwaysHave]
        .map((s) => s.toLowerCase().trim())
        .toSet();

    // Aggregate ingredients, consolidating quantities per ingredient
    final quantities = <String, List<ParsedQuantity>>{};
    final displayNames = <String, String>{};
    for (final day in _plan!.days) {
      for (final meal in day.meals.values) {
        if (meal == null) continue;
        for (final ingredient in meal.ingredients) {
          final cleanName = ShoppingService.cleanForShopping(ingredient.name);
          final key = cleanName.toLowerCase().trim();
          if (haveSet.any((h) => key.contains(h) || h.contains(key))) continue;
          if (ShoppingService.instance.isStaplePublic(key)) continue;
          displayNames.putIfAbsent(key, () => cleanName);
          final parsed = QuantityUtils.parse(ingredient.quantity, ingredient.unit);
          quantities.putIfAbsent(key, () => []).add(parsed);
        }
      }
    }

    // Build editable item list
    final items = <_ShoppingDialogItem>[];
    for (final key in quantities.keys) {
      final combinedQty = QuantityUtils.combine(quantities[key]!);
      items.add(_ShoppingDialogItem(
        name: displayNames[key] ?? key,
        quantity: combinedQty,
        included: true,
      ));
    }

    // Add running low items
    final existingKeys = items.map((i) => i.name.toLowerCase().trim()).toSet();
    for (final item in _runningLowItems) {
      final key = item.toLowerCase().trim();
      if (!existingKeys.contains(key)) {
        items.add(_ShoppingDialogItem(
          name: item,
          quantity: 'Restock',
          included: true,
          isRestock: true,
        ));
        existingKeys.add(key);
      }
    }

    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AddToShoppingDialog(items: items),
    );

    if (confirmed == true && mounted) {
      // Add selected items to persistent shopping list
      final shop = ShoppingService.instance;
      int addedCount = 0;
      for (final item in items) {
        if (!item.included) continue;
        final result = await shop.addItem(
          name: item.name.trim(),
          quantity: item.quantity.trim(),
          source: item.isRestock ? ShoppingSource.restock : ShoppingSource.mealPlan,
        );
        if (result != null) addedCount++;
      }
      _analytics.logEvent('meal_plan_shopping_added', {
        'item_count': addedCount,
        'total_available': items.length,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$addedCount item${addedCount == 1 ? '' : 's'} added to shopping list'),
            backgroundColor: ElioColors.navy,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'View',
              textColor: ElioColors.amber,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen(initialTab: 3)),
                );
              },
            ),
          ),
        );
      }
    }
  }

  String? _contextForFeature(String feature) {
    final f = feature.toLowerCase();
    if (f.contains('shop')) return 'shopping_list';
    if (f.contains('meal') || f.contains('plan')) return 'meal_planner';
    if (f.contains('household')) return 'household';
    return null;
  }

  void _showProRequiredSnack(String feature) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          triggerContext: _contextForFeature(feature),
          trigger: PaywallTrigger.lockedFeature,
          lockedFeatureName: feature,
        ),
      ),
    );
  }

  Future<void> _openMealDetail(MealSlot meal, int dayIndex, MealType mealType) async {
    // Phase 2: load detail on demand if not yet fetched
    if (!meal.hasDetail) {
      final slotKey = '${dayIndex}_${mealType.name}';
      setState(() => _regeneratingSlots.add(slotKey));
      try {
        final detailed = await MealPlanService.generateMealDetail(meal);
        if (!mounted) return;
        setState(() {
          final updatedDay = _plan!.days[dayIndex].copyWithMeal(mealType, detailed);
          _plan = _plan!.copyWithDay(dayIndex, updatedDay);
        });
        _savePlan();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecipeScreen(recipe: detailed.toGeneratedRecipe()),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: ElioColors.navy,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _regeneratingSlots.remove(slotKey));
      }
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecipeScreen(recipe: meal.toGeneratedRecipe()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_plan != null) _buildDayTabs(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
      floatingActionButton: _plan != null
          ? FloatingActionButton.extended(
              onPressed: _showAddToShoppingDialog,
              backgroundColor: ElioColors.navy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
              label: const Text(
                'Add to shopping list',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            )
          : null,
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios_new, size: 20, color: ElioColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Meal Planner', style: ElioText.headingLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (_plan == null)
                  Text(
                    'Generate your week in one tap',
                    style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    'Tap a meal to view full recipe',
                    style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_plan != null) ...[
            // "New plan" — discard current and reconfigure
            GestureDetector(
              onTap: () {
                setState(() => _plan = null);
                _firestore.deleteMealPlan();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: ElioColors.offWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ElioColors.border),
                ),
                child: const Text(
                  'New plan',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ElioColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          _GenerateButton(
            isGenerating: _isGenerating,
            hasExistingPlan: _plan != null,
            onTap: _generateWeeklyPlan,
          ),
        ],
      ),
    );
  }

  // ─── Day tabs ─────────────────────────────────────────────────────────────────
  Widget _buildDayTabs() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        labelPadding: EdgeInsets.zero,
        indicatorColor: ElioColors.amber,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: ElioColors.navy,
        unselectedLabelColor: ElioColors.textMuted,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: ElioColors.border,
        tabs: _dayAbbreviations.map((d) => Tab(text: d)).toList(),
      ),
    );
  }

  // ─── Body ─────────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (!_dataLoaded) {
      return const Center(child: CircularProgressIndicator(color: ElioColors.amber));
    }

    if (_plan == null) {
      return _buildEmptyState();
    }

    // TabBarView with 7 children — one per day, synced with the TabBar
    return TabBarView(
      controller: _tabController,
      children: List.generate(7, (dayIndex) => _buildDayContent(dayIndex)),
    );
  }

  /// Builds the meal card column for a single day by index (0=Mon .. 6=Sun).
  Widget _buildDayContent(int dayIndex) {
    const fullDayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = fullDayNames[dayIndex];
    final dayOrNull = _plan!.days.where((d) => d.dayName == dayName).firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        children: MealType.values.map((type) {
          final meal = dayOrNull?.meals[type];
          final slotKey = '${dayIndex}_${type.name}';
          final isRegenerating = _regeneratingSlots.contains(slotKey);
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _MealCard(
              mealType: type,
              meal: meal,
              isRegenerating: isRegenerating,
              onRegenerate: () => _regenerateMeal(dayIndex, type),
              onTap: meal != null && !isRegenerating ? () => _openMealDetail(meal, dayIndex, type) : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Empty state ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final totalMeals = _selectedDays.length * _selectedMealTypes.length;
    final mealTypeLabel = _selectedMealTypes.length == 3
        ? 'breakfast, lunch & dinner'
        : _selectedMealTypes.map((t) => t.displayName.toLowerCase()).join(' & ');
    final dayLabel = _selectedDays.length == 7
        ? 'every day'
        : '${_selectedDays.length} days';
    final summaryText = _selectedDays.isEmpty || _selectedMealTypes.isEmpty
        ? 'Select at least one day and one meal type'
        : 'Elio will generate $totalMeals meals — $mealTypeLabel for $dayLabel — tailored to your pantry and dietary needs.';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Meal types ──────────────────────────────────────────────
          Text('Meal types', style: ElioText.label.copyWith(color: ElioColors.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: MealType.values.map((type) {
              final isOn = _selectedMealTypes.contains(type);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isOn && _selectedMealTypes.length > 1) {
                    _selectedMealTypes.remove(type);
                  } else if (!isOn) {
                    _selectedMealTypes.add(type);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isOn ? ElioColors.navy : ElioColors.offWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOn ? ElioColors.navy : ElioColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(type.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        type.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isOn ? Colors.white : ElioColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // ── Days ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Days', style: ElioText.label.copyWith(color: ElioColors.textSecondary, letterSpacing: 0.5)),
              GestureDetector(
                onTap: () => setState(() {
                  if (_selectedDays.length == 7) {
                    _selectedDays.clear();
                    _selectedDays.add('Monday');
                  } else {
                    _selectedDays.addAll(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday']);
                  }
                }),
                child: Text(
                  _selectedDays.length == 7 ? 'Clear all' : 'Select all',
                  style: ElioText.label.copyWith(color: ElioColors.sky, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in [
                ('Mon', 'Monday'), ('Tue', 'Tuesday'), ('Wed', 'Wednesday'),
                ('Thu', 'Thursday'), ('Fri', 'Friday'), ('Sat', 'Saturday'), ('Sun', 'Sunday'),
              ])
                GestureDetector(
                  onTap: () => setState(() {
                    if (_selectedDays.contains(entry.$2)) {
                      if (_selectedDays.length > 1) _selectedDays.remove(entry.$2);
                    } else {
                      _selectedDays.add(entry.$2);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _selectedDays.contains(entry.$2) ? ElioColors.amber : ElioColors.offWhite,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedDays.contains(entry.$2) ? ElioColors.amber : ElioColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        entry.$1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _selectedDays.contains(entry.$2) ? Colors.white : ElioColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Summary ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ElioColors.offWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ElioColors.border),
            ),
            child: Text(
              summaryText,
              style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 24),

          // ── Generate button ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_isGenerating || _selectedDays.isEmpty || _selectedMealTypes.isEmpty)
                  ? null
                  : _generateWeeklyPlan,
              child: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text('Generate ${_selectedDays.length == 7 ? 'My Week' : '${_selectedDays.length} Days'} →'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Generate button ──────────────────────────────────────────────────────────
class _GenerateButton extends StatelessWidget {
  final bool isGenerating;
  final bool hasExistingPlan;
  final VoidCallback onTap;

  const _GenerateButton({
    required this.isGenerating,
    required this.hasExistingPlan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isGenerating) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ElioColors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(color: ElioColors.amber, strokeWidth: 2),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: hasExistingPlan ? ElioColors.offWhite : ElioColors.amber,
          borderRadius: BorderRadius.circular(20),
          border: hasExistingPlan ? Border.all(color: ElioColors.border) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasExistingPlan ? Icons.refresh : Icons.auto_awesome,
              size: 14,
              color: hasExistingPlan ? ElioColors.textSecondary : Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              hasExistingPlan ? 'Redo week' : 'Generate',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: hasExistingPlan ? ElioColors.textSecondary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Meal card ────────────────────────────────────────────────────────────────
class _MealCard extends StatelessWidget {
  final MealType mealType;
  final MealSlot? meal;
  final bool isRegenerating;
  final VoidCallback onRegenerate;
  final VoidCallback? onTap;

  const _MealCard({
    required this.mealType,
    required this.meal,
    required this.isRegenerating,
    required this.onRegenerate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: ElioColors.offWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ElioColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Meal type header ─────────────────────────────────
              Row(
                children: [
                  Text(mealType.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    mealType.displayName.toUpperCase(),
                    style: ElioText.label.copyWith(
                      color: ElioColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  // Tap hint if meal exists
                  if (meal != null && !isRegenerating)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.chevron_right, size: 16, color: ElioColors.textMuted),
                    ),
                  // Regenerate button
                  GestureDetector(
                    onTap: isRegenerating ? null : onRegenerate,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ElioColors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ElioColors.border),
                      ),
                      child: isRegenerating
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                color: ElioColors.amber,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.refresh, size: 16, color: ElioColors.textSecondary),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (isRegenerating)
                _buildLoadingState()
              else if (meal == null)
                _buildEmptySlot()
              else
                _buildMealContent(meal!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 18,
          width: 200,
          decoration: BoxDecoration(
            color: ElioColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 14,
          width: 140,
          decoration: BoxDecoration(
            color: ElioColors.border.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySlot() {
    return Text(
      'Tap ↺ to generate',
      style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
    );
  }

  Widget _buildMealContent(MealSlot meal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          meal.title,
          style: ElioText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          meal.description,
          style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _TimeBadge(minutes: meal.totalTimeMinutes),
            const SizedBox(width: 8),
            if (meal.dietaryTags.isNotEmpty)
              ...meal.dietaryTags.take(2).map((tag) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _DietaryTag(label: tag),
              )),
          ],
        ),
      ],
    );
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _TimeBadge extends StatelessWidget {
  final int minutes;
  const _TimeBadge({required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ElioColors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 11, color: ElioColors.amber),
          const SizedBox(width: 3),
          Text(
            '$minutes min',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ElioColors.amber,
            ),
          ),
        ],
      ),
    );
  }
}

class _DietaryTag extends StatelessWidget {
  final String label;
  const _DietaryTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: ElioColors.navy.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: ElioColors.navy,
        ),
      ),
    );
  }
}

// ─── Shopping dialog item model ──────────────────────────────────────────────

class _ShoppingDialogItem {
  String name;
  String quantity;
  bool included;
  final bool isRestock;

  _ShoppingDialogItem({
    required this.name,
    required this.quantity,
    this.included = true,
    this.isRestock = false,
  });
}

// ─── Add to shopping list dialog ─────────────────────────────────────────────

class _AddToShoppingDialog extends StatefulWidget {
  final List<_ShoppingDialogItem> items;

  const _AddToShoppingDialog({required this.items});

  @override
  State<_AddToShoppingDialog> createState() => _AddToShoppingDialogState();
}

class _AddToShoppingDialogState extends State<_AddToShoppingDialog> {
  late List<_ShoppingDialogItem> _items;

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
        backgroundColor: ElioColors.white,
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
            child: Text('Cancel', style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary)),
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
              color: ElioColors.navy,
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
      backgroundColor: ElioColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                    style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleAll(true),
                        child: Text(
                          'Select all',
                          style: ElioText.label.copyWith(
                            color: ElioColors.sky,
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
                            color: ElioColors.textMuted,
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
              child: _items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'All ingredients are already in your pantry!',
                          style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
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
                              color: item.included ? Colors.transparent : ElioColors.offWhite.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                // Checkbox
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: item.included ? ElioColors.navy : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: item.included ? ElioColors.navy : ElioColors.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: item.included
                                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                // Name
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
                                              ? ElioColors.textPrimary
                                              : ElioColors.textMuted,
                                          decoration: item.included
                                              ? null
                                              : TextDecoration.lineThrough,
                                          decorationColor: ElioColors.textMuted,
                                        ),
                                      ),
                                      if (item.quantity.isNotEmpty)
                                        Text(
                                          item.quantity,
                                          style: ElioText.label.copyWith(
                                            color: ElioColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Restock badge
                                if (item.isRestock)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: ElioColors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: ElioColors.amber.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      'Restock',
                                      style: ElioText.label.copyWith(
                                        color: ElioColors.amber,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                // Edit button
                                GestureDetector(
                                  onTap: () => _editItem(i),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.edit_outlined, size: 16, color: ElioColors.textMuted),
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
                  // Add to shopping list button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _includedCount > 0
                          ? () => Navigator.pop(context, true)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ElioColors.amber,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: ElioColors.border,
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
                  // View shopping list link
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context, false);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfileScreen(initialTab: 3)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'View shopping list',
                        style: ElioText.bodyMedium.copyWith(
                          color: ElioColors.sky,
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
