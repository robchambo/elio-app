import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/elio_models.dart';
import '../../services/firestore_service.dart';
import '../../theme/elio_theme.dart';
import '../scanner/scanner_screen.dart';

// ─────────────────────────────────────────────
// AddScreen
// Vibrant Editorial — pantry addition hub.
// Three colour-blocked action cards (SCAN RECEIPT,
// SNAP PHOTO, MANUAL ENTRY) plus a Recent Additions
// list showing the last items added to the pantry.
//
// Entry points:
//   • SCAN RECEIPT  → ScannerScreen(initialTab: 1)
//   • SNAP PHOTO    → ScannerScreen(initialTab: 0)
//   • MANUAL ENTRY  → _ManualEntrySheet modal
// ─────────────────────────────────────────────

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final FirestoreService _firestore = FirestoreService();

  List<_RecentAddition> _recentAdditions = [];
  bool _loadingRecent = true;

  @override
  void initState() {
    super.initState();
    _loadRecentAdditions();
  }

  Future<void> _loadRecentAdditions() async {
    try {
      final names = await _firestore.getInventoryNames();
      // Show up to 5 most recent names as additions
      final recent = names.take(5).map((name) {
        return _RecentAddition(
          name: name,
          category: _categoryForName(name),
          addedAt: null,
        );
      }).toList();
      if (mounted) setState(() { _recentAdditions = recent; _loadingRecent = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  /// Simple heuristic category label for display.
  String _categoryForName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('bread') || lower.contains('sourdough') || lower.contains('bagel')) return 'Counter';
    if (lower.contains('milk') || lower.contains('cheese') || lower.contains('yogurt') || lower.contains('butter')) return 'Fridge';
    if (lower.contains('apple') || lower.contains('banana') || lower.contains('orange') || lower.contains('lemon')) return 'Counter';
    if (lower.contains('chicken') || lower.contains('beef') || lower.contains('fish') || lower.contains('salmon')) return 'Fridge';
    if (lower.contains('rice') || lower.contains('pasta') || lower.contains('flour') || lower.contains('oil')) return 'Pantry';
    return 'Pantry';
  }

  void _openScanReceipt() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScannerScreen(initialTab: 1)),
    ).then((_) => _loadRecentAdditions());
  }

  void _openSnapPhoto() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScannerScreen(initialTab: 0)),
    ).then((_) => _loadRecentAdditions());
  }

  void _openManualEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManualEntrySheet(
        onItemAdded: (name, tier) async {
          await _firestore.addInventoryItem(name, tier);
          if (mounted) {
            Navigator.of(context).pop();
            _loadRecentAdditions();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$name added to your pantry'),
                backgroundColor: ElioColors.dark,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.scaffold,
      body: Stack(
        children: [
          // ── Decorative blur circles ──────────────────────────────────
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                color: ElioColors.amber.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -40,
            child: Container(
              width: 234,
              height: 234,
              decoration: BoxDecoration(
                color: ElioColors.warmOrange.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // ── Scrollable content ───────────────────────────────────────
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroHeader(),
                      const SizedBox(height: 40),
                      _buildActionCards(),
                      const SizedBox(height: 40),
                      _buildRecentAdditions(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // ── Bottom nav bar ───────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  // ─── Sliver app bar ──────────────────────────────────────────────────────────
  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: ElioColors.cardSurface,
      pinned: true,
      elevation: 0,
      expandedHeight: 0,
      titleSpacing: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 24),
        child: Icon(Icons.menu_rounded, color: ElioColors.dark, size: 22),
      ),
      title: Text(
        'elio',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: ElioColors.heroOrange,
          letterSpacing: -1.2,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Icon(Icons.person_outline_rounded, color: ElioColors.dark, size: 22),
        ),
      ],
    );
  }

  // ─── Hero header ──────────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.plusJakartaSans(
              fontSize: 56,
              fontWeight: FontWeight.w700,
              letterSpacing: -2.8,
              height: 1.1,
            ),
            children: [
              TextSpan(
                text: 'what did you\n',
                style: TextStyle(color: ElioColors.dark),
              ),
              TextSpan(
                text: 'pick up?',
                style: TextStyle(color: ElioColors.heroOrange),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Amber accent bar
        Container(
          width: 96,
          height: 4,
          decoration: BoxDecoration(
            color: ElioColors.amber,
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ],
    );
  }

  // ─── Action cards bento ───────────────────────────────────────────────────────
  Widget _buildActionCards() {
    return Column(
      children: [
        // SCAN RECEIPT — warmOrange tall card
        _buildScanReceiptCard(),
        const SizedBox(height: 16),
        // SNAP PHOTO — amber square card
        _buildSnapPhotoCard(),
        const SizedBox(height: 16),
        // MANUAL ENTRY — cardSurface wide short card
        _buildManualEntryCard(),
      ],
    );
  }

  // ─── SCAN RECEIPT card ────────────────────────────────────────────────────────
  Widget _buildScanReceiptCard() {
    return GestureDetector(
      onTap: _openScanReceipt,
      child: Container(
        width: double.infinity,
        height: 342,
        decoration: BoxDecoration(
          color: ElioColors.warmOrange,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // White blur circle top-right
            Positioned(
              top: -32,
              right: -32,
              child: Container(
                width: 192,
                height: 192,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receipt icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  // Labels
                  Text(
                    'FAST TRACK',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.80),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SCAN RECEIPT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SNAP PHOTO card ──────────────────────────────────────────────────────────
  Widget _buildSnapPhotoCard() {
    return GestureDetector(
      onTap: _openSnapPhoto,
      child: Container(
        width: double.infinity,
        height: 342,
        decoration: BoxDecoration(
          color: ElioColors.amber,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // White rotated square bottom-left
            Positioned(
              bottom: -73,
              left: -73,
              child: Transform.rotate(
                angle: 0.785398, // 45 degrees
                child: Container(
                  width: 160,
                  height: 160,
                  color: Colors.white.withOpacity(0.20),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Camera icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Color(0xFF663C00),
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  // Labels
                  Text(
                    'VISUAL ID',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF663C00).withOpacity(0.80),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SNAP PHOTO',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF663C00),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MANUAL ENTRY card ────────────────────────────────────────────────────────
  Widget _buildManualEntryCard() {
    return GestureDetector(
      onTap: _openManualEntry,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: ElioColors.cardSurface,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Row(
          children: [
            // Edit icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ElioColors.taupe.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.edit_rounded,
                color: ElioColors.taupe,
                size: 26,
              ),
            ),
            const SizedBox(width: 24),
            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRADITIONAL',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ElioColors.dark.withOpacity(0.60),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MANUAL ENTRY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: ElioColors.dark,
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: ElioColors.dark,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Recent Additions section ────────────────────────────────────────────────
  Widget _buildRecentAdditions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Additions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: ElioColors.dark,
              ),
            ),
            Text(
              'VIEW ALL',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ElioColors.heroOrange,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Items
        if (_loadingRecent)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: ElioColors.amber),
            ),
          )
        else if (_recentAdditions.isEmpty)
          _buildEmptyRecentState()
        else
          Column(
            children: _recentAdditions
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildRecentItem(item),
                    ))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildEmptyRecentState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 40, color: ElioColors.taupe.withOpacity(0.40)),
          const SizedBox(height: 12),
          Text(
            'Nothing added yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: ElioColors.dark.withOpacity(0.40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentItem(_RecentAddition item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Icon area
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ElioColors.cardSurface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              _iconForCategory(item.category),
              color: ElioColors.taupe,
              size: 22,
            ),
          ),
          const SizedBox(width: 20),
          // Name and time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: ElioColors.dark,
                  ),
                ),
                Text(
                  'Recently added',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: ElioColors.dark.withOpacity(0.60),
                  ),
                ),
              ],
            ),
          ),
          // Category label
          Text(
            item.category,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: ElioColors.heroOrange,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Fridge': return Icons.kitchen_rounded;
      case 'Counter': return Icons.countertops_rounded;
      default: return Icons.shelves;
    }
  }

  // ─── Bottom nav bar ──────────────────────────────────────────────────────────
  // Vibrant Editorial — cardSurface/blur bottom bar, ADD tab active.
  Widget _buildBottomNav() {
    return Container(
      height: 107,
      decoration: BoxDecoration(
        color: ElioColors.cardSurface.withOpacity(0.90),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF273420).withOpacity(0.06),
            blurRadius: 40,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(icon: Icons.home_outlined, label: 'HOME', active: false,
              onTap: () => Navigator.of(context).pop()),
          _buildNavItem(icon: Icons.shelves, label: 'PANTRY', active: false,
              onTap: () => Navigator.of(context).pop()),
          _buildNavItem(icon: Icons.menu_book_rounded, label: 'RECIPES', active: false,
              onTap: () => Navigator.of(context).pop()),
          _buildNavItemActive(),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: 0.50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: ElioColors.dark, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: ElioColors.dark,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItemActive() {
    return Container(
      decoration: BoxDecoration(
        color: ElioColors.warmOrange,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(
            'ADD',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recent addition data class ───────────────────────────────────────────────

class _RecentAddition {
  final String name;
  final String category;
  final DateTime? addedAt;

  const _RecentAddition({
    required this.name,
    required this.category,
    required this.addedAt,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _ManualEntrySheet
// Modal bottom sheet for typing an item name and choosing a pantry tier.
// ─────────────────────────────────────────────────────────────────────────────

class _ManualEntrySheet extends StatefulWidget {
  final void Function(String name, String tier) onItemAdded;

  const _ManualEntrySheet({required this.onItemAdded});

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final TextEditingController _controller = TextEditingController();
  String _selectedTier = 'perishable';

  static const _tiers = [
    ('Fresh / Perishable', 'perishable'),
    ('Always have', 'alwaysHave'),
    ('Almost always have', 'almostAlwaysHave'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: BoxDecoration(
        color: ElioColors.scaffold,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ElioColors.taupe.withOpacity(0.25),
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Add item',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: ElioColors.dark,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 20),
          // Text field
          TextField(
            controller: _controller,
            autofocus: true,
            style: GoogleFonts.plusJakartaSans(fontSize: 18, color: ElioColors.dark),
            decoration: InputDecoration(
              hintText: 'e.g. Organic kale, sourdough...',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                color: ElioColors.taupe.withOpacity(0.60),
              ),
              filled: true,
              fillColor: ElioColors.cardSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
          const SizedBox(height: 20),
          // Tier selector
          Text(
            'WHERE DOES IT LIVE?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ElioColors.taupe,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _tiers.map((tier) {
              final selected = _selectedTier == tier.$2;
              return GestureDetector(
                onTap: () => setState(() => _selectedTier = tier.$2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? ElioColors.dark : ElioColors.cardSurface,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    tier.$1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : ElioColors.taupe,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Add button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ElioColors.heroOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              onPressed: () {
                final name = _controller.text.trim();
                if (name.isEmpty) return;
                widget.onItemAdded(name, _selectedTier);
              },
              child: Text(
                'Add to pantry',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
