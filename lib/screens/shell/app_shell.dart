// lib/screens/shell/app_shell.dart
//
// Sprint 16 Phase 2 — top-level shell for authenticated users.
// Provides the 4-tab bottom nav (home / pantry / recipes / shopping list)
// and the elio top app bar via ElioAppScaffold.
//
// Sprint 16 Phase 6 — Shopping and Recipes tabs now use the new standalone
// body-only screens extracted from ProfileScreen.
//
// Sprint 16.3 — Android system back button now pops in-app tab history
// instead of exiting. Pushed routes (recipe, account, etc.) keep their
// normal Navigator-based pop. PopScope only intercepts when the Navigator
// can't pop — i.e. we're at the shell root.
import 'package:flutter/material.dart';
import '../../widgets/elio/elio_app_scaffold.dart';
import '../../widgets/elio/elio_bottom_nav.dart';
import '../account/account_screen.dart';
import '../home/home_screen.dart';
import '../pantry/pantry_screen.dart';
import '../recipes/recipes_tab_screen.dart';
import '../shopping/shopping_list_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  ElioNavTab _tab = ElioNavTab.home;
  final List<ElioNavTab> _tabHistory = <ElioNavTab>[];

  void _onTabSelected(ElioNavTab next) {
    if (next == _tab) return;
    setState(() {
      _tabHistory.add(_tab);
      _tab = next;
    });
  }

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
        body = const RecipesTabScreen();
        break;
      case ElioNavTab.shoppingList:
        body = const ShoppingListScreen();
        break;
    }
    return PopScope(
      // Only allow the system to actually pop (i.e. exit the app) when
      // we're on Home with no tab history. Otherwise we intercept.
      canPop: _tabHistory.isEmpty && _tab == ElioNavTab.home,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_tabHistory.isNotEmpty) {
          setState(() {
            _tab = _tabHistory.removeLast();
          });
          return;
        }
        if (_tab != ElioNavTab.home) {
          setState(() {
            _tab = ElioNavTab.home;
          });
        }
      },
      child: ElioAppScaffold(
        body: body,
        activeTab: _tab,
        onTabChanged: _onTabSelected,
        onProfileTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccountScreen()),
        ),
      ),
    );
  }
}
