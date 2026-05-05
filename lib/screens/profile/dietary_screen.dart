import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../widgets/elio/elio_chip.dart';
import '../../widgets/elio/elio_custom_field.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_page_title.dart';
import '../../widgets/elio/elio_section_heading.dart';

// ─────────────────────────────────────────────
// DietaryScreen
// Standalone screen for dietary requirements & custom allergens.
// Accessed from Settings. Auto-saves to Firestore on toggle.
// ─────────────────────────────────────────────

class _DietaryOption {
  final String id;
  final String label;
  final bool hasDropdown;
  const _DietaryOption(this.id, this.label, {required this.hasDropdown});
}

class DietaryScreen extends StatefulWidget {
  const DietaryScreen({super.key});

  @override
  State<DietaryScreen> createState() => _DietaryScreenState();
}

class _DietaryScreenState extends State<DietaryScreen> {
  bool _isLoading = true;
  List<String> _dietaryRequirements = [];
  List<String> _allergens = [];
  // Sprint 15.9.3 fix: defaults to 'owner' (the canonical doc id used by
  // the rest of the app) so writes never get silently skipped on
  // accounts that don't yet have a profiles subcollection. Combined
  // with set(merge:true) below, the doc is created on first toggle.
  String _ownerProfileId = 'owner';
  final TextEditingController _allergenController = TextEditingController();

  // Brief visual confirmation that an auto-save succeeded. Auto-save
  // is invisible by design (no Save button), so without this the user
  // has to navigate away and back to verify the write landed.
  bool _showSaveBadge = false;
  Timer? _saveBadgeTimer;

  // id is used as the Firestore value (kept identical to the pre-Sprint-16
  // string set so existing user docs continue to work without migration).
  static const List<_DietaryOption> _dietaryOptions = [
    _DietaryOption('Vegetarian', 'Vegetarian', hasDropdown: false),
    _DietaryOption('Vegan', 'Vegan', hasDropdown: false),
    _DietaryOption('Pescatarian', 'Pescatarian', hasDropdown: false),
    _DietaryOption('Gluten-free', 'Gluten-free', hasDropdown: false),
    _DietaryOption('Dairy-free', 'Dairy-free', hasDropdown: false),
    _DietaryOption('Egg-free', 'Egg-free', hasDropdown: false),
    _DietaryOption('Nut-free', 'Nut-free', hasDropdown: false),
    _DietaryOption('Soy-free', 'Soy-free', hasDropdown: false),
    _DietaryOption('Shellfish-free', 'Shellfish-free', hasDropdown: false),
    _DietaryOption('Halal', 'Halal', hasDropdown: false),
    _DietaryOption('Kosher', 'Kosher', hasDropdown: false),
    _DietaryOption('Low FODMAP', 'Low FODMAP', hasDropdown: false),
    _DietaryOption('Diabetic-friendly', 'Diabetic-friendly', hasDropdown: false),
    _DietaryOption('Low-carb', 'Low-carb', hasDropdown: false),
    _DietaryOption('High-protein', 'High-protein', hasDropdown: false),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _saveBadgeTimer?.cancel();
    _allergenController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final profilesSnap = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('profiles').get();
      // Sprint 15.9.3 fix: previously this used firstWhere(...orElse:
      // () => profilesSnap.docs.first), which throws on an empty
      // collection (the .first call). The throw was caught silently
      // and _ownerProfileId stayed null, which made every subsequent
      // toggle skip the write — the bug Rob hit.
      QueryDocumentSnapshot<Map<String, dynamic>>? owner;
      for (final d in profilesSnap.docs) {
        if (d.data()['isOwner'] == true) {
          owner = d;
          break;
        }
      }
      // Fallback: any profile we can find (legacy accounts without the
      // explicit isOwner flag). Final fallback: stay at the default
      // 'owner' id so the next save creates the doc cleanly.
      owner ??= profilesSnap.docs.isNotEmpty ? profilesSnap.docs.first : null;
      if (mounted) {
        setState(() {
          if (owner != null) {
            _ownerProfileId = owner.id;
            _dietaryRequirements = List<String>.from(owner.data()['dietaryRequirements'] ?? []);
            _allergens = List<String>.from(owner.data()['allergies'] ?? []);
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Auto-save indicator — flashes "Saved" briefly so the user has
  /// observable feedback that a chip toggle actually persisted. Without
  /// this, auto-save is invisible until the user navigates away and back.
  void _flashSavedBadge() {
    _saveBadgeTimer?.cancel();
    if (mounted) setState(() => _showSaveBadge = true);
    _saveBadgeTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showSaveBadge = false);
    });
  }

  /// Single Firestore write helper used by every toggle/add/remove
  /// action. Uses `set(merge: true)` so the doc is created on first
  /// write and partial-field updates work whether or not the doc
  /// exists. Was `update()` previously, which throws on missing docs
  /// and silently swallowed the error.
  Future<void> _persistOwnerProfile(Map<String, dynamic> patch) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('profiles')
        .doc(_ownerProfileId)
        .set({
          ...patch,
          // Defensive: if the doc didn't exist, mark it owner.
          'isOwner': true,
        }, SetOptions(merge: true));
  }

  Future<void> _toggleDietary(String req) async {
    final previous = List<String>.from(_dietaryRequirements);
    final updated = List<String>.from(_dietaryRequirements);
    if (updated.contains(req)) {
      updated.remove(req);
    } else {
      updated.add(req);
    }
    setState(() => _dietaryRequirements = updated);
    try {
      await _persistOwnerProfile({'dietaryRequirements': updated});
      _flashSavedBadge();
    } catch (_) {
      if (mounted) setState(() => _dietaryRequirements = previous);
      _showSnack('Could not save. Please try again.');
    }
  }

  Future<void> _addAllergen(String allergen) async {
    final trimmed = allergen.trim();
    if (trimmed.isEmpty || _allergens.contains(trimmed)) return;
    final updated = List<String>.from(_allergens)..add(trimmed);
    setState(() => _allergens = updated);
    _allergenController.clear();
    try {
      await _persistOwnerProfile({'allergies': updated});
      _flashSavedBadge();
    } catch (_) {
      if (mounted) setState(() => _allergens = List<String>.from(_allergens)..remove(trimmed));
      _showSnack('Could not save. Please try again.');
    }
  }

  Future<void> _removeAllergen(String allergen) async {
    final previous = List<String>.from(_allergens);
    final updated = List<String>.from(_allergens)..remove(allergen);
    setState(() => _allergens = updated);
    try {
      await _persistOwnerProfile({'allergies': updated});
      _flashSavedBadge();
    } catch (_) {
      if (mounted) setState(() => _allergens = previous);
      _showSnack('Could not remove. Please try again.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: ElioColors.espresso),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Sprint 15.9.3: visible "Saved" indicator for the auto-save
        // pattern. Flashes briefly after each successful chip toggle
        // or allergen add/remove so the user has feedback the write
        // landed (no Save button in this UX).
        actions: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _showSaveBadge ? 1.0 : 0.0,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: ElioColors.terracotta,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Saved',
                    style: ElioTextStyles.uiLabelStyle.copyWith(
                      color: ElioColors.terracotta,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: ElioColors.terracotta))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(ElioSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ElioPageTitle('dietary and allergens'),
                  const SizedBox(height: ElioSpacing.md),
                  Text(
                    "elio wont suggest recipes that dont work for you and your settings.",
                    style: ElioTextStyles.ledeStyle,
                  ),
                  const SizedBox(height: ElioSpacing.xl),
                  ElioSectionHeading('Dietary requirements'),
                  const SizedBox(height: ElioSpacing.sm),
                  const ElioEyebrow('you can pick multiple'),
                  const SizedBox(height: ElioSpacing.md),
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      for (final opt in _dietaryOptions)
                        ElioChip(
                          label: opt.label,
                          selected: _dietaryRequirements.contains(opt.id),
                          hasDropdown: opt.hasDropdown,
                          onTap: () => _toggleDietary(opt.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: ElioSpacing.xxl),
                  ElioSectionHeading('Custom allergens or dietary requirements'),
                  const SizedBox(height: ElioSpacing.sm),
                  Text(
                    "add anything that isn't listed above in the custom text field below",
                    style: ElioTextStyles.bodySmallStyle,
                  ),
                  const SizedBox(height: ElioSpacing.md),
                  if (_allergens.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: [
                        for (final allergen in _allergens)
                          InkWell(
                            onTap: () => _removeAllergen(allergen),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: ElioColors.terracotta.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: ElioColors.terracotta, width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    allergen,
                                    style: ElioTextStyles.bodyStyle.copyWith(color: ElioColors.espresso),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.close, size: 16, color: ElioColors.espresso),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: ElioSpacing.md),
                  ],
                  ElioCustomField(
                    placeholder: 'e.g. shellfish, mustard',
                    controller: _allergenController,
                    onSubmitted: _addAllergen,
                  ),
                ],
              ),
            ),
    );
  }
}
