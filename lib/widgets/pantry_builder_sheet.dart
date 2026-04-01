import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/pantry_categories.dart';
import '../theme/elio_theme.dart';
/// Bottom sheet for browsing and adding pantry items by category.
/// Tap to add (defaults to Always Have), long-press to choose tier.
class PantryBuilderSheet extends StatefulWidget {
  final List<String> existingItemNames;
  final Future<void> Function(String name, String tier, String? category) onAddItem;
  final Future<void> Function(String name) onRemoveItem;

  const PantryBuilderSheet({
    super.key,
    required this.existingItemNames,
    required this.onAddItem,
    required this.onRemoveItem,
  });

  @override
  State<PantryBuilderSheet> createState() => _PantryBuilderSheetState();
}

class _PantryBuilderSheetState extends State<PantryBuilderSheet> {
  String _searchQuery = '';
  String? _customItemError;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customItemController = TextEditingController();
  final Set<String> _expandedCategories = {};
  late Set<String> _existingLower;

  @override
  void initState() {
    super.initState();
    _existingLower = widget.existingItemNames
        .map((n) => n.toLowerCase().trim())
        .toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customItemController.dispose();
    super.dispose();
  }

  bool _isInPantry(String itemName) {
    return _existingLower.contains(itemName.toLowerCase().trim());
  }

  void _toggleItem(String itemName, String categoryName) {
    HapticFeedback.selectionClick();
    final key = itemName.toLowerCase().trim();
    if (_existingLower.contains(key)) {
      widget.onRemoveItem(itemName);
      setState(() => _existingLower.remove(key));
    } else {
      widget.onAddItem(itemName, 'alwaysHave', categoryName);
      setState(() => _existingLower.add(key));
    }
  }

  void _addCustomItem() {
    final name = _customItemController.text.trim();
    if (name.isEmpty) return;
    final key = name.toLowerCase();

    if (_existingLower.contains(key)) {
      // Already in pantry — haptic + inline error, keep text visible
      HapticFeedback.heavyImpact();
      setState(() => _customItemError = '"$name" is already in your pantry');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _customItemError = null);
      });
      return;
    }
    setState(() => _customItemError = null);
    _showCustomItemTierPicker(name);
  }

  /// Tier picker as a dialog — works reliably on top of the bottom sheet.
  void _showCustomItemTierPicker(String itemName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add "$itemName"', style: ElioText.headingMedium),
        content: Text('Choose a tier:', style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary)),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.inventory_2_outlined, size: 18, color: ElioColors.amber),
            label: const Text('Always Have'),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onAddItem(itemName, 'alwaysHave', '');
              setState(() {
                _existingLower.add(itemName.toLowerCase().trim());
                _customItemController.clear();
                _customItemError = null;
              });
            },
          ),
          TextButton.icon(
            icon: Icon(Icons.kitchen_outlined, size: 18, color: ElioColors.sky),
            label: const Text('Almost Always'),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onAddItem(itemName, 'almostAlwaysHave', '');
              setState(() {
                _existingLower.add(itemName.toLowerCase().trim());
                _customItemController.clear();
                _customItemError = null;
              });
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.eco_outlined, size: 18, color: Colors.green),
            label: const Text('Perishable'),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onAddItem(itemName, 'perishable', '');
              setState(() {
                _existingLower.add(itemName.toLowerCase().trim());
                _customItemController.clear();
                _customItemError = null;
              });
            },
          ),
        ],
      ),
    );
  }

  void _showTierPickerForItem(String itemName, String? categoryName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: ElioColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Add "$itemName"', style: ElioText.headingMedium),
              const SizedBox(height: 4),
              Text(
                'Choose which tier to add this item to.',
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: ElioColors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: ElioColors.amber, size: 20),
                ),
                title: Text('Always Have', style: ElioText.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('Staples you always keep', style: ElioText.label.copyWith(color: ElioColors.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onAddItem(itemName, 'alwaysHave', categoryName ?? '');
                  setState(() {
                    _existingLower.add(itemName.toLowerCase().trim());
                    _customItemController.clear();
                  });
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: ElioColors.sky.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.kitchen_outlined, color: ElioColors.sky, size: 20),
                ),
                title: Text('Almost Always Have', style: ElioText.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('Usually have but sometimes run out', style: ElioText.label.copyWith(color: ElioColors.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onAddItem(itemName, 'almostAlwaysHave', categoryName ?? '');
                  setState(() {
                    _existingLower.add(itemName.toLowerCase().trim());
                    _customItemController.clear();
                  });
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.eco_outlined, color: Colors.green, size: 20),
                ),
                title: Text('Perishable', style: ElioText.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('Fresh items with a limited shelf life', style: ElioText.label.copyWith(color: ElioColors.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onAddItem(itemName, 'perishable', categoryName ?? '');
                  setState(() {
                    _existingLower.add(itemName.toLowerCase().trim());
                    _customItemController.clear();
                  });
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _longPressItem(String itemName, String categoryName) {
    HapticFeedback.mediumImpact();
    if (_existingLower.contains(itemName.toLowerCase().trim())) return;

    _showTierPickerForItem(itemName, categoryName);
  }


  @override
  Widget build(BuildContext context) {
    final hasSearch = _searchQuery.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: ElioColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.construction_rounded, size: 22, color: ElioColors.amber),
                  const SizedBox(width: 8),
                  Text('Pantry Builder', style: ElioText.headingLarge),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                'Tap to add, hold to choose tier.',
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: ElioColors.textMuted),
                  suffixIcon: hasSearch
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(Icons.close_rounded, size: 18, color: ElioColors.textMuted),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ElioColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ElioColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ElioColors.navy, width: 1.5),
                  ),
                  filled: true,
                  fillColor: ElioColors.offWhite,
                ),
                style: GoogleFonts.outfit(fontSize: 14),
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              ),
            ),
            // Custom item input
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customItemController,
                      decoration: InputDecoration(
                        hintText: 'Add custom item...',
                        prefixIcon: Icon(Icons.add_rounded, size: 20, color: _customItemError != null ? ElioColors.amber : ElioColors.textMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: ElioColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _customItemError != null ? ElioColors.amber : ElioColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _customItemError != null ? ElioColors.amber : ElioColors.navy, width: 1.5),
                        ),
                        filled: true,
                        fillColor: ElioColors.offWhite,
                      ),
                      style: GoogleFonts.outfit(fontSize: 14),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addCustomItem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _addCustomItem,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ElioColors.navy,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            // Inline error for duplicate custom items
            if (_customItemError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  _customItemError!,
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ElioColors.amber,
                  ),
                ),
              ),
            // Categories list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 60),
                itemCount: PantryCategories.all.length,
                itemBuilder: (context, index) {
                  final cat = PantryCategories.all[index];
                  return _buildCategory(cat);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(PantryCategory cat) {
    // Filter items by search
    final allItems = cat.allItems;
    final filteredItems = _searchQuery.isEmpty
        ? allItems
        : allItems.where((item) => item.toLowerCase().contains(_searchQuery)).toList();

    // Hide entire category if no items match search
    if (filteredItems.isEmpty && _searchQuery.isNotEmpty) return const SizedBox.shrink();

    final isExpanded = _expandedCategories.contains(cat.name) || _searchQuery.isNotEmpty;
    final inPantryCount = filteredItems.where(_isInPantry).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        GestureDetector(
          onTap: () {
            if (_searchQuery.isNotEmpty) return; // Always expanded during search
            setState(() {
              if (_expandedCategories.contains(cat.name)) {
                _expandedCategories.remove(cat.name);
              } else {
                _expandedCategories.add(cat.name);
              }
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Text(cat.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.name,
                        style: ElioText.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${filteredItems.length} items${inPantryCount > 0 ? ' · $inPantryCount in pantry' : ''}',
                        style: ElioText.label.copyWith(color: ElioColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (_searchQuery.isEmpty)
                  Icon(
                    isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                    size: 22,
                    color: ElioColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
        // Expanded items
        if (isExpanded) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filteredItems.map((itemName) {
                final inPantry = _isInPantry(itemName);
                return RawGestureDetector(
                  gestures: <Type, GestureRecognizerFactory>{
                    TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                      () => TapGestureRecognizer(),
                      (instance) => instance.onTap = () => _toggleItem(itemName, cat.name),
                    ),
                    LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                      () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 300)),
                      (instance) => instance.onLongPress = () => _longPressItem(itemName, cat.name),
                    ),
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: inPantry
                          ? ElioColors.amber.withValues(alpha: 0.12)
                          : ElioColors.offWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: inPantry
                            ? ElioColors.amber.withValues(alpha: 0.5)
                            : ElioColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (inPantry) ...[
                          Icon(Icons.check_rounded, size: 14, color: ElioColors.amber),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          itemName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: inPantry ? FontWeight.w600 : FontWeight.w500,
                            color: inPantry ? ElioColors.amber : ElioColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const Divider(height: 1, color: ElioColors.border),
      ],
    );
  }
}
