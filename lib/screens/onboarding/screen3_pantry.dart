import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/elio_models.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../utils/pantry_utils.dart';
import '../../widgets/elio_progress_bar.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// PantryReviewScreen (Screen 3)
// Design: approachable utility.
// User reviews and adjusts the pre-populated pantry.
// Drag a chip (hold 400ms then drag) to move between tiers.
// Long-press also opens a context menu as fallback.
// Scroll is always available — drag only activates after 400ms hold.
// Step 3 of 5 in onboarding.
// ─────────────────────────────────────────────

class PantryReviewScreen extends StatefulWidget {
  final OnboardingState state;
  final void Function(OnboardingState) onNext;
  final VoidCallback onBack;

  const PantryReviewScreen({
    super.key,
    required this.state,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<PantryReviewScreen> createState() => _PantryReviewScreenState();
}

class _PantryReviewScreenState extends State<PantryReviewScreen> {
  late List<InventoryItem> _items;
  final TextEditingController _addController = TextEditingController();
  String _addTier = 'alwaysHave';
  String? _draggingItemName; // track which item is being dragged

  /// Quick-add packs data
  static const Map<String, Map<String, List<String>>> _quickAddPacks = {
    'Spices & Seasonings': {
      'Basic': [
        'Salt', 'Black pepper', 'Garlic powder', 'Onion powder', 'Paprika',
        'Cumin', 'Oregano', 'Chilli flakes', 'Cinnamon', 'Mixed herbs',
      ],
      'Asian': [
        'Ginger (ground)', 'Five-spice', 'Sesame oil', 'Soy sauce',
        'Fish sauce', 'Lemongrass', 'Turmeric', 'Sriracha',
      ],
      'Indian': [
        'Garam masala', 'Cumin seeds', 'Coriander (ground)', 'Turmeric',
        'Chilli powder', 'Cardamom', 'Mustard seeds', 'Fenugreek',
      ],
      'Mexican': [
        'Chilli powder', 'Cumin', 'Smoked paprika', 'Cayenne pepper',
        'Chipotle paste', 'Lime',
      ],
    },
    'Oils & Vinegars': {
      '': [
        'Olive oil', 'Vegetable oil', 'Coconut oil', 'Sesame oil',
        'Balsamic vinegar', 'White wine vinegar', 'Apple cider vinegar',
      ],
    },
    'Baking Essentials': {
      '': [
        'Plain flour', 'Self-raising flour', 'Baking powder',
        'Bicarbonate of soda', 'Vanilla extract', 'Cocoa powder',
        'Caster sugar', 'Brown sugar', 'Cornflour', 'Yeast',
      ],
    },
    'Sauces & Condiments': {
      '': [
        'Ketchup', 'Mayonnaise', 'Mustard', 'Worcestershire sauce',
        'Hot sauce', 'Honey', 'Maple syrup', 'Tomato puree',
        'Stock cubes (chicken)', 'Stock cubes (vegetable)',
      ],
    },
    'Grains & Pasta': {
      '': [
        'Rice (white)', 'Rice (brown)', 'Pasta (spaghetti)', 'Pasta (penne)',
        'Couscous', 'Quinoa', 'Oats', 'Noodles (egg)', 'Noodles (rice)',
        'Bread',
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.state.inventory);
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _removeItem(String name) {
    setState(() => _items.removeWhere((i) => i.name == name));
  }

  void _moveItemToTier(String name, String newTier) {
    HapticFeedback.mediumImpact();
    setState(() {
      final idx = _items.indexWhere((i) => i.name == name);
      if (idx != -1 && _items[idx].tier != newTier) {
        _items[idx] = InventoryItem(name: name, tier: newTier);
      }
    });
  }

  Future<void> _addItem() async {
    final name = _addController.text.trim();
    if (name.isEmpty) return;

    // Check for fuzzy duplicates against current items
    final existingNames = _items.map((i) => i.name).toList();
    final duplicates = PantryUtils.findDuplicates(name, existingNames);
    if (duplicates.isNotEmpty && mounted) {
      final addAnyway = await PantryUtils.showDuplicateWarning(
        context,
        name,
        duplicates,
      );
      if (!addAnyway) return;
    }

    setState(() {
      _items.add(InventoryItem(name: name, tier: _addTier));
      _addController.clear();
    });
  }

  /// Shows a bottom sheet with move options for the given item.
  void _showMoveMenu(BuildContext context, InventoryItem item) {
    HapticFeedback.selectionClick();
    final otherTier = item.tier == 'alwaysHave' ? 'almostAlwaysHave' : 'alwaysHave';
    final otherTierLabel = item.tier == 'alwaysHave' ? 'Almost Always Have' : 'Always Have';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ElioColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(item.name, style: ElioText.headingMedium),
              const SizedBox(height: 4),
              Text(
                'Currently in: ${item.tier == 'alwaysHave' ? 'Always Have' : 'Almost Always Have'}',
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ElioColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_vert_rounded, color: ElioColors.navy, size: 20),
                ),
                title: Text(
                  'Move to "$otherTierLabel"',
                  style: ElioText.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _moveItemToTier(item.name, otherTier);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                ),
                title: Text(
                  'Remove from pantry',
                  style: ElioText.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeItem(item.name);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Check if a pack item is already in the pantry (exact or fuzzy match).
  bool _isItemInPantry(String packItem) {
    for (final item in _items) {
      if (PantryUtils.isFuzzyMatch(packItem, item.name)) return true;
    }
    return false;
  }

  /// Toggle a quick-add pack item: add to alwaysHave or remove.
  void _togglePackItem(String name) {
    HapticFeedback.selectionClick();
    setState(() {
      // Check if already in pantry via fuzzy match
      final matchIdx = _items.indexWhere(
        (i) => PantryUtils.isFuzzyMatch(name, i.name),
      );
      if (matchIdx != -1) {
        // Remove the matched item — whether it came from a preset or a pack,
        // the user is explicitly toggling it off.
        _items.removeAt(matchIdx);
      } else {
        _items.add(InventoryItem(name: name, tier: 'alwaysHave'));
      }
    });
  }

  List<InventoryItem> get _alwaysHave =>
      _items.where((i) => i.tier == 'alwaysHave').toList();
  List<InventoryItem> get _almostAlwaysHave =>
      _items.where((i) => i.tier == 'almostAlwaysHave').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Progress ──────────────────────────────────────
              const ElioProgressBar(currentStep: 3, totalSteps: 8),
              const SizedBox(height: 28),

              // ── Header ────────────────────────────────────────
              GestureDetector(
                onTap: widget.onBack,
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: ElioColors.navy),
                    const SizedBox(width: 4),
                    Text('Back',
                        style: ElioText.bodyMedium
                            .copyWith(color: ElioColors.navy)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Your pantry', style: ElioText.displayMedium),
              const SizedBox(height: 4),
              Text(
                'Remove anything you don\'t have. Add anything that\'s missing.',
                style: ElioText.bodyLarge
                    .copyWith(color: ElioColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.drag_indicator_rounded,
                      size: 14, color: ElioColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Hold & drag a chip to move it between sections.',
                    style: ElioText.label
                        .copyWith(color: ElioColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Inventory list ────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Always have section
                      _TierSection(
                        tier: 'alwaysHave',
                        title: 'Always have',
                        subtitle: 'These are your pantry staples.',
                        color: ElioColors.amber,
                        items: _alwaysHave,
                        draggingItemName: _draggingItemName,
                        onRemove: _removeItem,
                        onLongPress: (item) => _showMoveMenu(context, item),
                        onDragStarted: (name) => setState(() => _draggingItemName = name),
                        onDragEnd: () => setState(() => _draggingItemName = null),
                        onAcceptDrag: (name) => _moveItemToTier(name, 'alwaysHave'),
                      ),
                      const SizedBox(height: 16),

                      // Almost always have section
                      _TierSection(
                        tier: 'almostAlwaysHave',
                        title: 'Almost always have',
                        subtitle:
                            'Things you usually have but might run out of.',
                        color: ElioColors.sky,
                        items: _almostAlwaysHave,
                        draggingItemName: _draggingItemName,
                        onRemove: _removeItem,
                        onLongPress: (item) => _showMoveMenu(context, item),
                        onDragStarted: (name) => setState(() => _draggingItemName = name),
                        onDragEnd: () => setState(() => _draggingItemName = null),
                        onAcceptDrag: (name) => _moveItemToTier(name, 'almostAlwaysHave'),
                      ),
                      const SizedBox(height: 16),

                      // Add item row
                      const Divider(),
                      const SizedBox(height: 12),
                      Text('Add an item', style: ElioText.headingMedium),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _addController,
                              textCapitalization:
                                  TextCapitalization.sentences,
                              style: GoogleFonts.outfit(fontSize: 15),
                              decoration: const InputDecoration(
                                hintText: 'e.g. Miso paste',
                              ),
                              onSubmitted: (_) => _addItem(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _addTier,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(
                                  value: 'alwaysHave',
                                  child: Text('Always',
                                      style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(
                                  value: 'almostAlwaysHave',
                                  child: Text('Almost',
                                      style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (v) => setState(
                                () => _addTier = v ?? 'alwaysHave'),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _addItem,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: ElioColors.navy,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.add,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Quick-add packs ─────────────────────────
                      _QuickAddPacksSection(
                        packs: _quickAddPacks,
                        isItemInPantry: _isItemInPantry,
                        onToggleItem: _togglePackItem,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // ── Next button ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onNext(widget.state.copyWith(inventory: _items));
                  },
                  child: const Text('Next →'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tier section with DragTarget ────────────────────────────────────────────

class _TierSection extends StatefulWidget {
  final String tier;
  final String title;
  final String subtitle;
  final Color color;
  final List<InventoryItem> items;
  final String? draggingItemName;
  final void Function(String name) onRemove;
  final void Function(InventoryItem item) onLongPress;
  final void Function(String name) onDragStarted;
  final VoidCallback onDragEnd;
  final void Function(String name) onAcceptDrag;

  const _TierSection({
    required this.tier,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.items,
    required this.draggingItemName,
    required this.onRemove,
    required this.onLongPress,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onAcceptDrag,
  });

  @override
  State<_TierSection> createState() => _TierSectionState();
}

class _TierSectionState extends State<_TierSection> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDraggingFromOtherTier = widget.draggingItemName != null &&
        !widget.items.any((i) => i.name == widget.draggingItemName);

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        // Only accept if the item is from a different tier
        final isFromThisTier = widget.items.any((i) => i.name == details.data);
        if (!isFromThisTier) {
          setState(() => _isHovered = true);
          return true;
        }
        return false;
      },
      onLeave: (_) => setState(() => _isHovered = false),
      onAcceptWithDetails: (details) {
        setState(() => _isHovered = false);
        widget.onAcceptDrag(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? widget.color
                  : isDraggingFromOtherTier
                      ? widget.color.withValues(alpha: 0.5)
                      : widget.color.withValues(alpha: 0.25),
              width: _isHovered ? 2 : 1,
            ),
            color: _isHovered
                ? widget.color.withValues(alpha: 0.08)
                : widget.color.withValues(alpha: 0.04),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: ElioText.bodyMedium
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        widget.subtitle,
                        style: ElioText.label.copyWith(
                          color: ElioColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  if (isDraggingFromOtherTier) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Drop here',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              // Chips
              if (widget.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    'No items yet. Add some below.',
                    style: ElioText.label.copyWith(color: ElioColors.textMuted),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.items.map((item) {
                    final isDraggingThis = widget.draggingItemName == item.name;
                    return LongPressDraggable<String>(
                      data: item.name,
                      delay: const Duration(milliseconds: 400),
                      onDragStarted: () => widget.onDragStarted(item.name),
                      onDragEnd: (_) => widget.onDragEnd(),
                      onDraggableCanceled: (_, __) => widget.onDragEnd(),
                      feedback: Material(
                        color: Colors.transparent,
                        child: _DragFeedbackChip(
                          label: item.name,
                          color: widget.color,
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _ItemChip(
                          label: item.name,
                          color: widget.color,
                          onRemove: () {},
                        ),
                      ),
                      child: GestureDetector(
                        onLongPress: isDraggingThis ? null : () => widget.onLongPress(item),
                        child: _ItemChip(
                          label: item.name,
                          color: widget.color,
                          onRemove: () => widget.onRemove(item.name),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Item chip ────────────────────────────────────────────────────────────────

class _ItemChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final Color color;

  const _ItemChip(
      {required this.label,
      required this.onRemove,
      this.color = ElioColors.amber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ElioColors.navy,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 16, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Drag feedback chip ───────────────────────────────────────────────────────

class _DragFeedbackChip extends StatelessWidget {
  final String label;
  final Color color;

  const _DragFeedbackChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── Quick-add packs section ─────────────────────────────────────────────────

class _QuickAddPacksSection extends StatelessWidget {
  final Map<String, Map<String, List<String>>> packs;
  final bool Function(String) isItemInPantry;
  final void Function(String) onToggleItem;

  const _QuickAddPacksSection({
    required this.packs,
    required this.isItemInPantry,
    required this.onToggleItem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ElioColors.offWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ElioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick-add packs', style: ElioText.headingMedium),
          const SizedBox(height: 2),
          Text(
            'Tap a category to expand and pick items',
            style: ElioText.label.copyWith(color: ElioColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...packs.entries.map((category) => _PackCategorySection(
                categoryName: category.key,
                subcategories: category.value,
                isItemInPantry: isItemInPantry,
                onToggleItem: onToggleItem,
              )),
        ],
      ),
    );
  }
}

// ─── Collapsible category within quick-add packs ─────────────────────────────

class _PackCategorySection extends StatefulWidget {
  final String categoryName;
  final Map<String, List<String>> subcategories;
  final bool Function(String) isItemInPantry;
  final void Function(String) onToggleItem;

  const _PackCategorySection({
    required this.categoryName,
    required this.subcategories,
    required this.isItemInPantry,
    required this.onToggleItem,
  });

  @override
  State<_PackCategorySection> createState() => _PackCategorySectionState();
}

class _PackCategorySectionState extends State<_PackCategorySection> {
  bool _expanded = false;

  int get _totalItemCount =>
      widget.subcategories.values.fold(0, (sum, list) => sum + list.length);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header — tap to expand/collapse
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? Icons.expand_more_rounded
                      : Icons.chevron_right_rounded,
                  size: 20,
                  color: ElioColors.navy,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.categoryName,
                    style: ElioText.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ElioColors.navy,
                    ),
                  ),
                ),
                Text(
                  '$_totalItemCount items',
                  style: ElioText.label.copyWith(
                    color: ElioColors.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Expanded content
        if (_expanded) ...[
          ...widget.subcategories.entries.map((sub) {
            final hasSubLabel = sub.key.isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasSubLabel) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 26, bottom: 6),
                      child: Text(
                        sub.key,
                        style: ElioText.label.copyWith(
                          color: ElioColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sub.value.map((itemName) {
                        final selected = widget.isItemInPantry(itemName);
                        return GestureDetector(
                          onTap: () => widget.onToggleItem(itemName),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? ElioColors.amber.withValues(alpha: 0.12)
                                  : ElioColors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: selected
                                    ? ElioColors.amber.withValues(alpha: 0.5)
                                    : ElioColors.border,
                              ),
                            ),
                            child: Text(
                              itemName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    selected ? FontWeight.w600 : FontWeight.w500,
                                color: selected
                                    ? ElioColors.amber
                                    : ElioColors.navy,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        // Divider between categories (except last)
        const Divider(height: 1, color: ElioColors.border),
      ],
    );
  }
}
