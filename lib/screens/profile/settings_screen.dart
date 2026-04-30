import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../services/firestore_service.dart';
import '../../utils/region_utils.dart';
import 'household_screen.dart';
import 'dietary_screen.dart';
import 'kitchen_screen.dart';

// ─────────────────────────────────────────────
// SettingsScreen
// Simple settings page for measurement units and region.
// Changes save immediately to Firestore.
// ─────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirestoreService _firestore = FirestoreService();
  bool _isLoading = true;
  String _measurementUnits = 'metric';
  String _region = 'US';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _firestore.getSettings();
      if (!mounted) return;
      setState(() {
        _measurementUnits = settings['measurementUnits'] ?? 'metric';
        _region = settings['region'] ?? 'US';
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateMeasurementUnits(String units) async {
    setState(() => _measurementUnits = units);
    RegionUtils.setMeasurementUnits(units);
    await _firestore.updateSettings(measurementUnits: units);
  }

  Future<void> _updateRegion(String region) async {
    setState(() => _region = region);
    RegionUtils.setRegion(region == 'UK' ? AppRegion.uk : AppRegion.us);
    await _firestore.updateSettings(region: region);
  }

  @override
  Widget build(BuildContext context) {
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
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back_ios_new, size: 20, color: ElioColors.espresso),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Settings', style: ElioText.headingLarge),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Content ─────────────────────────────────────────────
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator(color: ElioColors.terracotta)),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Household section
                      Text('Household', style: ElioText.headingMedium),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HouseholdScreen()),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: ElioColors.offWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ElioColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people_outline, size: 22, color: ElioColors.espresso),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Manage household members',
                                        style: ElioTextStyles.uiLabelStyle.copyWith(fontSize: 15, color: ElioColors.espresso)),
                                    const SizedBox(height: 2),
                                    Text('Add or remove people and their dietary needs',
                                        style: ElioTextStyles.bodySmallStyle.copyWith(fontSize: 12, color: ElioColors.textSecondary)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 22, color: ElioColors.textMuted),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DietaryScreen()),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: ElioColors.offWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ElioColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.no_meals_outlined, size: 22, color: ElioColors.espresso),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Dietary & Allergens',
                                        style: ElioTextStyles.uiLabelStyle.copyWith(fontSize: 15, color: ElioColors.espresso)),
                                    const SizedBox(height: 2),
                                    Text('Adjust your dietary requirements',
                                        style: ElioTextStyles.bodySmallStyle.copyWith(fontSize: 12, color: ElioColors.textSecondary)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 22, color: ElioColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const KitchenScreen()),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: ElioColors.offWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ElioColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.kitchen_outlined, size: 22, color: ElioColors.espresso),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Kitchen Appliances',
                                        style: ElioTextStyles.uiLabelStyle.copyWith(fontSize: 15, color: ElioColors.espresso)),
                                    const SizedBox(height: 2),
                                    Text('Select the appliances you own',
                                        style: ElioTextStyles.bodySmallStyle.copyWith(fontSize: 12, color: ElioColors.textSecondary)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 22, color: ElioColors.textMuted),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          final info = snapshot.data;
                          final versionLabel = info == null
                              ? 'Loading…'
                              : 'Version ${info.version} (build ${info.buildNumber})';
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: ElioColors.offWhite,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: ElioColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 22, color: ElioColors.espresso),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('About',
                                          style: ElioTextStyles.uiLabelStyle.copyWith(fontSize: 15, color: ElioColors.espresso)),
                                      const SizedBox(height: 2),
                                      Text(versionLabel,
                                          style: ElioTextStyles.bodySmallStyle.copyWith(fontSize: 12, color: ElioColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      // Measurement Units section
                      Text('Measurement Units', style: ElioText.headingMedium),
                      const SizedBox(height: 12),
                      _SettingsCard(
                        label: 'Metric (g, ml, \u00B0C)',
                        isSelected: _measurementUnits == 'metric',
                        onTap: () => _updateMeasurementUnits('metric'),
                      ),
                      const SizedBox(height: 10),
                      _SettingsCard(
                        label: 'Imperial (oz, cups, \u00B0F)',
                        isSelected: _measurementUnits == 'imperial',
                        onTap: () => _updateMeasurementUnits('imperial'),
                      ),

                      const SizedBox(height: 28),

                      // Region section
                      Text('Region', style: ElioText.headingMedium),
                      const SizedBox(height: 12),
                      _SettingsCard(
                        emoji: '\u{1F1FA}\u{1F1F8}',
                        label: 'United States',
                        isSelected: _region == 'US',
                        onTap: () => _updateRegion('US'),
                      ),
                      const SizedBox(height: 10),
                      _SettingsCard(
                        emoji: '\u{1F1EC}\u{1F1E7}',
                        label: 'United Kingdom',
                        isSelected: _region == 'UK',
                        onTap: () => _updateRegion('UK'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Tappable settings card ──────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.label,
    this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? ElioColors.terracotta.withValues(alpha: 0.12) : ElioColors.offWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? ElioColors.terracotta : ElioColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  label,
                  style: ElioText.bodyLarge.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? ElioColors.espresso : ElioColors.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: ElioColors.terracotta, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
