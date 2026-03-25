import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../models/meal_plan_models.dart';
import '../../services/meal_plan_service.dart';
import '../../services/firestore_service.dart';
import '../shopping/shopping_list_screen.dart';

// ─────────────────────────────────────────────
// MealPlanScreen
// Design: approachable utility.
//
// Layout:
//   • Header with "Generate Week" CTA
//   • Horizontal day selector (Mon–Sun tabs)
//   • 3-card column for Breakfast / Lunch / Dinner
//   • Each card: title, time badge, regenerate ↺ button
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

  // ── User data (loaded once) ────────────────────────────────────────
  List<String> _dietaryRequirements = [];
  List<String> _alwaysHave = [];
  List<String> _almostAlwaysHave = [];
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
      final data = await _firestore.getUserData();
      if (mounted) {
        setState(() {
          _dietaryRequirements = List<String>.from(data['dietaryRequirements'] ?? []);
          _alwaysHave = List<String>.from(data['alwaysHave'] ?? []);
          _almostAlwaysHave = List<String>.from(data['almostAlwaysHave'] ?? []);
          _stylePreferences = List<String>.from(data['stylePreferences'] ?? []);
          _dataLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dataLoaded = true);
    }
  }

  Future<void> _generateWeeklyPlan() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      final plan = await MealPlanService.generateWeeklyPlan(
        dietaryRequirements: _dietaryRequirements,
        alwaysHave: _alwaysHave,
        almostAlwaysHave: _almostAlwaysHave,
        stylePreferences: _stylePreferences,
      );
      if (mounted) {
        setState(() {
          _plan = plan;
          _selectedDayIndex = 0;
          _tabController.animateTo(0);
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
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _regenerateMeal(int dayIndex, MealType mealType) async {
    if (_plan == null) return;
    final slotKey = '${dayIndex}_${mealType.name}';
    if (_regeneratingSlots.contains(slotKey)) return;

    setState(() => _regeneratingSlots.add(slotKey));

    try {
      // Collect existing titles to avoid repeats
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
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShoppingListScreen(shoppingList: shoppingList),
      ),
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
            onTap: () => Navigator.of(context).pop(),
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
                      : 'Tap ↺ on any meal to swap it',
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Generate / Regenerate button
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
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
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

    // Show the selected day's meals
    final day = _plan!.days[_selectedDayIndex];
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
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ElioColors.amber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month_outlined, color: ElioColors.amber, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'Plan your whole week',
              style: ElioText.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Elio will generate 21 meals — breakfast, lunch, and dinner for every day — tailored to your pantry and dietary needs.',
              style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateWeeklyPlan,
                child: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Generate My Week →'),
              ),
            ),
          ],
        ),
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
          border: hasExistingPlan
              ? Border.all(color: ElioColors.border)
              : null,
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

  const _MealCard({
    required this.mealType,
    required this.meal,
    required this.isRegenerating,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
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
                  mealType.displayName,
                  style: ElioText.label.copyWith(
                    color: ElioColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
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
