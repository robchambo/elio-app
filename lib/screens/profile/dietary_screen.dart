import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/elio_theme.dart';

// ─────────────────────────────────────────────
// DietaryScreen
// Standalone screen for dietary requirements & custom allergens.
// Accessed from Settings.
// ─────────────────────────────────────────────

class DietaryScreen extends StatefulWidget {
  const DietaryScreen({super.key});

  @override
  State<DietaryScreen> createState() => _DietaryScreenState();
}

class _DietaryScreenState extends State<DietaryScreen> {
  bool _isLoading = true;
  List<String> _dietaryRequirements = [];
  List<String> _customAllergens = [];
  String? _ownerProfileId;
  final TextEditingController _allergenController = TextEditingController();

  static const List<String> _allOptions = [
    'Vegetarian', 'Vegan', 'Pescatarian', 'Gluten-free', 'Dairy-free',
    'Egg-free', 'Nut-free', 'Soy-free', 'Shellfish-free',
    'Halal', 'Kosher', 'Low FODMAP',
    'Diabetic-friendly', 'Low-carb', 'High-protein',
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
          _customAllergens = List<String>.from(owner.data()['customAllergens'] ?? []);
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
    if (trimmed.isEmpty || _customAllergens.contains(trimmed)) return;
    final updated = List<String>.from(_customAllergens)..add(trimmed);
    setState(() => _customAllergens = updated);
    _allergenController.clear();
    if (_ownerProfileId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('profiles')
            .doc(_ownerProfileId)
            .update({'customAllergens': updated});
      } catch (_) {
        if (mounted) setState(() => _customAllergens = List<String>.from(_customAllergens)..remove(trimmed));
        _showSnack('Could not save. Please try again.');
      }
    }
  }

  Future<void> _removeAllergen(String allergen) async {
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
        if (mounted) setState(() => _customAllergens = previous);
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
      backgroundColor: ElioColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back_ios_new, size: 20, color: ElioColors.navy),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Dietary & Allergens', style: ElioText.headingLarge),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: ElioColors.amber)))
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Dietary requirements', style: ElioText.headingMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Elio will never suggest recipes that don\'t work for you.',
                      style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _allOptions.map((req) {
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
                    Text('Custom allergens or dietary requirements', style: ElioText.headingMedium.copyWith(fontSize: 16)),
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
                                onTap: () => _removeAllergen(allergen),
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
                            controller: _allergenController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Sesame, Shellfish, Mustard...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ElioColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ElioColors.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ElioColors.navy, width: 1.5)),
                              filled: true,
                              fillColor: ElioColors.offWhite,
                            ),
                            style: ElioText.bodyMedium,
                            textCapitalization: TextCapitalization.words,
                            onSubmitted: (value) => _addAllergen(value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _addAllergen(_allergenController.text),
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
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
