import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../models/meal_plan_models.dart';

// ─────────────────────────────────────────────
// ShoppingListScreen
// Design: approachable utility.
//
// Derived from a MealPlan — shows all ingredients
// needed for the week, excluding items the user
// already has in their pantry.
//
// Features:
//   • Alphabetically sorted ingredient list
//   • Tap to check/uncheck items
//   • Progress indicator (x of y items)
//   • Share button (plain text list)
// ─────────────────────────────────────────────

class ShoppingListScreen extends StatefulWidget {
  final ShoppingList shoppingList;

  const ShoppingListScreen({super.key, required this.shoppingList});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late List<ShoppingItem> _items;

  @override
  void initState() {
    super.initState();
    // Make a mutable copy so we can toggle checked state
    _items = widget.shoppingList.items.map((item) => ShoppingItem(
      name: item.name,
      quantities: List.from(item.quantities),
      isRestock: item.isRestock,
      isChecked: false,
    )).toList();
  }

  int get _checkedCount => _items.where((i) => i.isChecked).length;

  void _toggleItem(int index) {
    setState(() => _items[index].isChecked = !_items[index].isChecked);
  }

  void _clearChecked() {
    setState(() {
      for (final item in _items) {
        item.isChecked = false;
      }
    });
  }

  void _shareList() {
    final unchecked = _items.where((i) => !i.isChecked).toList();
    if (unchecked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All items are already checked!')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('🛒 Elio Shopping List');
    buffer.writeln();
    for (final item in unchecked) {
      final qty = item.quantities.isNotEmpty ? ' (${item.quantities.first})' : '';
      buffer.writeln('• ${_capitalise(item.name)}$qty');
    }

    // Copy to clipboard
    // In a real app we'd use share_plus here — for now show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon!')),
    );
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final unchecked = _items.where((i) => !i.isChecked).toList();
    final checked = _items.where((i) => i.isChecked).toList();

    return Scaffold(
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────
            Padding(
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
                        Text('Shopping List', style: ElioText.headingLarge),
                        Text(
                          '${_items.length} items · $_checkedCount in basket',
                          style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Share button
                  GestureDetector(
                    onTap: _shareList,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ElioColors.offWhite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ElioColors.border),
                      ),
                      child: const Icon(Icons.share_outlined, size: 18, color: ElioColors.navy),
                    ),
                  ),
                ],
              ),
            ),

            // ── Progress bar ──────────────────────────────────────
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _items.isEmpty ? 0 : _checkedCount / _items.length,
                    backgroundColor: ElioColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(ElioColors.amber),
                    minHeight: 6,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),

            // ── List ──────────────────────────────────────────────
            Expanded(
              child: _items.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                      children: [
                        // Restock section (Running Low items) — always at top
                        ..._buildRestockSection(unchecked),

                        // Recipe ingredients section
                        ..._buildRecipeSection(unchecked),

                        // Checked items section
                        if (checked.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'In basket (${checked.length})',
                                style: ElioText.label.copyWith(
                                  color: ElioColors.textMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              GestureDetector(
                                onTap: _clearChecked,
                                child: Text(
                                  'Clear',
                                  style: ElioText.label.copyWith(
                                    color: ElioColors.sky,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...checked.map((item) {
                            final index = _items.indexOf(item);
                            return _ShoppingItemTile(
                              item: item,
                              onTap: () => _toggleItem(index),
                            );
                          }),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRestockSection(List<ShoppingItem> unchecked) {
    final restockItems = unchecked.where((i) => i.isRestock).toList();
    if (restockItems.isEmpty) return [];

    return [
      Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: ElioColors.amber),
          const SizedBox(width: 6),
          Text(
            'Restock (${restockItems.length})',
            style: ElioText.label.copyWith(
              color: ElioColors.amber,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ...restockItems.map((item) {
        final index = _items.indexOf(item);
        return _ShoppingItemTile(
          item: item,
          onTap: () => _toggleItem(index),
        );
      }),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildRecipeSection(List<ShoppingItem> unchecked) {
    final recipeItems = unchecked.where((i) => !i.isRestock).toList();
    if (recipeItems.isEmpty) return [];

    final hasRestock = unchecked.any((i) => i.isRestock);
    return [
      if (hasRestock) ...[
        Text(
          'For recipes (${recipeItems.length})',
          style: ElioText.label.copyWith(
            color: ElioColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
      ],
      ...recipeItems.map((item) {
        final index = _items.indexOf(item);
        return _ShoppingItemTile(
          item: item,
          onTap: () => _toggleItem(index),
        );
      }),
    ];
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Nothing to buy!',
              style: ElioText.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your pantry already has everything needed for this week\'s meals.',
              style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shopping item tile ───────────────────────────────────────────────────────
class _ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onTap;

  const _ShoppingItemTile({required this.item, required this.onTap});

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: item.isChecked
              ? ElioColors.offWhite.withValues(alpha: 0.5)
              : ElioColors.offWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isChecked ? ElioColors.border.withValues(alpha: 0.5) : ElioColors.border,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: item.isChecked ? ElioColors.amber : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: item.isChecked ? ElioColors.amber : ElioColors.border,
                  width: 1.5,
                ),
              ),
              child: item.isChecked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),

            // Item name
            Expanded(
              child: Text(
                _capitalise(item.name),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: item.isChecked ? ElioColors.textMuted : ElioColors.textPrimary,
                  decoration: item.isChecked ? TextDecoration.lineThrough : null,
                  decorationColor: ElioColors.textMuted,
                ),
              ),
            ),

            // Quantity hint (first occurrence)
            if (item.quantities.isNotEmpty && !item.isChecked)
              Text(
                item.quantities.first,
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
