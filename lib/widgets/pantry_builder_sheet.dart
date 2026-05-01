import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/pantry_categories.dart';
import '../models/pantry_memory_entry.dart';
import '../services/firestore_service.dart';
import '../services/pantry_memory_service.dart';
import '../theme/elio_radii.dart';
import '../theme/elio_spacing.dart';
import '../theme/elio_text_styles.dart';
import '../theme/elio_theme.dart';
import '../utils/dietary_filter.dart';
import '../utils/pantry_staples.dart';

/// Bottom sheet for browsing and adding pantry items by category.
///
/// Sprint-16-rebrand pass:
///  • Cream background (matches app shell), creamDeep input fields, no
///    border-rule outlines.
///  • Category headers use Material outlined icons (Streamline-adjacent
///    line style) inside a small peach rounded-square container, mirroring
///    the bento-tile inner-icon language.
///  • Item chips use the canonical ElioChip language (creamDeep idle,
///    terracotta + check selected) but keep RawGestureDetector locally so
///    long-press can open the tier picker without bottom-sheet conflicts.
///
/// Behaviour: tap to add (defaults to Always Have), long-press to choose
/// tier. Search filters across all categories. Custom add appends a new
/// custom item with a forced tier picker.
class PantryBuilderSheet extends StatefulWidget {
  final List<String> existingItemNames;
  final Future<void> Function(String name, String tier, String? category) onAddItem;
  final Future<void> Function(String name) onRemoveItem;

  /// Test-only override for the dietary loader. Production passes null
  /// and the sheet reads from the user doc via FirestoreService.
  @visibleForTesting
  final Future<({List<String> dietary, List<String> allergies})>
      Function()? dietaryLoaderOverride;

  const PantryBuilderSheet({
    super.key,
    required this.existingItemNames,
    required this.onAddItem,
    required this.onRemoveItem,
    this.dietaryLoaderOverride,
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

  // Loaded once on init; rebuilt only when the user adds a custom.
  List<PantryMemoryEntry> _usuals = const [];
  Set<String> _hadBeforeKeys = const {};
  Map<String, List<PantryMemoryEntry>> _customsByCategory = const {};
  List<String> _userDietary = const [];
  List<String> _userAllergies = const [];
  bool _memoryLoaded = false;

  @override
  void initState() {
    super.initState();
    _existingLower = widget.existingItemNames
        .map((n) => n.toLowerCase().trim())
        .toSet();
    _loadMemory();
  }

  Future<void> _loadMemory() async {
    final memSvc = PantryMemoryService.instance;

    // Backfill is fire-and-forget; we don't await it before showing
    // the UI. If it lands during this open, the next open sees usuals
    // populated.
    memSvc.backfillFromInventoryIfNeeded();

    final dietaryLoader = widget.dietaryLoaderOverride ?? _loadDietaryFromUser;
    final results = await Future.wait([
      memSvc.recentUsuals(),
      memSvc.hadBeforeKeys(),
      memSvc.customsByCategory(),
      dietaryLoader(),
    ]);
    if (!mounted) return;
    setState(() {
      _usuals = results[0] as List<PantryMemoryEntry>;
      _hadBeforeKeys = results[1] as Set<String>;
      _customsByCategory =
          results[2] as Map<String, List<PantryMemoryEntry>>;
      final diet = results[3] as ({List<String> dietary, List<String> allergies});
      _userDietary = diet.dietary;
      _userAllergies = diet.allergies;
      _memoryLoaded = true;
    });
  }

  Future<({List<String> dietary, List<String> allergies})>
      _loadDietaryFromUser() async {
    try {
      final userData = await FirestoreService().getUserData();
      final dietary = List<String>.from(userData['dietary'] ?? []);
      final allergies = List<String>.from(userData['allergies'] ?? []);
      return (dietary: dietary, allergies: allergies);
    } catch (_) {
      return (dietary: const <String>[], allergies: const <String>[]);
    }
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

  /// Map a category to a Streamline-adjacent Material outlined icon.
  ///
  /// Stock outlined icons are the closest single-stroke set we have
  /// without shipping bundled SVG assets. If we later license the
  /// Streamline pack for an exact match, swap this to a string→AssetImage
  /// lookup; the call sites won't change.
  static IconData _iconFor(String categoryName) {
    switch (categoryName) {
      case 'Spices & Seasonings':
        return Icons.local_fire_department_outlined;
      case 'Asian Pantry':
        return Icons.ramen_dining_outlined;
      case 'Indian Pantry':
        return Icons.rice_bowl_outlined;
      case 'Mexican & Latin':
        return Icons.lunch_dining_outlined;
      case 'Mediterranean':
        return Icons.eco_outlined;
      case 'Oils & Vinegars':
        return Icons.water_drop_outlined;
      case 'Dairy & Eggs':
        return Icons.egg_outlined;
      case 'Canned & Jarred':
        return Icons.inventory_2_outlined;
      case 'Grains & Pasta':
        return Icons.dinner_dining_outlined;
      case 'Baking Essentials':
        return Icons.cake_outlined;
      case 'Sauces & Condiments':
        return Icons.opacity_outlined;
      case 'Frozen Staples':
        return Icons.ac_unit_outlined;
      default:
        return Icons.kitchen_outlined;
    }
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
    _showTierPickerForItem(itemName, null, clearCustomFieldOnAdd: true);
  }

  void _showTierPickerForItem(
    String itemName,
    String? categoryName, {
    bool clearCustomFieldOnAdd = false,
  }) {
    // Must use showDialog — not showModalBottomSheet — because the Pantry
    // Builder is already a bottom sheet and nested sheets fail silently.
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ElioColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElioRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add "$itemName"', style: ElioTextStyles.sectionHeadingStyle),
              const SizedBox(height: 4),
              Text(
                'Pick a tier.',
                style: ElioTextStyles.bodySmallStyle,
              ),
              const SizedBox(height: ElioSpacing.md),
              _TierTile(
                icon: Icons.star_outline_rounded,
                iconBg: ElioColors.peach,
                title: 'Always have',
                subtitle: 'Staples you always keep',
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onAddItem(itemName, 'alwaysHave', categoryName ?? '');
                  setState(() {
                    _existingLower.add(itemName.toLowerCase().trim());
                    if (clearCustomFieldOnAdd) {
                      _customItemController.clear();
                      _customItemError = null;
                    }
                  });
                },
              ),
              const SizedBox(height: ElioSpacing.xs),
              _TierTile(
                icon: Icons.kitchen_outlined,
                iconBg: const Color(0xFFF5C26B),
                title: 'Almost always have',
                subtitle: 'Usually in, sometimes runs out',
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onAddItem(itemName, 'almostAlwaysHave', categoryName ?? '');
                  setState(() {
                    _existingLower.add(itemName.toLowerCase().trim());
                    if (clearCustomFieldOnAdd) {
                      _customItemController.clear();
                      _customItemError = null;
                    }
                  });
                },
              ),
              const SizedBox(height: ElioSpacing.xs),
              _TierTile(
                icon: Icons.eco_outlined,
                iconBg: ElioColors.perishFresh.withValues(alpha: 0.25),
                iconColor: ElioColors.perishFresh,
                title: 'Perishable',
                subtitle: 'Fresh items with a shelf life',
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onAddItem(itemName, 'perishable', categoryName ?? '');
                  setState(() {
                    _existingLower.add(itemName.toLowerCase().trim());
                    if (clearCustomFieldOnAdd) {
                      _customItemController.clear();
                      _customItemError = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _addUsualToPantry(PantryMemoryEntry entry) {
    HapticFeedback.selectionClick();
    final key = entry.displayName.toLowerCase().trim();
    if (_existingLower.contains(key)) {
      widget.onRemoveItem(entry.displayName);
      setState(() => _existingLower.remove(key));
    } else {
      // Pass entry.category so a custom item lands in its saved
      // category bucket on the inventory write. tierMemory rows have
      // a null category (no preference recorded), which the caller
      // already handles by inferring from tier.
      widget.onAddItem(entry.displayName, entry.tier, entry.category);
      setState(() => _existingLower.add(key));
    }
  }

  void _longPressItem(String itemName, String? categoryName) {
    HapticFeedback.mediumImpact();
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
          color: ElioColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle.
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ElioColors.rule,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title + sub.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pantry Builder',
                      style: ElioTextStyles.sectionHeadingStyle),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to add, hold to choose tier.',
                    style: ElioTextStyles.bodySmallStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: ElioSpacing.md),
            // Search field — creamDeep, no border.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SoftField(
                controller: _searchController,
                hintText: 'Search items',
                prefixIcon: Icons.search_rounded,
                suffixIcon: hasSearch ? Icons.close_rounded : null,
                onSuffixTap: hasSearch
                    ? () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      }
                    : null,
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: ElioSpacing.sm),
            // Custom-add row — field + terracotta circular button.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _SoftField(
                      controller: _customItemController,
                      hintText: 'Add custom item',
                      prefixIcon: Icons.add_rounded,
                      errorTinted: _customItemError != null,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addCustomItem(),
                    ),
                  ),
                  const SizedBox(width: ElioSpacing.sm),
                  Material(
                    color: ElioColors.terracotta,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _addCustomItem,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.add_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_customItemError != null)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, ElioSpacing.xs, 20, 0),
                child: Text(
                  _customItemError!,
                  style: ElioTextStyles.eyebrowStyle.copyWith(
                    color: ElioColors.terracotta,
                  ),
                ),
              ),
            const SizedBox(height: ElioSpacing.sm),
            if (_memoryLoaded && _usuals.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, ElioSpacing.sm, 20, ElioSpacing.xs),
                child: Text(
                  'Your usuals',
                  style: ElioTextStyles.eyebrowStyle,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _usuals.map((entry) {
                    final inPantry = _isInPantry(entry.displayName);
                    return _BuilderChip(
                      label: entry.displayName,
                      selected: inPantry,
                      onTap: () => _addUsualToPantry(entry),
                      onLongPress: () => _longPressItem(entry.displayName, null),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: ElioSpacing.sm),
            ],
            // Category list — fills remaining height.
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
    final allItems = cat.allItems
        .where((item) => !PantryStaples.isStaple(item))
        .toList();
    final filteredItems = _searchQuery.isEmpty
        ? allItems
        : allItems
            .where((item) => item.toLowerCase().contains(_searchQuery))
            .toList();

    if (filteredItems.isEmpty && _searchQuery.isNotEmpty) {
      return const SizedBox.shrink();
    }

    final isExpanded =
        _expandedCategories.contains(cat.name) || _searchQuery.isNotEmpty;
    final inPantryCount = filteredItems.where(_isInPantry).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (_searchQuery.isNotEmpty) return;
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ElioColors.peach,
                    borderRadius: BorderRadius.circular(ElioRadii.panel),
                  ),
                  child: Icon(
                    _iconFor(cat.name),
                    color: ElioColors.espresso,
                    size: 20,
                  ),
                ),
                const SizedBox(width: ElioSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat.name, style: ElioTextStyles.uiLabelStyle),
                      const SizedBox(height: 2),
                      Text(
                        '${filteredItems.length} items'
                        '${inPantryCount > 0 ? ' · $inPantryCount in pantry' : ''}',
                        style: ElioTextStyles.bodySmallStyle,
                      ),
                    ],
                  ),
                ),
                if (_searchQuery.isEmpty)
                  Icon(
                    isExpanded
                        ? Icons.expand_more_rounded
                        : Icons.chevron_right_rounded,
                    size: 22,
                    color: ElioColors.mocha,
                  ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 1. User customs land FIRST inside their saved category.
                ...?(_customsByCategory[cat.name]?.map((entry) {
                  final blocked = DietaryFilter.blockReasons(
                    itemName: entry.displayName,
                    dietary: _userDietary,
                    allergies: _userAllergies,
                    categoryName: cat.name,
                  ).isNotEmpty;
                  final inPantry = _isInPantry(entry.displayName);
                  return _BuilderChip(
                    label: entry.displayName,
                    selected: inPantry,
                    hadBefore: true, // customs are by definition had-before
                    blocked: blocked,
                    onTap: () => _addUsualToPantry(entry),
                    onLongPress: () =>
                        _longPressItem(entry.displayName, cat.name),
                  );
                })),
                // 2. Canonical category items.
                ...filteredItems.map((itemName) {
                  final blocked = DietaryFilter.blockReasons(
                    itemName: itemName,
                    dietary: _userDietary,
                    allergies: _userAllergies,
                    categoryName: cat.name,
                  ).isNotEmpty;
                  final inPantry = _isInPantry(itemName);
                  final hadBefore = _hadBeforeKeys.contains(
                    itemName.toLowerCase().trim(),
                  );
                  return _BuilderChip(
                    label: itemName,
                    selected: inPantry,
                    hadBefore: hadBefore,
                    blocked: blocked,
                    onTap: () => _toggleItem(itemName, cat.name),
                    onLongPress: () => _longPressItem(itemName, cat.name),
                  );
                }),
              ],
            ),
          ),
        ],
        Divider(
          height: 1,
          color: ElioColors.rule.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}

// ─── Soft input field (creamDeep fill, no border) ────────────────────
class _SoftField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool errorTinted;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  const _SoftField({
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.errorTinted = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final tint = errorTinted ? ElioColors.terracotta : ElioColors.mocha;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      style: ElioTextStyles.bodyStyle,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle:
            ElioTextStyles.bodyStyle.copyWith(color: ElioColors.mocha),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 20, color: tint),
        suffixIcon: suffixIcon == null
            ? null
            : GestureDetector(
                onTap: onSuffixTap,
                child: Icon(suffixIcon, size: 18, color: ElioColors.mocha),
              ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: ElioColors.creamDeep,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElioRadii.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElioRadii.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElioRadii.input),
          borderSide: BorderSide.none,
        ),
        isDense: true,
      ),
    );
  }
}

// ─── Toggle-add chip with tap + long-press ───────────────────────────
//
// Visually mirrors ElioChip (creamDeep idle / terracotta selected with
// trailing check) but keeps RawGestureDetector locally so long-press can
// open the tier picker without losing the gesture to the wrapping
// scrollable.
class _BuilderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool hadBefore;
  final bool blocked;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BuilderChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    this.hadBefore = false,
    this.blocked = false,
  });

  @override
  Widget build(BuildContext context) {
    // Blocked items render greyed-out and ignore taps.
    if (blocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ElioColors.creamDeep.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(ElioRadii.chip),
        ),
        child: Text(
          label,
          style: ElioTextStyles.bodySmallStyle.copyWith(
            color: ElioColors.mocha.withValues(alpha: 0.6),
            decoration: TextDecoration.lineThrough,
            decorationColor: ElioColors.mocha.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    final bg = selected ? ElioColors.terracotta : ElioColors.creamDeep;
    final fg = selected ? Colors.white : ElioColors.espresso;
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (instance) => instance.onTap = onTap,
        ),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
              duration: const Duration(milliseconds: 300)),
          (instance) => instance.onLongPress = onLongPress,
        ),
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ElioRadii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show the had-before dot ONLY on idle (non-selected) chips —
            // on a terracotta-selected chip the dot would clash with the
            // check icon and the bold fill already announces engagement.
            if (hadBefore && !selected) const _HadBeforeDot(),
            Text(
              label,
              style: ElioTextStyles.bodySmallStyle.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}

class _HadBeforeDot extends StatelessWidget {
  const _HadBeforeDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(right: 6),
      decoration: const BoxDecoration(
        color: ElioColors.terracotta,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─── Tier-picker dialog tile ─────────────────────────────────────────
class _TierTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TierTile({
    required this.icon,
    required this.iconBg,
    this.iconColor = ElioColors.espresso,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ElioRadii.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ElioSpacing.sm,
          vertical: ElioSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(ElioRadii.panel),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: ElioSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ElioTextStyles.uiLabelStyle),
                  const SizedBox(height: 2),
                  Text(subtitle, style: ElioTextStyles.bodySmallStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
