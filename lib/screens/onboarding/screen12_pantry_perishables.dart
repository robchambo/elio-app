import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../../models/elio_models.dart';
import '../../services/analytics_service.dart';
import '../../services/guest_pantry_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../utils/dietary_filter.dart';
import '../../widgets/elio/elio_add_pantry_item_dialog.dart';
import '../../widgets/elio/elio_add_something_tile.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../../widgets/elio/elio_onboarding_progress_bar.dart';
import '../../widgets/elio/elio_pantry_item_tile.dart';
import '../../widgets/elio/elio_pantry_tier_legend.dart';
import '../../widgets/elio/elio_sticky_category_header.dart';

// ─────────────────────────────────────────────
// Screen 12 — Pantry (perishables)
//
// Four fresh-item categories. Tap cycles:
//   unselected → fresh → thisWeek → today → unselected.
// Long-press opens a dialog-based action sheet (NOT a modal bottom
// sheet — see CLAUDE.md hard rule: bottom sheets do not layer reliably
// in Flutter; showDialog is the required pattern).
//
// Derived data on Continue (defaults the user can override later):
//   today    → expiryDate = DateTime.now(),      runningLow = true
//   thisWeek → expiryDate = now + 3 days,        runningLow = false
//   fresh    → expiryDate = now + 7 days,        runningLow = false
// Matches docs/onboarding/12-pantry-perishables.md §Data model.
//
// Perishables merge into controller.state.inventory alongside any
// staples captured on screen 11. Selections are persisted to
// SharedPreferences via GuestPantryService.savePerishables for
// crash-resume.
//
// Copy + behaviour: docs/onboarding/12-pantry-perishables.md.
// ─────────────────────────────────────────────

class _PerishableCategory {
  final String name;
  final List<String> items;
  const _PerishableCategory(this.name, this.items);
}

const List<_PerishableCategory> _perishableCategories = [
  _PerishableCategory('Fresh veg', [
    'Onion',
    'Garlic',
    'Carrot',
    'Potato',
    'Tomato',
    'Red pepper',
    'Yellow pepper',
    'Courgette',
    'Aubergine',
    'Spinach',
    'Broccoli',
    'Cauliflower',
    'Mushroom',
    'Cucumber',
    'Avocado',
    'Spring onion',
    'Leek',
    'Sweet potato',
    'Lettuce',
    'Celery',
  ]),
  _PerishableCategory('Fresh fruit', [
    'Lemon',
    'Lime',
    'Apple',
    'Banana',
    'Berries',
    'Orange',
  ]),
  _PerishableCategory('Fresh meat & fish', [
    'Chicken breast',
    'Chicken thighs',
    'Mince (beef)',
    'Mince (pork)',
    'Bacon',
    'Sausages',
    'Salmon',
    'White fish',
    'Prawns',
    'Steak',
  ]),
  _PerishableCategory('Fresh dairy & herbs', [
    'Milk',
    'Yoghurt',
    'Double cream',
    'Parsley',
    'Coriander',
    'Basil',
    'Mint',
    'Chives',
    'Dill',
  ]),
];

class Screen12PantryPerishables extends StatefulWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback onBack;
  final GuestPantryService? pantryService;

  const Screen12PantryPerishables({
    super.key,
    required this.controller,
    required this.onContinue,
    required this.onBack,
    this.pantryService,
  });

  @override
  State<Screen12PantryPerishables> createState() =>
      _Screen12PantryPerishablesState();
}

class _Screen12PantryPerishablesState extends State<Screen12PantryPerishables> {
  /// tier ∈ {'fresh', 'thisWeek', 'today'}. Absent keys are unselected.
  final Map<String, String> _tiers = {};

  /// Custom items added via "+ Add something", keyed by perishable category.
  final Map<String, List<String>> _customItemsByCategory = {};

  /// Flat list of everything visible on this screen (spec perishables +
  /// already-added custom items). Used as the dedup scope.
  List<String> _allVisibleItems() {
    final names = <String>[];
    for (final cat in _perishableCategories) {
      names.addAll(cat.items);
    }
    for (final list in _customItemsByCategory.values) {
      names.addAll(list);
    }
    return names;
  }

  Future<void> _openAddDialog(String categoryName) async {
    final result = await showAddPantryItemDialog(
      context,
      categoryName: categoryName,
      existing: _allVisibleItems(),
    );
    switch (result) {
      case AddItemCancelled():
        return;
      case AddItemPromoteExisting(:final existingName):
        setState(() {
          _tiers[existingName] = 'fresh';
        });
      case AddItemAddNew(:final name):
        setState(() {
          final list = _customItemsByCategory.putIfAbsent(
            categoryName,
            () => <String>[],
          );
          list.add(name);
          _tiers[name] = 'fresh';
        });
    }
  }

  int get _freshCount =>
      _tiers.values.where((t) => t == 'fresh').length;

  int get _todayCount => _tiers.values.where((t) => t == 'today').length;

  void _cycle(String name, String next) {
    setState(() {
      if (next == 'unselected') {
        _tiers.remove(name);
      } else {
        _tiers[name] = next;
      }
    });
  }

  void _setTier(String name, String? tier) {
    setState(() {
      if (tier == null) {
        _tiers.remove(name);
      } else {
        _tiers[name] = tier;
      }
    });
  }

  Future<void> _openLongPressMenu(String name) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(name),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'fresh'),
            child: const Text('Mark fresh'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'thisWeek'),
            child: const Text('Mark this week'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'today'),
            child: const Text('Mark today'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '__remove__'),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == '__remove__') {
      _setTier(name, null);
    } else {
      _setTier(name, choice);
    }
  }

  Future<void> _onContinue() async {
    final now = DateTime.now();
    final perishables = <InventoryItem>[];
    _tiers.forEach((name, tier) {
      DateTime? expiry;
      var runningLow = false;
      switch (tier) {
        case 'today':
          expiry = now;
          runningLow = true;
          break;
        case 'thisWeek':
          expiry = now.add(const Duration(days: 3));
          runningLow = false;
          break;
        case 'fresh':
        default:
          expiry = now.add(const Duration(days: 7));
          runningLow = false;
          break;
      }
      perishables.add(
        InventoryItem(
          name: name,
          tier: 'perishable',
          isRunningLow: runningLow,
          expiryDate: expiry,
        ),
      );
    });

    // Preserve staples already in inventory (set by screen 11).
    final staples = widget.controller.state.inventory
        .where((i) => i.tier != 'perishable')
        .toList();

    widget.controller.setInventory([...staples, ...perishables]);

    final svc = widget.pantryService ?? GuestPantryService();
    await svc.savePerishables(Map<String, String>.from(_tiers));

    if (!mounted) return;
    AnalyticsService.instance.logEvent(
      'onboarding_step_completed',
      const {'step_index': 12, 'step_name': 'pantry_perishables'},
    );
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final footerRed = _todayCount > 0;
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PINNED TOP — back + progress only.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ElioSpacing.screenEdge,
                ElioSpacing.sm,
                ElioSpacing.screenEdge,
                0,
              ),
              child: Row(
                children: [
                  BackButton(
                    color: ElioColors.navy,
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: ElioSpacing.sm),
                  const Expanded(
                    child: ElioOnboardingProgressBar(value: 12 / 15),
                  ),
                ],
              ),
            ),
            // SCROLLABLE MIDDLE — heading/subhead scroll together with the
            // perishable category grids; category headers stay sticky.
            Expanded(
              child: CustomScrollView(
                slivers: _buildCategorySlivers(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(ElioSpacing.screenEdge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElioBigButton(
                    label: "Let's make something!",
                    onTap: _onContinue,
                    trailingIcon: Icons.arrow_forward,
                  ),
                  const SizedBox(height: ElioSpacing.xs),
                  Text(
                    '$_freshCount fresh · $_todayCount today',
                    textAlign: TextAlign.center,
                    style: ElioTextStyles.bodySmall.copyWith(
                      color: footerRed
                          ? ElioColors.perishToday
                          : ElioColors.textSecondary,
                      fontWeight:
                          footerRed ? FontWeight.w700 : FontWeight.w500,
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

  List<Widget> _buildCategorySlivers() {
    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          ElioSpacing.screenEdge,
          ElioSpacing.md,
          ElioSpacing.screenEdge,
          ElioSpacing.md,
        ),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ElioHeroHeading(
                lines: ['And what\'s', 'fresh right now?'],
                amberLastLine: true,
              ),
              const SizedBox(height: ElioSpacing.sm),
              Text(
                "Tap what you've got in. Tap again if it needs using sooner.",
                style: ElioTextStyles.body.copyWith(
                  color: ElioColors.textSecondary,
                ),
              ),
              const SizedBox(height: ElioSpacing.xs),
              ElioPantryTierLegend.perishables(),
            ],
          ),
        ),
      ),
    ];
    for (final cat in _perishableCategories) {
      final customItems = _customItemsByCategory[cat.name] ?? const <String>[];
      final items = [...cat.items, ...customItems];
      if (items.isEmpty) continue;
      slivers.add(
        SliverPersistentHeader(
          // Sprint 16.2 bug — see screen 11 for rationale. pinned:true
          // stacked every header at the top; scroll them out with
          // their content instead.
          pinned: false,
          delegate: ElioStickyCategoryHeader(title: cat.name),
        ),
      );
      final childCount = items.length + 1;
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: ElioSpacing.screenEdge,
            vertical: ElioSpacing.xs,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: ElioSpacing.sm,
              crossAxisSpacing: ElioSpacing.sm,
              childAspectRatio: 2.4,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == items.length) {
                  return ElioAddSomethingTile(
                    key: ValueKey('perishable_add_${cat.name}'),
                    onTap: () => _openAddDialog(cat.name),
                  );
                }
                final name = items[index];
                final blocked = DietaryFilter.blockReasons(
                  itemName: name,
                  dietary: widget.controller.state.dietary,
                  allergies: widget.controller.state.allergies,
                  categoryName: cat.name,
                );
                return ElioPantryItemTile(
                  key: ValueKey('perishable_$name'),
                  label: name,
                  tier: _tiers[name] ?? 'unselected',
                  tiers: const ['unselected', 'fresh', 'thisWeek', 'today'],
                  onCycle: (next) => _cycle(name, next),
                  onLongPress: () => _openLongPressMenu(name),
                  blockedReasons: blocked,
                );
              },
              childCount: childCount,
            ),
          ),
        ),
      );
    }
    slivers.add(
      const SliverToBoxAdapter(child: SizedBox(height: ElioSpacing.lg)),
    );
    return slivers;
  }
}
