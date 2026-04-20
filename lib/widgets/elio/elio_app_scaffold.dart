// lib/widgets/elio/elio_app_scaffold.dart
import 'package:flutter/material.dart';
import '../../theme/elio_theme.dart';
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
    return Scaffold(
      backgroundColor: ElioColors.offWhite,
      appBar: ElioTopAppBar(onProfileTap: onProfileTap),
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: showBottomNav && activeTab != null && onTabChanged != null
          ? ElioBottomNav(active: activeTab!, onTap: onTabChanged!)
          : null,
    );
  }
}
