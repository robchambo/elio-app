import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/scanner_service.dart';
import '../../theme/elio_theme.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';

// ─────────────────────────────────────────────
// ScanSuccessScreen
// Confirmation screen shown after items have been
// successfully added to the user's pantry.
// ─────────────────────────────────────────────

class ScanSuccessScreen extends StatelessWidget {
  final List<ScannedItem> items;
  final int perishableCount;
  final int alwaysHaveCount;
  final int almostAlwaysCount;

  const ScanSuccessScreen({
    super.key,
    required this.items,
    required this.perishableCount,
    required this.alwaysHaveCount,
    required this.almostAlwaysCount,
  });

  @override
  Widget build(BuildContext context) {
    final firstPerishable = items
        .where((i) => i.suggestedTier == 'perishable')
        .toList();
    final previewItem = firstPerishable.isNotEmpty ? firstPerishable.first : null;
    final remainingCount = items.length - 1;

    return Scaffold(
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Success checkmark
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: ElioColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 52,
                  color: ElioColors.success,
                ),
              ),
              const SizedBox(height: 24),
              // Heading
              Text(
                '${items.length} item${items.length == 1 ? '' : 's'} added!',
                style: ElioText.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Subtitle breakdown
              Text(
                _buildSubtitle(),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: ElioColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Preview card for first perishable item
              if (previewItem != null) _buildPreviewCard(previewItem),
              // "+ N more items" text
              if (remainingCount > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '+ $remainingCount more item${remainingCount == 1 ? '' : 's'}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: ElioColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(flex: 3),
              // Action buttons
              _buildActionButtons(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (perishableCount > 0) parts.add('$perishableCount perishable');
    if (alwaysHaveCount > 0) parts.add('$alwaysHaveCount always have');
    if (almostAlwaysCount > 0) parts.add('$almostAlwaysCount almost always');
    return parts.join(' \u2022 '); // bullet separator
  }

  Widget _buildPreviewCard(ScannedItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ElioColors.offWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ElioColors.border),
      ),
      child: Row(
        children: [
          // Item icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.kitchen_rounded,
              color: ElioColors.amber,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Name + tier
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ElioColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Perishable',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: ElioColors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Checkmark
          const Icon(Icons.check_rounded, color: ElioColors.success, size: 22),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Generate Recipe button (amber, primary)
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () {
              // Pop to root and push HomeScreen with scanned items for auto-generation
              final perishableNames = items
                  .where((i) => i.suggestedTier == 'perishable')
                  .map((i) => i.name)
                  .toList();
              final allNames = items.map((i) => i.name).toList();
              final itemsToGenerate = perishableNames.isNotEmpty ? perishableNames : allNames;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => HomeScreen(scannedItems: itemsToGenerate)),
                (route) => false,
              );
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: const Text('Generate Recipe with These'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ElioColors.amber,
              foregroundColor: ElioColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Back to Pantry button (outline)
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () {
              // Pop scanner stack and navigate to pantry tab
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen(initialTab: 0)),
              );
            },
            icon: const Icon(Icons.inventory_2_outlined, size: 20),
            label: const Text('Back to Pantry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ElioColors.navy,
              side: const BorderSide(color: ElioColors.navy, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
