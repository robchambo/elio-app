// lib/screens/shopping/shopping_list_screen.dart
//
// Sprint 16 Phase 6 — standalone Shopping List tab.
//
// Body-only (hosted inside ElioAppScaffold via AppShell). Replaces the legacy
// Shopping tab that previously lived inside ProfileScreen. Structure follows
// the V1 user flow supplied by Rob:
//   • ElioHeroHeading — "your / shopping list" with amber last line + underline
//   • Share icon (top-right of body)
//   • ElioCustomField — "Add an item" with trailing amber add IconButton
//   • Firestore stream on users/{uid}/shoppingItems, grouped by grocery aisle
//   • Each row tappable: tap = toggle checked + grey-out in place
//   • Swipe-to-delete via Dismissible (with discoverability cue on first item)
//   • Quantity rendered inline, right-aligned (no second line)
//
// Sprint 16.3 polish:
//   • Tap-greys-in-place — checked items stay where they are with a strikethrough
//     instead of jumping into a separate "in basket" section.
//   • Custom inline row replaces ElioIngredientRow so qty sits on the same line.
//   • Subtle "swipe to remove ←" hint rendered above the list so the swipe
//     gesture is discoverable (Rob's note: a few users didn't realise it existed).
//   • Standalone [ShoppingListPage] wrapper — used when pushed via Navigator
//     (e.g. from the meal planner snack action) so the screen has its own
//     scaffold instead of rendering on a black void.
//
// Uses ShoppingService for mutations and AisleUtils for grouping. Share uses
// share_plus and formats the unchecked items grouped by aisle (same format as
// the legacy ProfileScreen shopping tab).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/firestore_service.dart';
import '../../services/shopping_service.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../utils/aisle_utils.dart';
import '../../utils/snackbar_helpers.dart';
import '../../widgets/elio/elio_app_scaffold.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

/// SharedPreferences key for the one-time aisle-reorder hint snackbar.
/// Bumping the suffix forces the hint to re-show (e.g. if we ever
/// change the gesture or copy materially).
const String _kAisleReorderHintKey = 'aisle_reorder_hint_shown_v1';

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final TextEditingController _addController = TextEditingController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  List<PersistentShoppingItem> _items = const [];
  bool _loading = true;
  // Sprint 16.7c: per-user aisle ordering. null = use default enum order.
  // Loaded once on init; updated optimistically + persisted to Firestore
  // each time the user reorders.
  List<String>? _aisleOrder;
  // Discoverability backstop for the long-press-to-reorder gesture
  // (Sprint 16.7c). Defaults to true ("already shown — don't bother")
  // so we never accidentally fire on a brand-new install while prefs
  // are still loading. The actual value lands in [_loadAisleOrder].
  // [_hintScheduled] guards against re-firing across rebuilds.
  bool _aisleHintShown = true;
  bool _hintScheduled = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _loadAisleOrder();
  }

  Future<void> _loadAisleOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final order = await FirestoreService().getAisleOrder();
      final prefs = await SharedPreferences.getInstance();
      final hintShown = prefs.getBool(_kAisleReorderHintKey) ?? false;
      if (!mounted) return;
      setState(() {
        _aisleOrder = order;
        _aisleHintShown = hintShown;
      });
    } catch (_) {
      // Silent — fall back to default order via AisleUtils.orderedFor(null).
    }
  }

  /// One-time snackbar pointing at the long-press-to-reorder gesture.
  /// Only fires once the user actually has something to reorder
  /// (>= 2 visible aisles); persists to SharedPreferences immediately
  /// so reopens don't re-trigger even if the user dismisses without
  /// tapping "Got it".
  void _maybeShowReorderHint(int visibleAisleCount) {
    if (_aisleHintShown || _hintScheduled || visibleAisleCount < 2) return;
    _hintScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      // Persist before showing so a reopen mid-snackbar can't re-fire.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kAisleReorderHintKey, true);
      } catch (_) {
        // Silent — at worst the hint shows once more next session.
      }
      if (!mounted) return;
      _aisleHintShown = true;
      // Sprint 16.7c — withTimer enforces the 6s dismiss even when
      // accessibleNavigation is true (Flutter would otherwise suppress
      // its own timer because of the action).
      messenger.showSnackBarWithTimer(
        SnackBar(
          content: const Text(
            'Tip: long-press an aisle header to drag and reorder.',
          ),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Got it',
            onPressed: messenger.hideCurrentSnackBar,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _addController.dispose();
    super.dispose();
  }

  void _subscribe() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shoppingItems')
        .orderBy('addedAt');

    _sub = query.snapshots().listen((snap) {
      if (!mounted) return;
      final items = snap.docs.map((doc) {
        final data = doc.data();
        return PersistentShoppingItem(
          id: doc.id,
          name: data['name'] as String? ?? '',
          quantity: data['quantity'] as String? ?? '',
          source: _parseSource(data['source'] as String?),
          isChecked: data['isChecked'] as bool? ?? false,
          addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
      setState(() {
        _items = items;
        _loading = false;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  static ShoppingSource _parseSource(String? source) {
    switch (source) {
      case 'mealPlan':
        return ShoppingSource.mealPlan;
      case 'restock':
        return ShoppingSource.restock;
      default:
        return ShoppingSource.manual;
    }
  }

  // ── Actions ────────────────────────────────────────────────────────
  Future<void> _addItem() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    _addController.clear();
    try {
      await ShoppingService.instance.addItem(name: text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add item.')),
      );
    }
  }

  Future<void> _toggle(PersistentShoppingItem item) async {
    await ShoppingService.instance.toggleChecked(item.id, !item.isChecked);
  }

  Future<void> _remove(PersistentShoppingItem item) async {
    await ShoppingService.instance.removeItem(item.id);
  }

  Future<void> _clearChecked() async {
    final checkedCount = _items.where((i) => i.isChecked).length;
    if (checkedCount == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.creamDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElioRadii.card),
        ),
        title: Text(
          checkedCount == 1
              ? 'Remove 1 checked item?'
              : 'Remove $checkedCount checked items?',
          style: ElioTextStyles.sectionHeadingStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: ElioTextStyles.uiLabelStyle.copyWith(color: ElioColors.mocha),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Remove',
              style: ElioTextStyles.uiLabelStyle.copyWith(color: ElioColors.terracotta),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ShoppingService.instance.clearChecked();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove items.')),
      );
    }
  }

  void _share() {
    final unchecked = _items.where((i) => !i.isChecked).toList();
    if (unchecked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to share — your list is empty.')),
      );
      return;
    }
    final grouped = <GroceryAisle, List<PersistentShoppingItem>>{};
    for (final item in unchecked) {
      final aisle = AisleUtils.classify(item.name);
      grouped.putIfAbsent(aisle, () => []).add(item);
    }
    final buffer = StringBuffer();
    buffer.writeln('Shopping List');
    buffer.writeln('─────────────');
    // Honour the user's custom aisle order so the share text reads in
    // the same sequence as the on-screen list.
    for (final aisle in AisleUtils.orderedFor(_aisleOrder)) {
      final items = grouped[aisle];
      if (items == null || items.isEmpty) continue;
      buffer.writeln();
      buffer.writeln(AisleUtils.displayName(aisle));
      for (final item in items) {
        final qty = item.quantity.isNotEmpty ? '${item.quantity} ' : '';
        buffer.writeln('  • $qty${_capitalise(item.name)}');
      }
    }
    buffer.writeln();
    buffer.writeln('Shared from ELiO — AI Recipe Generator');
    Share.share(buffer.toString(), subject: 'Shopping List');
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ElioSpacing.screenEdge,
        ElioSpacing.lg,
        ElioSpacing.screenEdge,
        ElioSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: ElioHeroHeading(
                  lines: ['your', 'shopping list'],
                  amberLastLine: true,
                  showUnderline: true,
                ),
              ),
              IconButton(
                onPressed: _share,
                icon: const Icon(Icons.ios_share_rounded),
                color: ElioColors.espresso,
                tooltip: 'Share list',
              ),
            ],
          ),
          const SizedBox(height: ElioSpacing.xl),

          // ── Add item row ───────────────────────────────────────────
          _AddItemField(
            controller: _addController,
            onSubmit: _addItem,
          ),
          const SizedBox(height: ElioSpacing.lg),

          // ── List body ──────────────────────────────────────────────
          if (_items.isEmpty)
            _buildEmptyState()
          else ...[
            // Discoverability hint for swipe-to-delete on rows AND the
            // long-press-to-reorder on aisle headers (Sprint 16.7c).
            Padding(
              padding: const EdgeInsets.only(bottom: ElioSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.drag_indicator_rounded,
                    size: 14,
                    color: ElioColors.mocha.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'long-press header to reorder · swipe row to remove',
                    style: ElioTextStyles.bodySmall.copyWith(
                      color: ElioColors.mocha,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _buildReorderableAisles(_items),
            if (_items.any((i) => i.isChecked)) ...[
              const SizedBox(height: ElioSpacing.lg),
              _ClearCheckedButton(
                count: _items.where((i) => i.isChecked).length,
                onTap: _clearChecked,
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Sprint 16.7c — aisles render as a [ReorderableListView] so the user
  /// can long-press an aisle header and drag the whole section up or
  /// down to match their store's actual layout. Default Flutter drag
  /// handles are disabled (`buildDefaultDragHandles: false`) and a
  /// [ReorderableDragStartListener] is wrapped around the header only —
  /// long-pressing a row inside the section does NOT trigger reorder
  /// (which would clash with swipe-to-delete and tap-to-check).
  ///
  /// shrinkWrap + NeverScrollableScrollPhysics so the list nests inside
  /// the screen's outer SingleChildScrollView. Aisles with no items
  /// auto-hide (visible-only reorder); newly-arriving items in a
  /// previously-invisible aisle slot in at the bottom of the user's
  /// custom order — they can be dragged into place from there.
  Widget _buildReorderableAisles(List<PersistentShoppingItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Group all items (checked + unchecked) by aisle so checked rows stay in
    // place greyed instead of jumping to a separate "in basket" section.
    final grouped = <GroceryAisle, List<PersistentShoppingItem>>{};
    for (final item in items) {
      final aisle = AisleUtils.classify(item.name);
      grouped.putIfAbsent(aisle, () => []).add(item);
    }

    final orderedAll = AisleUtils.orderedFor(_aisleOrder);
    final visible = orderedAll
        .where((a) => grouped[a]?.isNotEmpty == true)
        .toList();

    // Discoverability backstop — fire the one-time tooltip if there are
    // actually >= 2 aisles to reorder. Internal guards prevent re-firing
    // across rebuilds; the call is safe from build via post-frame defer.
    _maybeShowReorderHint(visible.length);

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) =>
          _onAisleReorder(visible, oldIndex, newIndex),
      children: [
        for (var i = 0; i < visible.length; i++)
          _AisleSection(
            key: ValueKey('aisle-${visible[i].name}'),
            aisle: visible[i],
            items: grouped[visible[i]]!,
            dragIndex: i,
            buildRow: _buildRow,
          ),
      ],
    );
  }

  /// Apply a visible-aisles reorder to the full preference list. Invisible
  /// aisles (no items today) preserve their relative position in the
  /// default enum order and append after the user's custom-ordered
  /// visible aisles.
  void _onAisleReorder(
    List<GroceryAisle> visible,
    int oldIndex,
    int newIndex,
  ) {
    // ReorderableListView semantics: when moving down, newIndex points
    // to the position AFTER removal. Adjust here so the math below is
    // simple "remove + insert at index".
    var adjustedNew = newIndex;
    if (adjustedNew > oldIndex) adjustedNew -= 1;

    final reorderedVisible = List<GroceryAisle>.from(visible);
    final moved = reorderedVisible.removeAt(oldIndex);
    reorderedVisible.insert(adjustedNew, moved);

    final visibleSet = visible.toSet();
    final invisibleInDefaultOrder =
        GroceryAisle.values.where((a) => !visibleSet.contains(a));
    final newFullOrder = <String>[
      ...reorderedVisible.map((a) => a.name),
      ...invisibleInDefaultOrder.map((a) => a.name),
    ];

    setState(() => _aisleOrder = newFullOrder);
    // Fire-and-forget — UI updates optimistically. A failure here just
    // means the next page load reverts to the prior order; no action
    // for the user to take, so no snackbar.
    FirestoreService().saveAisleOrder(newFullOrder).catchError((_) {});
  }

  Widget _buildRow(PersistentShoppingItem item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: ElioColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(ElioRadii.card),
        ),
        child: const Icon(Icons.delete_outline, color: ElioColors.error),
      ),
      onDismissed: (_) => _remove(item),
      child: _ShoppingRow(
        name: _capitalise(item.name),
        // Restock items are added via the pantry "Mark running low"
        // action with quantity == 'Restock'. The badge already
        // communicates that, so the qty text would be redundant.
        quantity: item.isRestock ? '' : item.quantity,
        checked: item.isChecked,
        isRestock: item.isRestock,
        onTap: () => _toggle(item),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ElioSpacing.xxl),
      child: Center(
        child: Text(
          'your list is empty — add an item above',
          style: ElioTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ─── Standalone page wrapper ─────────────────────────────────────────
//
// [ShoppingListScreen] is body-only and lives inside AppShell's scaffold for
// the Shopping tab. When other flows (e.g. the meal planner "View" snack
// action) push the list via Navigator, they need their own scaffold —
// otherwise the body floats on a black void. Use [ShoppingListPage] for
// those entry points.
class ShoppingListPage extends StatelessWidget {
  const ShoppingListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ElioAppScaffold(
      body: ShoppingListScreen(),
      showBottomNav: false,
    );
  }
}

// ─── Aisle section (Sprint 16.7c) ────────────────────────────────────
//
// One reorderable item in the [_buildReorderableAisles] list. The header
// is wrapped in [ReorderableDragStartListener] so long-press-to-drag is
// scoped to the eyebrow row only — item rows below stay free for tap +
// swipe. A subtle drag-indicator icon on the right of the header gives
// the gesture some discoverability without screaming for attention.
class _AisleSection extends StatelessWidget {
  final GroceryAisle aisle;
  final List<PersistentShoppingItem> items;
  final int dragIndex;
  final Widget Function(PersistentShoppingItem) buildRow;

  const _AisleSection({
    required Key key,
    required this.aisle,
    required this.items,
    required this.dragIndex,
    required this.buildRow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReorderableDragStartListener(
          index: dragIndex,
          child: Padding(
            padding: const EdgeInsets.only(
              top: ElioSpacing.sm,
              bottom: ElioSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElioEyebrow(AisleUtils.displayName(aisle)),
                ),
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 16,
                  color: ElioColors.mocha.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
        ...items.map(buildRow),
      ],
    );
  }
}

// ─── Inline shopping row ─────────────────────────────────────────────
//
// Bespoke row for the shopping list (NOT ElioIngredientRow): keeps quantity
// inline on the right and renders checked items greyed/struck-through in
// place rather than moving them to a separate section.
class _ShoppingRow extends StatelessWidget {
  final String name;
  final String quantity;
  final bool checked;
  final bool isRestock;
  final VoidCallback onTap;

  const _ShoppingRow({
    required this.name,
    required this.quantity,
    required this.checked,
    required this.onTap,
    this.isRestock = false,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = ElioColors.mocha.withValues(alpha: 0.6);
    final nameStyle = ElioTextStyles.body.copyWith(
      color: checked ? mutedColor : ElioColors.espresso,
      decoration: checked ? TextDecoration.lineThrough : null,
      decorationColor: mutedColor,
      fontWeight: FontWeight.w600,
    );
    final qtyStyle = ElioTextStyles.bodySmall.copyWith(
      color: checked ? mutedColor : ElioColors.mocha,
      decoration: checked ? TextDecoration.lineThrough : null,
      decorationColor: mutedColor,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ElioRadii.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ElioSpacing.xs,
          vertical: ElioSpacing.sm,
        ),
        child: Row(
          children: [
            // Circle checkbox — matches ElioIngredientRow styling.
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? ElioColors.terracotta : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: checked ? ElioColors.terracotta : ElioColors.rule,
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: ElioSpacing.md),
            Expanded(
              child: Text(name, style: nameStyle, overflow: TextOverflow.ellipsis),
            ),
            if (isRestock) ...[
              const SizedBox(width: ElioSpacing.sm),
              _RestockBadge(faded: checked),
            ],
            if (quantity.isNotEmpty) ...[
              const SizedBox(width: ElioSpacing.sm),
              Text(quantity, style: qtyStyle),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Restock badge ─────────────────────────────────────────────────────
//
// Sprint 16.6.x — distinguishes items added via the pantry "Mark running
// low" action from manual / meal-plan / recipe entries. Mirrors the
// terracotta "Low" badge on the pantry chip so the two screens speak the
// same visual language.
class _RestockBadge extends StatelessWidget {
  final bool faded;
  const _RestockBadge({required this.faded});

  @override
  Widget build(BuildContext context) {
    final alpha = faded ? 0.4 : 1.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ElioColors.terracotta.withValues(alpha: 0.15 * alpha),
        borderRadius: BorderRadius.circular(ElioRadii.chip),
        border: Border.all(
          color: ElioColors.terracotta.withValues(alpha: 0.55 * alpha),
        ),
      ),
      child: Text(
        'Restock',
        style: ElioTextStyles.bodySmall.copyWith(
          color: ElioColors.terracotta.withValues(alpha: alpha),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─── Bottom CTA: clear all checked items ─────────────────────────────
class _ClearCheckedButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ClearCheckedButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? 'Delete 1 checked item' : 'Delete $count checked items';
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.delete_outline, size: 18, color: ElioColors.mocha),
        label: Text(
          label,
          style: ElioTextStyles.uiLabelStyle.copyWith(color: ElioColors.mocha),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: ElioSpacing.lg,
            vertical: ElioSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ElioRadii.button),
          ),
        ),
      ),
    );
  }
}

// ─── Add item field with trailing add button ─────────────────────────
class _AddItemField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _AddItemField({required this.controller, required this.onSubmit});

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
                hintText: 'Add an item',
                hintStyle:
                    ElioTextStyles.body.copyWith(color: ElioColors.mocha),
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
