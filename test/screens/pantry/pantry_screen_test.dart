import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elio_app/screens/pantry/pantry_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugPantryInitialItems = null;
    debugPantryMutationOverride = null;
    debugPantryAddOverride = null;
  });

  tearDown(() {
    debugPantryInitialItems = null;
    debugPantryMutationOverride = null;
    debugPantryAddOverride = null;
  });

  Future<void> pumpPantry(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PantryScreen()),
    ));
    await tester.pumpAndSettle();
  }

  // Sprint 16.4 (Bug 4): tapping a chip is now a no-op. Long-press is
  // the only mutation entry point — chips were vanishing on a stray tap
  // because the cycle ended in delete. Remove now lives only inside the
  // long-press SimpleDialog (covered by the two long-press tests below).

  testWidgets('Tapping a staple chip does NOT mutate the item',
      (tester) async {
    debugPantryInitialItems = [
      {
        'id': 'salt-1',
        'name': 'Salt',
        'tier': 'alwaysHave',
        'runningLow': false,
      },
    ];
    final calls = <Map<String, dynamic>>[];
    debugPantryMutationOverride = (id, action) {
      calls.add({'id': id, ...action});
    };

    await pumpPantry(tester);
    await tester.tap(find.text('Always Have (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Salt'), findsOneWidget);

    await tester.tap(find.text('Salt'));
    await tester.pumpAndSettle();

    expect(calls, isEmpty,
        reason: 'Single tap should be a no-op — only long-press mutates.');
    expect(find.text('Salt'), findsOneWidget);
  });

  testWidgets('Tapping a perishable chip does NOT mutate the item',
      (tester) async {
    final freshExpiry =
        DateTime.now().add(const Duration(days: 7)).toIso8601String();
    debugPantryInitialItems = [
      {
        'id': 'tomato-1',
        'name': 'Tomato',
        'tier': 'perishable',
        'runningLow': false,
        'expiryDate': freshExpiry,
      },
    ];
    final calls = <Map<String, dynamic>>[];
    debugPantryMutationOverride = (id, action) {
      calls.add({'id': id, ...action});
    };

    await pumpPantry(tester);
    await tester.tap(find.text('Perishables (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Tomato'));
    await tester.pumpAndSettle();

    expect(calls, isEmpty,
        reason: 'Single tap should be a no-op — only long-press mutates.');
    expect(find.textContaining('Tomato'), findsOneWidget);
  });

  testWidgets('Long-pressing a staple chip opens tier picker dialog',
      (tester) async {
    debugPantryInitialItems = [
      {
        'id': 'olive-oil-1',
        'name': 'Olive oil',
        'tier': 'alwaysHave',
        'runningLow': false,
      },
    ];
    debugPantryMutationOverride = (_, __) {};

    await pumpPantry(tester);
    await tester.tap(find.text('Always Have (1)'));
    await tester.pumpAndSettle();

    final chip = find.text('Olive oil');
    expect(chip, findsOneWidget);

    await tester.longPress(chip);
    await tester.pumpAndSettle();

    expect(find.text('Always have'), findsOneWidget);
    expect(find.text('Almost always have'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('Long-pressing a perishable opens fresh/thisWeek/today picker',
      (tester) async {
    debugPantryInitialItems = [
      {
        'id': 'spinach-1',
        'name': 'Spinach',
        'tier': 'perishable',
        'runningLow': false,
        'expiryDate':
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      },
    ];
    debugPantryMutationOverride = (_, __) {};

    await pumpPantry(tester);
    await tester.tap(find.text('Perishables (1)'));
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('Spinach'));
    await tester.pumpAndSettle();

    expect(find.text('Mark fresh'), findsOneWidget);
    expect(find.text('Mark this week'), findsOneWidget);
    expect(find.text('Mark today'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
  });

  // Sprint 16.4 (Bug 3): each expanded tier ends in an "+ Add" chip so
  // the user can grow the pantry after onboarding (perishables in
  // particular had no add path).
  testWidgets('Add chip in Always Have tier adds a new staple', (tester) async {
    debugPantryInitialItems = [
      {
        'id': 'salt-1',
        'name': 'Salt',
        'tier': 'alwaysHave',
        'runningLow': false,
      },
    ];
    final added = <Map<String, dynamic>>[];
    debugPantryAddOverride = (name, tier, expiry) {
      added.add({'name': name, 'tier': tier, 'expiry': expiry});
      return 'new-id-${added.length}';
    };

    await pumpPantry(tester);
    await tester.tap(find.text('Always Have (1)'));
    await tester.pumpAndSettle();

    // The "+ Add" chip is the only InkWell with an Icons.add child.
    // Use `.first` because Material wraps InkWell internals.
    final addChip = find
        .ancestor(
          of: find.byIcon(Icons.add),
          matching: find.byType(InkWell),
        )
        .first;
    await tester.tap(addChip);
    await tester.pumpAndSettle();

    // Dialog open for the right category.
    expect(find.text('Add to Always Have'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Olive oil');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add'));
    await tester.pumpAndSettle();

    expect(added, hasLength(1));
    expect(added.first['name'], 'Olive oil');
    expect(added.first['tier'], 'alwaysHave');
    expect(added.first['expiry'], isNull);
    expect(find.text('Olive oil'), findsOneWidget);
  });

  // Sprint 16.6.x (Restock wiring): long-press picker exposes a
  // "Mark running low" toggle. Picking it dispatches a
  // `toggleRunningLow` mutation and (in production) also adds the
  // item to the shopping list with source: restock. The chip then
  // shows a small "Low" badge so the state is visible from the
  // pantry without having to long-press again.
  testWidgets('Long-pressing a not-low staple shows "Mark running low"',
      (tester) async {
    debugPantryInitialItems = [
      {
        'id': 'milk-1',
        'name': 'Milk',
        'tier': 'almostAlwaysHave',
        'runningLow': false,
      },
    ];
    debugPantryMutationOverride = (_, __) {};

    await pumpPantry(tester);
    await tester.tap(find.text('Almost Always Have (1)'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();

    expect(find.text('Mark running low'), findsOneWidget);
    expect(find.text('Unmark running low'), findsNothing);
  });

  testWidgets(
      'Long-pressing an already-low staple shows "Unmark running low"',
      (tester) async {
    debugPantryInitialItems = [
      {
        'id': 'milk-1',
        'name': 'Milk',
        'tier': 'almostAlwaysHave',
        'runningLow': true,
      },
    ];
    debugPantryMutationOverride = (_, __) {};

    await pumpPantry(tester);
    await tester.tap(find.text('Almost Always Have (1)'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();

    expect(find.text('Unmark running low'), findsOneWidget);
    expect(find.text('Mark running low'), findsNothing);
  });

  testWidgets(
      'Picking "Mark running low" dispatches toggleRunningLow mutation',
      (tester) async {
    debugPantryInitialItems = [
      {
        'id': 'milk-1',
        'name': 'Milk',
        'tier': 'almostAlwaysHave',
        'runningLow': false,
      },
    ];
    final calls = <Map<String, dynamic>>[];
    debugPantryMutationOverride = (id, action) {
      calls.add({'id': id, ...action});
    };

    await pumpPantry(tester);
    await tester.tap(find.text('Almost Always Have (1)'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark running low'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.first['id'], 'milk-1');
    expect(calls.first['type'], 'toggleRunningLow');
    expect(calls.first['runningLow'], isTrue);
    expect(calls.first['name'], 'Milk');
  });

  testWidgets(
      'Picking "Unmark running low" dispatches toggleRunningLow=false',
      (tester) async {
    debugPantryInitialItems = [
      {
        'id': 'milk-1',
        'name': 'Milk',
        'tier': 'almostAlwaysHave',
        'runningLow': true,
      },
    ];
    final calls = <Map<String, dynamic>>[];
    debugPantryMutationOverride = (id, action) {
      calls.add({'id': id, ...action});
    };

    await pumpPantry(tester);
    await tester.tap(find.text('Almost Always Have (1)'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unmark running low'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.first['type'], 'toggleRunningLow');
    expect(calls.first['runningLow'], isFalse);
  });

  testWidgets('Running-low staple chip renders a "Low" badge', (tester) async {
    debugPantryInitialItems = [
      {
        'id': 'milk-1',
        'name': 'Milk',
        'tier': 'almostAlwaysHave',
        'runningLow': true,
      },
    ];
    await pumpPantry(tester);
    await tester.tap(find.text('Almost Always Have (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Low'), findsOneWidget);
  });

  testWidgets('Long-pressing a perishable also offers running-low toggle',
      (tester) async {
    debugPantryInitialItems = [
      {
        'id': 'spinach-1',
        'name': 'Spinach',
        'tier': 'perishable',
        'runningLow': false,
        'expiryDate':
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      },
    ];
    debugPantryMutationOverride = (_, __) {};

    await pumpPantry(tester);
    await tester.tap(find.text('Perishables (1)'));
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('Spinach'));
    await tester.pumpAndSettle();

    expect(find.text('Mark running low'), findsOneWidget);
  });

  testWidgets('Add chip in Perishables prompts a freshness bucket',
      (tester) async {
    debugPantryInitialItems = const <Map<String, dynamic>>[];
    final added = <Map<String, dynamic>>[];
    debugPantryAddOverride = (name, tier, expiry) {
      added.add({'name': name, 'tier': tier, 'expiry': expiry});
      return 'new-id';
    };

    await pumpPantry(tester);
    await tester.tap(find.text('Perishables (0)'));
    await tester.pumpAndSettle();

    await tester.tap(find
        .ancestor(
          of: find.byIcon(Icons.add),
          matching: find.byType(InkWell),
        )
        .first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Spinach');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add'));
    await tester.pumpAndSettle();

    // Bucket dialog appears next.
    expect(find.text('How fresh is Spinach?'), findsOneWidget);
    await tester.tap(find.text('Use this week'));
    await tester.pumpAndSettle();

    expect(added, hasLength(1));
    expect(added.first['name'], 'Spinach');
    expect(added.first['tier'], 'perishable');
    expect(added.first['expiry'], isNotNull);
  });
}
