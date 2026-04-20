import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../../models/elio_models.dart';
import '../../services/guest_pantry_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../../widgets/elio/elio_onboarding_progress_bar.dart';
import '../../widgets/elio/elio_pantry_item_tile.dart';
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
// Derived data on Continue:
//   today    → expiryDate = DateTime.now(), runningLow = true
//   thisWeek → expiryDate = now + 7 days,   runningLow = false
//   fresh    → expiryDate = null,           runningLow = false
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
          expiry = now.add(const Duration(days: 7));
          runningLow = false;
          break;
        case 'fresh':
        default:
          expiry = null;
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
            const SizedBox(height: ElioSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ElioSpacing.screenEdge,
              ),
              child: const ElioHeroHeading(
                lines: ['And what\'s', 'fresh right now?'],
                amberLastLine: true,
              ),
            ),
            const SizedBox(height: ElioSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ElioSpacing.screenEdge,
              ),
              child: Text(
                "Tap what you've got in. Tap again if it needs using sooner.",
                style: ElioTextStyles.body.copyWith(
                  color: ElioColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: ElioSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ElioSpacing.screenEdge,
              ),
              child: Text(
                '🟢 Fresh   ·   🟡 This week   ·   🔴 Today',
                style: ElioTextStyles.bodySmall.copyWith(
                  color: ElioColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: ElioSpacing.md),
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
    final slivers = <Widget>[];
    for (final cat in _perishableCategories) {
      if (cat.items.isEmpty) continue;
      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: ElioStickyCategoryHeader(title: cat.name),
        ),
      );
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
                final name = cat.items[index];
                return ElioPantryItemTile(
                  key: ValueKey('perishable_$name'),
                  label: name,
                  tier: _tiers[name] ?? 'unselected',
                  tiers: const ['unselected', 'fresh', 'thisWeek', 'today'],
                  onCycle: (next) => _cycle(name, next),
                  onLongPress: () => _openLongPressMenu(name),
                );
              },
              childCount: cat.items.length,
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
