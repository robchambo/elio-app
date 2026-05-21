// lib/screens/account/account_screen.dart
//
// Sprint 16.1 — Settings redesign per Rob's docx
// (`docs/strategy/Elio settings.docx`).
//
// Replaces the legacy single-list "Account" screen with a four-section
// Settings tree: Household / Preferences / Account / About. Some rows
// inline their control (Measurement Units, Region, Saver Mode) — the
// rest push to existing sub-screens.
//
// File name kept as `account_screen.dart` so the AppShell top-bar
// person-icon route doesn't change. The class is still `AccountScreen`
// but the rendered title is "settings." per the new structure.
//
// What's new vs the old screen:
//   - Sectioned iOS-style layout (cream-deep grouped tiles)
//   - Inline segmented controls for Units + Region (no sub-screen)
//   - Inline switch for Saver Mode default (writes to user doc)
//   - Account section now includes Restore Purchases + Delete Account
//   - About section (Privacy / ToS / Export / Feedback / Version)
//   - GDPR services (AccountService.deleteAccount,
//     DataExportService.exportData) wired
//   - Privacy / ToS render via in-app LegalDocScreen from bundled
//     markdown (no url_launcher dep needed for this phase)
//   - Send Feedback shows a dialog with the support email + tap-to-copy
//
// What's removed:
//   - "Food Style" tile — dropped per Rob's review of the docx
//   - Pre-Sprint 16.1 settings_screen.dart — its content is now inline

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../services/account_service.dart';
import '../../services/auth_service.dart';
import '../../services/data_export_service.dart';
import '../../services/firestore_service.dart';
import '../../services/guest_pantry_service.dart';
import '../../services/legal_links.dart';
import '../../services/purchase_service.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';
import '../../utils/region_utils.dart';
import '../../widgets/elio/elio_page_title.dart';
import '../../widgets/elio/elio_provider_signin_button.dart';
import '../auth/email_login_screen.dart';
import '../profile/dietary_screen.dart';
import '../profile/household_screen.dart';
import '../profile/kitchen_screen.dart';
import '../profile/notification_prefs_screen.dart';
import '../shell/app_shell.dart';
import 'account_actions.dart';
import 'legal_doc_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final FirestoreService _firestore = FirestoreService();

  bool _loading = true;
  String _measurementUnits = 'metric';
  // 21 May 2026 — canonical region value is lowercase ('uk' / 'us' /
  // 'other'), matching what onboarding screen 09 writes via
  // `_RegionOption.value`. Settings used to default to 'US'
  // (uppercase) and offer `('US', 'US') / ('UK', 'UK')` toggle
  // options, so the value read back from Firestore (lowercase) never
  // matched either option → nothing selected on settings open. Plus
  // 'other' was missing from settings entirely despite being a valid
  // onboarding choice.
  String _region = 'us';
  bool _saverModeDefault = false;
  String _appVersion = '';

  // Sprint 16.1.x — Auth UX fix. Captures the signed-in/out state at
  // build time so the Account + About sections can show the right
  // tiles. Re-read fresh each time the screen is opened: sign-in
  // pushes AppShell as new root (EmailLoginScreen.handleSignIn does
  // pushAndRemoveUntil), and our _signOut routes via AuthGate, so a
  // new AccountScreen instance picks up the new auth state on the
  // next visit. No need to listen to authStateChanges here.
  bool get _isSignedIn => FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  Future<void> _loadEverything() async {
    try {
      final settings = await _firestore.getSettings();
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      // Sprint 16.6.x — every APK is stamped by build.ps1 with a
      // BUILD_LABEL like "0.16.6-restock+a85e273" so testers can read
      // off the exact commit they're on instead of inferring from the
      // pubspec semver (which sits at 1.0.0 until launch). Falls back
      // to pubspec version + buildNumber for flutter run/IDE builds
      // that don't set BUILD_LABEL.
      const buildLabel =
          String.fromEnvironment('BUILD_LABEL', defaultValue: '');
      final version = buildLabel.isNotEmpty
          ? buildLabel
          : '${info.version}+${info.buildNumber}';
      setState(() {
        _measurementUnits =
            (settings['measurementUnits'] as String?) ?? 'metric';
        // Canonicalise to lowercase. Older accounts may have a stored
        // 'US' / 'UK' value from before the case was normalised — accept
        // either and re-emit as the canonical form so subsequent writes
        // clean up the underlying Firestore doc.
        _region = ((settings['region'] as String?) ?? 'us').toLowerCase();
        _saverModeDefault =
            (settings['saverModeDefault'] as bool?) ?? false;
        _appVersion = version;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Setting writers ──────────────────────────────────────────────

  Future<void> _setUnits(String units) async {
    setState(() => _measurementUnits = units);
    // Sprint 16.6.x: push to RegionUtils in-memory cache too, so the
    // NEXT generation reads the new value instead of waiting until
    // the next app cold-start to pick it up from Firestore. Mirrors
    // what `_setRegion` already does for the region toggle.
    RegionUtils.setMeasurementUnits(units);
    await _firestore.updateSettings(measurementUnits: units);
  }

  Future<void> _setRegion(String region) async {
    setState(() => _region = region);
    final canonical = region.toLowerCase();
    final AppRegion target;
    switch (canonical) {
      case 'uk':
        target = AppRegion.uk;
      case 'ca':
        target = AppRegion.ca;
      case 'au':
        target = AppRegion.au;
      default:
        // 'us' + legacy 'other' both land here. Mirrors
        // app_shell._hydrateRegionUtils.
        target = AppRegion.us;
    }
    RegionUtils.setRegion(target);
    await _firestore.updateSettings(region: canonical);
  }

  Future<void> _setSaverMode(bool value) async {
    setState(() => _saverModeDefault = value);
    await _firestore.updateSettings(saverModeDefault: value);
  }

  // ─── Region picker ────────────────────────────────────────────────

  // Sprint 17 — single source of truth for region display labels in
  // Settings. Keep in sync with onboarding screen 09's `_regionOptions`.
  static const List<(String, String)> _regionPickerOptions = [
    ('uk', 'United Kingdom'),
    ('us', 'United States'),
    ('ca', 'Canada'),
    ('au', 'Australia'),
  ];

  String _regionDisplayLabel(String value) {
    for (final (v, label) in _regionPickerOptions) {
      if (v == value) return label;
    }
    // Legacy 'other' accounts (Sprint 16 and earlier) — the value is
    // still mapped to US in RegionUtils, but the row shows it honestly
    // so the user knows to re-pick.
    if (value == 'other') return 'Other (legacy)';
    return value;
  }

  Future<void> _openRegionPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ElioColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  'Region',
                  style: ElioTextStyles.heading5,
                ),
              ),
              for (final (value, label) in _regionPickerOptions)
                InkWell(
                  onTap: () => Navigator.of(sheetContext).pop(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: ElioTextStyles.uiLabelStyle,
                          ),
                        ),
                        if (value == _region)
                          const Icon(
                            Icons.check_rounded,
                            size: 22,
                            color: ElioColors.terracotta,
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != _region) {
      await _setRegion(picked);
    }
  }

  // ─── Account actions ──────────────────────────────────────────────

  Future<void> _openManageSubscription() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Manage your subscription in the Play Store or App Store.',
        ),
        backgroundColor: ElioColors.espresso,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _restorePurchases() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 1),
        content: Text('Restoring purchases…'),
      ),
    );
    try {
      await PurchaseService.instance.restorePurchases();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Purchases restored.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.cream,
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
    // Sprint 16.1.x: delegate to the unit-tested helper. Crucially this
    // does NOT wipe `onboardingComplete` — pre-fix, sign-out threw the
    // user back into the 15-screen onboarding flow on the next pump.
    // Now they land on AppShell as a guest with the Sign In tile
    // visible right here on AccountScreen for a single-tap return.
    await performSignOut(firebaseSignOut: AuthService().signOut);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  /// Sprint 16.1.x — Auth UX fix. Guest-user single-tap path to sign
  /// in without forcing the user to redo the entire 15-screen
  /// onboarding flow. Pushes EmailLoginScreen which already routes
  /// to AppShell on success via `pushAndRemoveUntil`, so we don't
  /// need to pop back here — the whole AccountScreen instance is
  /// disposed and a fresh one will be built next visit.
  /// Sprint 16.1.x — Auth UX fix.
  /// Sprint 16.6.x — provider-chooser sheet.
  ///
  /// First version pushed `EmailLoginScreen` directly, which locked out
  /// every Google-only account (the most common kind in dev + early
  /// users) — they'd see the form, have no password, and be stuck.
  /// This version mirrors the onboarding screen 15 provider-button
  /// pattern: a bottom sheet with Google + Email options. Apple is
  /// hidden until Sprint 19. After a successful sign-in the user is
  /// routed to AppShell so the new entitlement / pantry state is
  /// fresh.
  Future<void> _signIn() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ElioColors.cream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ElioSpacing.xl,
            ElioSpacing.md,
            ElioSpacing.xl,
            ElioSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: ElioSpacing.md),
                  decoration: BoxDecoration(
                    color: ElioColors.rule,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'sign in.',
                style: ElioTextStyles.pageTitleStyle.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 6),
              Text(
                'Continue with the account you used at sign-up.',
                style: ElioTextStyles.bodySmallStyle.copyWith(
                  color: ElioColors.mocha,
                ),
              ),
              const SizedBox(height: ElioSpacing.lg),
              ElioProviderSignInButton(
                kind: ProviderButtonKind.google,
                onPressed: () async {
                  Navigator.of(sheetCtx).pop();
                  await _signInWithGoogle();
                },
              ),
              const SizedBox(height: ElioSpacing.sm),
              ElioProviderSignInButton(
                kind: ProviderButtonKind.email,
                onPressed: () async {
                  Navigator.of(sheetCtx).pop();
                  await _signInWithEmail();
                },
              ),
            ],
          ),
        ),
      ),
    );
    // Refresh in case sign-in raced our pop (or the sheet was just
    // dismissed). EmailLoginScreen does pushAndRemoveUntil to AppShell
    // on success; Google success path also routes to AppShell, so the
    // typical case is we're never here. Defensive only.
    if (mounted) setState(() {});
  }

  /// Sprint 16.6.x — Google sign-in from the in-app provider sheet.
  /// Uses the same `AuthService.signInWithGoogle()` as onboarding screen 15.
  /// On success, route to AppShell so post-sign-in state (Pro entitlement,
  /// Firestore pantry, etc.) renders fresh. On cancel / failure, stay
  /// where the user is and surface a snackbar.
  Future<void> _signInWithGoogle() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final cred = await AuthService().signInWithGoogle();
      if (!mounted) return;
      if (cred == null) {
        // User cancelled the Google chooser — silent.
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Couldn\'t sign in with Google: $e',
          ),
          backgroundColor: ElioColors.error,
        ),
      );
    }
  }

  /// Sprint 16.6.x — Email sign-in from the in-app provider sheet.
  /// Pushes the existing EmailLoginScreen which handles its own AppShell
  /// routing on success.
  Future<void> _signInWithEmail() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
    );
    if (mounted) setState(() {});
  }

  /// Sprint 16.1.x — Auth UX fix. Deliberate "I want to walk the
  /// onboarding flow again" action. Distinct from Sign Out: this
  /// clears the guest-pantry state, wipes the onboardingComplete
  /// flag, and routes through AuthGate which will land on
  /// OnboardingFlow. Useful for QA (Rob testing onboarding changes)
  /// and for real users who want a clean reset.
  Future<void> _restartOnboarding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.cream,
        title: const Text('Restart onboarding?'),
        content: const Text(
          'This signs you out and walks you through the setup flow again. '
          'Your Firestore data (recipes, dietary, household) is kept — '
          'only the local guest selections and onboarding progress are '
          'cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Restart',
              style: TextStyle(color: ElioColors.terracotta),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await performRestartOnboarding(
      firebaseSignOut: AuthService().signOut,
      clearGuestPantry: GuestPantryService().clear,
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.cream,
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your account, recipes, and pantry. '
          'This cannot be undone. You may need to sign in again to confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete forever',
              style: TextStyle(color: ElioColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('Deleting your account…'),
      ),
    );
    final result = await AccountService.instance.deleteAccount(
      reauth: _reauthForDelete,
    );
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    switch (result) {
      case DeleteAccountSuccess():
        // Clear local onboarding flag and route to AuthGate.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboardingComplete', false);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );
      case DeleteAccountCancelled():
        // User backed out — silent.
        break;
      case DeleteAccountFailed(:final stage, :final message):
        messenger.showSnackBar(
          SnackBar(content: Text('Delete failed at $stage: $message')),
        );
    }
  }

  /// Sprint 16.1 V1 re-auth callback. Supports Google sign-in (Rob's
  /// primary flow). Email/password and Apple are deferred — they show
  /// a snackbar pointing the user at Google for now.
  ///
  /// Returns `null` to signal user-cancelled or unsupported provider →
  /// AccountService aborts the delete cleanly.
  Future<AuthCredential?> _reauthForDelete(String providerId) async {
    if (providerId == GoogleAuthProvider.PROVIDER_ID) {
      try {
        // Re-trigger Google's account picker. We grab the credential
        // BEFORE signing in so we can hand it to AccountService for
        // reauthenticateWithCredential.
        final googleSignIn = GoogleSignIn();
        final account = await googleSignIn.signIn();
        if (account == null) return null;
        final auth = await account.authentication;
        return GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        );
      } catch (_) {
        return null;
      }
    }
    // Email/password and Apple flows pending — show guidance.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account deletion currently requires Google sign-in. '
            'Email us at ${LegalLinks.supportEmail} for help.',
          ),
        ),
      );
    }
    return null;
  }

  // ─── About actions ────────────────────────────────────────────────

  Future<void> _exportData() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 1),
        content: Text('Building your data export…'),
      ),
    );
    try {
      final result = await DataExportService.instance.exportAndShare();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      switch (result) {
        case DataExportSuccess():
          // share_plus already showed the system share sheet; nothing
          // more to do here.
          break;
        case DataExportNotSignedIn():
          messenger.showSnackBar(
            const SnackBar(content: Text('Sign in to export your data.')),
          );
        case DataExportFailed(:final message):
          messenger.showSnackBar(
            SnackBar(content: Text('Export failed: $message')),
          );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _sendFeedback() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ElioColors.cream,
        title: const Text('Send feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email us at:',
              style: ElioTextStyles.bodyStyle,
            ),
            const SizedBox(height: 8),
            SelectableText(
              LegalLinks.supportEmail,
              style: ElioTextStyles.uiLabelStyle.copyWith(
                color: ElioColors.terracotta,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap "Copy" to put the address on your clipboard, then '
              'paste into your mail app.',
              style: ElioTextStyles.bodySmallStyle,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                  const ClipboardData(text: LegalLinks.supportEmail));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email copied to clipboard.')),
              );
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElioColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: ElioColors.espresso),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: ElioColors.terracotta),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                ElioSpacing.xl,
                0,
                ElioSpacing.xl,
                ElioSpacing.xxxl,
              ),
              children: [
                const ElioPageTitle('settings.'),
                const SizedBox(height: ElioSpacing.xl),

                // ── Household ───────────────────────────────────────
                _Section(
                  title: 'Household',
                  rows: [
                    _PushRow(
                      label: 'Manage household members',
                      onTap: () => _push(const HouseholdScreen()),
                    ),
                    _PushRow(
                      label: 'Dietary & Allergens',
                      onTap: () => _push(const DietaryScreen()),
                    ),
                    _PushRow(
                      label: 'Kitchen Appliances',
                      onTap: () => _push(const KitchenScreen()),
                    ),
                  ],
                ),

                // ── Preferences ─────────────────────────────────────
                _Section(
                  title: 'Preferences',
                  rows: [
                    _SegmentedRow(
                      label: 'Measurement Units',
                      options: const [('metric', 'Metric'), ('imperial', 'Imperial')],
                      value: _measurementUnits,
                      onChanged: _setUnits,
                    ),
                    _PickerRow(
                      label: 'Region',
                      // Sprint 17 — replaced segmented control (was UK/
                      // US/Other) with a 4-option modal picker (UK / US
                      // / CA / AU). Legacy 'other' accounts render as
                      // "Other (legacy)" in the row until the user
                      // picks a real region.
                      value: _region,
                      displayFor: _regionDisplayLabel,
                      onTap: () => _openRegionPicker(context),
                    ),
                    _PushRow(
                      label: 'Notifications',
                      onTap: () => _push(const NotificationPrefsScreen()),
                    ),
                    _SwitchRow(
                      label: 'Saver Mode default',
                      subtitle: 'Start each recipe in budget-friendly mode',
                      value: _saverModeDefault,
                      onChanged: _setSaverMode,
                    ),
                  ],
                ),

                // ── Account ─────────────────────────────────────────
                // Sprint 16.1.x — Auth UX fix. Sign In is shown to
                // guests only; Sign Out + Delete Account hidden for
                // guests (you can't sign out of nothing). Manage
                // Subscription + Restore Purchases stay always visible
                // — they go through the store directly, no Firebase
                // auth needed.
                _Section(
                  title: 'Account',
                  rows: [
                    if (!_isSignedIn)
                      _ActionRow(
                        label: 'Sign In',
                        onTap: _signIn,
                      ),
                    _PushRow(
                      label: 'Manage Subscription',
                      onTap: _openManageSubscription,
                    ),
                    _ActionRow(
                      label: 'Restore Purchases',
                      onTap: _restorePurchases,
                    ),
                    if (_isSignedIn)
                      _ActionRow(
                        label: 'Sign Out',
                        onTap: _signOut,
                      ),
                    if (_isSignedIn)
                      _ActionRow(
                        label: 'Delete Account',
                        destructive: true,
                        onTap: _deleteAccount,
                      ),
                  ],
                ),

                // ── About ───────────────────────────────────────────
                _Section(
                  title: 'About',
                  rows: [
                    _PushRow(
                      label: 'Privacy Policy',
                      onTap: () => _push(const LegalDocScreen(
                        assetPath: 'privacy-policy.md',
                        title: 'Privacy Policy',
                      )),
                    ),
                    _PushRow(
                      label: 'Terms of Service',
                      onTap: () => _push(const LegalDocScreen(
                        assetPath: 'terms-of-service.md',
                        title: 'Terms of Service',
                      )),
                    ),
                    _ActionRow(
                      label: 'Export My Data',
                      onTap: _exportData,
                    ),
                    _ActionRow(
                      label: 'Send Feedback',
                      onTap: _sendFeedback,
                    ),
                    // Sprint 16.1.x — deliberate opt-in path to redo
                    // the onboarding flow. Distinct from Sign Out:
                    // wipes guest pantry + onboardingComplete and
                    // routes to OnboardingFlow via AuthGate. Useful
                    // for QA and for real users who want a reset.
                    _ActionRow(
                      label: 'Restart Onboarding',
                      onTap: _restartOnboarding,
                    ),
                    _StaticRow(
                      label: 'App Version',
                      value: _appVersion.isEmpty ? '—' : _appVersion,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

// ═══════════════════════════════════════════════════════════════════
// Layout primitives
// ═══════════════════════════════════════════════════════════════════

/// A labelled section of the Settings list. Renders an eyebrow header
/// then a single rounded cream-deep panel containing the [rows], with
/// thin rule dividers between them.
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ElioSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, ElioSpacing.sm),
            child: Text(
              title.toUpperCase(),
              style: ElioTextStyles.eyebrowStyle.copyWith(
                color: ElioColors.mocha,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: ElioColors.creamDeep,
              borderRadius: BorderRadius.circular(ElioRadii.card),
              border: Border.all(color: ElioColors.rule, width: 1),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i < rows.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(height: 1, color: ElioColors.rule),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Push-style row — title + chevron, full-width tap.
class _PushRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PushRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ElioRadii.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: ElioTextStyles.uiLabelStyle),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: ElioColors.mocha,
            ),
          ],
        ),
      ),
    );
  }
}

/// Picker row — label on the left, current value + chevron on the
/// right. Tap opens a modal bottom sheet (or any picker) via [onTap].
/// Used for Region in Sprint 17 (4 options too many for the inline
/// segmented control).
class _PickerRow extends StatelessWidget {
  final String label;
  final String value;
  final String Function(String value) displayFor;
  final VoidCallback onTap;
  const _PickerRow({
    required this.label,
    required this.value,
    required this.displayFor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ElioRadii.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: ElioTextStyles.uiLabelStyle),
            ),
            Text(
              displayFor(value),
              style: ElioTextStyles.uiLabelStyle.copyWith(
                color: ElioColors.mocha,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: ElioColors.mocha,
            ),
          ],
        ),
      ),
    );
  }
}

/// Action row — title only, no chevron. Optional [destructive] flag
/// renders the label in the error colour for the Delete Account case.
class _ActionRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _ActionRow({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ElioRadii.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          label,
          style: ElioTextStyles.uiLabelStyle.copyWith(
            color: destructive ? ElioColors.error : ElioColors.espresso,
          ),
        ),
      ),
    );
  }
}

/// Inline segmented control row — label on the left, segments on the
/// right. Used for Measurement Units + Region.
class _SegmentedRow extends StatelessWidget {
  final String label;
  final List<(String, String)> options; // (value, displayLabel)
  final String value;
  final ValueChanged<String> onChanged;
  const _SegmentedRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: ElioTextStyles.uiLabelStyle)),
          Container(
            decoration: BoxDecoration(
              color: ElioColors.cream,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ElioColors.rule, width: 1),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (val, display) in options)
                  GestureDetector(
                    onTap: () {
                      if (val != value) onChanged(val);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: val == value
                            ? ElioColors.terracotta
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        display,
                        style: ElioTextStyles.uiLabelStyle.copyWith(
                          color: val == value
                              ? Colors.white
                              : ElioColors.espresso,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline switch row — title + optional subtitle on the left, Switch
/// on the right.
class _SwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ElioTextStyles.uiLabelStyle),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: ElioTextStyles.bodySmallStyle),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: ElioColors.terracotta,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// Static info row — label + read-only value. Used for App Version.
///
/// 17 May 2026: switched from Row(Expanded(label), Text(value)) to
/// a Column. The old layout broke once build labels exceeded ~20
/// chars: `Text(value)` reports its intrinsic width to the Row,
/// which squeezed the Expanded label down to its smallest possible
/// width (1 character per line, vertical). Rob screenshot showed
/// "App Version" stacked vertically with the value spilling
/// horizontally off-screen. Stacking label-above-value sidesteps
/// the intrinsic-width tug-of-war and lets the mono value soft-
/// wrap onto a second line when it's longer than the screen.
class _StaticRow extends StatelessWidget {
  final String label;
  final String value;
  const _StaticRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ElioTextStyles.uiLabelStyle),
          const SizedBox(height: 4),
          Text(
            value,
            softWrap: true,
            style: ElioTextStyles.bodySmallStyle.copyWith(
              color: ElioColors.mocha,
              fontFamily: 'DM Mono',
            ),
          ),
        ],
      ),
    );
  }
}
