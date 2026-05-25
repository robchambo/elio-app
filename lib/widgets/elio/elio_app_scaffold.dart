// lib/widgets/elio/elio_app_scaffold.dart
import 'package:flutter/material.dart';
import '../../screens/pantry/pending_imports_screen.dart';
import '../../services/order_import_service.dart';
import '../../theme/elio_theme.dart';
import 'elio_backdrop_illustration.dart';
import 'elio_bottom_nav.dart';
import 'elio_top_app_bar.dart';

class ElioAppScaffold extends StatelessWidget {
  final Widget body;
  final ElioNavTab? activeTab;
  final ValueChanged<ElioNavTab>? onTabChanged;
  final VoidCallback? onProfileTap;
  final bool showBottomNav;

  const ElioAppScaffold({
    super.key,
    required this.body,
    this.activeTab,
    this.onTabChanged,
    this.onProfileTap,
    this.showBottomNav = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasNav =
        showBottomNav && activeTab != null && onTabChanged != null;
    return Scaffold(
      backgroundColor: ElioColors.cream,
      appBar: ElioTopAppBar(onProfileTap: onProfileTap),
      // Top inset is consumed by the app bar's own SafeArea. Bottom inset
      // is consumed by ElioBottomNav when present; when the nav is hidden
      // (e.g. ShoppingListPage pushed from the meal planner) the body
      // itself must respect the bottom inset to keep CTAs above the
      // system gesture bar / 3-button nav.
      body: SafeArea(
        top: false,
        bottom: !hasNav,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ElioBackdropIllustration(),
            body,
          ],
        ),
      ),
      bottomNavigationBar: hasNav
          ? ElioBottomNav(
              active: activeTab!,
              onTap: onTabChanged!,
              // Pantry-tab dot badge for pending order imports.
              // Default-wires the production service; widget tests
              // that mount ElioBottomNav directly can override.
              pendingImportsStream:
                  FirebaseOrderImportService().pendingImportsStream(),
              // Task 9: tapping the pantry tab while the badge is
              // visible pushes the PendingImportsScreen instead of
              // switching tabs. Once the inbox empties the user lands
              // back on whatever tab they were on.
              onPendingImportsBadgeTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PendingImportsScreen(
                      service: FirebaseOrderImportService(),
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }
}
