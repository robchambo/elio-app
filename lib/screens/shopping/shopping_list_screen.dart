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
//   • Each row is a tappable ElioIngredientRow (tap toggles isChecked)
//   • Swipe-to-delete via Dismissible
//   • Checked items pushed to the bottom under an "in basket" eyebrow
//
// Uses ShoppingService for mutations and AisleUtils for grouping. Share uses
// share_plus and formats the unchecked items grouped by aisle (same format as
// the legacy ProfileScreen shopping tab).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/shopping_service.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../utils/aisle_utils.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../../widgets/elio/elio_ingredient_row.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final TextEditingController _addController = TextEditingController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  List<PersistentShoppingItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscribe();
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
    for (final aisle in AisleUtils.displayOrder) {
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

    final unchecked = _items.where((i) => !i.isChecked).toList();
    final checked = _items.where((i) => i.isChecked).toList();

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
                color: ElioColors.navy,
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
            ..._buildAisleSections(unchecked),
            if (checked.isNotEmpty) ...[
              const SizedBox(height: ElioSpacing.md),
              const ElioEyebrow('in basket'),
              const SizedBox(height: ElioSpacing.sm),
              ...checked.map(_buildRow),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAisleSections(List<PersistentShoppingItem> unchecked) {
    if (unchecked.isEmpty) return const [];
    final grouped = <GroceryAisle, List<PersistentShoppingItem>>{};
    for (final item in unchecked) {
      final aisle = AisleUtils.classify(item.name);
      grouped.putIfAbsent(aisle, () => []).add(item);
    }

    final sections = <Widget>[];
    for (final aisle in AisleUtils.displayOrder) {
      final items = grouped[aisle];
      if (items == null || items.isEmpty) continue;
      sections.add(Padding(
        padding: const EdgeInsets.only(top: ElioSpacing.sm, bottom: ElioSpacing.xs),
        child: ElioEyebrow(AisleUtils.displayName(aisle)),
      ));
      sections.addAll(items.map(_buildRow));
    }
    return sections;
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
          borderRadius: ElioRadii.card,
        ),
        child: const Icon(Icons.delete_outline, color: ElioColors.error),
      ),
      onDismissed: (_) => _remove(item),
      child: ElioIngredientRow(
        name: _capitalise(item.name),
        detail: item.quantity.isNotEmpty ? item.quantity : null,
        checked: item.isChecked,
        onChanged: (_) => _toggle(item),
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
        borderRadius: ElioRadii.card,
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
                    ElioTextStyles.body.copyWith(color: ElioColors.textSecondary),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: ElioColors.amber,
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
