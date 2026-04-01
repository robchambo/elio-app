import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
import '../../services/firestore_service.dart';

// ─────────────────────────────────────────────
// KitchenScreen
// Standalone screen for kitchen appliance selection.
// Accessed from Settings.
// ─────────────────────────────────────────────

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  final FirestoreService _firestore = FirestoreService();
  bool _isLoading = true;
  List<String> _appliances = [];

  static const List<String> _allOptions = [
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
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _firestore.getUserData();
      if (mounted) {
        setState(() {
          _appliances = List<String>.from(data['appliances'] ?? []);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    }
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
                    child: const Icon(Icons.arrow_back_ios_new, size: 20, color: ElioColors.navy),
                  ),
                  const SizedBox(width: 12),
                  Text('Kitchen Appliances', style: ElioText.headingLarge),
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
                    Text(
                      "Select the appliances you own and we'll tailor recipes to make the most of them.",
                      style: ElioText.bodyMedium.copyWith(color: ElioColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _allOptions.map((appliance) {
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}
