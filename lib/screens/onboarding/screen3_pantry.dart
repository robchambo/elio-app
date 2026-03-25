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
// Long-press a chip to drag it between tiers.
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
  String? _draggingItemName; // name of item being dragged

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
    setState(() {
      final idx = _items.indexWhere((i) => i.name == name);
      if (idx != -1 && _items[idx].tier != newTier) {
        _items[idx] = InventoryItem(name: name, tier: newTier);
      }
      _draggingItemName = null;
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
                  const Icon(Icons.drag_indicator_rounded,
                      size: 14, color: ElioColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Long-press a chip to drag it between sections.',
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
                      _DragTargetSection(
                        tier: 'alwaysHave',
                        title: 'Always have',
                        subtitle: 'These are your pantry staples.',
                        color: ElioColors.amber,
                        items: _alwaysHave,
                        draggingItemName: _draggingItemName,
                        onDrop: (name) => _moveItemToTier(name, 'alwaysHave'),
                        onRemove: _removeItem,
                        onDragStarted: (name) =>
                            setState(() => _draggingItemName = name),
                        onDragEnd: () =>
                            setState(() => _draggingItemName = null),
                      ),
                      const SizedBox(height: 16),

                      // Almost always have section
                      _DragTargetSection(
                        tier: 'almostAlwaysHave',
                        title: 'Almost always have',
                        subtitle:
                            'Things you usually have but might run out of.',
                        color: ElioColors.sky,
                        items: _almostAlwaysHave,
                        draggingItemName: _draggingItemName,
                        onDrop: (name) =>
                            _moveItemToTier(name, 'almostAlwaysHave'),
                        onRemove: _removeItem,
                        onDragStarted: (name) =>
                            setState(() => _draggingItemName = name),
                        onDragEnd: () =>
                            setState(() => _draggingItemName = null),
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

// ─── Drag-target section ──────────────────────────────────────────────────────

class _DragTargetSection extends StatefulWidget {
  final String tier;
  final String title;
  final String subtitle;
  final Color color;
  final List<InventoryItem> items;
  final String? draggingItemName;
  final void Function(String name) onDrop;
  final void Function(String name) onRemove;
  final void Function(String name) onDragStarted;
  final VoidCallback onDragEnd;

  const _DragTargetSection({
    required this.tier,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.items,
    required this.draggingItemName,
    required this.onDrop,
    required this.onRemove,
    required this.onDragStarted,
    required this.onDragEnd,
  });

  @override
  State<_DragTargetSection> createState() => _DragTargetSectionState();
}

class _DragTargetSectionState extends State<_DragTargetSection> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    // Only show as a drop target when something from the OTHER tier is being dragged
    final isDragActive = widget.draggingItemName != null &&
        !widget.items.any((i) => i.name == widget.draggingItemName);

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        // Only accept items not already in this tier
        final alreadyHere =
            widget.items.any((i) => i.name == details.data);
        return !alreadyHere;
      },
      onAcceptWithDetails: (details) {
        HapticFeedback.mediumImpact();
        setState(() => _isHovering = false);
        widget.onDrop(details.data);
      },
      onMove: (_) {
        if (!_isHovering) setState(() => _isHovering = true);
      },
      onLeave: (_) {
        if (_isHovering) setState(() => _isHovering = false);
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = _isHovering && isDragActive;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hovering
                ? widget.color.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: hovering
                ? Border.all(
                    color: widget.color.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : Border.all(color: Colors.transparent),
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
                    decoration: BoxDecoration(
                        color: widget.color, shape: BoxShape.circle),
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
                  if (hovering) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.15),
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
              if (widget.items.isEmpty && !hovering)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    'Drag items here to move them to this section.',
                    style: ElioText.label
                        .copyWith(color: ElioColors.textMuted),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.items.map((item) {
                    return LongPressDraggable<String>(
                      data: item.name,
                      delay: const Duration(milliseconds: 300),
                      onDragStarted: () {
                        HapticFeedback.selectionClick();
                        widget.onDragStarted(item.name);
                      },
                      onDragEnd: (_) => widget.onDragEnd(),
                      onDraggableCanceled: (_, __) => widget.onDragEnd(),
                      feedback: Material(
                        color: Colors.transparent,
                        child: _DragChip(
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
                      child: _ItemChip(
                        label: item.name,
                        color: widget.color,
                        onRemove: () => widget.onRemove(item.name),
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

// ─── Drag feedback chip ───────────────────────────────────────────────────────

class _DragChip extends StatelessWidget {
  final String label;
  final Color color;

  const _DragChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
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
          color: ElioColors.navy,
        ),
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
            style: TextStyle(
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
