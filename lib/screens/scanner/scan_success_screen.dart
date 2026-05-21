import 'package:flutter/material.dart';

import '../../services/scanner_service.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';

// ─────────────────────────────────────────────
// ScanSuccessScreen
// Confirmation screen shown after items have been
// successfully added to the user's pantry.
//
// 19 May 2026 — both CTAs used to push naked PantryScreen / HomeScreen
// onto the Navigator via MaterialPageRoute. Both screens are tab body
// widgets that depend on AppShell's Scaffold (cream background, top
// app bar, bottom nav). Pushed in isolation they rendered with no
// Material chrome — the default Scaffold-less background is black —
// which gave the "black background with stark yellow underlines"
// screen Rob caught on 19may-b. Both CTAs now just popUntil the
// Navigator's root, returning the user to AppShell with whatever tab
// they were on (Pantry tab, in the receipt-scan flow).
//
// Generate-with-these-items auto-generation is lost here as a side
// effect. Restoring it requires threading scannedItems into AppShell's
// HomeScreen — Sprint 17 follow-up.
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
      backgroundColor: ElioColors.cream,
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
                style: ElioTextStyles.bodySmallStyle.copyWith(
                  color: ElioColors.mocha,
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
                  style: ElioTextStyles.bodySmallStyle.copyWith(
                    color: ElioColors.mocha,
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
        color: ElioColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ElioColors.rule),
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
              color: ElioColors.terracotta,
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
                  style: ElioTextStyles.uiLabelStyle.copyWith(
                    fontSize: 15,
                    color: ElioColors.espresso,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Perishable',
                  style: ElioTextStyles.bodySmallStyle.copyWith(
                    color: ElioColors.terracotta,
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
              // 19 May 2026 — used to `pushAndRemoveUntil` a naked
              // HomeScreen with `scannedItems`. HomeScreen is an
              // AppShell tab body (no own Scaffold) so it rendered
              // chrome-less on a black background. Pop to root
              // instead; the auto-generation feature is the casualty
              // — restore via an AppShell `initialScannedItems`
              // mechanism in Sprint 17.
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: const Text('Generate Recipe with These'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ElioColors.terracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: ElioTextStyles.uiLabelStyle,
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
              // 19 May 2026 — used to popUntil-first then push a naked
              // PantryScreen, which renders chrome-less on a black
              // background (no AppShell Scaffold). The user reached
              // this flow from the Pantry tab, so popping to root
              // lands them there with no extra navigation needed.
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.inventory_2_outlined, size: 20),
            label: const Text('Back to Pantry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ElioColors.espresso,
              side: const BorderSide(color: ElioColors.espresso, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: ElioTextStyles.uiLabelStyle,
            ),
          ),
        ),
      ],
    );
  }
}
