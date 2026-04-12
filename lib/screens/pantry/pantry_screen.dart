import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/firestore_service.dart';
import '../../theme/elio_theme.dart';
import '../add/add_screen.dart';
import '../profile/profile_screen.dart';

// ─────────────────────────────────────────────
// PantryScreen
// Vibrant Editorial — "the kitchen archive."
//
// Three bento-style sections pulled from Firestore:
//   01 / FRESH   → Fridge    (cardSurface, perishable tier)
//   02 / PANTRY  → Dry Goods (amber,       alwaysHave tier)
//   03 / FLAVOR  → Spices    (warmOrange,  almostAlwaysHave tier)
//
// FAB opens AddScreen. "Manage Fridge →" opens
// ProfileScreen (pantry management tab).
// ─────────────────────────────────────────────

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final FirestoreService _firestore = FirestoreService();

  List<Map<String, dynamic>> _fridge = [];    // perishable
  List<Map<String, dynamic>> _dryGoods = [];  // alwaysHave
  List<Map<String, dynamic>> _spices = [];    // almostAlwaysHave
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _firestore.getUserData();
      final items = List<Map<String, dynamic>>.from(
        (data['inventoryWithIds'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
      );
      if (mounted) {
        setState(() {
          _fridge   = items.where((i) => i['tier'] == 'perishable').toList();
          _dryGoods = items.where((i) => i['tier'] == 'alwaysHave').toList();
          _spices   = items.where((i) => i['tier'] == 'almostAlwaysHave').toList();
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.scaffold,
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(64),
                        child: Center(child: CircularProgressIndicator(color: ElioColors.amber)),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 160),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeroHeader(),
                            const SizedBox(height: 48),
                            _buildFridgeCard(),
                            const SizedBox(height: 24),
                            _buildDryGoodsCard(),
                            const SizedBox(height: 24),
                            _buildSpicesCard(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          // Bottom nav bar
          Positioned(
            bottom: 0, left: 0, right: 0,
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
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.menu_rounded, color: ElioColors.dark, size: 22),
        ),
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
          child: const Icon(Icons.person_outline_rounded, color: ElioColors.dark, size: 22),
        ),
      ],
    );
  }

  // ─── FAB ─────────────────────────────────────────────────────────────────────
  Widget _buildFab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: FloatingActionButton(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AddScreen()))
            .then((_) => _loadData()),
        backgroundColor: ElioColors.heroOrange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }

  // ─── Hero header ──────────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'the kitchen\narchive',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 60,
            fontWeight: FontWeight.w700,
            color: ElioColors.dark,
            letterSpacing: -3.0,
            height: 0.85,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: 96,
          height: 6,
          decoration: BoxDecoration(
            color: ElioColors.warmOrange,
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ],
    );
  }

  // ─── 01 / FRESH — Fridge ─────────────────────────────────────────────────────
  // cardSurface card with perishable items.
  Widget _buildFridgeCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ElioColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Geometric decoration top-right: warmOrange circle + amber ring
          Positioned(
            top: -48,
            right: -48,
            child: SizedBox(
              width: 256,
              height: 256,
              child: Stack(
                children: [
                  // Filled warmOrange circle
                  Container(
                    decoration: BoxDecoration(
                      color: ElioColors.warmOrange.withOpacity(0.20),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Amber ring
                  Center(
                    child: Container(
                      width: 192,
                      height: 192,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ElioColors.amber.withOpacity(0.20),
                          width: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section label
                Text(
                  '01 / FRESH',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ElioColors.heroOrange,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fridge',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: ElioColors.dark,
                  ),
                ),
                const SizedBox(height: 24),
                // Items
                if (_fridge.isEmpty)
                  _buildEmptyState('No perishable items yet')
                else
                  Column(
                    children: _fridge
                        .take(4)
                        .map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildFridgeItem(item),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 16),
                // Manage Fridge link
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfileScreen(initialTab: 0)),
                      ).then((_) => _loadData()),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Manage Fridge',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: ElioColors.heroOrange,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 16, color: ElioColors.heroOrange),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFridgeItem(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? '';
    final isLow = item['runningLow'] as bool? ?? false;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF273420).withOpacity(0.08),
            blurRadius: 80,
            spreadRadius: -20,
            offset: const Offset(0, 40),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Icon area
          Container(
            width: 44,
            height: 48,
            decoration: BoxDecoration(
              color: ElioColors.warmOrange.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.eco_rounded,
              color: ElioColors.warmOrange,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          // Name
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: ElioColors.dark,
              ),
            ),
          ),
          // Status badge
          _buildFridgeStatusBadge(isLow),
        ],
      ),
    );
  }

  Widget _buildFridgeStatusBadge(bool isLow) {
    if (isLow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFDAD6),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          'LOW',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF93000A),
            letterSpacing: -0.5,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: ElioColors.cardSurface,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          'FULL',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: ElioColors.taupe,
            letterSpacing: -0.5,
          ),
        ),
      );
    }
  }

  // ─── 02 / PANTRY — Dry Goods ─────────────────────────────────────────────────
  // Amber card with frosted glass item rows.
  Widget _buildDryGoodsCard() {
    final totalItems = _dryGoods.length;
    final displayItems = _dryGoods.take(5).toList();
    // Capacity heuristic: 100% = 20 items
    final capacity = totalItems == 0 ? 0.0 : (totalItems / 20.0).clamp(0.0, 1.0);
    final capacityPct = (capacity * 100).round();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ElioColors.amber,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // White arch shapes bottom decoration
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 128,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildArch(Colors.white.withOpacity(0.12), 114, 96, -32),
                  _buildArch(Colors.white.withOpacity(0.08), 114, 128, -16),
                  _buildArch(Colors.white.withOpacity(0.24), 114, 64, -48),
                ],
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section label
                Opacity(
                  opacity: 0.80,
                  child: Text(
                    '02 / PANTRY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF663C00),
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dry Goods',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF663C00),
                  ),
                ),
                const SizedBox(height: 24),
                // Items
                if (_dryGoods.isEmpty)
                  Opacity(
                    opacity: 0.70,
                    child: Text(
                      'No staples added yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: const Color(0xFF663C00),
                      ),
                    ),
                  )
                else
                  Column(
                    children: displayItems
                        .map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildDryGoodItem(item),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 40),
                // Storage capacity bar
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: capacity,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: 0.80,
                  child: Text(
                    'STORAGE CAPACITY $capacityPct%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: const Color(0xFF663C00),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDryGoodItem(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? '';
    final isLow = item['runningLow'] as bool? ?? false;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
      child: Row(
        children: [
          Icon(Icons.grain_rounded, color: const Color(0xFF663C00), size: 17),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: const Color(0xFF663C00),
              ),
            ),
          ),
          if (isLow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF663C00),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Refill',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ElioColors.amber,
                ),
              ),
            )
          else
            Opacity(
              opacity: 0.60,
              child: Text(
                '—',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF663C00),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArch(Color color, double width, double height, double bottomOffset) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            bottom: bottomOffset,
            left: 0,
            right: 0,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(9999)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 03 / FLAVOR — Spices ────────────────────────────────────────────────────
  // warmOrange card with 2×2 spice card grid.
  Widget _buildSpicesCard() {
    // Dark brick colour used in this section
    const brickColor = Color(0xFF511800);
    final displaySpices = _spices.take(4).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ElioColors.warmOrange,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Diagonal parallelogram decoration right side
          Positioned(
            right: -16,
            top: 0,
            bottom: 0,
            width: 120,
            child: _buildDiagonalOverlay(),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section label
                Opacity(
                  opacity: 0.80,
                  child: Text(
                    '03 / FLAVOR',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: brickColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Spices',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: brickColor,
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: 0.90,
                  child: Text(
                    'Organized by intensity. Your collection is curated for Mediterranean & Asian fusion.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: brickColor,
                      height: 1.625,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // 2×2 spice grid
                if (_spices.isEmpty)
                  Opacity(
                    opacity: 0.70,
                    child: Text(
                      'No spices added yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: brickColor,
                      ),
                    ),
                  )
                else
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.85,
                    children: List.generate(
                      displaySpices.length,
                      (i) => _buildSpiceCard(displaySpices[i], i),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagonalOverlay() {
    return ClipRect(
      child: Transform(
        transform: Matrix4.identity()..setEntry(0, 1, -0.2),
        child: Container(
          color: ElioColors.peach.withOpacity(0.20),
        ),
      ),
    );
  }

  Widget _buildSpiceCard(Map<String, dynamic> item, int index) {
    const brickColor = Color(0xFF511800);
    final name = item['name'] as String? ?? '';
    final isLow = item['runningLow'] as bool? ?? false;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.all(25),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: ElioColors.heroOrange,
              shape: BoxShape.circle,
            ),
            child: Center(child: _buildSpiceIconShape(index)),
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: brickColor,
              height: 1.43,
            ),
          ),
          const SizedBox(height: 6),
          // Status
          if (isLow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: brickColor,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                'Low',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            )
          else
            Opacity(
              opacity: 0.60,
              child: Text(
                'FULL',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: brickColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Alternates between four abstract geometric shapes inside spice icon circles.
  Widget _buildSpiceIconShape(int index) {
    const c = Color(0xFFFFDBCE);
    switch (index % 4) {
      case 0: // Rotated square (diamond)
        return Transform.rotate(
          angle: 0.785,
          child: Container(
            width: 16, height: 16,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
          ),
        );
      case 1: // Horizontal bar
        return Container(
          width: 24, height: 4,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(9999)),
        );
      case 2: // Ring
        return Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c, width: 2),
          ),
        );
      default: // Circle
        return Container(
          width: 16, height: 16,
          decoration: const BoxDecoration(color: c, shape: BoxShape.circle),
        );
    }
  }

  Widget _buildEmptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: ElioColors.taupe.withOpacity(0.60),
        ),
      ),
    );
  }

  // ─── Bottom nav bar ──────────────────────────────────────────────────────────
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
          _buildNavItem(icon: Icons.home_outlined, label: 'HOME',
              onTap: () => Navigator.of(context).pop()),
          _buildNavItemActive(icon: Icons.shelves, label: 'PANTRY'),
          _buildNavItem(icon: Icons.menu_book_rounded, label: 'RECIPES',
              onTap: () => Navigator.of(context).pop()),
          _buildNavItem(icon: Icons.add_circle_outline_rounded, label: 'ADD',
              onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddScreen()),
                  ).then((_) => _loadData())),
        ],
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required VoidCallback onTap}) {
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
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: ElioColors.dark, letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItemActive({required IconData icon, required String label}) {
    return Container(
      decoration: BoxDecoration(
        color: ElioColors.warmOrange,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: Colors.white, letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
