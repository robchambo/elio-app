// lib/widgets/elio/elio_bottom_nav.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';

enum ElioNavTab { home, pantry, recipes, shoppingList }

class ElioBottomNav extends StatelessWidget {
  final ElioNavTab active;
  final ValueChanged<ElioNavTab> onTap;

  const ElioBottomNav({super.key, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // SafeArea(top:false) lifts the nav row above the system bottom inset
    // (Samsung 3-button nav, gesture pill) so the icons aren't clipped by
    // back/home/recents. The Container colour extends *into* the inset so
    // the bar looks continuous rather than leaving a strip of off-white
    // behind the system buttons.
    return Material(
      color: ElioColors.cream,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 95, // visual nav row height; SafeArea adds inset on top
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_outlined, label: 'HOME',
                    active: active == ElioNavTab.home, onTap: () => onTap(ElioNavTab.home)),
                _NavItem(icon: Icons.kitchen_outlined, label: 'PANTRY',
                    active: active == ElioNavTab.pantry, onTap: () => onTap(ElioNavTab.pantry)),
                _NavItem(icon: Icons.menu_book_outlined, label: 'RECIPES',
                    active: active == ElioNavTab.recipes, onTap: () => onTap(ElioNavTab.recipes)),
                _NavItem(icon: Icons.checklist_outlined, label: 'SHOPPING LIST',
                    active: active == ElioNavTab.shoppingList, onTap: () => onTap(ElioNavTab.shoppingList)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = active ? ElioColors.espresso : ElioColors.mocha;
    return InkWell(
      onTap: onTap,
      borderRadius: ElioRadii.all(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: ElioTextStyles.tabLabelStyle.copyWith(color: fg)),
            const SizedBox(height: 4),
            // Active-tab tick — small terracotta underline below the label.
            // SizedBox keeps the row vertical metrics stable on idle tabs.
            SizedBox(
              height: 2,
              width: 18,
              child: active
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                        color: ElioColors.terracotta,
                        borderRadius: BorderRadius.all(Radius.circular(1)),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
