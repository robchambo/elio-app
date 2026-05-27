import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../../data/pantry_categories.dart';
import '../../models/elio_models.dart';
import '../../services/analytics_service.dart';
import '../../services/guest_pantry_service.dart';
import '../../theme/elio_radii.dart';
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
// Screen 11 — Pantry (staples)
//
// 12 category grid; tap cycles tile unselected → usually → always →
// unselected. Long-press (300 ms via RawGestureDetector in
// ElioPantryItemTile) jumps straight to always.
//
// ~16 items pre-selected in the "usually" tier, filtered against the
// user's dietary + allergy selections from screens 04/05.
//
// On Continue:
//   • staple tiers are mapped into InventoryItem with tier
//     'alwaysHave' (always) / 'almostAlwaysHave' (usually);
//   • any perishables already present in controller.state.inventory
//     (user navigated back from screen 12) are preserved;
//   • the selection is persisted to SharedPreferences via
//     GuestPantryService.saveStaples for crash-resume.
//
// Copy + behaviour: docs/onboarding/11-pantry-staples.md.
// ─────────────────────────────────────────────

/// Category order shown on screen — matches the spec §Copy list.
const List<String> _categoryOrder = [
  'Oils & Vinegars',
  'Spices & Seasonings',
  'Sauces & Condiments',
  'Canned & Jarred',
  'Grains & Pasta',
  'Dairy & Eggs',
  'Baking Essentials',
  'Frozen Staples',
  'Asian Pantry',
  'Indian Pantry',
  'Mediterranean',
  'Mexican & Latin',
];

/// Default-selected rule for a single item.
///
/// * [dietaryExcludes] — if any of the user's dietary selections match, the
///   item is dropped from the pre-selected defaults. E.g. honey is excluded
///   for vegans.
/// * [allergyExcludes] — if any of the user's allergy tokens match, the item
///   is dropped from defaults.
class _DefaultRule {
  final String category;
  final List<String> dietaryExcludes;
  final List<String> allergyExcludes;
  const _DefaultRule({
    required this.category,
    this.dietaryExcludes = const [],
    this.allergyExcludes = const [],
  });
}

/// Pre-selected defaults per docs/onboarding/11-pantry-staples.md §Pre-selected
/// defaults table — ~16 items, all entering in the "usually" tier.
const Map<String, _DefaultRule> _kDefaultStaples = {
  // Cooking oils (Olive, Vegetable) intentionally excluded — Sprint 16.3
  // Bug 10: everyone has a basic cooking oil, so the Gemini prompt now
  // assumes water/salt/oil. Vinegars stay (specialty, not assumed).
  // Spices & Seasonings
  'Salt': _DefaultRule(category: 'Spices & Seasonings'),
  'Black pepper': _DefaultRule(category: 'Spices & Seasonings'),
  'Mixed herbs': _DefaultRule(category: 'Spices & Seasonings'),
  'Paprika': _DefaultRule(category: 'Spices & Seasonings'),
  // Sauces & Condiments
  'Ketchup': _DefaultRule(category: 'Sauces & Condiments'),
  'Soy sauce': _DefaultRule(
    category: 'Sauces & Condiments',
    allergyExcludes: ['soy'],
  ),
  'Mustard': _DefaultRule(category: 'Sauces & Condiments'),
  'Honey': _DefaultRule(
    category: 'Sauces & Condiments',
    dietaryExcludes: ['vegan'],
  ),
  // Canned & Jarred
  'Canned tomatoes': _DefaultRule(category: 'Canned & Jarred'),
  'Chickpeas': _DefaultRule(category: 'Canned & Jarred'),
  // Grains & Pasta
  'Rice (white)': _DefaultRule(category: 'Grains & Pasta'),
  'Oats': _DefaultRule(
    category: 'Grains & Pasta',
    allergyExcludes: ['gluten', 'wheat'],
  ),
  // Dairy & Eggs
  'Eggs': _DefaultRule(
    category: 'Dairy & Eggs',
    dietaryExcludes: ['vegan'],
    allergyExcludes: ['egg'],
  ),
  'Butter': _DefaultRule(
    category: 'Dairy & Eggs',
    dietaryExcludes: ['vegan', 'dairyFree'],
    allergyExcludes: ['dairy'],
  ),
  // Baking Essentials
  'All-purpose flour': _DefaultRule(
    category: 'Baking Essentials',
    allergyExcludes: ['gluten', 'wheat'],
  ),
  'Granulated sugar': _DefaultRule(category: 'Baking Essentials'),
  'Baking powder': _DefaultRule(category: 'Baking Essentials'),
  // Frozen Staples
  'Frozen peas': _DefaultRule(category: 'Frozen Staples'),
};

/// True when [rule] should be excluded given the user's screens 04/05 state.
bool _excludedByUser(
  _DefaultRule rule,
  List<String> dietary,
  List<String> allergies,
) {
  for (final d in rule.dietaryExcludes) {
    if (dietary.contains(d)) return true;
  }
  for (final a in rule.allergyExcludes) {
    for (final userAllergy in allergies) {
      if (userAllergy.toLowerCase() == a.toLowerCase()) return true;
    }
  }
  return false;
}

/// Build the initial tier map: all default-eligible items start in "usually".
/// Items also greyed out by [DietaryFilter] (the cross-cutting block layer)
/// are skipped — they'll render as blocked tiles regardless.
Map<String, String> _buildDefaultTiers(
  List<String> dietary,
  List<String> allergies,
) {
  final map = <String, String>{};
  _kDefaultStaples.forEach((name, rule) {
    if (_excludedByUser(rule, dietary, allergies)) return;
    if (DietaryFilter.isBlocked(
      itemName: name,
      dietary: dietary,
      allergies: allergies,
      categoryName: rule.category,
    )) {
      return;
    }
    map[name] = 'usually';
  });
  return map;
}

class Screen11PantryStaples extends StatefulWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  /// Optional override for testing — defaults to a live GuestPantryService.
  final GuestPantryService? pantryService;

  const Screen11PantryStaples({
    super.key,
    required this.controller,
    required this.onContinue,
    required this.onBack,
    this.pantryService,
  });

  @override
  State<Screen11PantryStaples> createState() => _Screen11PantryStaplesState();
}

class _Screen11PantryStaplesState extends State<Screen11PantryStaples> {
  /// Selected tier per item. Items not in the map are unselected.
  /// tier ∈ {'usually', 'always'}.
  late Map<String, String> _tiers;

  /// Custom items the user added via "+ Add something", keyed by category.
  /// Display order = user-added order.
  final Map<String, List<String>> _customItemsByCategory = {};

  @override
  void initState() {
    super.initState();
    _hydrateFromControllerOrDefaults();
  }

  /// Re-populates [_tiers] + [_customItemsByCategory] from the
  /// onboarding controller's current inventory if the user has
  /// already passed through this screen (back-nav from screen 12).
  /// Otherwise falls back to the dietary-aware defaults.
  void _hydrateFromControllerOrDefaults() {
    final existing = widget.controller.state.inventory
        .where((i) => i.tier == 'alwaysHave' || i.tier == 'almostAlwaysHave')
        .toList();

    if (existing.isEmpty) {
      _tiers = _buildDefaultTiers(
        widget.controller.state.dietary,
        widget.controller.state.allergies,
      );
      return;
    }

    _tiers = <String, String>{
      for (final i in existing)
        i.name: i.tier == 'alwaysHave' ? 'always' : 'usually',
    };

    // Re-bucket any items not present in the canonical spec back into
    // their user-chosen category, so the "+ Add something" flow on
    // re-entry sees them.
    final specNames = <String>{};
    for (final cat in PantryCategories.all) {
      specNames.addAll(cat.allItems);
    }
    for (final i in existing) {
      if (specNames.contains(i.name)) continue;
      final cat = i.category;
      if (cat == null) continue;
      _customItemsByCategory.putIfAbsent(cat, () => <String>[]).add(i.name);
    }
  }

  /// Flat list of every item visible on this screen (spec items across all
  /// categories + custom items already added). Used as the dedup scope
  /// when the user tries to add another.
  List<String> _allVisibleItems() {
    final names = <String>[];
    for (final catName in _categoryOrder) {
      final cat = PantryCategories.byName(catName);
      if (cat != null) names.addAll(cat.allItems);
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
        // Silently promote the existing tile to the "usually" tier.
        setState(() {
          _tiers[existingName] = 'usually';
        });
      case AddItemAddNew(:final name):
        setState(() {
          final list = _customItemsByCategory.putIfAbsent(
            categoryName,
            () => <String>[],
          );
          list.add(name);
          _tiers[name] = 'usually';
        });
    }
  }

  void _cycle(String name, String next) {
    setState(() {
      if (next == 'unselected') {
        _tiers.remove(name);
      } else {
        _tiers[name] = next;
      }
    });
  }

  void _jumpToAlways(String name) {
    setState(() {
      _tiers[name] = 'always';
    });
  }

  String _tierFor(String name) => _tiers[name] ?? 'unselected';

  int get _count => _tiers.length;

  /// Reverse map: custom item name → the category the user added it under.
  /// Used so custom items persist with their user-chosen category, since
  /// `PantryCategories.categorize` only knows about spec items.
  String? _categoryForCustom(String name) {
    for (final entry in _customItemsByCategory.entries) {
      if (entry.value.contains(name)) return entry.key;
    }
    return null;
  }

  Future<void> _onContinue() async {
    // Map tier strings → InventoryItem tier values used elsewhere in the app.
    final newStaples = <InventoryItem>[];
    _tiers.forEach((name, tier) {
      newStaples.add(
        InventoryItem(
          name: name,
          tier: tier == 'always' ? 'alwaysHave' : 'almostAlwaysHave',
          category:
              PantryCategories.categorize(name) ?? _categoryForCustom(name),
        ),
      );
    });

    // Preserve any perishables already in inventory (back-nav from screen 12).
    final preserved = widget.controller.state.inventory
        .where((i) => i.tier == 'perishable')
        .toList();

    widget.controller.setInventory([...preserved, ...newStaples]);

    final svc = widget.pantryService ?? GuestPantryService();
    await svc.saveStaples(Map<String, String>.from(_tiers));

    if (!mounted) return;
    AnalyticsService.instance.logEvent(
      'onboarding_step_completed',
      const {'step_index': 11, 'step_name': 'pantry_staples'},
    );
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
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
                    color: ElioColors.espresso,
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: ElioSpacing.sm),
                  const Expanded(
                    child: ElioOnboardingProgressBar(value: 11 / 15),
                  ),
                ],
              ),
            ),
            // SCROLLABLE MIDDLE — heading/subhead scroll together with the
            // category grids; category headers stay sticky while scrolling.
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
                    label: 'Next',
                    onTap: _onContinue,
                    trailingIcon: Icons.arrow_forward,
                  ),
                  const SizedBox(height: ElioSpacing.xs),
                  Text(
                    '$_count things in your kitchen',
                    textAlign: TextAlign.center,
                    style: ElioTextStyles.bodySmall.copyWith(
                      color: ElioColors.mocha,
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
                lines: ['What do you', 'always have in?'],
                amberLastLine: true,
              ),
              const SizedBox(height: ElioSpacing.sm),
              Text(
                "Tap what you've usually got. Long-press anything you always have — we'll lean on those heavier.",
                style: ElioTextStyles.body.copyWith(
                  color: ElioColors.mocha,
                ),
              ),
              const SizedBox(height: ElioSpacing.xs),
              ElioPantryTierLegend.staples(),
            ],
          ),
        ),
      ),
    ];
    for (final catName in _categoryOrder) {
      final cat = PantryCategories.byName(catName);
      if (cat == null) continue;
      final specItems = cat.allItems;
      final customItems = _customItemsByCategory[catName] ?? const <String>[];
      final items = [...specItems, ...customItems];
      if (items.isEmpty && customItems.isEmpty) continue;

      slivers.add(
        SliverPersistentHeader(
          // Sprint 16.2 bug: pinned:true stacked every previous
          // category header at the top as the user scrolled, so by
          // the 12th category ~half the viewport was headers. Let
          // the headers scroll out of view with their content — only
          // the currently-visible category reads as a header
          // regardless.
          pinned: false,
          delegate: ElioStickyCategoryHeader(title: catName),
        ),
      );
      // Grid children = all items + a trailing "+ Add something" tile.
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
                    key: ValueKey('staple_add_$catName'),
                    onTap: () => _openAddDialog(catName),
                  );
                }
                final name = items[index];
                final blocked = DietaryFilter.blockReasons(
                  itemName: name,
                  dietary: widget.controller.state.dietary,
                  allergies: widget.controller.state.allergies,
                  categoryName: catName,
                );
                return ElioPantryItemTile(
                  key: ValueKey('staple_$name'),
                  label: name,
                  tier: _tierFor(name),
                  tiers: const ['unselected', 'usually', 'always'],
                  onCycle: (next) => _cycle(name, next),
                  onLongPress: () => _jumpToAlways(name),
                  blockedReasons: blocked,
                );
              },
              childCount: childCount,
            ),
          ),
        ),
      );
    }
    // Bottom padding so the last grid isn't flush with the CTA.
    slivers.add(
      const SliverToBoxAdapter(child: SizedBox(height: ElioSpacing.lg)),
    );
    return slivers;
  }
}

// A convenience corner — used only via `ElioRadii.md` if needed elsewhere.
// (Kept colocated so the file is self-contained for Kate's visual review.)
// ignore: unused_element
const double _tileRadius = ElioRadii.md;
