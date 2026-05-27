// lib/widgets/order_import_review_sheet.dart
//
// Sprint 17 — Online Order → Pantry Import (Task 8).
//
// Bottom-sheet that lets the user review a parsed order email before
// it gets written into the pantry. One row per parsed item:
//   - Checkbox (food classification → on by default, household → off and
//     hidden under an expander).
//   - Editable normalisedName text field.
//   - Category label.
//
// The CTA at the bottom shows the live selected count
// (`Add N items to pantry`) and is disabled when N == 0.
//
// InventoryWriter.addItem handles dedup correctly server-side
// regardless of whether the row already exists, so the sheet does not
// surface a per-row "Will add" / "Will increment" hint.
//
// Apply-side wiring (InventoryWriter + status flip) lives in Task 9 —
// this widget is purely UI + an `onApply(List<ApplyItem>)` callback.
//
// For `parse_failed` imports (empty items list) we render a short
// fallback: a one-line apology + a Discard button only.

import 'package:flutter/material.dart';

import '../models/pending_import.dart';
import '../theme/elio_radii.dart';
import '../theme/elio_spacing.dart';
import '../theme/elio_text_styles.dart';
import '../theme/elio_theme.dart';

/// Bridge between the review sheet and Task 9's apply flow.
///
/// `name` is the (possibly edited) normalisedName the user accepted,
/// `category` is the original parsed category. `tier` is derived so
/// callers can pass it straight to `InventoryWriter.addItem`.
class ApplyItem {
  final String name;
  final String category;

  ApplyItem({required this.name, required this.category});

  /// Maps category → InventoryWriter tier:
  ///   produce/dairy/meat/bakery → perishable
  ///   frozen                    → frozen
  ///   else                      → pantry
  String get tier => _tierFor(category);
}

String _tierFor(String category) {
  switch (category) {
    case 'produce':
    case 'dairy':
    case 'meat':
    case 'bakery':
      return 'perishable';
    case 'frozen':
      return 'frozen';
    default:
      return 'pantry';
  }
}

class OrderImportReviewSheet extends StatefulWidget {
  /// The pending import being reviewed.
  final PendingImport pendingImport;

  /// Called when the user taps the CTA. Receives the selected items
  /// (with potentially edited names). The host is responsible for the
  /// InventoryWriter + status-flip wiring (Task 9).
  final Future<void> Function(List<ApplyItem> selected) onApply;

  /// Called when the user discards a parse_failed import (or, in
  /// future, an empty selection).
  final VoidCallback onDiscard;

  const OrderImportReviewSheet({
    super.key,
    required this.pendingImport,
    required this.onApply,
    required this.onDiscard,
  });

  @override
  State<OrderImportReviewSheet> createState() => _OrderImportReviewSheetState();
}

class _RowState {
  final TextEditingController controller;
  final PendingImportItem original;
  bool selected;

  _RowState({
    required this.controller,
    required this.original,
    required this.selected,
  });

  void dispose() => controller.dispose();

  bool get isHousehold => original.classification == 'household';
}

class _OrderImportReviewSheetState extends State<OrderImportReviewSheet> {
  late List<_RowState> _rows;
  bool _householdExpanded = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _rows = widget.pendingImport.items.map((it) {
      final ctrl = TextEditingController(text: it.normalizedName);
      return _RowState(
        controller: ctrl,
        original: it,
        selected: it.classification == 'food',
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  int get _selectedCount => _rows.where((r) => r.selected).length;

  List<ApplyItem> _buildApplyItems() {
    return _rows
        .where((r) => r.selected)
        .map((r) => ApplyItem(
              name: r.controller.text.trim(),
              category: r.original.category,
            ))
        .toList();
  }

  Future<void> _handleApply() async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      await widget.onApply(_buildApplyItems());
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  // ─── Formatting helpers ───────────────────────────────────────────────

  String _formatRetailer(String retailer) {
    if (retailer.isEmpty) return 'Order';
    return retailer[0].toUpperCase() + retailer.substring(1);
  }

  String _formatReceivedAt(DateTime? d) {
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _orderTypeLabel(String orderType) {
    switch (orderType) {
      case 'confirmation':
        return 'Order confirmation';
      case 'post_pickup_receipt':
        return 'Final receipt';
      case 'delivery_receipt':
        return 'Delivery receipt';
      default:
        return 'Order receipt';
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final items = widget.pendingImport.items;
    final isFailed = items.isEmpty;

    return Padding(
      // Lift the sheet above the keyboard when a name field is focused.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: ElioColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: isFailed ? _buildFailed(context) : _buildReview(context),
        ),
      ),
    );
  }

  Widget _buildFailed(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ElioSpacing.lg,
        ElioSpacing.md,
        ElioSpacing.lg,
        ElioSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _grabber(),
          const SizedBox(height: ElioSpacing.md),
          Text(
            _formatRetailer(widget.pendingImport.retailer),
            style: ElioTextStyles.sectionHeadingStyle,
          ),
          const SizedBox(height: ElioSpacing.sm),
          const Text(
            "We couldn't read this email.",
            style: ElioTextStyles.bodyStyle,
          ),
          const SizedBox(height: ElioSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onDiscard,
              child: const Text('Discard'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final foodRows = _rows.where((r) => !r.isHousehold).toList();
    final householdRows = _rows.where((r) => r.isHousehold).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            _grabber(),
            const SizedBox(height: ElioSpacing.sm),
            _buildHeader(),
            const Divider(height: 1, color: ElioColors.rule),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: ElioSpacing.lg,
                  vertical: ElioSpacing.sm,
                ),
                children: [
                  for (final row in foodRows) _itemRow(row),
                  if (householdRows.isNotEmpty) ...[
                    const SizedBox(height: ElioSpacing.sm),
                    _householdExpander(householdRows.length),
                    if (_householdExpanded)
                      for (final row in householdRows) _itemRow(row),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: ElioColors.rule),
            _buildCta(),
          ],
        );
      },
    );
  }

  Widget _grabber() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: ElioColors.rule,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final pi = widget.pendingImport;
    final retailer = _formatRetailer(pi.retailer);
    final received = _formatReceivedAt(pi.receivedAt);
    final subtitle = _orderTypeLabel(pi.orderType);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ElioSpacing.lg,
        ElioSpacing.sm,
        ElioSpacing.lg,
        ElioSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            received.isEmpty ? retailer : '$retailer  ·  $received',
            style: ElioTextStyles.sectionHeadingStyle,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: ElioTextStyles.bodySmallStyle,
          ),
        ],
      ),
    );
  }

  Widget _householdExpander(int count) {
    final label = _householdExpanded
        ? 'Hide $count household item${count == 1 ? '' : 's'}'
        : 'Show $count household item${count == 1 ? '' : 's'}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ElioSpacing.xs),
      child: InkWell(
        borderRadius: BorderRadius.circular(ElioRadii.md),
        onTap: () => setState(() => _householdExpanded = !_householdExpanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ElioSpacing.sm,
            vertical: ElioSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                _householdExpanded
                    ? Icons.expand_less
                    : Icons.expand_more,
                color: ElioColors.mocha,
                size: 20,
              ),
              const SizedBox(width: ElioSpacing.xs),
              Text(label, style: ElioTextStyles.bodySmallStyle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemRow(_RowState row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ElioSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: row.selected,
              onChanged: (v) => setState(() => row.selected = v ?? false),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: row.controller,
                  style: ElioTextStyles.bodyStyle,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.original.category,
                  style: ElioTextStyles.bodySmallStyle
                      .copyWith(color: ElioColors.mocha),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCta() {
    final n = _selectedCount;
    final enabled = n > 0 && !_applying;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ElioSpacing.lg,
        ElioSpacing.md,
        ElioSpacing.lg,
        ElioSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _applying ? null : widget.onDiscard,
              child: const Text('Discard'),
            ),
          ),
          const SizedBox(width: ElioSpacing.sm),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: enabled ? _handleApply : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: ElioColors.terracotta,
                foregroundColor: Colors.white,
                disabledBackgroundColor: ElioColors.rule,
                disabledForegroundColor: ElioColors.mocha,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                elevation: 0,
              ),
              child: Text(
                'Add $n item${n == 1 ? '' : 's'} to pantry',
                style: ElioTextStyles.uiLabelStyle.copyWith(
                  color: enabled ? Colors.white : ElioColors.mocha,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
