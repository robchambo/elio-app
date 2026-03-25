import 'package:flutter/material.dart';
import '../../models/elio_models.dart';
import '../../models/onboarding_state.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio_progress_bar.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// PantryReviewScreen (Screen 3)
// Design: approachable utility.
// User reviews and adjusts the pre-populated pantry
// from their chosen kitchen preset.
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

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _addItem() {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _items.add(InventoryItem(name: name, tier: _addTier));
      _addController.clear();
    });
  }

  List<InventoryItem> get _alwaysHave => _items.where((i) => i.tier == 'alwaysHave').toList();
  List<InventoryItem> get _almostAlwaysHave => _items.where((i) => i.tier == 'almostAlwaysHave').toList();

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
                    const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: ElioColors.navy),
                    const SizedBox(width: 4),
                    Text('Back', style: ElioText.bodyMedium.copyWith(color: ElioColors.navy)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Your pantry', style: ElioText.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Remove anything you don\'t have. Add anything that\'s missing.',
                style: ElioText.bodyLarge.copyWith(color: ElioColors.textSecondary),
              ),
              const SizedBox(height: 20),

              // ── Inventory list ────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Always have section
                      if (_alwaysHave.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'Always have',
                          subtitle: 'These are your pantry staples.',
                          color: ElioColors.amber,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _alwaysHave.map((item) {
                            final index = _items.indexOf(item);
                            return _ItemChip(
                              label: item.name,
                              onRemove: () => _removeItem(index),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Almost always have section
                      if (_almostAlwaysHave.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'Almost always have',
                          subtitle: 'Things you usually have but might run out of.',
                          color: ElioColors.sky,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _almostAlwaysHave.map((item) {
                            final index = _items.indexOf(item);
                            return _ItemChip(
                              label: item.name,
                              onRemove: () => _removeItem(index),
                              color: ElioColors.sky,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

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
                              textCapitalization: TextCapitalization.sentences,
                              style: GoogleFonts.outfit(fontSize: 15),
                              decoration: const InputDecoration(
                                hintText: 'e.g. Miso paste',
                              ),
                              onSubmitted: (_) => _addItem(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Tier selector
                          DropdownButton<String>(
                            value: _addTier,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 'alwaysHave', child: Text('Always', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'almostAlwaysHave', child: Text('Almost', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (v) => setState(() => _addTier = v ?? 'alwaysHave'),
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
                              child: const Icon(Icons.add, color: Colors.white, size: 22),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _SectionHeader({required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
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
            Text(title, style: ElioText.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
            Text(subtitle, style: ElioText.label.copyWith(color: ElioColors.textSecondary, fontWeight: FontWeight.w400)),
          ],
        ),
      ],
    );
  }
}

class _ItemChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final Color color;

  const _ItemChip({required this.label, required this.onRemove, this.color = ElioColors.amber});

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
            style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color == ElioColors.amber ? ElioColors.navy : ElioColors.navy,
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
