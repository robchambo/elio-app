// lib/screens/shell/app_shell.dart
//
// Sprint 16 Phase 2 — top-level shell for authenticated users.
// Provides the 4-tab bottom nav (home / pantry / recipes / shopping list)
// and the elio top app bar via ElioAppScaffold.
//
// Pantry, Recipes, and Shopping List tabs are placeholders until Phase 3+
// ports the existing screens into the new design system.
import 'package:flutter/material.dart';
import '../../widgets/elio/elio_app_scaffold.dart';
import '../../widgets/elio/elio_bottom_nav.dart';
import '../home/home_screen.dart';
import '../pantry/pantry_screen.dart';
import '../profile/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  ElioNavTab _tab = ElioNavTab.home;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    switch (_tab) {
      case ElioNavTab.home:
        body = const HomeScreen();
        break;
      case ElioNavTab.pantry:
        body = const PantryScreen();
        break;
      case ElioNavTab.recipes:
        body = const _Placeholder(label: 'Recipes');
        break;
      case ElioNavTab.shoppingList:
        body = const _Placeholder(label: 'Shopping List');
        break;
    }
    return ElioAppScaffold(
      body: body,
      activeTab: _tab,
      onTabChanged: (t) => setState(() => _tab = t),
      onProfileTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String label;
  const _Placeholder({required this.label});
  @override
  Widget build(BuildContext c) => Center(child: Text('$label — coming soon'));
}
