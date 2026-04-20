import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../widgets/elio/elio_chip.dart';
import '../../widgets/elio/elio_custom_field.dart';
import '../../widgets/elio/elio_eyebrow.dart';
import '../../widgets/elio/elio_hero_heading.dart';

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
  String? _ownerProfileId;
  final TextEditingController _allergenController = TextEditingController();

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
    _allergenController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final profilesSnap = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('profiles').get();
      final owner = profilesSnap.docs.firstWhere(
        (d) => d.data()['isOwner'] == true,
        orElse: () => profilesSnap.docs.first,
      );
      if (mounted) {
        setState(() {
          _ownerProfileId = owner.id;
          _dietaryRequirements = List<String>.from(owner.data()['dietaryRequirements'] ?? []);
          _allergens = List<String>.from(owner.data()['allergies'] ?? []);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
    if (_ownerProfileId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('profiles')
            .doc(_ownerProfileId)
            .update({'dietaryRequirements': updated});
      } catch (_) {
        if (mounted) setState(() => _dietaryRequirements = previous);
        _showSnack('Could not save. Please try again.');
      }
    }
  }

  Future<void> _addAllergen(String allergen) async {
    final trimmed = allergen.trim();
    if (trimmed.isEmpty || _allergens.contains(trimmed)) return;
    final updated = List<String>.from(_allergens)..add(trimmed);
    setState(() => _allergens = updated);
    _allergenController.clear();
    if (_ownerProfileId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('profiles')
            .doc(_ownerProfileId)
            .update({'allergies': updated});
      } catch (_) {
        if (mounted) setState(() => _allergens = List<String>.from(_allergens)..remove(trimmed));
        _showSnack('Could not save. Please try again.');
      }
    }
  }

  Future<void> _removeAllergen(String allergen) async {
    final previous = List<String>.from(_allergens);
    final updated = List<String>.from(_allergens)..remove(allergen);
    setState(() => _allergens = updated);
    if (_ownerProfileId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('profiles')
            .doc(_ownerProfileId)
            .update({'allergies': updated});
      } catch (_) {
        if (mounted) setState(() => _allergens = previous);
        _showSnack('Could not remove. Please try again.');
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: ElioColors.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: ElioColors.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(ElioSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ElioHeroHeading(
                    lines: ['dietary &', 'allergens'],
                    amberLastLine: true,
                  ),
                  const SizedBox(height: ElioSpacing.md),
                  Text(
                    "elio wont suggest recipes that dont work for you.",
                    style: ElioTextStyles.body,
                  ),
                  const SizedBox(height: ElioSpacing.xl),
                  Text('Dietary requirements', style: ElioTextStyles.heading3),
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
                  Text(
                    'Custom allergens or dietary requirements',
                    style: ElioTextStyles.heading3,
                  ),
                  const SizedBox(height: ElioSpacing.sm),
                  Text(
                    "add anything that isn't listed above in the custom text field below",
                    style: ElioTextStyles.bodySmall,
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
                                color: ElioColors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: ElioColors.amber, width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    allergen,
                                    style: ElioTextStyles.body.copyWith(color: ElioColors.navy),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.close, size: 16, color: ElioColors.navy),
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
