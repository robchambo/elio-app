import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/elio_theme.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../utils/pantry_utils.dart';
import '../onboarding/screen0_welcome.dart';
import '../../services/analytics_service.dart';
import '../../services/entitlement_service.dart';

// ─────────────────────────────────────────────
// ProfileScreen
// Design philosophy: approachable utility.
// Tabs: Pantry (drag-to-move tiers, running-low) | Dietary & Allergens | Household | Style
// ─────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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

  // ── Dietary requirements ───────────────────────────────────────────
  List<String> _dietaryRequirements = [];
  List<String> _customAllergens = [];
  String? _ownerProfileId;
  final TextEditingController _customAllergenController = TextEditingController();

  // ── Household members ──────────────────────────────────────────────
  List<Map<String, dynamic>> _householdProfiles = [];

  // ── Style preferences ──────────────────────────────────────────────
  List<String> _stylePreferences = [];

  // ── Kitchen appliances ─────────────────────────────────────────────
  List<String> _appliances = [];

  // ── Available options ──────────────────────────────────────────────
  static const List<String> _allDietaryOptions = [
    'Vegetarian', 'Vegan', 'Gluten-free', 'Dairy-free',
    'Nut-free', 'Halal', 'Kosher', 'Low FODMAP',
    'Diabetic-friendly', 'Low-carb', 'High-protein',
  ];

  static const List<String> _allStyleOptions = [
    'Italian', 'Asian', 'Middle Eastern', 'Mexican',
    'Mediterranean', 'Indian', 'American', 'French',
    'Japanese', 'Thai', 'Greek', 'British',
    'Comfort food', 'Healthy', 'Quick & easy', 'Smoothies',
  ];

  static const List<String> _allApplianceOptions = [
    'Air fryer',
    'Slow cooker',
    'Rice cooker',
    'Instant Pot / Pressure cooker',
    'Stand mixer',
    'Food processor',
    'Blender',
    'Sous vide',
    'Bread maker',
    'Waffle iron',
    'Spiralizer',
    'Grill / BBQ',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customAllergenController.dispose();
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
        _appliances = List<String>.from(data['appliances'] ?? []);
        _householdProfiles = List<Map<String, dynamic>>.from(
          (data['householdProfiles'] as List?)?.map((p) => Map<String, dynamic>.from(p as Map)) ?? [],
        );
        final owner = _householdProfiles.firstWhere(
          (p) => p['isOwner'] == true,
          orElse: () => {},
        );
        if (owner.isNotEmpty) {
          _ownerProfileId = owner['id'] as String?;
          _dietaryRequirements = List<String>.from(owner['dietaryRequirements'] ?? []);
          _customAllergens = List<String>.from(owner['customAllergens'] ?? []);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
    setState(() {
      final idx = _inventoryItems.indexWhere((i) => i['id'] == itemId);
      if (idx != -1) _inventoryItems[idx]['runningLow'] = newValue;
    });
    if (newValue) {
      _analytics.logEvent('pantry_item_running_low');
    }
    try {
      await _firestore.toggleRunningLow(itemId, newValue);
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _inventoryItems.indexWhere((i) => i['id'] == itemId);
          if (idx != -1) _inventoryItems[idx]['runningLow'] = current;
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

  Future<void> _addInventoryItem(String name, String tier) async {
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

    try {
      final id = await _firestore.addInventoryItem(name.trim(), tier);
      if (mounted) {
        setState(() => _inventoryItems.add({
          'id': id,
          'name': name.trim(),
          'tier': tier,
          'runningLow': false,
        }));
        _analytics.logEvent('pantry_item_added', {'tier': tier});
      }
    } catch (_) {
      _showSnack('Could not add item. Please try again.');
    }
  }

  // ── Dietary helpers ────────────────────────────────────────────────

  Future<void> _toggleDietary(String req) async {
    final previous = List<String>.from(_dietaryRequirements);
    final updated = List<String>.from(_dietaryRequirements);
    if (updated.contains(req)) {
      updated.remove(req);
    } else {
      updated.add(req);
    }
    setState(() => _dietaryRequirements = updated);
    if (_ownerProfileId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('profiles')
            .doc(_ownerProfileId)
            .update({'dietaryRequirements': updated});
      } catch (_) {
        setState(() => _dietaryRequirements = previous);
        _showSnack('Could not save dietary change. Please try again.');
      }
    } else {
      setState(() => _dietaryRequirements = previous);
      _showSnack('Could not save — profile not loaded. Try restarting the app.');
    }
  }

  Future<void> _addCustomAllergen(String allergen) async {
    final trimmed = allergen.trim();
    if (trimmed.isEmpty || _customAllergens.contains(trimmed)) return;
    final previous = List<String>.from(_customAllergens);
    final updated = List<String>.from(_customAllergens)..add(trimmed);
    setState(() => _customAllergens = updated);
    _customAllergenController.clear();
    if (_ownerProfileId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('profiles')
            .doc(_ownerProfileId)
            .update({'customAllergens': updated});
      } catch (_) {
        setState(() => _customAllergens = previous);
        _showSnack('Could not save allergen. Please try again.');
      }
    } else {
      setState(() => _customAllergens = previous);
      _showSnack('Could not save — profile not loaded. Try restarting the app.');
    }
  }

  Future<void> _removeCustomAllergen(String allergen) async {
    final previous = List<String>.from(_customAllergens);
    final updated = List<String>.from(_customAllergens)..remove(allergen);
    setState(() => _customAllergens = updated);
    if (_ownerProfileId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('profiles')
            .doc(_ownerProfileId)
            .update({'customAllergens': updated});
      } catch (_) {
        setState(() => _customAllergens = previous);
        _showSnack('Could not remove allergen. Please try again.');
      }
    } else {
      setState(() => _customAllergens = previous);
      _showSnack('Could not save — profile not loaded. Try restarting the app.');
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

  // ── Appliance helpers ──────────────────────────────────────────────

  Future<void> _toggleAppliance(String appliance) async {
    final updated = List<String>.from(_appliances);
    if (updated.contains(appliance)) {
      updated.remove(appliance);
    } else {
      updated.add(appliance);
    }
    setState(() => _appliances = updated);
    try {
      await _firestore.saveAppliances(updated);
    } catch (_) {
      _showSnack('Could not save appliance change. Please try again.');
    }
  }

  // ── Household helpers ──────────────────────────────────────────────

  Future<void> _deleteMember(String profileId) async {
    final removed = _householdProfiles.firstWhere((p) => p['id'] == profileId, orElse: () => {});
    setState(() => _householdProfiles.removeWhere((p) => p['id'] == profileId));
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('profiles')
          .doc(profileId)
          .delete();
    } catch (_) {
      if (mounted && removed.isNotEmpty) {
        setState(() => _householdProfiles.add(removed));
        _showSnack('Could not remove member. Please try again.');
      }
    }
  }

  Future<void> _addMember(String name, List<String> dietary) async {
    if (name.trim().isEmpty) return;

    // Enforce household member limit for free tier.
    if (_householdProfiles.length >= EntitlementService.instance.maxHouseholdMembers) {
      _showSnack('Upgrade to Pro to add more household members.');
      return;
    }

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('profiles')
          .doc();
      await ref.set({
        'name': name.trim(),
        'dietaryRequirements': dietary,
        'isOwner': false,
      });
      if (mounted) {
        setState(() => _householdProfiles.add({
          'id': ref.id,
          'name': name.trim(),
          'dietaryRequirements': dietary,
          'isOwner': false,
        }));
      }
    } catch (_) {
      _showSnack('Could not add member. Please try again.');
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
              tabs: const [
                Tab(text: 'Pantry'),
                Tab(text: 'Dietary'),
                Tab(text: 'Household'),
                Tab(text: 'Style'),
                Tab(text: 'Kitchen'),
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
                        _buildDietaryTab(),
                        _buildHouseholdTab(),
                        _buildStyleTab(),
                        _buildKitchenTab(),
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

    if (isGuest) {
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
                'Sign in with Google to complete setup and fill your pantry.',
                textAlign: TextAlign.center,
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Your pantry', style: ElioText.headingMedium),
        const SizedBox(height: 4),
        Text(
          'Long-press any item to move it between tiers. Tap ⚠ to flag items running low.',
          style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
        ),
        const SizedBox(height: 20),
        _buildTierSection(
          title: 'Always Have',
          subtitle: 'Staples you always keep stocked',
          items: _alwaysHaveItems,
          tier: 'alwaysHave',
          icon: Icons.inventory_2_outlined,
        ),
        const SizedBox(height: 24),
        _buildTierSection(
          title: 'Almost Always Have',
          subtitle: 'Items you usually have but sometimes run out of',
          items: _almostAlwaysHaveItems,
          tier: 'almostAlwaysHave',
          icon: Icons.kitchen_outlined,
        ),
      ],
    );
  }

  /// Shows a bottom sheet with move/delete options for the given inventory item.
  void _showItemMoveMenu(Map<String, dynamic> item) {
    HapticFeedback.selectionClick();
    final itemId = item['id'] as String;
    final itemName = item['name'] as String? ?? '';
    final currentTier = item['tier'] as String? ?? 'alwaysHave';
    final otherTier = currentTier == 'alwaysHave' ? 'almostAlwaysHave' : 'alwaysHave';
    final otherTierLabel = currentTier == 'alwaysHave' ? 'Almost Always Have' : 'Always Have';

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
                'Currently in: ${currentTier == 'alwaysHave' ? 'Always Have' : 'Almost Always Have'}',
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
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
                  'Move to "$otherTierLabel"',
                  style: ElioText.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _moveItemToTier(itemId, otherTier);
                },
              ),
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

  Widget _buildTierSection({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> items,
    required String tier,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ElioColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: ElioColors.navy),
              const SizedBox(width: 6),
              Text(title, style: ElioText.headingMedium),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No items yet. Add some below.',
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
              ),
            ),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: GestureDetector(
              onLongPress: () => _showItemMoveMenu(item),
              child: _buildInventoryRowContent(item, item['runningLow'] as bool? ?? false, item['id'] as String),
            ),
          )),
          const SizedBox(height: 8),
          _buildAddItemRow(tier),
        ],
      ),
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
                  child: Text(
                    item['name'] as String? ?? '',
                    style: ElioText.bodyMedium.copyWith(
                      color: isRunningLow ? const Color(0xFFE65100) : ElioColors.textPrimary,
                      fontWeight: isRunningLow ? FontWeight.w600 : FontWeight.w400,
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

  // ─── Dietary tab ──────────────────────────────────────────────────────────────
  Widget _buildDietaryTab() {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user?.isAnonymous ?? true;

    if (isGuest) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_meals_outlined, size: 56, color: ElioColors.textMuted),
              const SizedBox(height: 16),
              Text('Dietary preferences', style: ElioText.headingMedium),
              const SizedBox(height: 8),
              Text(
                'Sign in with Google to set your dietary requirements and allergens.',
                textAlign: TextAlign.center,
                style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Dietary requirements & Allergens', style: ElioText.headingMedium),
        const SizedBox(height: 4),
        Text(
          'Elio will never suggest recipes that don\'t work for you.',
          style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _allDietaryOptions.map((req) {
            final isSelected = _dietaryRequirements.contains(req);
            return GestureDetector(
              onTap: () => _toggleDietary(req),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? ElioColors.navy : ElioColors.offWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? ElioColors.navy : ElioColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  req,
                  style: ElioText.label.copyWith(
                    color: isSelected ? Colors.white : ElioColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        // ── Custom allergens ──────────────────────────────────────────
        Text('Custom allergens', style: ElioText.headingMedium.copyWith(fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          'Add any allergies or intolerances not listed above.',
          style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_customAllergens.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _customAllergens.map((allergen) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFB300)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(allergen, style: ElioText.label.copyWith(color: const Color(0xFFE65100), fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _removeCustomAllergen(allergen),
                    child: const Icon(Icons.close, size: 14, color: Color(0xFFE65100)),
                  ),
                ],
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customAllergenController,
                decoration: InputDecoration(
                  hintText: 'e.g. Sesame, Shellfish, Mustard...',
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
                onSubmitted: (value) => _addCustomAllergen(value),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _addCustomAllergen(_customAllergenController.text),
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
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF4FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16, color: ElioColors.sky),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'To edit a household member\'s dietary requirements, go to the Household tab.',
                  style: ElioText.bodyMedium.copyWith(color: ElioColors.sky, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Household tab ────────────────────────────────────────────────────────────
  Widget _buildHouseholdTab() {
    final members = _householdProfiles.where((p) => p['isOwner'] != true).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Household members', style: ElioText.headingMedium),
        const SizedBox(height: 4),
        Text(
          'Elio applies the union of all active dietary requirements when generating recipes.',
          style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
        ),
        const SizedBox(height: 20),
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No household members added yet.',
              style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted),
            ),
          ),
        ...members.map((member) => _buildMemberCard(member)),
        const SizedBox(height: 16),
        _buildAddMemberButton(),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final reqs = List<String>.from(member['dietaryRequirements'] ?? []);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ElioColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ElioColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: ElioColors.navy, shape: BoxShape.circle),
            child: Center(
              child: Text(
                (member['name'] as String? ?? '?').isNotEmpty
                    ? (member['name'] as String)[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member['name'] as String? ?? 'Member', style: ElioText.headingMedium.copyWith(fontSize: 15)),
                if (reqs.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: reqs.map((r) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ElioColors.navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(r, style: ElioText.label.copyWith(fontSize: 11, color: ElioColors.navy)),
                    )).toList(),
                  ),
                ] else
                  Text('No dietary requirements', style: ElioText.bodyMedium.copyWith(color: ElioColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _deleteMember(member['id'] as String),
            child: const Icon(Icons.close, size: 18, color: ElioColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMemberButton() {
    return GestureDetector(
      onTap: _showAddMemberSheet,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ElioColors.border, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add_outlined, size: 18, color: ElioColors.navy),
            const SizedBox(width: 8),
            Text('Add household member', style: ElioText.label.copyWith(color: ElioColors.navy)),
          ],
        ),
      ),
    );
  }

  void _showAddMemberSheet() {
    final nameController = TextEditingController();
    final selectedDietary = <String>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add household member', style: ElioText.headingMedium),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Name (e.g. Partner, Child)'),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Text('Dietary requirements', style: ElioText.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allDietaryOptions.map((req) {
                  final isSelected = selectedDietary.contains(req);
                  return GestureDetector(
                    onTap: () => setSheetState(() {
                      if (isSelected) { selectedDietary.remove(req); }
                      else { selectedDietary.add(req); }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? ElioColors.navy : ElioColors.offWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? ElioColors.navy : ElioColors.border),
                      ),
                      child: Text(req, style: ElioText.label.copyWith(
                        color: isSelected ? Colors.white : ElioColors.textPrimary,
                      )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _addMember(nameController.text, List.from(selectedDietary));
                  },
                  child: const Text('Add member'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _allStyleOptions.map((style) {
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

  // ─── Kitchen tab ──────────────────────────────────────────────────────────────
  Widget _buildKitchenTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Your kitchen appliances', style: ElioText.headingMedium),
        const SizedBox(height: 4),
        Text(
          "Select the appliances you own and we'll tailor recipes to make the most of them.",
          style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _allApplianceOptions.map((appliance) {
            final isSelected = _appliances.contains(appliance);
            return GestureDetector(
              onTap: () => _toggleAppliance(appliance),
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
                  appliance,
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
}
