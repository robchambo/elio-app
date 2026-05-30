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
//
// Sprint 16-rebrand polish — tabs are now hosted in a PageView so the user
// can swipe horizontally between Home / Pantry / Recipes / Shopping list.
// Tap on the bottom-nav and swipe both feed through `_selectTab` which
// keeps `_tab`, the controller, and the back-history in sync.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../utils/region_utils.dart';
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
  late final PageController _pageController;

  // Sprint 17 (28 May 2026) — auth-state subscription so AppShell + its
  // children re-render when Firebase Auth restoration completes late
  // (Rob's "signed out on cold restart" bug from S17--27may-a). Without
  // this, the only path that flips `_isSignedIn` is a manual sign-out
  // tile tap or a navigator pop back to AppShell after sign-in.
  StreamSubscription<User?>? _authSub;

  // Order must match the PageView children below and the index/enum mapping.
  static const List<ElioNavTab> _tabOrder = <ElioNavTab>[
    ElioNavTab.home,
    ElioNavTab.pantry,
    ElioNavTab.recipes,
    ElioNavTab.shoppingList,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tabOrder.indexOf(_tab));
    _hydrateRegionUtils();

    // Subscribe to auth-state changes. The stream emits the current
    // user (or null) immediately, plus every subsequent restoration /
    // sign-in / sign-out. setState reruns build → children that depend
    // on FirebaseAuth.instance.currentUser (e.g. AccountScreen's
    // _isSignedIn, the Pantry tab's Firestore reads) see the new
    // state next frame. Cheap: rebuild is local, PageView children
    // re-render lazily.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() {});
      // If a user has just been restored (was null at AppShell mount
      // but is non-null now), re-hydrate RegionUtils from their
      // Firestore settings now that we have a uid.
      if (user != null) {
        _hydrateRegionUtils();
      }
    });
  }

  /// Sprint 16.6.x — pull the user's measurement-units + region prefs
  /// out of Firestore and push them into the in-memory [RegionUtils]
  /// cache so the very first generation reads the right values. The
  /// AccountScreen used to be the only writer to RegionUtils, which
  /// meant a cold-started app stayed on the metric/US defaults until
  /// the user happened to visit Settings. Fire-and-forget.
  Future<void> _hydrateRegionUtils() async {
    // Sprint 17 — sign-out preserves `onboardingComplete=true` (per the
    // 16.1.x Auth UX fix), which means AuthGate can route a signed-out
    // user straight to AppShell. `FirestoreService.getSettings()` reads
    // `_uid` synchronously and throws StateError if no user is signed
    // in. Guests keep the in-memory RegionUtils defaults (metric / US,
    // overridable via Settings). See Crashes row
    // `36c4718e-358a-81ea-9b18-c679ba28f7b7`.
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      final settings = await FirestoreService().getSettings();
      final units = settings['measurementUnits'] as String?;
      final region = (settings['region'] as String?)?.toLowerCase();
      if (units == 'metric' || units == 'imperial') {
        RegionUtils.setMeasurementUnits(units!);
      }
      switch (region) {
        case 'uk':
          RegionUtils.setRegion(AppRegion.uk);
        case 'ca':
          RegionUtils.setRegion(AppRegion.ca);
        case 'au':
          RegionUtils.setRegion(AppRegion.au);
        case 'us':
        case 'other':
          // Legacy 'other' accounts (Sprint 16 and earlier) keep
          // falling back to US for cost/currency until the user
          // picks a real region in Settings. Matches
          // account_screen._setRegion.
          RegionUtils.setRegion(AppRegion.us);
      }
    } catch (_) {
      // Best-effort. RegionUtils retains its defaults on failure.
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Single state-mutation path for both tap and swipe.
  ///
  /// `animate=true` (tap) animates the PageView; `false` (called from
  /// onPageChanged or back-button) just syncs state without re-driving the
  /// controller.
  void _selectTab(ElioNavTab next, {bool animate = true}) {
    if (next == _tab) return;
    // Sprint 16.7c — AppShell hosts a single root ScaffoldMessenger that
    // all four PageView children share. A snackbar fired from one tab
    // (e.g. "Removed Sausages." from Pantry) otherwise persists across
    // tab switches because changing tabs isn't a Navigator pop event,
    // so the messenger queue isn't cleared. Clear on every tab change
    // for consistent behaviour across all current and future snackbars.
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _tabHistory.add(_tab);
      _tab = next;
    });
    if (animate) {
      final index = _tabOrder.indexOf(next);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _goToTabFromHistory(ElioNavTab next) {
    // Same rationale as in _selectTab — clear pending snackbars on the
    // back-button path too, so a snackbar from the leaving tab doesn't
    // follow the user across.
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _tab = next;
    });
    final index = _tabOrder.indexOf(next);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Only allow the system to actually pop (i.e. exit the app) when
      // we're on Home with no tab history. Otherwise we intercept.
      canPop: _tabHistory.isEmpty && _tab == ElioNavTab.home,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_tabHistory.isNotEmpty) {
          _goToTabFromHistory(_tabHistory.removeLast());
          return;
        }
        if (_tab != ElioNavTab.home) {
          _goToTabFromHistory(ElioNavTab.home);
        }
      },
      child: ElioAppScaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            final next = _tabOrder[index];
            // animate=false because the user already drove the controller
            // by swiping; we just need to sync _tab + history.
            _selectTab(next, animate: false);
          },
          children: const <Widget>[
            HomeScreen(),
            PantryScreen(),
            RecipesTabScreen(),
            ShoppingListScreen(),
          ],
        ),
        activeTab: _tab,
        onTabChanged: _selectTab,
        onProfileTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccountScreen()),
        ),
      ),
    );
  }
}
