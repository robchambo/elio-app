import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../models/meal_plan_models.dart';
import '../../services/meal_plan_service.dart';
import '../../services/firestore_service.dart';
import '../shopping/shopping_list_screen.dart';
import '../../utils/region_utils.dart';

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

  // ── State ──────────────────────────────────────────────────────────
  MealPlan? _plan;
  bool _isGenerating = false;
  int _selectedDayIndex = 0;

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
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedDayIndex = _tabController.index);
      }
    });
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
          _selectedDayIndex = 0;
          _tabController.animateTo(0);
        });
        _savePlan();
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

  void _openShoppingList() {
    if (_plan == null) return;
    final shoppingList = ShoppingList.fromMealPlan(
      _plan!,
      alreadyHave: [..._alwaysHave, ..._almostAlwaysHave],
      runningLowItems: _runningLowItems,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShoppingListScreen(shoppingList: shoppingList),
      ),
    );
  }

  void _openMealDetail(MealSlot meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MealDetailSheet(meal: meal),
    );
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
              onPressed: _openShoppingList,
              backgroundColor: ElioColors.navy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.shopping_cart_outlined, size: 20),
              label: const Text(
                'Shopping List',
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
            onTap: () {
              if (_plan != null) {
                // Clear plan and return to config screen
                setState(() => _plan = null);
                _firestore.deleteMealPlan();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: const Icon(Icons.arrow_back_ios_new, size: 20, color: ElioColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Meal Planner', style: ElioText.headingLarge),
                Text(
                  _plan == null
                      ? 'Generate your week in one tap'
                      : 'Tap a meal to view · ← to reconfigure',
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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

    // Map tab index → full day name → find in plan (plan may not include all 7 days)
    const fullDayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final selectedDayName = fullDayNames[_selectedDayIndex];
    final dayOrNull = _plan!.days.where((d) => d.dayName == selectedDayName).firstOrNull;

    if (dayOrNull == null) {
      return Center(
        child: Text(
          '$selectedDayName is not included\nin this meal plan.',
          textAlign: TextAlign.center,
          style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
        ),
      );
    }

    final day = dayOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        children: MealType.values.map((type) {
          final meal = day.meals[type];
          final slotKey = '${_selectedDayIndex}_${type.name}';
          final isRegenerating = _regeneratingSlots.contains(slotKey);
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _MealCard(
              mealType: type,
              meal: meal,
              isRegenerating: isRegenerating,
              onRegenerate: () => _regenerateMeal(_selectedDayIndex, type),
              onTap: meal != null && !isRegenerating ? () => _openMealDetail(meal) : null,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            const SizedBox(width: 5),
            Text(
              hasExistingPlan ? 'Redo week' : 'Generate',
              style: TextStyle(
                fontSize: 13,
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

// ─── Meal detail bottom sheet ─────────────────────────────────────────────────
class _MealDetailSheet extends StatelessWidget {
  final MealSlot meal;

  const _MealDetailSheet({required this.meal});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ElioColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(meal.title, style: ElioText.headingLarge),
                      const SizedBox(height: 6),
                      Text(
                        meal.description,
                        style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                      ),
                      const SizedBox(height: 14),

                      // Meta badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _TimeBadge(minutes: meal.totalTimeMinutes),
                          _TimeBadge(minutes: meal.prepTimeMinutes, label: 'prep'),
                          if (meal.caloriesPerServing != null)
                            _MetaBadge(
                              icon: Icons.local_fire_department_outlined,
                              label: '${meal.caloriesPerServing} kcal',
                              color: const Color(0xFFE53935),
                            ),
                          if (RegionUtils.formatCost(usd: meal.estimatedCostPerServingUSD, gbp: meal.estimatedCostPerServingGBP) != null)
                            _MetaBadge(
                              icon: Icons.attach_money,
                              label: RegionUtils.formatCost(usd: meal.estimatedCostPerServingUSD, gbp: meal.estimatedCostPerServingGBP)!,
                              color: const Color(0xFF2E7D32),
                            ),
                          ...meal.dietaryTags.map((tag) => _DietaryTag(label: tag)),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Ingredients
                      Text('Ingredients', style: ElioText.headingMedium),
                      const SizedBox(height: 10),
                      ...meal.ingredients.map((ing) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: ElioColors.amber,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                ing.displayString,
                                style: ElioText.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )),

                      if (meal.steps.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Method', style: ElioText.headingMedium),
                        const SizedBox(height: 10),
                        ...meal.steps.asMap().entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: ElioColors.navy,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    entry.value,
                                    style: ElioText.bodyMedium,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeBadge extends StatelessWidget {
  final int minutes;
  final String? label;
  const _TimeBadge({required this.minutes, this.label});

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
            label != null ? '$minutes min $label' : '$minutes min',
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
