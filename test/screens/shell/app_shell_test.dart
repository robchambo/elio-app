// Sprint 16.3 Task 10 — Android system back button.
//
// Verifies AppShell's PopScope intercepts back to walk the tab history
// and only allows the framework to actually pop (i.e. exit the app)
// when we're on Home with no history.
//
// We inspect the PopScope.canPop value directly rather than driving
// real `handlePopRoute` calls — the tab body widgets fire Firebase /
// Firestore reads which aren't fully mocked in the test harness, but
// the shell's intercept logic lives entirely in _AppShellState and is
// independent of what the tab body renders.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:elio_app/screens/shell/app_shell.dart';
import 'package:elio_app/widgets/elio/elio_bottom_nav.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  // ignore: avoid_dynamic_calls
  dynamic findPopScope(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byType(AppShell),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString().startsWith('PopScope'),
      ),
    );
    return tester.widget(finder);
  }

  testWidgets('PopScope.canPop is true on initial Home tab with no history',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pump();

    final popScope = findPopScope(tester);
    expect(popScope.canPop, isTrue,
        reason: 'On Home with no history, system back should exit app');
  });

  testWidgets('Switching tabs disables canPop and back walks history',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pump();

    final state = tester.state<State<AppShell>>(find.byType(AppShell));
    // ignore: avoid_dynamic_calls
    final dynamic shellState = state;

    // Tap PANTRY via the bottom nav.
    final pantryFinder = find.descendant(
      of: find.byType(ElioBottomNav),
      matching: find.text('PANTRY'),
    );
    await tester.tap(pantryFinder, warnIfMissed: false);
    await tester.pump();
    expect(shellState.toString().contains('AppShell'), isTrue);

    // After the switch, canPop should be false (we're not on Home).
    var popScope = findPopScope(tester);
    expect(popScope.canPop, isFalse,
        reason: 'After switching to Pantry, system back must not exit');

    // Tap RECIPES.
    final recipesFinder = find.descendant(
      of: find.byType(ElioBottomNav),
      matching: find.text('RECIPES'),
    );
    await tester.tap(recipesFinder, warnIfMissed: false);
    await tester.pump();

    popScope = findPopScope(tester);
    expect(popScope.canPop, isFalse);

    // Simulate system back: should pop history → Pantry.
    popScope.onPopInvokedWithResult!(false, null);
    await tester.pump();
    popScope = findPopScope(tester);
    expect(popScope.canPop, isFalse,
        reason: 'After popping to Pantry, still not on Home');

    // Simulate system back again: should pop history → Home.
    popScope.onPopInvokedWithResult!(false, null);
    await tester.pump();
    popScope = findPopScope(tester);
    expect(popScope.canPop, isTrue,
        reason: 'After popping back to Home with empty history, exit allowed');
  });

  testWidgets('Back from non-Home tab with empty history jumps to Home',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pump();

    // Switch to Pantry (history: [home]).
    await tester.tap(
      find.descendant(
        of: find.byType(ElioBottomNav),
        matching: find.text('PANTRY'),
      ),
      warnIfMissed: false,
    );
    await tester.pump();

    var popScope = findPopScope(tester);
    expect(popScope.canPop, isFalse);

    // Back → pops to Home, history empties, canPop becomes true.
    popScope.onPopInvokedWithResult!(false, null);
    await tester.pump();
    popScope = findPopScope(tester);
    expect(popScope.canPop, isTrue);
  });
}
