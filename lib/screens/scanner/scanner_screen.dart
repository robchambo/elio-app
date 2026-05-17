import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/analytics_service.dart';
import '../../services/firestore_service.dart';
import '../../services/scanner_service.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import 'receipt_results_screen.dart';
import 'scan_success_screen.dart';

// ─────────────────────────────────────────────
// ScannerScreen
// Main scanner UI with tab switcher between
// Barcode (live camera) and Receipt (photo capture).
// Scanned items accumulate in a list and can be
// added to the user's pantry in a single action.
// ─────────────────────────────────────────────

class ScannerScreen extends StatefulWidget {
  /// Which tab to start on: 0 = barcode, 1 = receipt.
  final int initialTab;

  const ScannerScreen({super.key, this.initialTab = 0});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late int _activeTab;
  final List<ScannedItem> _scannedItems = [];
  final Set<String> _scannedBarcodes = {}; // prevent duplicate scans
  bool _isProcessing = false;
  bool _isAddingToPantry = false;
  MobileScannerController? _cameraController;

  // ─── Lifecycle ──────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    if (_activeTab == 0) _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _initCamera() {
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  void _disposeCamera() {
    _cameraController?.dispose();
    _cameraController = null;
  }

  void _switchTab(int index) {
    if (index == _activeTab) return;
    setState(() => _activeTab = index);
    if (index == 0) {
      _initCamera();
    } else {
      _disposeCamera();
    }
  }

  // ─── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Scan Items', style: ElioText.headingLarge),
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildTabSwitcher(),
          Expanded(
            child: SingleChildScrollView(
              child: _activeTab == 0 ? _buildBarcodeTab() : _buildReceiptTab(),
            ),
          ),
          _buildAddButton(),
        ],
      ),
    );
  }

  // ─── Tab Switcher ───────────────────────────────────────────────

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: ElioColors.cream,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildTab('Barcode', 0),
            _buildTab('Receipt', 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive ? ElioColors.cream : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: ElioTextStyles.uiLabelStyle.copyWith(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? ElioColors.espresso : ElioColors.mocha,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Barcode Tab ────────────────────────────────────────────────

  Widget _buildBarcodeTab() {
    return Column(
      children: [
        // Camera viewfinder
        SizedBox(
          height: 280,
          child: Stack(
            children: [
              Container(color: Colors.black),
              if (_cameraController != null)
                ClipRRect(
                  child: MobileScanner(
                    controller: _cameraController!,
                    onDetect: _onBarcodeDetected,
                  ),
                ),
              _buildScanOverlay(),
              _buildFlashButton(),
              _buildHintText('Point at a product barcode'),
              if (_isProcessing) _buildProcessingIndicator(),
            ],
          ),
        ),
        // Scanned items list
        if (_scannedItems.isNotEmpty) _buildScannedItemsList(),
      ],
    );
  }

  /// Amber corner brackets overlay for the scan region.
  Widget _buildScanOverlay() {
    return Center(
      child: SizedBox(
        width: 220,
        height: 140,
        child: CustomPaint(painter: _ScanFramePainter()),
      ),
    );
  }

  bool _torchOn = false;

  Widget _buildFlashButton() {
    return Positioned(
      top: 12,
      right: 12,
      child: Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          icon: Icon(
            _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            color: Colors.white,
            size: 22,
          ),
          onPressed: () {
            _cameraController?.toggleTorch();
            setState(() => _torchOn = !_torchOn);
          },
        ),
      ),
    );
  }

  Widget _buildHintText(String text) {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: ElioTextStyles.bodySmallStyle.copyWith(
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Positioned.fill(
      child: Container(
        color: Colors.black26,
        child: const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: ElioColors.terracotta,
              strokeWidth: 3,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Barcode Detection ──────────────────────────────────────────

  void _onBarcodeDetected(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || _scannedBarcodes.contains(barcode) || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _scannedBarcodes.add(barcode);
    });

    try {
      final item = await ScannerService.instance.lookupBarcode(barcode);
      if (item != null && mounted) {
        setState(() {
          _scannedItems.add(item);
          _isProcessing = false;
        });
        HapticFeedback.mediumImpact();
      } else {
        // Product not found
        if (mounted) {
          setState(() => _isProcessing = false);
          _scannedBarcodes.remove(barcode); // allow re-scan
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product not found for barcode $barcode'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── Receipt Tab ────────────────────────────────────────────────

  Widget _buildReceiptTab() {
    return Column(
      children: [
        // Visual area with receipt icon
        Container(
          height: 320,
          width: double.infinity,
          color: const Color(0xFF111111),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_rounded, size: 56, color: Colors.white54),
                const SizedBox(height: 12),
                Text(
                  'Capture your receipt',
                  style: ElioTextStyles.sectionHeadingStyle.copyWith(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Hold steady — we'll extract the items",
                  style: ElioTextStyles.bodySmallStyle.copyWith(
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tip: Lay receipt flat for best results',
                  style: ElioTextStyles.eyebrowStyle.copyWith(
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Receipt quality varies — Elio may not extract every item. You can always add missing items manually.',
                    textAlign: TextAlign.center,
                    style: ElioTextStyles.tabLabelStyle.copyWith(
                      color: Colors.white24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _amberButton(
                  'Camera',
                  Icons.camera_alt_rounded,
                  _captureReceipt,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _outlineButton(
                  'Gallery',
                  Icons.photo_library_rounded,
                  _pickFromGallery,
                ),
              ),
            ],
          ),
        ),
        // Loading indicator when processing
        if (_isProcessing)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircularProgressIndicator(color: ElioColors.terracotta),
                const SizedBox(height: 12),
                Text('Analysing receipt...', style: ElioText.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }

  // 17 May 2026: height 50 → 56 + `maxLines: 1` on the label so
  // glyph descenders don't clip vertically and long labels don't
  // wrap to a second clipped line. Mirrors the recipe_import_screen
  // fix in 3892d9b.
  Widget _amberButton(String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          backgroundColor: ElioColors.terracotta,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: ElioTextStyles.uiLabelStyle.copyWith(fontSize: 15),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _outlineButton(String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _isProcessing ? null : onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: ElioColors.espresso,
          side: const BorderSide(color: ElioColors.rule, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: ElioTextStyles.uiLabelStyle.copyWith(fontSize: 14),
        ),
      ),
    );
  }

  // ─── Receipt Capture ────────────────────────────────────────────

  Future<void> _captureReceipt() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (image == null) return;
    await _processReceiptImage(await image.readAsBytes());
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (image == null) return;
    await _processReceiptImage(await image.readAsBytes());
  }

  Future<void> _processReceiptImage(Uint8List bytes) async {
    setState(() => _isProcessing = true);
    try {
      final result = await ScannerService.instance.scanReceipt(bytes);
      if (mounted) {
        // Navigate to receipt results screen for user confirmation
        final confirmed = await Navigator.of(context).push<List<ScannedItem>>(
          MaterialPageRoute(
            builder: (_) => ReceiptResultsScreen(result: result),
          ),
        );
        if (confirmed != null && confirmed.isNotEmpty) {
          setState(() => _scannedItems.addAll(confirmed));
        }
      }
    } catch (e) {
      if (mounted) {
        // Sprint 16.1: explicit duration so error toast doesn't follow
        // the user across navigation.
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Could not read receipt. Try again with better lighting.'),
            backgroundColor: ElioColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── Scanned Items List ─────────────────────────────────────────

  Widget _buildScannedItemsList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Scanned (${_scannedItems.length})',
                style: ElioText.headingMedium,
              ),
              GestureDetector(
                onTap: _editAllItems,
                child: Text(
                  'Edit all',
                  style: ElioTextStyles.uiLabelStyle.copyWith(
                    fontSize: 14,
                    color: ElioColors.terracotta,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Items
          ...List.generate(_scannedItems.length, (index) {
            final item = _scannedItems[index];
            return Dismissible(
              key: ValueKey('${item.name}_$index'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: ElioColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: ElioColors.error),
              ),
              onDismissed: (_) => setState(() => _scannedItems.removeAt(index)),
              child: _buildScannedItemTile(item, index),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScannedItemTile(ScannedItem item, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: item.isNonFood ? ElioColors.cream.withValues(alpha: 0.5) : ElioColors.cream,
        border: Border(bottom: BorderSide(color: ElioColors.rule.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          // Item name + brand
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: ElioTextStyles.uiLabelStyle.copyWith(
                    fontSize: 15,
                    color: item.isNonFood ? ElioColors.mocha : ElioColors.espresso,
                    decoration: item.isNonFood ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (item.brand != null && item.brand!.isNotEmpty)
                  Text(
                    item.brand!,
                    style: ElioTextStyles.bodySmallStyle.copyWith(
                      color: ElioColors.mocha,
                    ),
                  ),
              ],
            ),
          ),
          // Tier badge — tappable to cycle
          if (!item.isNonFood)
            GestureDetector(
              onTap: () => _cycleTier(index),
              child: _buildTierBadge(item.suggestedTier),
            ),
        ],
      ),
    );
  }

  Widget _buildTierBadge(String tier) {
    final (Color bg, Color fg, String label) = switch (tier) {
      'alwaysHave' => (const Color(0xFFE8F5E9), ElioColors.success, 'Always Have'),
      'almostAlways' => (const Color(0xFFE3F2FD), ElioColors.mocha, 'Almost Always'),
      'perishable' => (const Color(0xFFFFF3E0), ElioColors.terracotta, 'Perishable'),
      _ => (ElioColors.cream, ElioColors.mocha, tier),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: ElioTextStyles.tabLabelStyle.copyWith(
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  void _cycleTier(int index) {
    const tiers = ['perishable', 'alwaysHave', 'almostAlways'];
    final item = _scannedItems[index];
    final current = tiers.indexOf(item.suggestedTier);
    final next = (current + 1) % tiers.length;
    setState(() {
      _scannedItems[index] = item.copyWith(suggestedTier: tiers[next]);
    });
    HapticFeedback.selectionClick();
  }

  void _editAllItems() {
    // Cycle all items to the next tier together (batch edit)
    if (_scannedItems.isEmpty) return;
    const tiers = ['perishable', 'alwaysHave', 'almostAlways'];
    final firstTier = _scannedItems.first.suggestedTier;
    final current = tiers.indexOf(firstTier);
    final next = (current + 1) % tiers.length;
    setState(() {
      for (int i = 0; i < _scannedItems.length; i++) {
        if (!_scannedItems[i].isNonFood) {
          _scannedItems[i] = _scannedItems[i].copyWith(suggestedTier: tiers[next]);
        }
      }
    });
  }

  // ─── Add to Pantry Button ───────────────────────────────────────

  Widget _buildAddButton() {
    if (_scannedItems.isEmpty) return const SizedBox.shrink();
    final foodItems = _scannedItems.where((i) => !i.isNonFood).toList();
    if (foodItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isAddingToPantry ? null : () => _addToPantry(foodItems),
            style: ElevatedButton.styleFrom(
              backgroundColor: ElioColors.terracotta,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isAddingToPantry
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Add ${foodItems.length} Item${foodItems.length == 1 ? '' : 's'} to Pantry',
                    style: ElioTextStyles.uiLabelStyle.copyWith(
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ─── Add to Pantry Logic ────────────────────────────────────────

  /// Convert a preset expiry label (e.g. "3 days", "1 week") into a concrete
  /// [DateTime]. Returns null when the label is missing, "No expiry", or
  /// unrecognised.
  DateTime? _expiryDateFromLabel(String? label) {
    if (label == null || label.isEmpty) return null;
    final now = DateTime.now();
    switch (label) {
      case '3 days':
        return now.add(const Duration(days: 3));
      case '1 week':
        return now.add(const Duration(days: 7));
      case '2 weeks':
        return now.add(const Duration(days: 14));
      default:
        return null;
    }
  }

  Future<void> _addToPantry(List<ScannedItem> items) async {
    setState(() => _isAddingToPantry = true);
    final firestore = FirestoreService();
    final scanner = ScannerService.instance;

    int perishableCount = 0;
    int alwaysHaveCount = 0;
    int almostAlwaysCount = 0;

    try {
      for (final item in items) {
        // Save tier memory for future scans
        await scanner.saveTierMemory(item.name, item.suggestedTier);

        // Convert expiry preset label into a concrete DateTime.
        final expiryDate = _expiryDateFromLabel(item.expiryLabel);

        // Add to the appropriate inventory tier
        await firestore.addInventoryItem(
          item.name,
          item.suggestedTier,
          expiryDate: expiryDate,
          price: item.price,
        );

        switch (item.suggestedTier) {
          case 'perishable':
            perishableCount++;
          case 'alwaysHave':
            alwaysHaveCount++;
          case 'almostAlways':
            almostAlwaysCount++;
        }
      }

      if (mounted) {
        AnalyticsService.instance.logEvent('scan_items_added', {
          'count': items.length,
          'perishable': perishableCount,
          'always_have': alwaysHaveCount,
          'almost_always': almostAlwaysCount,
          'source': _activeTab == 0 ? 'barcode' : 'receipt',
        });

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ScanSuccessScreen(
              items: items,
              perishableCount: perishableCount,
              alwaysHaveCount: alwaysHaveCount,
              almostAlwaysCount: almostAlwaysCount,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Sprint 16.1: explicit duration so error toast doesn't follow
        // the user across navigation.
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Failed to add items. Please try again.'),
            backgroundColor: ElioColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToPantry = false);
    }
  }
}

// ─── Scan Frame Overlay Painter ──────────────────────────────────
// Draws amber corner brackets over the camera viewfinder.

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ElioColors.terracotta
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;

    // Top-left corner
    canvas.drawLine(Offset.zero, const Offset(cornerLen, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, cornerLen), paint);

    // Top-right corner
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLen, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLen), paint);

    // Bottom-left corner
    canvas.drawLine(Offset(0, size.height), Offset(cornerLen, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLen), paint);

    // Bottom-right corner
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLen, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLen),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
