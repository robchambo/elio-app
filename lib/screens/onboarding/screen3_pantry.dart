import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/elio_models.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio_progress_bar.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// PantryReviewScreen (Screen 3)
// Design: approachable utility.
// User reviews and adjusts the pre-populated pantry.
// Long-press a chip to move it between tiers via a context menu.
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

  void _addItem() {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
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
              // Handle bar
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
              Text(
                item.name,
                style: ElioText.headingMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Currently in: ${item.tier == 'alwaysHave' ? 'Always Have' : 'Almost Always Have'}',
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
              const SizedBox(height: 16),
              // Move option
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
              // Remove option
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
              const ElioProgressBar(currentStep: 3, totalSteps: 5),
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
                  const Icon(Icons.touch_app_rounded,
                      size: 14, color: ElioColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Long-press a chip to move it between sections.',
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
                        onRemove: _removeItem,
                        onLongPress: (item) => _showMoveMenu(context, item),
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
                        onRemove: _removeItem,
                        onLongPress: (item) => _showMoveMenu(context, item),
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

// ─── Tier section ─────────────────────────────────────────────────────────────

class _TierSection extends StatelessWidget {
  final String tier;
  final String title;
  final String subtitle;
  final Color color;
  final List<InventoryItem> items;
  final void Function(String name) onRemove;
  final void Function(InventoryItem item) onLongPress;

  const _TierSection({
    required this.tier,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.items,
    required this.onRemove,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        color: color.withValues(alpha: 0.04),
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
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: ElioText.bodyMedium
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    subtitle,
                    style: ElioText.label.copyWith(
                      color: ElioColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Chips
          if (items.isEmpty)
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
              children: items.map((item) {
                return GestureDetector(
                  onLongPress: () => onLongPress(item),
                  child: _ItemChip(
                    label: item.name,
                    color: color,
                    onRemove: () => onRemove(item.name),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
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
