import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_spacing.dart';
import '../../services/entitlement_service.dart';
import '../../services/firestore_service.dart';
import '../../services/guest_pantry_service.dart';
import '../../widgets/elio/elio_household_stepper.dart';

// ─────────────────────────────────────────────
// HouseholdScreen
// Standalone screen for managing household members
// and their dietary requirements. Accessible from Settings.
// ─────────────────────────────────────────────

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _members = [];

  // 16 May 2026: household size mirrors the onboarding screen-03
  // stepper. Drives the default `servings` value for every generation
  // (home_screen reads users/{uid}.householdCount). Loaded once in
  // initState; edits write straight to Firestore via
  // FirestoreService.saveHouseholdCount, with optimistic local update
  // for instant feedback.
  int _householdCount = 2;
  bool _householdCountLoaded = false;
  final FirestoreService _firestore = FirestoreService();

  // Sprint 16.6.x: live Firestore stream replaces the previous one-shot
  // get(). Mutations now write to Firestore and the stream re-renders;
  // we no longer optimistic-add in setState then false-error in the
  // catch block when something benign threw after a successful write
  // (Rob reported add/remove/edit all showed "Could not …" toasts while
  // the change actually persisted).
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _profilesSub;

  static const List<String> _allDietaryOptions = [
    'Vegetarian', 'Vegan', 'Pescatarian', 'Gluten-free', 'Dairy-free',
    'Egg-free', 'Nut-free', 'Soy-free', 'Shellfish-free',
    'Halal', 'Kosher', 'Low FODMAP',
    'Diabetic-friendly', 'Low-carb', 'High-protein',
  ];

  @override
  void initState() {
    super.initState();
    _subscribeMembers();
    _loadHouseholdCount();
  }

  Future<void> _loadHouseholdCount() async {
    try {
      // 16 May 2026 follow-up: branch on auth state. Guest users
      // (skipped account creation on screen 15) have no Firebase
      // user, so FirestoreService throws on `_uid`. Mirror the
      // pantry pattern — Firestore for signed-in, SharedPreferences
      // for guests via GuestPantryService.
      final signedIn = FirebaseAuth.instance.currentUser != null;
      final count = signedIn
          ? await _firestore.getHouseholdCount()
          : await GuestPantryService.loadHouseholdCount();
      if (mounted) {
        setState(() {
          _householdCount = count;
          _householdCountLoaded = true;
        });
      }
    } catch (_) {
      // Non-critical — stepper just renders the default of 2.
      if (mounted) setState(() => _householdCountLoaded = true);
    }
  }

  Future<void> _onHouseholdCountChanged(int v) async {
    // Optimistic update so the stepper is instant. Revert on failure.
    final previous = _householdCount;
    setState(() => _householdCount = v);
    try {
      final signedIn = FirebaseAuth.instance.currentUser != null;
      if (signedIn) {
        await _firestore.saveHouseholdCount(v);
      } else {
        await GuestPantryService.saveHouseholdCount(v);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _householdCount = previous);
        _showSnack('Could not save household size. Try again.');
      }
    }
  }

  @override
  void dispose() {
    _profilesSub?.cancel();
    super.dispose();
  }

  void _subscribeMembers() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('profiles');
    _profilesSub = query.snapshots().listen((snap) {
      if (!mounted) return;
      final profiles = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': data['name'] as String? ?? '',
          'dietaryRequirements':
              List<String>.from(data['dietaryRequirements'] ?? []),
          'isOwner': data['isOwner'] as bool? ?? false,
        };
      }).toList();
      setState(() {
        _members = profiles.where((p) => p['isOwner'] != true).toList();
        _isLoading = false;
      });
    }, onError: (e) {
      debugPrint('Household stream error: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _deleteMember(String profileId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not signed in');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profiles')
          .doc(profileId)
          .delete();
      // Stream picks up the delete; no manual setState.
    } catch (e) {
      debugPrint('Household delete error: $e');
      _showSnack('Could not remove member. Please try again.');
    }
  }

  Future<void> _addMember(String name, List<String> dietary) async {
    if (name.trim().isEmpty) return;

    // Check entitlement limit (includes owner, so total profiles)
    final totalProfiles = _members.length + 1; // +1 for owner
    if (totalProfiles >= EntitlementService.instance.maxHouseholdMembers) {
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
      // Stream picks up the insert; no manual setState.
    } catch (e) {
      debugPrint('Household add error: $e');
      _showSnack('Could not add member. Please try again.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    // Sprint 16.1: explicit duration + hide-current. Floating snackbars
    // show via the root MaterialApp ScaffoldMessenger and follow the
    // user across navigation; without an explicit duration they linger
    // long after the action they were reporting on.
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ElioColors.espresso,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _updateMember(String profileId, String name, List<String> dietary) async {
    if (name.trim().isEmpty) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not signed in');
      // Use set with merge instead of update — more resilient if doc
      // was created via batch during onboarding
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profiles')
          .doc(profileId)
          .set({
        'name': name.trim(),
        'dietaryRequirements': dietary,
        'isOwner': false,
      }, SetOptions(merge: true));
      // Stream picks up the change; no manual setState.
    } catch (e) {
      debugPrint('Household update error: $e');
      _showSnack('Could not update member. Please try again.');
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> member) async {
    final name = member['name'] as String? ?? 'this member';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove $name?', style: ElioText.headingMedium),
        content: Text(
          'This will remove $name and their dietary requirements from your household.',
          style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: ElioText.bodyMedium.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _deleteMember(member['id'] as String);
    }
  }

  void _showMemberSheet({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: isEdit ? existing['name'] as String? ?? '' : '');
    final selectedDietary = List<String>.from(isEdit ? existing['dietaryRequirements'] ?? [] : []);

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
              Text(
                isEdit ? 'Edit household member' : 'Add household member',
                style: ElioText.headingMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Name (e.g. Partner, Child)'),
                textCapitalization: TextCapitalization.words,
                autofocus: !isEdit,
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
                        color: isSelected ? ElioColors.espresso : ElioColors.cream,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? ElioColors.espresso : ElioColors.rule),
                      ),
                      child: Text(req, style: ElioText.label.copyWith(
                        color: isSelected ? Colors.white : ElioColors.espresso,
                      )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (isEdit) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          // Wait for the bottom sheet dismiss animation to
                          // fully complete before opening the confirm dialog.
                          await Future.delayed(const Duration(milliseconds: 350));
                          if (mounted) _confirmDelete(existing);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Remove'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (isEdit) {
                          _updateMember(existing['id'] as String, nameController.text, List.from(selectedDietary));
                        } else {
                          _addMember(nameController.text, List.from(selectedDietary));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ElioColors.terracotta,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: Text(isEdit ? 'Save' : 'Add member'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back_ios_new, size: 20, color: ElioColors.espresso),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Household', style: ElioText.headingLarge),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Content ───────────────────────────────────────
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator(color: ElioColors.terracotta)),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Household size (drives default servings) ─────────
                    // 16 May 2026: mirrors the onboarding screen-03
                    // stepper so the user can adjust the size that
                    // drives default recipe servings without redoing
                    // onboarding. Sits above the members list because
                    // every household has a size, even when no extra
                    // members have been added.
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ElioColors.cream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ElioColors.rule),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Household size',
                                    style: ElioText.label.copyWith(
                                        color: ElioColors.espresso)),
                                const SizedBox(height: 4),
                                Text(
                                  'Default servings for every recipe.',
                                  style: ElioText.bodyMedium
                                      .copyWith(color: ElioColors.mocha),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: ElioSpacing.md),
                          if (_householdCountLoaded)
                            ElioHouseholdStepper(
                              value: _householdCount,
                              onChanged: _onHouseholdCountChanged,
                            )
                          else
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ElioColors.terracotta,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Add household members so Elio can respect everyone\'s dietary needs when generating recipes.',
                      style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
                    ),
                    const SizedBox(height: 20),
                    if (_members.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.people_outline, size: 20, color: ElioColors.mocha),
                            const SizedBox(width: 10),
                            Text(
                              'No household members added yet.',
                              style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha),
                            ),
                          ],
                        ),
                      ),
                    ..._members.map(_buildMemberCard),
                    const SizedBox(height: 16),
                    // Add member button
                    GestureDetector(
                      onTap: () => _showMemberSheet(),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ElioColors.rule, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_add_outlined, size: 18, color: ElioColors.espresso),
                            const SizedBox(width: 8),
                            Text('Add household member', style: ElioText.label.copyWith(color: ElioColors.espresso)),
                          ],
                        ),
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

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final reqs = List<String>.from(member['dietaryRequirements'] ?? []);
    return GestureDetector(
      onTap: () => _showMemberSheet(existing: member),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ElioColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ElioColors.rule),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: ElioColors.espresso, shape: BoxShape.circle),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(member['name'] as String? ?? 'Member',
                            style: ElioTextStyles.uiLabelStyle.copyWith(fontSize: 15, color: ElioColors.espresso)),
                      ),
                      Icon(Icons.edit_outlined, size: 16, color: ElioColors.mocha.withValues(alpha: 0.5)),
                    ],
                  ),
                  if (reqs.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: reqs.map((r) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ElioColors.espresso.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(r, style: ElioText.label.copyWith(fontSize: 11, color: ElioColors.espresso)),
                      )).toList(),
                    ),
                  ] else
                    Text('No dietary requirements',
                        style: ElioText.bodyMedium.copyWith(color: ElioColors.mocha, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
