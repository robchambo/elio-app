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
  });

  tearDown(() {
    debugPantryInitialItems = null;
    debugPantryMutationOverride = null;
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

  testWidgets('Tapping an alwaysHave staple chip cycles to almostAlwaysHave',
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

    // Expand "Always Have" tier so the chip is visible.
    await tester.tap(find.text('Always Have (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Salt'), findsOneWidget);
    await tester.tap(find.text('Salt'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.first['id'], 'salt-1');
    expect(calls.first['type'], 'updateTier');
    expect(calls.first['tier'], 'almostAlwaysHave');
  });

  testWidgets(
      'Tapping an almostAlwaysHave chip cycles to removed (delete)',
      (tester) async {
    debugPantryInitialItems = [
      {
        'id': 'mustard-1',
        'name': 'Mustard',
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
    await tester.tap(find.text('Mustard'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.first['type'], 'delete');
    expect(calls.first['id'], 'mustard-1');
  });

  testWidgets('Tapping a fresh perishable cycles to thisWeek expiry',
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

    expect(calls, hasLength(1));
    expect(calls.first['type'], 'updateExpiry');
    final newExpiry = calls.first['expiryDate'] as DateTime;
    final daysAhead = newExpiry.difference(DateTime.now()).inDays;
    // thisWeek = now + 3 days
    expect(daysAhead, inInclusiveRange(2, 3));
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
}
