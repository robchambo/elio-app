import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/error_service.dart';
import '../../services/user_settings_service.dart';
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
            // Sprint 16.1 case fix: legacy onboarding wrote lowercase
            // dietary tokens ('vegetarian'). The chip IDs on this
            // screen are TitleCase ('Vegetarian'), and `.contains` is
            // case-sensitive — without normalising the chips would
            // appear unselected even though the value is saved. Use
            // the singleton's helper so the canonical form is shared
            // across consumers.
            _dietaryRequirements = UserSettingsService.canonicaliseDietaryList(
              List<String>.from(owner.data()['dietaryRequirements'] ?? const <String>[]),
            );
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
  ///
  /// Sprint 16.1 diagnostic: Rob hit a case where `set` returned
  /// successfully (badge flashed) but a navigate-away/return showed
  /// stale data. Most likely cause: silent server-side rule denial —
  /// Firestore queues the write locally and the await completes
  /// against the local cache even when the server rejects. Once it
  /// rejects, subsequent reads from the server see the old data.
  ///
  /// To surface this we now do a verify read-back AFTER the write
  /// (forced from server). If the field we just wrote isn't there,
  /// throw — which surfaces a visible "Could not save" snackbar
  /// instead of the silent flash.
  Future<void> _persistOwnerProfile(Map<String, dynamic> patch) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Not signed in.');
    }
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('profiles')
        .doc(_ownerProfileId);

    try {
      await docRef.set({
        ...patch,
        // Defensive: if the doc didn't exist, mark it owner.
        'isOwner': true,
      }, SetOptions(merge: true));
    } catch (e, st) {
      ErrorService.log('dietary_save_write', e, st);
      rethrow;
    }

    // Verify the write actually landed on the server (not just the
    // local cache). The Source.server flag bypasses cache for this
    // single read so a denied write surfaces here rather than silently
    // returning stale data on next navigation.
    try {
      final snap = await docRef.get(const GetOptions(source: Source.server));
      final data = snap.data() ?? const <String, dynamic>{};
      for (final entry in patch.entries) {
        final got = data[entry.key];
        final want = entry.value;
        if (!_listEquals(got, want)) {
          ErrorService.log(
            'dietary_save_verify_mismatch',
            'patch ${entry.key}=$want; server returned $got. '
                'docPath=${docRef.path}',
          );
          throw StateError(
            'Save did not persist (server returned ${got ?? 'null'} for '
            '${entry.key}).',
          );
        }
      }
    } catch (e, st) {
      ErrorService.log('dietary_save_verify', e, st);
      rethrow;
    }
  }

  /// Shallow list/value equality — compares two values that came from
  /// a Firestore `set` patch and a `get` round-trip. List comparison
  /// is order-sensitive (matches what the user sees).
  bool _listEquals(dynamic a, dynamic b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i].toString() != b[i].toString()) return false;
      }
      return true;
    }
    return a == b;
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
      // Sprint 16.1: push the new state into UserSettingsService so
      // HomeScreen / RecipeScreen rebuild and the next recipe sees
      // the change without an app restart.
      await UserSettingsService.instance.refresh();
      _flashSavedBadge();
    } catch (e) {
      if (mounted) setState(() => _dietaryRequirements = previous);
      _showSnack('Save failed: $e');
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
      await UserSettingsService.instance.refresh();
      _flashSavedBadge();
    } catch (e) {
      if (mounted) setState(() => _allergens = List<String>.from(_allergens)..remove(trimmed));
      _showSnack('Save failed: $e');
    }
  }

  Future<void> _removeAllergen(String allergen) async {
    final previous = List<String>.from(_allergens);
    final updated = List<String>.from(_allergens)..remove(allergen);
    setState(() => _allergens = updated);
    try {
      await _persistOwnerProfile({'allergies': updated});
      await UserSettingsService.instance.refresh();
      _flashSavedBadge();
    } catch (e) {
      if (mounted) setState(() => _allergens = previous);
      _showSnack('Remove failed: $e');
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
