// lib/screens/account/account_screen.dart
//
// Sprint 16 Phase 6 — Account screen replaces the legacy multi-tab
// ProfileScreen as the destination of the top-bar person-icon tap. It is a
// simple list of tiles, one per sub-screen, matching the V1 user flow.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/elio/elio_hero_heading.dart';
import '../../widgets/elio/elio_secondary_card.dart';
import '../../main.dart';
import '../profile/dietary_screen.dart';
import '../profile/household_screen.dart';
import '../profile/kitchen_screen.dart';
import '../profile/settings_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _openSubscriptionManagement(BuildContext context) async {
    // url_launcher is not in pubspec yet — surface guidance instead of
    // fake UI. Play Store / App Store management still works via the
    // system's own subscription center.
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Manage your subscription in the Play Store or App Store.',
        ),
        backgroundColor: ElioColors.navy,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access your recipes and meal plans.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: ElioColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService().signOut();
    if (!context.mounted) return;
    // Also clear the onboardingComplete flag so AuthGate sends the user
    // back through the onboarding flow.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', false);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ElioColors.navy),
      ),
      body: ListView(
        padding: const EdgeInsets.all(ElioSpacing.xl),
        children: [
          const ElioHeroHeading(
            lines: ['your', 'account'],
            amberLastLine: true,
            showUnderline: true,
          ),
          const SizedBox(height: ElioSpacing.xl),
          ElioSecondaryCard(
            title: 'Subscription',
            subtitle: 'Manage your Elio Pro plan',
            actionLabel: 'Open',
            onAction: () => _openSubscriptionManagement(context),
          ),
          const SizedBox(height: ElioSpacing.md),
          ElioSecondaryCard(
            title: 'Household',
            subtitle: 'Add or edit household members',
            actionLabel: 'Open',
            onAction: () => _push(context, const HouseholdScreen()),
          ),
          const SizedBox(height: ElioSpacing.md),
          ElioSecondaryCard(
            title: 'Dietary & Allergens',
            subtitle: "What you can and can't eat",
            actionLabel: 'Open',
            onAction: () => _push(context, const DietaryScreen()),
          ),
          const SizedBox(height: ElioSpacing.md),
          ElioSecondaryCard(
            title: 'Food Style',
            subtitle: 'Comfort food, healthy, spicy...',
            actionLabel: 'Open',
            onAction: () => _push(context, const SettingsScreen()),
          ),
          const SizedBox(height: ElioSpacing.md),
          ElioSecondaryCard(
            title: 'Kitchen Appliances',
            subtitle: 'Help Elio suggest dishes you can make',
            actionLabel: 'Open',
            onAction: () => _push(context, const KitchenScreen()),
          ),
          const SizedBox(height: ElioSpacing.md),
          ElioSecondaryCard(
            title: 'Metrics',
            subtitle: 'Metric or Imperial units',
            actionLabel: 'Open',
            onAction: () => _push(context, const SettingsScreen()),
          ),
          const SizedBox(height: ElioSpacing.xxl),
          Center(
            child: TextButton(
              onPressed: () => _signOut(context),
              child: Text(
                'Sign out',
                style: ElioTextStyles.uiLabelStyle.copyWith(
                  color: ElioColors.navy.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          const SizedBox(height: ElioSpacing.xl),
        ],
      ),
    );
  }
}
