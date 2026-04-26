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
}
