import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/elio_theme.dart';
import '../../models/elio_models.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../utils/pantry_utils.dart';
import '../../data/pantry_categories.dart';
import '../../widgets/pantry_builder_sheet.dart';
import '../onboarding/screen0_welcome.dart';
import '../../services/analytics_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/history_service.dart';
import '../../services/shopping_service.dart';
import '../../utils/aisle_utils.dart';
import '../../models/recipe_models.dart';
import '../recipe/recipe_screen.dart';
import 'notification_prefs_screen.dart';
import 'settings_screen.dart';
import '../scanner/scanner_screen.dart';
import 'recipe_import_screen.dart';
import '../paywall/paywall_screen.dart';

// ─────────────────────────────────────────────
// ProfileScreen
// Design philosophy: approachable utility.
// Tabs: Pantry (drag-to-move tiers, running-low) | Dietary & Allergens | Household | Style
// ─────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  final int initialTab;
  const ProfileScreen({super.key, this.initialTab = 0});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestore = FirestoreService();
  final AnalyticsService _analytics = AnalyticsService.instance;
  late TabController _tabController;

  // ── Dev override: emails allowed to self-grant Pro ─────────────────
  static const Set<String> _proOverrideAllowlist = {
    'info.autex@gmail.com',
    'kate.d.r.taylor@gmail.com',
  };

  bool _isLoading = true;

  // ── Pantry state ───────────────────────────────────────────────────
  List<Map<String, dynamic>> _inventoryItems = [];
  final Set<String> _collapsedTiers = {}; // tracks which tiers are collapsed
  // Pantry items are always displayed grouped by category

  // ── Style preferences ──────────────────────────────────────────────
  List<String> _stylePreferences = [];

  // ── Shopping list ──────────────────────────────────────────────────
  List<PersistentShoppingItem> _shoppingItems = [];
  bool _shoppingLoading = true;
  final TextEditingController _shoppingAddController = TextEditingController();

  // ── Available options ──────────────────────────────────────────────
  static const List<String> _cuisineOptions = [
    'Italian', 'Mediterranean', 'Asian', 'Chinese', 'Japanese', 'Thai',
    'Korean', 'Indian', 'Middle Eastern', 'Mexican', 'American', 'Southern',
    'French', 'Caribbean',
  ];

  static const List<String> _styleOptions = [
    'Comfort food', 'Light & healthy', 'Quick & easy', 'High protein',
    'Vegetable-forward', 'Budget-friendly', 'One-pot',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
    _loadData();
    _loadShoppingItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shoppingAddController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final data = await _firestore.getUserData();
      if (!mounted) return;
      setState(() {
        _inventoryItems = List<Map<String, dynamic>>.from(
          (data['inventoryWithIds'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        _stylePreferences = List<String>.from(data['stylePreferences'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Shopping list loading ───────────────────────────────────────────
  Future<void> _loadShoppingItems() async {
    try {
      // One-time cleanup: remove residual staples (water, salt, etc.)
      // that were added before staple filtering existed.
      await ShoppingService.instance.purgeStaples();
      final items = await ShoppingService.instance.loadItems();
      if (!mounted) return;
      setState(() {
        _shoppingItems = items;
        _shoppingLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _shoppingLoading = false);
    }
  }

  // ── Pro override helper ────────────────────────────────────────────

  Future<void> _onProOverrideLongPress(String email) async {
    if (!_proOverrideAllowlist.contains(email)) return;

    final entitlements = EntitlementService.instance;
    await entitlements.refresh();
    final isCurrentlyPro = entitlements.isPro;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Dev: Pro Override'),
        content: Text(
          isCurrentlyPro
              ? 'Pro access is currently active. Revoke it?'
              : 'Grant Pro access to this account without billing?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (isCurrentlyPro) {
                await _firestore.revokeProAccess();
              } else {
                await _firestore.grantProAccess();
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isCurrentlyPro ? 'Pro access revoked.' : 'Pro access granted!'),
                    backgroundColor: ElioColors.navy,
                  ),
                );
              }
            },
            child: Text(isCurrentlyPro ? 'Revoke' : 'Grant Pro'),
          ),
        ],
      ),
    );
  }

  // ── Pantry helpers ─────────────────────────────────────────────────

  List<Map<String, dynamic>> get _alwaysHaveItems =>
      _inventoryItems.where((i) => i['tier'] == 'alwaysHave').toList();

  List<Map<String, dynamic>> get _almostAlwaysHaveItems =>
      _inventoryItems.where((i) => i['tier'] == 'almostAlwaysHave').toList();

  List<Map<String, dynamic>> get _perishableItems {
    final items = _inventoryItems.where((i) => i['tier'] == 'perishable').toList();
    items.sort((a, b) {
      final aExpiry = a['expiryDate'] as String?;
      final bExpiry = b['expiryDate'] as String?;
      if (aExpiry == null && bExpiry == null) return 0;
      if (aExpiry == null) return 1;
      if (bExpiry == null) return -1;
      final aDate = DateTime.tryParse(aExpiry);
      final bDate = DateTime.tryParse(bExpiry);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return items;
  }

  Future<void> _moveItemToTier(String itemId, String newTier) async {
    final idx = _inventoryItems.indexWhere((i) => i['id'] == itemId);
    if (idx == -1) return;
    final oldTier = _inventoryItems[idx]['tier'] as String;
    if (oldTier == newTier) return;
    setState(() => _inventoryItems[idx]['tier'] = newTier);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('inventory')
          .doc(itemId)
          .update({'tier': newTier});
    } catch (_) {
      if (mounted) {
        setState(() => _inventoryItems[idx]['tier'] = oldTier);
        _showSnack('Could not move item. Please try again.');
      }
    }
  }

  Future<void> _toggleRunningLow(String itemId, bool current) async {
    final newValue = !current;
    final idx = _inventoryItems.indexWhere((i) => i['id'] == itemId);
    final itemName = idx != -1 ? (_inventoryItems[idx]['name'] as String? ?? '') : '';
    setState(() {
      if (idx != -1) _inventoryItems[idx]['runningLow'] = newValue;
    });
    if (newValue) {
      _analytics.logEvent('pantry_item_running_low');
    }
    try {
      await _firestore.toggleRunningLow(itemId, newValue);
      // Sync with persistent shopping list
      if (itemName.isNotEmpty) {
        if (newValue) {
          await ShoppingService.instance.addRestockItem(itemName);
        } else {
          await ShoppingService.instance.removeRestockItem(itemName);
        }
        // Refresh shopping items if we're on that tab
        _loadShoppingItems();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final i = _inventoryItems.indexWhere((i) => i['id'] == itemId);
          if (i != -1) _inventoryItems[i]['runningLow'] = current;
        });
      }
    }
  }

  Future<void> _deleteInventoryItem(String itemId) async {
    final removed = _inventoryItems.firstWhere((i) => i['id'] == itemId, orElse: () => {});
    setState(() => _inventoryItems.removeWhere((i) => i['id'] == itemId));
    try {
      await _firestore.deleteInventoryItem(itemId);
    } catch (_) {
      if (mounted && removed.isNotEmpty) {
        setState(() => _inventoryItems.add(removed));
        _showSnack('Could not remove item. Please try again.');
      }
    }
  }

  Future<void> _addInventoryItem(String name, String tier, {String? category}) async {
    if (name.trim().isEmpty) return;

    // Check for fuzzy duplicates against existing inventory
    final existingNames = _inventoryItems
        .map((item) => item['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    final duplicates = PantryUtils.findDuplicates(name.trim(), existingNames);
    if (duplicates.isNotEmpty && mounted) {
      final addAnyway = await PantryUtils.showDuplicateWarning(
        context,
        name.trim(),
        duplicates,
      );
      if (!addAnyway) return;
    }

    // Auto-categorize if no category provided
    final resolvedCategory = category ?? PantryCategories.categorize(name.trim());

    try {
      final id = await _firestore.addInventoryItem(name.trim(), tier, category: resolvedCategory);
      if (mounted) {
        setState(() => _inventoryItems.add({
          'id': id,
          'name': name.trim(),
          'tier': tier,
          'runningLow': false,
          if (resolvedCategory != null) 'category': resolvedCategory,
        }));
        _analytics.logEvent('pantry_item_added', {'tier': tier});
      }
    } catch (_) {
      _showSnack('Could not add item. Please try again.');
    }
  }

  Future<void> _addPerishableItem(String name, {DateTime? expiryDate}) async {
    if (name.trim().isEmpty) return;
    final existingNames = _inventoryItems
        .map((item) => item['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    final duplicates = PantryUtils.findDuplicates(name.trim(), existingNames);
    if (duplicates.isNotEmpty && mounted) {
      final addAnyway = await PantryUtils.showDuplicateWarning(context, name.trim(), duplicates);
      if (!addAnyway) return;
    }
    try {
      final id = await _firestore.addInventoryItem(name.trim(), 'perishable', expiryDate: expiryDate);
      if (mounted) {
        setState(() => _inventoryItems.add({
          'id': id,
          'name': name.trim(),
          'tier': 'perishable',
          'runningLow': false,
          if (expiryDate != null) 'expiryDate': expiryDate.toIso8601String(),
        }));
        _analytics.logEvent('pantry_item_added', {'tier': 'perishable', 'has_expiry': expiryDate != null});
      }
    } catch (_) {
      _showSnack('Could not add item. Please try again.');
    }
  }

  // ── Style helpers ──────────────────────────────────────────────────

  Future<void> _toggleStyle(String style) async {
    final updated = List<String>.from(_stylePreferences);
    if (updated.contains(style)) {
      updated.remove(style);
    } else {
      updated.add(style);
    }
    setState(() => _stylePreferences = updated);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'stylePreferences': updated});
    } catch (_) {
      _showSnack('Could not save style change. Please try again.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Sign out ───────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign out?', style: ElioText.headingMedium),
        content: Text(
          'You will need to sign in again to access your recipes and meal plans.',
          style: ElioText.bodyMedium,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out', style: TextStyle(color: ElioColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Your Profile';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back_ios_new, size: 20, color: ElioColors.navy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: ElioText.headingLarge),
                        if (email.isNotEmpty)
                          GestureDetector(
                            onLongPress: () => _onProOverrideLongPress(email),
                            child: Text(email, style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary)),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ElioColors.offWhite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ElioColors.border),
                      ),
                      child: const Icon(Icons.settings_outlined, size: 18, color: ElioColors.navy),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationPrefsScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ElioColors.offWhite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ElioColors.border),
                      ),
                      child: const Icon(Icons.notifications_outlined, size: 18, color: ElioColors.navy),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _signOut,
                    child: Text('Sign out', style: ElioText.label.copyWith(color: ElioColors.error)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── Tabs ─────────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              labelColor: ElioColors.navy,
              unselectedLabelColor: ElioColors.textMuted,
              indicatorColor: ElioColors.amber,
              indicatorWeight: 2.5,
              labelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w400),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Pantry'),
                Tab(text: 'Recipe Book'),
                Tab(text: 'Style'),
                Tab(text: 'Shopping'),
              ],
            ),
            const Divider(height: 1),
            // ── Tab content ──────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: ElioColors.amber))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPantryTab(),
                        _buildRecipeBookTab(),
                        _buildStyleTab(),
                        _buildShoppingTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Pantry tab ───────────────────────────────────────────────────────────────
  Widget _buildPantryTab() {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user?.isAnonymous ?? true;

    if (isGuest || _inventoryItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.kitchen_outlined, size: 56, color: ElioColors.textMuted),
              const SizedBox(height: 16),
              Text('Your pantry is empty', style: ElioText.headingMedium),
              const SizedBox(height: 8),
              Text(
                'Add your kitchen staples so Elio can generate recipes from what you have.',
                textAlign: TextAlign.center,
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
              if (!isGuest) ...[
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _openPantryBuilder,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    decoration: BoxDecoration(
                      color: ElioColors.navy,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.construction_rounded, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Pantry Builder',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your pantry', style: ElioText.headingMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Long-press to move items. Tap warning to flag low.',
                    style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ── Scan buttons + Pantry Builder ─────────────────────
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScannerScreen(initialTab: 1)),
                ).then((_) => _loadData()),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8EE),
                    border: Border.all(color: ElioColors.amber, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 26, color: ElioColors.amber),
                      const SizedBox(height: 4),
                      Text('Scan Receipt', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: ElioColors.navy)),
                      Text('Photo or camera', style: GoogleFonts.quicksand(fontSize: 11, color: ElioColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScannerScreen(initialTab: 0)),
                ).then((_) => _loadData()),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: ElioColors.offWhite,
                    border: Border.all(color: ElioColors.border, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, size: 26, color: ElioColors.navy),
                      const SizedBox(height: 4),
                      Text('Scan Barcode', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: ElioColors.navy)),
                      Text('Product lookup', style: GoogleFonts.quicksand(fontSize: 11, color: ElioColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ── Pantry Builder button ────────────────────────────
        GestureDetector(
          onTap: _openPantryBuilder,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: ElioColors.navy,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.construction_rounded, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Pantry Builder',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Browse & add by category',
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildPerishableSection(),
        const SizedBox(height: 24),
        _buildTierSection(
          title: 'Always Have',
          subtitle: 'Staples you always keep stocked',
          items: _alwaysHaveItems,
          tier: 'alwaysHave',
          icon: Icons.inventory_2_outlined,
          color: ElioColors.amber,
        ),
        const SizedBox(height: 24),
        _buildTierSection(
          title: 'Almost Always Have',
          subtitle: 'Items you usually have but sometimes run out of',
          items: _almostAlwaysHaveItems,
          tier: 'almostAlwaysHave',
          icon: Icons.kitchen_outlined,
          color: ElioColors.sky,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _openPantryBuilder() {
    final existingNames = _inventoryItems
        .map((item) => item['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PantryBuilderSheet(
        existingItemNames: existingNames,
        onAddItem: (name, tier, category) async {
          await _addInventoryItem(name, tier, category: category);
        },
        onRemoveItem: (name) async {
          // Find and remove the item by name
          final idx = _inventoryItems.indexWhere(
            (i) => (i['name'] as String? ?? '').toLowerCase() == name.toLowerCase(),
          );
          if (idx != -1) {
            final itemId = _inventoryItems[idx]['id'] as String;
            await _deleteInventoryItem(itemId);
          }
        },
      ),
    );
  }

  /// Shows a bottom sheet with move/delete options for the given inventory item.
  void _showItemMoveMenu(Map<String, dynamic> item) {
    HapticFeedback.selectionClick();
    final itemId = item['id'] as String;
    final itemName = item['name'] as String? ?? '';
    final currentTier = item['tier'] as String? ?? 'alwaysHave';

    String tierLabel(String t) {
      switch (t) {
        case 'alwaysHave': return 'Always Have';
        case 'almostAlwaysHave': return 'Almost Always Have';
        case 'perishable': return 'Perishables';
        default: return t;
      }
    }

    final allTiers = ['alwaysHave', 'almostAlwaysHave', 'perishable'];
    final otherTiers = allTiers.where((t) => t != currentTier).toList();

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
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: ElioColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(itemName, style: ElioText.headingMedium),
              const SizedBox(height: 4),
              Text(
                'Currently in: ${tierLabel(currentTier)}',
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ...otherTiers.map((t) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: ElioColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_vert_rounded, color: ElioColors.navy, size: 20),
                ),
                title: Text(
                  'Move to "${tierLabel(t)}"',
                  style: ElioText.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _moveItemToTier(itemId, t);
                },
              )),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40, height: 40,
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
                  _deleteInventoryItem(itemId);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Edit item name ─────────────────────────────────────────────────────────
  void _showEditNameDialog(Map<String, dynamic> item) {
    final itemId = item['id'] as String;
    final currentName = item['name'] as String? ?? '';
    final tier = item['tier'] as String? ?? '';
    final isPerishable = tier == 'perishable';
    final rawExpiry = item['expiryDate'] as String?;
    final currentExpiry = rawExpiry != null ? DateTime.tryParse(rawExpiry) : null;

    final controller = TextEditingController(text: currentName);
    controller.selection = TextSelection(baseOffset: 0, extentOffset: currentName.length);

    // Determine which preset is closest to the current expiry, if any.
    // null = no selection yet (no change), 'none' = explicitly No expiry, int = days
    Object? selectedPreset;
    if (isPerishable && currentExpiry != null) {
      final daysAway = currentExpiry.difference(DateTime.now()).inDays;
      const presets = [3, 7, 14];
      int closest = presets.first;
      int bestDiff = (daysAway - closest).abs();
      for (final p in presets) {
        final d = (daysAway - p).abs();
        if (d < bestDiff) {
          bestDiff = d;
          closest = p;
        }
      }
      selectedPreset = closest;
    } else if (isPerishable && currentExpiry == null) {
      selectedPreset = 'none';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isPerishable ? 'Edit item' : 'Edit item name',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ElioColors.navy,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.outfit(fontSize: 16, color: ElioColors.navy),
                decoration: InputDecoration(
                  hintText: 'Item name',
                  hintStyle: GoogleFonts.outfit(color: ElioColors.textMuted),
                  filled: true,
                  fillColor: ElioColors.offWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ElioColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ElioColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ElioColors.amber, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              if (isPerishable) ...[
                const SizedBox(height: 14),
                Text(
                  'Expiry',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ElioColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _editExpiryChip('3 days', 3, selectedPreset, () => setLocalState(() => selectedPreset = 3)),
                    _editExpiryChip('1 week', 7, selectedPreset, () => setLocalState(() => selectedPreset = 7)),
                    _editExpiryChip('2 weeks', 14, selectedPreset, () => setLocalState(() => selectedPreset = 14)),
                    _editExpiryChip('No expiry', null, selectedPreset, () => setLocalState(() => selectedPreset = 'none')),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: ElioColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isEmpty) return;

                DateTime? newExpiry;
                bool clearExpiry = false;
                if (isPerishable) {
                  if (selectedPreset == 'none') {
                    if (currentExpiry != null) clearExpiry = true;
                  } else if (selectedPreset is int) {
                    final days = selectedPreset as int;
                    final candidate = DateTime.now().add(Duration(days: days));
                    // Only treat as a change if the user picked something different
                    // from the closest preset to the existing expiry.
                    if (currentExpiry == null) {
                      newExpiry = candidate;
                    } else {
                      final daysAway = currentExpiry.difference(DateTime.now()).inDays;
                      if ((daysAway - days).abs() > 0) {
                        newExpiry = candidate;
                      }
                    }
                  }
                }

                final nameChanged = newName != currentName;
                if (!nameChanged && newExpiry == null && !clearExpiry) {
                  Navigator.pop(ctx);
                  return;
                }

                Navigator.pop(ctx);
                _updateItem(
                  itemId,
                  name: nameChanged ? newName : null,
                  expiryDate: newExpiry,
                  clearExpiry: clearExpiry,
                );
              },
              child: Text(
                'Save',
                style: GoogleFonts.outfit(color: ElioColors.amber, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editExpiryChip(String label, int? days, Object? selectedPreset, VoidCallback onTap) {
    final isSelected = (days == null && selectedPreset == 'none') ||
        (days != null && selectedPreset is int && selectedPreset == days);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ElioColors.amber : ElioColors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? ElioColors.amber : ElioColors.amber.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : ElioColors.amber,
          ),
        ),
      ),
    );
  }

  Future<void> _updateItem(
    String itemId, {
    String? name,
    DateTime? expiryDate,
    bool clearExpiry = false,
  }) async {
    await _firestore.updateInventoryItem(
      itemId,
      name: name,
      expiryDate: expiryDate,
      clearExpiry: clearExpiry,
    );
    await _loadData();
  }

  // ─── Perishable section ────────────────────────────────────────────────────
  Widget _buildPerishableSection() {
    final items = _perishableItems;
    final isCollapsed = _collapsedTiers.contains('perishable');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ElioColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() {
              if (isCollapsed) {
                _collapsedTiers.remove('perishable');
              } else {
                _collapsedTiers.add('perishable');
              }
            }),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                const Icon(Icons.kitchen_rounded, size: 16, color: Color(0xFF3D9970)),
                const SizedBox(width: 6),
                Text('Perishables', style: ElioText.headingMedium),
                const SizedBox(width: 6),
                Text(
                  '(${items.length})',
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted, fontSize: 13),
                ),
                const Spacer(),
                Icon(
                  isCollapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
                  size: 22,
                  color: ElioColors.textMuted,
                ),
              ],
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(height: 2),
            Text(
              'Fresh items with optional expiry tracking',
              style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildPerishableAddRow(),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No perishables yet.',
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
                ),
              ),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: GestureDetector(
                onLongPress: () => _showItemMoveMenu(item),
                child: _buildPerishableRow(item),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildPerishableRow(Map<String, dynamic> item) {
    final itemId = item['id'] as String;
    final name = item['name'] as String? ?? '';
    final rawExpiry = item['expiryDate'] as String?;
    DateTime? expiryDate;
    if (rawExpiry != null) expiryDate = DateTime.tryParse(rawExpiry);

    final invItem = InventoryItem(name: name, tier: 'perishable', expiryDate: expiryDate);
    final label = invItem.expiryLabel;
    final isExpired = invItem.isExpired;
    final isExpiringSoon = invItem.isExpiringSoon;

    Color? badgeColor;
    if (label != null) {
      if (isExpired) {
        badgeColor = ElioColors.error;
      } else if (isExpiringSoon) {
        badgeColor = ElioColors.amber;
      } else {
        badgeColor = const Color(0xFF3D9970);
      }
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isExpired
                  ? const Color(0xFFFFF0F0)
                  : isExpiringSoon
                      ? const Color(0xFFFFF8F0)
                      : ElioColors.offWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isExpired
                    ? ElioColors.error.withValues(alpha: 0.5)
                    : isExpiringSoon
                        ? ElioColors.amber.withValues(alpha: 0.5)
                        : ElioColors.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showEditNameDialog(item),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: ElioText.bodyMedium.copyWith(
                              color: isExpired ? ElioColors.error : ElioColors.textPrimary,
                              fontWeight: (isExpired || isExpiringSoon) ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (expiryDate == null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.event_outlined, size: 16, color: ElioColors.textMuted),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.edit_rounded, size: 14, color: ElioColors.textMuted.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ),
                if (label != null && badgeColor != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
                if (isExpiringSoon || isExpired) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ElioColors.error),
                      ),
                      child: Text(
                        'Use it up',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ElioColors.error),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _deleteInventoryItem(itemId),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ElioColors.offWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ElioColors.border),
            ),
            child: const Icon(Icons.close, size: 15, color: ElioColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildPerishableAddRow() {
    final controller = TextEditingController();
    return StatefulBuilder(
      builder: (context, setLocalState) {
        final hasText = controller.text.trim().isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Add perishable...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ElioColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ElioColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ElioColors.navy, width: 1.5),
                      ),
                      filled: true,
                      fillColor: ElioColors.offWhite,
                    ),
                    style: ElioText.bodyMedium,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setLocalState(() {}),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _addPerishableItem(value.trim());
                        controller.clear();
                        setLocalState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (controller.text.trim().isNotEmpty) {
                      _addPerishableItem(controller.text.trim());
                      controller.clear();
                      setLocalState(() {});
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ElioColors.navy,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add, size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
            if (hasText) ...[
              const SizedBox(height: 8),
              Text('Set expiry:', style: ElioText.label.copyWith(color: ElioColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _expiryPresetChip('3 days', 3, controller),
                  _expiryPresetChip('1 week', 7, controller),
                  _expiryPresetChip('2 weeks', 14, controller),
                  _expiryPresetChip('No expiry', null, controller),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _expiryPresetChip(String label, int? days, TextEditingController controller) {
    return GestureDetector(
      onTap: () {
        final name = controller.text.trim();
        if (name.isEmpty) return;
        final expiryDate = days != null ? DateTime.now().add(Duration(days: days)) : null;
        _addPerishableItem(name, expiryDate: expiryDate);
        controller.clear();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ElioColors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ElioColors.amber.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ElioColors.amber),
        ),
      ),
    );
  }

  Widget _buildTierSection({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> items,
    required String tier,
    required IconData icon,
    required Color color,
  }) {
    final isCollapsed = _collapsedTiers.contains(tier);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ElioColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() {
              if (isCollapsed) {
                _collapsedTiers.remove(tier);
              } else {
                _collapsedTiers.add(tier);
              }
            }),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(title, style: ElioText.headingMedium),
                const SizedBox(width: 6),
                Text(
                  '(${items.length})',
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted, fontSize: 13),
                ),
                const Spacer(),
                Icon(
                  isCollapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
                  size: 22,
                  color: ElioColors.textMuted,
                ),
              ],
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            _buildAddItemRow(tier),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No items yet.',
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
                ),
              )
            else
              _buildGroupedItems(items, tier, color),
          ],
        ],
      ),
    );
  }

  /// Builds items grouped by category within a tier.
  Widget _buildGroupedItems(List<Map<String, dynamic>> items, String tier, Color color) {
    // Group items by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final category = item['category'] as String? ??
          PantryCategories.categorize(item['name'] as String? ?? '') ??
          'Other';
      grouped.putIfAbsent(category, () => []).add(item);
    }

    // Sort categories: known categories first (in definition order), then 'Other' last
    final categoryOrder = PantryCategories.all.map((c) => c.name).toList();
    final sortedKeys = grouped.keys.toList()..sort((a, b) {
      if (a == 'Other') return 1;
      if (b == 'Other') return -1;
      final aIdx = categoryOrder.indexOf(a);
      final bIdx = categoryOrder.indexOf(b);
      if (aIdx == -1 && bIdx == -1) return a.compareTo(b);
      if (aIdx == -1) return 1;
      if (bIdx == -1) return -1;
      return aIdx.compareTo(bIdx);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedKeys.map((categoryName) {
        final catItems = grouped[categoryName]!;
        final cat = PantryCategories.byName(categoryName);
        final icon = cat?.icon ?? '📦';

        return _CollapsibleCategoryGroup(
          categoryName: categoryName,
          icon: icon,
          color: color,
          items: catItems,
          onLongPressItem: _showItemMoveMenu,
          buildRow: (item) => _buildInventoryRowContent(
            item, item['runningLow'] as bool? ?? false, item['id'] as String,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInventoryRowContent(Map<String, dynamic> item, bool isRunningLow, String itemId) {
    return Row(
      children: [
        // Long-press hint
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Icon(Icons.more_vert_rounded, size: 18, color: ElioColors.textMuted.withValues(alpha: 0.5)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isRunningLow ? const Color(0xFFFFF8F0) : ElioColors.offWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isRunningLow ? const Color(0xFFFFB300) : ElioColors.border,
                width: isRunningLow ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showEditNameDialog(item),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['name'] as String? ?? '',
                            style: ElioText.bodyMedium.copyWith(
                              color: isRunningLow ? const Color(0xFFE65100) : ElioColors.textPrimary,
                              fontWeight: isRunningLow ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.edit_rounded, size: 14, color: ElioColors.textMuted.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isRunningLow) ...[
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFE65100)),
                  const SizedBox(width: 4),
                  const Text('Low', style: TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Running low toggle
        GestureDetector(
          onTap: () => _toggleRunningLow(itemId, isRunningLow),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isRunningLow ? const Color(0xFFFFF3E0) : ElioColors.offWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isRunningLow ? const Color(0xFFFFB300) : ElioColors.border),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: isRunningLow ? const Color(0xFFE65100) : ElioColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Delete button
        GestureDetector(
          onTap: () => _deleteInventoryItem(itemId),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ElioColors.offWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ElioColors.border),
            ),
            child: const Icon(Icons.close, size: 15, color: ElioColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildAddItemRow(String tier) {
    final controller = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Add item...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: ElioColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: ElioColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: ElioColors.navy, width: 1.5),
              ),
              filled: true,
              fillColor: ElioColors.offWhite,
            ),
            style: ElioText.bodyMedium,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (value) {
              _addInventoryItem(value, tier);
              controller.clear();
            },
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            _addInventoryItem(controller.text, tier);
            controller.clear();
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ElioColors.navy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add, size: 20, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ─── Recipe Book tab ───────────────────────────────────────────────────────────
  Widget _buildRecipeBookTab() {
    return const _RecipeBookContent();
  }


  // ─── Style tab ────────────────────────────────────────────────────────────────
  Widget _buildStyleTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Your food style', style: ElioText.headingMedium),
        const SizedBox(height: 4),
        Text(
          'These appear as quick-select chips on the home screen.',
          style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Text('Cuisines', style: ElioText.label.copyWith(color: ElioColors.textSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _cuisineOptions.map((style) {
            final isSelected = _stylePreferences.contains(style);
            return GestureDetector(
              onTap: () => _toggleStyle(style),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? ElioColors.amber : ElioColors.offWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? ElioColors.amber : ElioColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  style,
                  style: ElioText.label.copyWith(
                    color: isSelected ? Colors.white : ElioColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text('Styles', style: ElioText.label.copyWith(color: ElioColors.textSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _styleOptions.map((style) {
            final isSelected = _stylePreferences.contains(style);
            return GestureDetector(
              onTap: () => _toggleStyle(style),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? ElioColors.amber : ElioColors.offWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? ElioColors.amber : ElioColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  style,
                  style: ElioText.label.copyWith(
                    color: isSelected ? Colors.white : ElioColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Shopping tab ─────────────────────────────────────────────────────────────
  Widget _buildShoppingTab() {
    if (_shoppingLoading) {
      return const Center(child: CircularProgressIndicator(color: ElioColors.amber));
    }

    final unchecked = _shoppingItems.where((i) => !i.isChecked).toList();
    final checked = _shoppingItems.where((i) => i.isChecked).toList();

    return Column(
      children: [
        // ── Add item input ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _shoppingAddController,
                  style: ElioText.bodyMedium,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Add an item...',
                    hintStyle: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: ElioColors.offWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ElioColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ElioColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: ElioColors.amber, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _addShoppingItem(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addShoppingItem,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ElioColors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),

        // ── Progress bar ───────────────────────────────────────
        if (_shoppingItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _shoppingItems.isEmpty ? 0 : checked.length / _shoppingItems.length,
                backgroundColor: ElioColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(ElioColors.amber),
                minHeight: 6,
              ),
            ),
          ),

        const SizedBox(height: 4),

        // ── Item count ─────────────────────────────────────────
        if (_shoppingItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_shoppingItems.length} items · ${checked.length} done',
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
            ),
          ),

        const SizedBox(height: 8),

        // ── Items list ─────────────────────────────────────────
        Expanded(
          child: _shoppingItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart_outlined, size: 56, color: ElioColors.textMuted),
                        const SizedBox(height: 16),
                        Text('Shopping list is empty', style: ElioText.headingMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Add items manually, generate a meal plan, or mark pantry items as Running Low.',
                          textAlign: TextAlign.center,
                          style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                  children: [
                    // Aisle-grouped sections for all unchecked items
                    ..._buildShoppingAisleSections(unchecked),

                    // Checked items
                    if (checked.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Done (${checked.length})',
                            style: ElioText.label.copyWith(
                              color: ElioColors.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          GestureDetector(
                            onTap: _clearCheckedShopping,
                            child: Text(
                              'Clear',
                              style: ElioText.label.copyWith(
                                color: ElioColors.sky,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...checked.map((item) => _buildShoppingTile(item)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  static IconData _aisleIcon(GroceryAisle aisle) {
    switch (aisle) {
      case GroceryAisle.produce:
        return Icons.eco_outlined;
      case GroceryAisle.meatAndFish:
        return Icons.set_meal_outlined;
      case GroceryAisle.dairy:
        return Icons.egg_outlined;
      case GroceryAisle.bakery:
        return Icons.bakery_dining_outlined;
      case GroceryAisle.tinsAndDry:
        return Icons.inventory_2_outlined;
      case GroceryAisle.condiments:
        return Icons.local_dining_outlined;
      case GroceryAisle.spices:
        return Icons.grass_outlined;
      case GroceryAisle.frozen:
        return Icons.ac_unit_outlined;
      case GroceryAisle.drinks:
        return Icons.local_cafe_outlined;
      case GroceryAisle.other:
        return Icons.shopping_bag_outlined;
    }
  }

  List<Widget> _buildShoppingAisleSections(List<PersistentShoppingItem> unchecked) {
    // Group items by aisle
    final grouped = <GroceryAisle, List<PersistentShoppingItem>>{};
    for (final item in unchecked) {
      final aisle = AisleUtils.classify(item.name);
      grouped.putIfAbsent(aisle, () => []).add(item);
    }

    final sections = <Widget>[];
    for (final aisle in AisleUtils.displayOrder) {
      final items = grouped[aisle];
      if (items == null || items.isEmpty) continue;

      sections.addAll([
        Row(
          children: [
            Icon(_aisleIcon(aisle), size: 16, color: ElioColors.navy),
            const SizedBox(width: 6),
            Text(
              AisleUtils.displayName(aisle),
              style: ElioText.label.copyWith(
                color: ElioColors.navy,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _buildShoppingTile(item)),
        const SizedBox(height: 16),
      ]);
    }
    return sections;
  }

  Widget _buildShoppingTile(PersistentShoppingItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(right: 16),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: ElioColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
      ),
      onDismissed: (_) => _removeShoppingItem(item),
      child: GestureDetector(
        onTap: () => _toggleShoppingItem(item),
        onLongPress: () => _showEditShoppingDialog(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: item.isChecked
                ? ElioColors.offWhite.withValues(alpha: 0.5)
                : ElioColors.offWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.isChecked ? ElioColors.border.withValues(alpha: 0.5) : ElioColors.border,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: item.isChecked ? ElioColors.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.isChecked ? ElioColors.amber : ElioColors.border,
                    width: 1.5,
                  ),
                ),
                child: item.isChecked
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      _capitaliseShoppingName(item.name),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: item.isChecked ? ElioColors.textMuted : ElioColors.textPrimary,
                        decoration: item.isChecked ? TextDecoration.lineThrough : null,
                        decorationColor: ElioColors.textMuted,
                      ),
                    ),
                    if (item.isRestock && !item.isChecked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ElioColors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: ElioColors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Restock',
                          style: ElioText.label.copyWith(
                            color: ElioColors.amber,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (item.quantity.isNotEmpty && !item.isChecked && !item.isRestock)
                Text(
                  item.quantity,
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _capitaliseShoppingName(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _addShoppingItem() async {
    final text = _shoppingAddController.text.trim();
    if (text.isEmpty) return;
    _shoppingAddController.clear();
    try {
      final item = await ShoppingService.instance.addItem(name: text);
      if (!mounted) return;
      if (item == null) return; // silently dropped — staple item
      setState(() {
        // Remove existing if it was updated (same name)
        _shoppingItems.removeWhere((i) => i.id == item.id);
        _shoppingItems.add(item);
      });
    } catch (_) {
      if (mounted) _showSnack('Could not add item.');
    }
  }

  Future<void> _toggleShoppingItem(PersistentShoppingItem item) async {
    final newChecked = !item.isChecked;
    setState(() => item.isChecked = newChecked);
    try {
      await ShoppingService.instance.toggleChecked(item.id, newChecked);
    } catch (_) {
      if (mounted) setState(() => item.isChecked = !newChecked);
    }
  }

  Future<void> _removeShoppingItem(PersistentShoppingItem item) async {
    final index = _shoppingItems.indexOf(item);
    setState(() => _shoppingItems.remove(item));
    try {
      await ShoppingService.instance.removeItem(item.id);
    } catch (_) {
      if (mounted) setState(() => _shoppingItems.insert(index, item));
    }
  }

  Future<void> _showEditShoppingDialog(PersistentShoppingItem item) async {
    final nameController = TextEditingController(text: _capitaliseShoppingName(item.name));
    final quantityController = TextEditingController(text: item.quantity);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Item',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ElioColors.navy,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: GoogleFonts.outfit(fontSize: 15, color: ElioColors.navy),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: GoogleFonts.outfit(color: ElioColors.textMuted),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: ElioColors.amber),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              style: GoogleFonts.outfit(fontSize: 15, color: ElioColors.navy),
              decoration: InputDecoration(
                labelText: 'Quantity',
                labelStyle: GoogleFonts.outfit(color: ElioColors.textMuted),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: ElioColors.amber),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: ElioColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Save',
              style: GoogleFonts.outfit(
                color: ElioColors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      nameController.dispose();
      quantityController.dispose();
      return;
    }

    final newName = nameController.text.trim();
    final newQuantity = quantityController.text.trim();
    nameController.dispose();
    quantityController.dispose();

    if (newName.isEmpty) return;

    try {
      await ShoppingService.instance.updateItem(
        item.id,
        name: newName,
        quantity: newQuantity,
      );
      if (mounted) await _loadShoppingItems();
    } catch (_) {
      if (mounted) _showSnack('Could not update item.');
    }
  }

  Future<void> _clearCheckedShopping() async {
    final checked = _shoppingItems.where((i) => i.isChecked).toList();
    setState(() => _shoppingItems.removeWhere((i) => i.isChecked));
    try {
      await ShoppingService.instance.clearChecked();
    } catch (_) {
      if (mounted) setState(() => _shoppingItems.addAll(checked));
    }
  }

}

// ─── Collapsible category group within grouped view ─────────────────────────

class _CollapsibleCategoryGroup extends StatefulWidget {
  final String categoryName;
  final String icon;
  final Color color;
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic>) onLongPressItem;
  final Widget Function(Map<String, dynamic>) buildRow;

  const _CollapsibleCategoryGroup({
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.items,
    required this.onLongPressItem,
    required this.buildRow,
  });

  @override
  State<_CollapsibleCategoryGroup> createState() => _CollapsibleCategoryGroupState();
}

class _CollapsibleCategoryGroupState extends State<_CollapsibleCategoryGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${widget.categoryName} (${widget.items.length})',
                    style: ElioText.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: widget.color,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                  size: 18,
                  color: ElioColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: GestureDetector(
              onLongPress: () => widget.onLongPressItem(item),
              child: widget.buildRow(item),
            ),
          )),
        if (!_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 22, bottom: 4),
            child: Text(
              widget.items.map((i) => i['name'] as String? ?? '').join(' · '),
              style: ElioText.label.copyWith(color: ElioColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

// ─── Recipe Book tab content ────────────────────────────────────────────────

class _RecipeBookContent extends StatefulWidget {
  const _RecipeBookContent();

  @override
  State<_RecipeBookContent> createState() => _RecipeBookContentState();
}

class _RecipeBookContentState extends State<_RecipeBookContent> {
  int _selectedTab = 0; // 0 = Saved, 1 = History
  List<SavedRecipe> _saved = [];
  List<SavedRecipe> _history = [];
  bool _loading = true;
  bool _historyTrimmed = false;

  // ── Search ─────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Collections filter ────────────────────────────────────────────
  String? _selectedCollection; // null = "All"

  // ── Makeable now ─────────────────────────────────────────────────
  List<String> _pantryItems = [];
  Set<String> _makeableNow = {};
  bool _makeableFilter = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(SavedRecipe saved, String query) {
    final q = query.toLowerCase();
    final r = saved.recipe;
    if (r.title.toLowerCase().contains(q)) return true;
    if (r.description.toLowerCase().contains(q)) return true;
    return r.ingredients.any((i) => i.name.toLowerCase().contains(q));
  }

  Future<void> _load() async {
    await EntitlementService.instance.refresh();
    final allRecipes = await HistoryService.getHistory();
    final bookmarked = allRecipes.where((r) => r.isBookmarked).toList();

    List<SavedRecipe> history = allRecipes;
    bool trimmed = false;
    if (EntitlementService.instance.isFree &&
        allRecipes.length > EntitlementService.freeHistoryLimit) {
      history = allRecipes.take(EntitlementService.freeHistoryLimit).toList();
      trimmed = true;
    }

    // Load pantry for "Makeable now" feature (non-blocking on failure)
    List<String> pantryItems = _pantryItems;
    try {
      final userData = await FirestoreService().getUserData();
      final alwaysHave = List<String>.from(userData['alwaysHave'] ?? []);
      final almostAlwaysHave = List<String>.from(userData['almostAlwaysHave'] ?? []);
      final inventoryWithIds = List<Map<String, dynamic>>.from(
        (userData['inventoryWithIds'] as List<dynamic>? ?? []).map((e) => e as Map<String, dynamic>),
      );
      final perishables = inventoryWithIds
          .where((i) => i['tier'] == 'perishable')
          .map((i) => i['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      pantryItems = [
        ...alwaysHave,
        ...almostAlwaysHave,
        ...perishables,
      ].map((s) => s.toLowerCase()).toList();
    } catch (_) {
      // Keep previous pantry if Firestore unavailable
    }

    // Compute makeable recipes: all ingredients fuzzy-match pantry
    final makeableNow = <String>{};
    for (final saved in allRecipes) {
      final ingredients = saved.recipe.ingredients;
      if (ingredients.isEmpty) { makeableNow.add(saved.savedAt); continue; }
      final allMatch = ingredients.every(
        (ing) => pantryItems.any((p) => PantryUtils.isFuzzyMatch(ing.name, p)),
      );
      if (allMatch) makeableNow.add(saved.savedAt);
    }

    if (mounted) {
      setState(() {
        _saved = bookmarked;
        _history = history;
        _historyTrimmed = trimmed;
        _pantryItems = pantryItems;
        _makeableNow = makeableNow;
        _loading = false;
      });
    }
  }

  Future<void> _toggleBookmark(SavedRecipe recipe) async {
    await HistoryService.toggleBookmark(recipe.savedAt);
    await _load();
  }

  Future<void> _deleteRecipe(SavedRecipe recipe) async {
    await HistoryService.deleteRecipe(recipe.savedAt);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${recipe.recipe.title} removed'),
          backgroundColor: ElioColors.navy,
          action: SnackBarAction(
            label: 'Undo',
            textColor: ElioColors.amber,
            onPressed: () async {
              await HistoryService.saveRecipe(recipe);
              _load();
            },
          ),
        ),
      );
    }
    await _load();
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.offWhite,
        title: Text('Clear history?', style: ElioText.headingMedium),
        content: Text(
          'All non-bookmarked recipes will be removed.',
          style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear', style: TextStyle(color: ElioColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await HistoryService.clearHistory();
      await _load();
    }
  }

  void _importRecipe(BuildContext context) {
    if (!EntitlementService.instance.isPro) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PaywallScreen(
            trigger: PaywallTrigger.lockedFeature,
            lockedFeatureName: 'Recipe Import',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecipeImportScreen()),
    ).then((_) => _load()); // Refresh list after import
  }

  /// Returns all unique collection names across saved recipes, sorted.
  List<String> get _allCollections {
    final names = <String>{};
    for (final r in _saved) {
      names.addAll(r.collections);
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  Future<void> _showTagDialog(BuildContext ctx, SavedRecipe saved) async {
    final allCollections = _allCollections;
    final selected = List<String>.from(saved.collections);
    final textController = TextEditingController();

    await showDialog<void>(
      context: ctx,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (dCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: ElioColors.offWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Tag recipe', style: ElioText.headingMedium),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // New collection input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textController,
                            style: ElioText.bodyMedium,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'New collection…',
                              hintStyle: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: ElioColors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: ElioColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: ElioColors.amber, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final name = textController.text.trim();
                            if (name.isNotEmpty && !selected.contains(name)) {
                              setDialogState(() {
                                selected.add(name);
                                textController.clear();
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ElioColors.amber,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    // Existing collections
                    if (allCollections.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Collections',
                        style: ElioText.label.copyWith(
                          color: ElioColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allCollections.map((col) {
                              final isOn = selected.contains(col);
                              return GestureDetector(
                                onTap: () => setDialogState(() {
                                  if (isOn) {
                                    selected.remove(col);
                                  } else {
                                    selected.add(col);
                                  }
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isOn ? ElioColors.amber : ElioColors.offWhite,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isOn ? ElioColors.amber : ElioColors.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    col,
                                    style: ElioText.label.copyWith(
                                      color: isOn ? Colors.white : ElioColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: Text(
                    'Cancel',
                    style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dCtx);
                    await HistoryService.updateCollections(saved.savedAt, selected);
                    await _load();
                  },
                  child: Text(
                    'Save',
                    style: ElioText.bodyMedium.copyWith(
                      color: ElioColors.amber,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: ElioColors.amber));
    }

    final bool isSearching = _searchQuery.isNotEmpty;
    final collections = _allCollections;

    return Column(
      children: [
        // Search bar + makeable toggle row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.outfit(
                    color: ElioColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search recipes, ingredients…',
                    hintStyle: GoogleFonts.outfit(
                      color: ElioColors.textMuted,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isSearching ? ElioColors.amber : ElioColors.textMuted,
                      size: 20,
                    ),
                    suffixIcon: isSearching
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                            },
                            child: const Icon(Icons.close_rounded, color: ElioColors.textMuted, size: 18),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    filled: true,
                    fillColor: ElioColors.offWhite,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ElioColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: ElioColors.amber, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Makeable now toggle button
              GestureDetector(
                onTap: () => setState(() => _makeableFilter = !_makeableFilter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _makeableFilter
                        ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
                        : ElioColors.offWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _makeableFilter ? const Color(0xFF2E7D32) : ElioColors.border,
                      width: _makeableFilter ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.kitchen_rounded,
                        size: 15,
                        color: _makeableFilter ? const Color(0xFF2E7D32) : ElioColors.textMuted,
                      ),
                      if (_makeableFilter) ...[
                        const SizedBox(width: 4),
                        Text(
                          'Makeable',
                          style: ElioText.label.copyWith(
                            fontSize: 11,
                            color: const Color(0xFF2E7D32),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Segment tabs + action row — hidden while searching
        if (!isSearching) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: ElioColors.offWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ElioColors.border),
              ),
              child: Row(
                children: [
                  _segmentButton(0, Icons.bookmark_rounded, 'Saved', _saved.length),
                  _segmentButton(1, Icons.history_rounded, 'History', _history.length),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _importRecipe(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_photo_alternate_rounded, size: 14, color: ElioColors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'Import recipe',
                        style: ElioText.label.copyWith(color: ElioColors.amber, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_selectedTab == 1 && _history.isNotEmpty)
                  GestureDetector(
                    onTap: _clearHistory,
                    child: Text(
                      'Clear history',
                      style: ElioText.label.copyWith(color: ElioColors.error, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          // Collection filter chips — only on Saved tab when collections exist
          if (_selectedTab == 0 && collections.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                children: [
                  _collectionChip(null),
                  ...collections.map((col) => _collectionChip(col)),
                ],
              ),
            ),
        ],
        const SizedBox(height: 8),
        // Recipe list — search results or normal tab view
        Expanded(
          child: isSearching
              ? _buildSearchResults(_searchQuery)
              : (_selectedTab == 0 ? _buildSavedList() : _buildHistoryList()),
        ),
      ],
    );
  }

  Widget _collectionChip(String? col) {
    final label = col ?? 'All';
    final isSelected = _selectedCollection == col;
    return GestureDetector(
      onTap: () => setState(() => _selectedCollection = col),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? ElioColors.amber : ElioColors.offWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? ElioColors.amber : ElioColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: ElioText.label.copyWith(
            fontSize: 12,
            color: isSelected ? Colors.white : ElioColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _segmentButton(int index, IconData icon, String label, int count) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? ElioColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? ElioColors.navy : ElioColors.textMuted),
              const SizedBox(width: 6),
              Text(
                '$label ($count)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? ElioColors.navy : ElioColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(String query) {
    final filteredSaved = _saved.where((r) => _matchesQuery(r, query)).toList();
    final filteredHistory = _history.where((r) => _matchesQuery(r, query)).toList();

    final emptyLabelStyle = GoogleFonts.outfit(
      fontSize: 13,
      color: ElioColors.textMuted,
      fontWeight: FontWeight.w500,
    );
    final sectionLabelStyle = GoogleFonts.outfit(
      fontSize: 11,
      color: ElioColors.textSecondary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // ── Saved section ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(
            children: [
              const Icon(Icons.bookmark_rounded, size: 13, color: ElioColors.textSecondary),
              const SizedBox(width: 5),
              Text('SAVED', style: sectionLabelStyle),
            ],
          ),
        ),
        if (filteredSaved.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text('No saved recipes match', style: emptyLabelStyle),
          )
        else
          ...filteredSaved.map((r) => _buildRecipeCard(r, showBookmark: true)),
        const SizedBox(height: 8),
        // ── History section ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, size: 13, color: ElioColors.textSecondary),
              const SizedBox(width: 5),
              Text('HISTORY', style: sectionLabelStyle),
            ],
          ),
        ),
        if (filteredHistory.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text('No history matches', style: emptyLabelStyle),
          )
        else
          ...filteredHistory.map((r) => _buildRecipeCard(r, showBookmark: true)),
      ],
    );
  }

  Widget _buildSavedList() {
    if (_saved.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bookmark_border_rounded, size: 56, color: ElioColors.border),
              const SizedBox(height: 16),
              Text('No saved recipes yet', style: ElioText.headingMedium),
              const SizedBox(height: 8),
              Text(
                "Bookmark recipes you love and they'll appear here.",
                textAlign: TextAlign.center,
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Apply collection and makeable filters
    var filtered = _saved.where((r) {
      if (_selectedCollection != null && !r.collections.contains(_selectedCollection)) return false;
      if (_makeableFilter && !_makeableNow.contains(r.savedAt)) return false;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            _makeableFilter
                ? 'No saved recipes are makeable with your current pantry.'
                : 'No recipes in this collection.',
            textAlign: TextAlign.center,
            style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildRecipeCard(filtered[index], showBookmark: true),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book_rounded, size: 56, color: ElioColors.border),
              const SizedBox(height: 16),
              Text('No history yet', style: ElioText.headingMedium),
              const SizedBox(height: 8),
              Text(
                'Generate your first recipe to start building your history.',
                textAlign: TextAlign.center,
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Apply makeable filter only (no collection filter in History tab)
    final filtered = _makeableFilter
        ? _history.where((r) => _makeableNow.contains(r.savedAt)).toList()
        : _history;

    if (_makeableFilter && filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'No history recipes are makeable with your current pantry.',
            textAlign: TextAlign.center,
            style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: filtered.length + (_historyTrimmed && !_makeableFilter ? 1 : 0),
      itemBuilder: (context, index) {
        if (_historyTrimmed && !_makeableFilter && index == filtered.length) {
          return _buildUpgradeBanner();
        }
        return _buildRecipeCard(filtered[index], showBookmark: true);
      },
    );
  }

  Widget _buildRecipeCard(SavedRecipe saved, {bool showBookmark = false}) {
    final recipe = saved.recipe;
    final isMakeable = _makeableNow.contains(saved.savedAt);
    return Dismissible(
      key: Key(saved.savedAt),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteRecipe(saved),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ElioColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
      ),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RecipeScreen(recipe: recipe, savedAt: saved.savedAt)),
        ).then((_) => _load()),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ElioColors.offWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ElioColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: ElioText.bodyMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe.description,
                      style: ElioText.label.copyWith(color: ElioColors.textSecondary, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Collection badge
                    if (saved.collections.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ElioColors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              saved.collections.first,
                              style: ElioText.label.copyWith(
                                fontSize: 10,
                                color: ElioColors.amber,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (saved.collections.length > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ElioColors.amber.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+${saved.collections.length - 1} more',
                                style: ElioText.label.copyWith(
                                  fontSize: 10,
                                  color: ElioColors.amber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    // Makeable now badge
                    if (isMakeable) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '\u2713 Makeable now',
                          style: ElioText.label.copyWith(
                            fontSize: 10,
                            color: const Color(0xFF2E7D32),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 12, color: ElioColors.textSecondary),
                        const SizedBox(width: 3),
                        Text('${recipe.totalTimeMinutes} min',
                            style: ElioText.label.copyWith(color: ElioColors.textSecondary, fontSize: 11)),
                        const SizedBox(width: 10),
                        Icon(Icons.people_outline_rounded, size: 12, color: ElioColors.textSecondary),
                        const SizedBox(width: 3),
                        Text('${recipe.servings}',
                            style: ElioText.label.copyWith(color: ElioColors.textSecondary, fontSize: 11)),
                        const Spacer(),
                        Text(
                          _formatDate(saved.savedAt),
                          style: ElioText.label.copyWith(color: ElioColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tag button — always shown
                  GestureDetector(
                    onTap: () => _showTagDialog(context, saved),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Icon(
                        Icons.label_outline_rounded,
                        size: 20,
                        color: saved.collections.isNotEmpty ? ElioColors.amber : ElioColors.textMuted,
                      ),
                    ),
                  ),
                  if (showBookmark)
                    GestureDetector(
                      onTap: () => _toggleBookmark(saved),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          saved.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 22,
                          color: saved.isBookmarked ? ElioColors.amber : ElioColors.textMuted,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded, color: ElioColors.border, size: 22),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpgradeBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: ElioColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ElioColors.amber),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: ElioColors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Upgrade for full history — free accounts show the 20 most recent recipes.',
              style: ElioText.bodyMedium.copyWith(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
