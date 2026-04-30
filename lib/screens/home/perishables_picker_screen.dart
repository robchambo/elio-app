// lib/screens/home/perishables_picker_screen.dart
//
// Sprint 16.3 — restores the "pick what you want to use up" affordance lost
// in the UI refresh. Pushed from RecipePreferencesScreen via the
// "Got something to use up?" CTA.
//
// Renders:
//   • Hero heading — "use up / what you have?"
//   • A grid of selectable ElioChips for each perishable inventory item
//     supplied by the parent (already loaded on Home from Firestore).
//   • A custom-add field for items not in the pantry ("leftover roast
//     chicken") — appears as additional chips under a small eyebrow.
//   • A bottom-anchored ElioBigButton that returns the selected names to
//     the caller via Navigator.pop.
//
// The screen is self-contained: the caller passes initial state in,
// receives the final List<String> on pop. No Firestore coupling here.

import 'package:flutter/material.dart';

import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_app_scaffold.dart';
import '../../widgets/elio/elio_big_button.dart';
import '../../widgets/elio/elio_chip.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';

class PerishablesPickerScreen extends StatefulWidget {
  /// Names of perishable inventory items pulled from Firestore — shown as
  /// pre-built chips at the top.
  final List<String> perishableInventory;

  /// Items already chosen (re-opening the picker after a partial selection
  /// or after a custom add). Items not in [perishableInventory] are
  /// rendered under the "Other" eyebrow.
  final List<String> initialSelection;

  /// Sprint 16.4 (Bug 2): when [initialSelection] is empty, auto-select
  /// the first [autoSelectCount] entries of [perishableInventory] (which
  /// HomeScreen pre-sorts by expiry urgency). Defaults to 3 — feels like
  /// the right "we picked something for you, change if you want" nudge.
  /// Pass 0 to disable auto-select entirely.
  final int autoSelectCount;

  const PerishablesPickerScreen({
    super.key,
    required this.perishableInventory,
    this.initialSelection = const [],
    this.autoSelectCount = 3,
  });

  @override
  State<PerishablesPickerScreen> createState() =>
      _PerishablesPickerScreenState();
}

class _PerishablesPickerScreenState extends State<PerishablesPickerScreen> {
  final TextEditingController _customController = TextEditingController();

  /// All chips currently rendered. Inventory items always appear; custom
  /// adds are appended in entry order. We track selection separately.
  late List<String> _allItems;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _allItems = List<String>.from(widget.perishableInventory);
    _selected = {...widget.initialSelection};
    // Surface any prior selections that aren't in inventory as custom chips.
    for (final item in widget.initialSelection) {
      if (!_allItems.any((i) => i.toLowerCase() == item.toLowerCase())) {
        _allItems.add(item);
      }
    }
    // Sprint 16.4 (Bug 2): if we arrived with no prior selection, pre-tick
    // the top-N most urgent perishables (caller-sorted by expiry). The
    // user can immediately tap Generate without having to think about it,
    // and can still untick / add more if they want.
    if (widget.initialSelection.isEmpty && widget.autoSelectCount > 0) {
      final take = widget.perishableInventory
          .take(widget.autoSelectCount)
          .toList();
      _selected.addAll(take);
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────

  void _toggle(String name) {
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
  }

  void _addCustom() {
    final raw = _customController.text.trim();
    if (raw.isEmpty) return;
    final lower = raw.toLowerCase();
    if (_allItems.any((i) => i.toLowerCase() == lower)) {
      // Already a chip — just select it and clear the field.
      final existing = _allItems.firstWhere((i) => i.toLowerCase() == lower);
      setState(() {
        _selected.add(existing);
        _customController.clear();
      });
      return;
    }
    setState(() {
      _allItems.add(raw);
      _selected.add(raw);
      _customController.clear();
    });
  }

  void _confirm() {
    Navigator.of(context).pop<List<String>>(_selected.toList());
  }

  void _clearAll() {
    setState(() => _selected.clear());
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Split: pantry inventory chips first, custom chips under their own
    // eyebrow so the user can see what they typed is being included.
    final inventoryLower =
        widget.perishableInventory.map((s) => s.toLowerCase()).toSet();
    final pantryChips =
        _allItems.where((i) => inventoryLower.contains(i.toLowerCase())).toList();
    final customChips =
        _allItems.where((i) => !inventoryLower.contains(i.toLowerCase())).toList();

    return ElioAppScaffold(
      showBottomNav: false,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                ElioSpacing.screenEdge,
                ElioSpacing.lg,
                ElioSpacing.screenEdge,
                ElioSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ElioHeroHeading(
                    lines: ['use up', 'what you have?'],
                    amberLastLine: true,
                    showUnderline: true,
                  ),
                  const SizedBox(height: ElioSpacing.md),
                  Text(
                    'Tap anything you want me to centre the recipe around. '
                    'Selected items become required ingredients.',
                    style: ElioTextStyles.bodySmall.copyWith(
                      color: ElioColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: ElioSpacing.xl),

                  // ── Pantry perishables ─────────────────────────────
                  if (pantryChips.isNotEmpty) ...[
                    const ElioEyebrow('from your pantry'),
                    const SizedBox(height: ElioSpacing.sm),
                    Wrap(
                      spacing: ElioSpacing.sm,
                      runSpacing: ElioSpacing.sm,
                      children: [
                        for (final item in pantryChips)
                          ElioChip(
                            label: item,
                            selected: _selected.contains(item),
                            onTap: () => _toggle(item),
                          ),
                      ],
                    ),
                    const SizedBox(height: ElioSpacing.xl),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(ElioSpacing.md),
                      decoration: BoxDecoration(
                        color: ElioColors.cream,
                        borderRadius: BorderRadius.circular(ElioRadii.card),
                      ),
                      child: Text(
                        'No perishables flagged in your pantry yet — add items '
                        'with the Pantry tab or type one below.',
                        style: ElioTextStyles.bodySmall,
                      ),
                    ),
                    const SizedBox(height: ElioSpacing.xl),
                  ],

                  // ── Custom additions ───────────────────────────────
                  const ElioEyebrow('something else'),
                  const SizedBox(height: ElioSpacing.sm),
                  Text(
                    'Leftovers, half-used jars, anything not in the pantry.',
                    style: ElioTextStyles.bodySmall.copyWith(
                      color: ElioColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: ElioSpacing.sm),
                  if (customChips.isNotEmpty) ...[
                    Wrap(
                      spacing: ElioSpacing.sm,
                      runSpacing: ElioSpacing.sm,
                      children: [
                        for (final item in customChips)
                          ElioChip(
                            label: item,
                            selected: _selected.contains(item),
                            onTap: () => _toggle(item),
                          ),
                      ],
                    ),
                    const SizedBox(height: ElioSpacing.sm),
                  ],
                  _CustomAddField(
                    controller: _customController,
                    onSubmit: _addCustom,
                  ),
                  const SizedBox(height: ElioSpacing.xl),

                  if (_selected.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _clearAll,
                        child: const Text('Clear selection'),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Sticky bottom CTA ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(
              ElioSpacing.screenEdge,
              ElioSpacing.md,
              ElioSpacing.screenEdge,
              ElioSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: ElioColors.offWhite,
              border: Border(top: BorderSide(color: ElioColors.border)),
            ),
            child: ElioBigButton(
              label: _selected.isEmpty
                  ? 'Skip — no specific items'
                  : 'Use these (${_selected.length})',
              onTap: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom-add inline field ─────────────────────────────────────────────
class _CustomAddField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _CustomAddField({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(ElioRadii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSubmit(),
              textInputAction: TextInputAction.done,
              style: ElioTextStyles.body,
              decoration: InputDecoration(
                hintText: 'e.g. leftover roast chicken',
                hintStyle: ElioTextStyles.body
                    .copyWith(color: ElioColors.textSecondary),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: ElioColors.terracotta,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onSubmit,
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Add',
            ),
          ),
        ],
      ),
    );
  }
}
