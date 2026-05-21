import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/scanner_service.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';

// ─────────────────────────────────────────────
// ReceiptResultsScreen
// Shown after receipt OCR. Displays parsed items
// with tier assignment. Users can edit tiers and
// confirm which items to add to their pantry.
// ─────────────────────────────────────────────

class ReceiptResultsScreen extends StatefulWidget {
  final ReceiptScanResult result;

  const ReceiptResultsScreen({super.key, required this.result});

  @override
  State<ReceiptResultsScreen> createState() => _ReceiptResultsScreenState();
}

class _ReceiptResultsScreenState extends State<ReceiptResultsScreen> {
  late List<ScannedItem> _items;
  int? _expandedIndex; // which item is expanded for tier editing
  bool _showTierHint = true; // one-time hint dismissed after first tier tap

  // ─── Name Edit Dialog ────────────────────────────────────────────

  Future<void> _showNameEditDialog(int index) async {
    final controller = TextEditingController(text: _items[index].name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Edit Name', style: ElioTextStyles.uiLabelStyle.copyWith(
          color: ElioColors.espresso,
        )),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: ElioTextStyles.bodySmallStyle.copyWith(color: ElioColors.espresso),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ElioColors.terracotta, width: 1.5),
            ),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: ElioTextStyles.bodyStyle.copyWith(color: ElioColors.mocha)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text('Save', style: ElioTextStyles.uiLabelStyle.copyWith(
              color: ElioColors.terracotta,
            )),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty && result != _items[index].name) {
      setState(() {
        _items[index] = _items[index].copyWith(name: result);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _items = List<ScannedItem>.from(widget.result.items);
  }

  /// Number of items that had tier memory applied.
  int get _tierMemoryCount => _items.where((i) => i.tierFromMemory).length;

  /// Food items only.
  List<ScannedItem> get _foodItems => _items.where((i) => !i.isNonFood).toList();

  /// Non-food items.
  int get _nonFoodCount => _items.where((i) => i.isNonFood).length;

  // ─── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: Text('Receipt Items', style: ElioText.headingLarge),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // 19 May 2026 — Rob: receipts shorten item names
                // ("ORG PNAPPLE", "KS COAST CHI") and the OCR + Gemini
                // pass can only do so much. Set expectations up-front
                // that the user should sweep each line before
                // confirming. Sits above the smart-memory banner so
                // first-time scanners see it on every receipt; once
                // dismissed (Sprint 17 polish), only first-time users
                // would see it.
                _buildEditPromptBanner(),
                const SizedBox(height: 10),
                // Smart memory banner
                if (_tierMemoryCount > 0) _buildMemoryBanner(),
                const SizedBox(height: 12),
                // Store name + item count
                _buildStoreHeader(),
                const SizedBox(height: 12),
                // Items in receipt-style container
                _buildReceiptContainer(),
                // Non-food note
                if (_nonFoodCount > 0) _buildNonFoodNote(),
                const SizedBox(height: 80), // space for bottom button
              ],
            ),
          ),
          _buildConfirmButton(),
        ],
      ),
    );
  }

  // ─── Edit-prompt Banner ─────────────────────────────────────────
  //
  // Receipt OCR + Gemini parsing can't always rescue truncated names
  // ("ORG PNAPPLE", "KS COAST CHI") or correct mis-categorised tiers.
  // This banner sets expectations so the user knows to sweep each
  // line before confirming, rather than feeling like the import is
  // broken when names look weird.

  Widget _buildEditPromptBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ElioColors.terracotta.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ElioColors.terracotta.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.edit_note_rounded,
            color: ElioColors.terracotta,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Check each line before adding',
                  style: ElioTextStyles.bodySmallStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ElioColors.espresso,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Supermarkets shorten item names on receipts. Tap a row "
                  "to rename it, fix the tier, or remove it — every store's "
                  "receipt is different and a quick sweep is normal.",
                  style: ElioTextStyles.bodySmallStyle.copyWith(
                    color: ElioColors.mocha,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Smart Memory Banner ────────────────────────────────────────

  Widget _buildMemoryBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ElioColors.peach.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ElioColors.mocha.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_rounded, color: ElioColors.mocha, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Elio remembered tier preferences for $_tierMemoryCount item${_tierMemoryCount == 1 ? '' : 's'} from previous receipts',
              style: ElioTextStyles.bodySmallStyle.copyWith(
                color: ElioColors.mocha,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Store Header ───────────────────────────────────────────────

  Widget _buildStoreHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.result.storeName != null)
              Text(
                widget.result.storeName!,
                style: ElioText.headingMedium,
              ),
            Text(
              '${_foodItems.length} food item${_foodItems.length == 1 ? '' : 's'} found',
              style: ElioTextStyles.bodySmallStyle.copyWith(
                color: ElioColors.mocha,
              ),
            ),
          ],
        ),
        // Item count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ElioColors.terracotta.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_items.length} total',
            style: ElioTextStyles.bodySmallStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: ElioColors.terracotta,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Receipt Container ──────────────────────────────────────────

  Widget _buildReceiptContainer() {
    return Container(
      decoration: BoxDecoration(
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ElioColors.rule),
      ),
      child: Column(
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final isLast = index == _items.length - 1;
          final isExpanded = _expandedIndex == index;

          return Column(
            children: [
              _buildReceiptItemTile(item, index, isExpanded),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _DottedLinePainter(color: ElioColors.rule),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildReceiptItemTile(ScannedItem item, int index, bool isExpanded) {
    final firstFoodIndex = _items.indexWhere((i) => !i.isNonFood);
    final isFirstFood = !item.isNonFood && index == firstFoodIndex;
    return InkWell(
      onTap: item.isNonFood
          ? null
          : () => setState(() {
                _expandedIndex = isExpanded ? null : index;
              }),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main row: name, tier badge, price
            Row(
              children: [
                Expanded(
                  child: isExpanded && !item.isNonFood
                      ? GestureDetector(
                          onTap: () => _showNameEditDialog(index),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.name,
                                  style: ElioTextStyles.uiLabelStyle.copyWith(
                                    fontSize: 14,
                                    color: ElioColors.espresso,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_rounded, size: 14, color: ElioColors.terracotta),
                            ],
                          ),
                        )
                      : Text(
                          item.name,
                          style: ElioTextStyles.uiLabelStyle.copyWith(
                            fontSize: 14,
                            color: item.isNonFood ? ElioColors.mocha : ElioColors.espresso,
                            decoration: item.isNonFood ? TextDecoration.lineThrough : null,
                          ),
                        ),
                ),
                if (!item.isNonFood)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _expandedIndex = isExpanded ? null : index;
                        _showTierHint = false;
                      });
                    },
                    child: _buildTierBadge(item.suggestedTier),
                  ),
                if (item.price != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    '\$${item.price!}',
                    style: ElioTextStyles.bodySmallStyle.copyWith(
                      color: ElioColors.mocha,
                    ),
                  ),
                ],
                if (!item.isNonFood) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() {
                      _items.removeAt(index);
                      if (_expandedIndex == index) _expandedIndex = null;
                      if (_expandedIndex != null && _expandedIndex! > index) {
                        _expandedIndex = _expandedIndex! - 1;
                      }
                    }),
                    child: const Icon(Icons.close_rounded, size: 18, color: ElioColors.mocha),
                  ),
                ],
              ],
            ),
            // One-time hint shown beneath the first food item.
            if (isFirstFood && _showTierHint)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tap tier badge to change category',
                  style: ElioTextStyles.tabLabelStyle.copyWith(
                    color: ElioColors.mocha,
                  ),
                ),
              ),
            // Expanded tier editor
            if (isExpanded && !item.isNonFood) ...[
              const SizedBox(height: 10),
              _buildTierSelector(index),
              if (_items[index].suggestedTier == 'perishable') ...[
                const SizedBox(height: 8),
                _buildExpiryPresets(index),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTierBadge(String tier) {
    // 19 May 2026 — Rob's on-device screenshot showed badges rendering
    // as `almostAlwaysHave` (the raw enum value tracked-out in
    // tabLabelStyle, looked like terminal text and overflowed the row).
    // Root cause: scanner_service writes the canonical inventory tier
    // `'almostAlwaysHave'` (with the `Have` suffix — matches
    // `InventoryItem.tier` everywhere else in the app), but this
    // switch only matched the legacy `'almostAlways'` form. Items
    // suggested with the canonical tier fell through to the `_`
    // fallback and rendered the raw string. Match both for safety.
    final (Color bg, Color fg, String label) = switch (tier) {
      'alwaysHave' =>
        (const Color(0xFFE8F5E9), ElioColors.success, 'Always Have'),
      'almostAlwaysHave' || 'almostAlways' =>
        (const Color(0xFFE3F2FD), ElioColors.mocha, 'Almost Always'),
      'perishable' =>
        (const Color(0xFFFFF3E0), ElioColors.terracotta, 'Perishable'),
      _ => (ElioColors.cream, ElioColors.mocha, tier),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: ElioTextStyles.tabLabelStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          Icon(Icons.arrow_drop_down, size: 14, color: fg),
        ],
      ),
    );
  }

  // ─── Tier Selector Chips ────────────────────────────────────────

  Widget _buildTierSelector(int index) {
    // 19 May 2026 — canonical inventory tiers (match InventoryItem.tier).
    // The legacy `'almostAlways'` form was a receipt-screen local; it
    // wrote out values that didn't round-trip cleanly with the rest of
    // the app's pantry data. Use the same strings every other surface
    // does.
    const tiers = [
      ('alwaysHave', 'Always Have'),
      ('almostAlwaysHave', 'Almost Always'),
      ('perishable', 'Perishable'),
    ];
    final currentRaw = _items[index].suggestedTier;
    // Treat legacy `'almostAlways'` as `'almostAlwaysHave'` so a tile
    // built before this commit still shows the chip as selected.
    final current = currentRaw == 'almostAlways' ? 'almostAlwaysHave' : currentRaw;

    return Wrap(
      spacing: 8,
      children: tiers.map((tier) {
        final isSelected = current == tier.$1;
        return GestureDetector(
          onTap: () {
            setState(() {
              _items[index] = _items[index].copyWith(suggestedTier: tier.$1);
            });
            HapticFeedback.selectionClick();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? ElioColors.terracotta.withValues(alpha: 0.12) : ElioColors.cream,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? ElioColors.terracotta : ElioColors.rule,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              tier.$2,
              style: ElioTextStyles.bodySmallStyle.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? ElioColors.terracotta : ElioColors.mocha,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Expiry Presets ─────────────────────────────────────────────

  Widget _buildExpiryPresets(int index) {
    const presets = ['3 days', '1 week', '2 weeks', 'No expiry'];
    final currentExpiry = _items[index].expiryLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expires in:',
          style: ElioTextStyles.tabLabelStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: ElioColors.mocha,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          children: presets.map((preset) {
            final isSelected = currentExpiry == preset;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _items[index] = _items[index].copyWith(expiryLabel: preset);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? ElioColors.terracotta.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? ElioColors.terracotta : ElioColors.rule,
                  ),
                ),
                child: Text(
                  preset,
                  style: ElioTextStyles.tabLabelStyle.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? ElioColors.terracotta : ElioColors.mocha,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Non-Food Note ──────────────────────────────────────────────

  Widget _buildNonFoodNote() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: ElioColors.mocha),
          const SizedBox(width: 6),
          Text(
            '$_nonFoodCount non-food item${_nonFoodCount == 1 ? '' : 's'} filtered',
            style: ElioTextStyles.bodySmallStyle.copyWith(
              color: ElioColors.mocha,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Confirm Button ─────────────────────────────────────────────

  Widget _buildConfirmButton() {
    final count = _foodItems.length;
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: ElioColors.cream,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_foodItems),
            style: ElevatedButton.styleFrom(
              backgroundColor: ElioColors.terracotta,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              'Add $count Item${count == 1 ? '' : 's'} to Pantry',
              style: ElioTextStyles.uiLabelStyle.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dotted Line Painter ─────────────────────────────────────────
// Draws a horizontal dotted line between receipt items.

class _DottedLinePainter extends CustomPainter {
  final Color color;
  _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
