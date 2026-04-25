import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/models/elio_models.dart';
import 'package:elio_app/screens/onboarding/screen12_pantry_perishables.dart';
import 'package:elio_app/services/guest_pantry_service.dart';
import 'package:elio_app/widgets/elio/elio_big_button.dart';
import 'package:elio_app/widgets/elio/elio_pantry_item_tile.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  void useTallViewport(WidgetTester t) {
    t.view.physicalSize = const Size(800, 4000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders 4 category headers', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    expect(find.text('Fresh veg', skipOffstage: false), findsOneWidget);
    expect(find.text('Fresh fruit', skipOffstage: false), findsOneWidget);
    expect(find.text('Fresh meat & fish', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Fresh dairy & herbs', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('no items pre-selected on entry', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    final tiles = t
        .widgetList<ElioPantryItemTile>(
            find.byType(ElioPantryItemTile, skipOffstage: false))
        .toList();
    expect(tiles, isNotEmpty);
    for (final tile in tiles) {
      expect(tile.tier, 'unselected');
    }
  });

  testWidgets('initial footer reads 0 fresh · 0 today', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    expect(find.text('0 fresh · 0 today'), findsOneWidget);
  });

  testWidgets('tap cycles unselected → fresh → thisWeek → today → unselected',
      (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    final onionFinder = find.ancestor(
      of: find.text('Onion', skipOffstage: false),
      matching: find.byType(ElioPantryItemTile, skipOffstage: false),
    );
    await t.ensureVisible(onionFinder);
    await t.pump();

    Future<void> tap() async {
      await t.tap(onionFinder);
      await t.pump();
    }

    ElioPantryItemTile tile() => t.widget<ElioPantryItemTile>(onionFinder);

    expect(tile().tier, 'unselected');
    await tap();
    expect(tile().tier, 'fresh');
    await tap();
    expect(tile().tier, 'thisWeek');
    await tap();
    expect(tile().tier, 'today');
    await tap();
    expect(tile().tier, 'unselected');
  });

  testWidgets('long-press opens a dialog action sheet (not bottom sheet)',
      (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    final onionFinder = find.ancestor(
      of: find.text('Onion', skipOffstage: false),
      matching: find.byType(ElioPantryItemTile, skipOffstage: false),
    );
    await t.ensureVisible(onionFinder);
    await t.pump();
    await t.longPress(onionFinder);
    await t.pumpAndSettle();

    // All four actions must be present.
    expect(find.text('Mark fresh'), findsOneWidget);
    expect(find.text('Mark this week'), findsOneWidget);
    expect(find.text('Mark today'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);

    // Tap "Mark today" → tile jumps to today.
    await t.tap(find.text('Mark today'));
    await t.pumpAndSettle();
    final tile = t.widget<ElioPantryItemTile>(onionFinder);
    expect(tile.tier, 'today');
  });

  testWidgets('footer turns red when at least one item is marked today',
      (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    final onionFinder = find.ancestor(
      of: find.text('Onion', skipOffstage: false),
      matching: find.byType(ElioPantryItemTile, skipOffstage: false),
    );
    await t.ensureVisible(onionFinder);
    await t.pump();
    // Cycle to today (3 taps).
    await t.tap(onionFinder);
    await t.pump();
    await t.tap(onionFinder);
    await t.pump();
    await t.tap(onionFinder);
    await t.pump();

    final footerFinder = find.text('1 fresh · 1 today');
    // We rendered thisWeek between fresh and today. Let's select ONE fresh.
    // Actually after 3 taps the single tile is 'today' and there's 0 fresh,
    // so footer should read "0 fresh · 1 today" with red styling.
    expect(footerFinder, findsNothing);
    final zeroFreshOneToday = find.text('0 fresh · 1 today');
    expect(zeroFreshOneToday, findsOneWidget);
    final textWidget = t.widget<Text>(zeroFreshOneToday);
    expect(textWidget.style?.color, isNotNull);
    // Red channel should dominate on the perishToday coral.
    final c = textWidget.style!.color!;
    expect(c.r, greaterThan(c.g));
    expect(c.r, greaterThan(c.b));
  });

  testWidgets('Continue persists and derives expiry dates + runningLow',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    var continued = false;
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: c,
      onContinue: () => continued = true,
      onBack: () {},
    )));
    await t.pump();

    // Mark Onion today (3 taps) and Tomato fresh (1 tap).
    final onion = find.ancestor(
      of: find.text('Onion', skipOffstage: false),
      matching: find.byType(ElioPantryItemTile, skipOffstage: false),
    );
    await t.ensureVisible(onion);
    await t.pump();
    await t.tap(onion);
    await t.pump();
    await t.tap(onion);
    await t.pump();
    await t.tap(onion);
    await t.pump();

    final tomato = find.ancestor(
      of: find.text('Tomato', skipOffstage: false),
      matching: find.byType(ElioPantryItemTile, skipOffstage: false),
    );
    await t.ensureVisible(tomato);
    await t.pump();
    await t.tap(tomato);
    await t.pump();

    await t.ensureVisible(find.byType(ElioBigButton));
    await t.pump();
    await t.tap(find.byType(ElioBigButton));
    await t.pumpAndSettle();

    expect(continued, isTrue);
    final now = DateTime.now();
    final onionItem =
        c.state.inventory.firstWhere((i) => i.name == 'Onion');
    expect(onionItem.tier, 'perishable');
    expect(onionItem.isRunningLow, isTrue);
    expect(onionItem.expiryDate, isNotNull);
    // today → expiryDate ≈ now (within a few seconds of the test run).
    expect(
      onionItem.expiryDate!.difference(now).inSeconds.abs(),
      lessThan(30),
    );

    final tomatoItem =
        c.state.inventory.firstWhere((i) => i.name == 'Tomato');
    expect(tomatoItem.tier, 'perishable');
    expect(tomatoItem.isRunningLow, isFalse);
    expect(tomatoItem.expiryDate, isNotNull);
    // fresh → expiryDate ≈ now + 7 days (spec default).
    final tomatoDelta = tomatoItem.expiryDate!.difference(now);
    expect(tomatoDelta.inHours, inInclusiveRange(7 * 24 - 1, 7 * 24 + 1));

    final snap = await GuestPantryService().loadAll();
    expect(snap.perishables['Onion'], 'today');
    expect(snap.perishables['Tomato'], 'fresh');
  });

  testWidgets('Continue preserves existing staples in inventory', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    c.setInventory([
      const InventoryItem(name: 'Olive oil', tier: 'almostAlwaysHave'),
      const InventoryItem(name: 'Salt', tier: 'alwaysHave'),
    ]);

    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    await t.ensureVisible(find.byType(ElioBigButton));
    await t.pump();
    await t.tap(find.byType(ElioBigButton));
    await t.pumpAndSettle();

    final staples =
        c.state.inventory.where((i) => i.tier != 'perishable').toList();
    expect(staples.length, 2);
    expect(staples.map((i) => i.name), containsAll(['Olive oil', 'Salt']));
  });

  testWidgets('an Add-something tile renders in each perishable category',
      (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    for (final catName in [
      'Fresh veg',
      'Fresh fruit',
      'Fresh meat & fish',
      'Fresh dairy & herbs',
    ]) {
      final finder = find.byKey(
        ValueKey('perishable_add_$catName'),
        skipOffstage: false,
      );
      await t.scrollUntilVisible(finder, 300);
      expect(finder, findsOneWidget, reason: 'missing add tile for $catName');
    }
  });

  testWidgets('adding a unique perishable appends a custom tile at fresh tier',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    final addTile = find.byKey(
      const ValueKey('perishable_add_Fresh fruit'),
      skipOffstage: false,
    );
    await t.scrollUntilVisible(addTile, 300);
    await t.tap(addTile);
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), 'Pear');
    await t.pumpAndSettle();
    await t.tap(find.text('Add'));
    await t.pumpAndSettle();

    final pearTile = find.ancestor(
      of: find.text('Pear', skipOffstage: false),
      matching: find.byType(ElioPantryItemTile, skipOffstage: false),
    );
    await t.scrollUntilVisible(pearTile, 300);
    final tile = t.widget<ElioPantryItemTile>(pearTile);
    expect(tile.tier, 'fresh');
  });

  testWidgets('exact-match perishable add silently promotes existing tile',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    final addTile = find.byKey(
      const ValueKey('perishable_add_Fresh veg'),
      skipOffstage: false,
    );
    await t.scrollUntilVisible(addTile, 300);
    await t.tap(addTile);
    await t.pumpAndSettle();

    // "Carrot" is in the spec list. Typed with padding to prove normalisation.
    await t.enterText(find.byType(TextField), '  carrot ');
    await t.pumpAndSettle();
    await t.tap(find.text('Add'));
    await t.pumpAndSettle();

    // No warning dialog (exact match is silent).
    expect(find.text('Similar item found'), findsNothing);

    await t.ensureVisible(find.byType(ElioBigButton));
    await t.pump();
    await t.tap(find.byType(ElioBigButton));
    await t.pumpAndSettle();

    final matches = c.state.inventory
        .where((i) => i.name == 'Carrot')
        .toList();
    expect(matches.length, 1);
    expect(matches.first.tier, 'perishable');
  });

  testWidgets('fuzzy-match perishable add shows duplicate warning',
      (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    final addTile = find.byKey(
      const ValueKey('perishable_add_Fresh veg'),
      skipOffstage: false,
    );
    await t.scrollUntilVisible(addTile, 300);
    await t.tap(addTile);
    await t.pumpAndSettle();

    // "Carot" → Levenshtein 1 from "Carrot".
    await t.enterText(find.byType(TextField), 'Carot');
    await t.pumpAndSettle();
    await t.tap(find.text('Add'));
    await t.pumpAndSettle();

    expect(find.text('Similar item found'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('Carot', skipOffstage: false), findsNothing);
  });

  testWidgets('hydrates _tiers from controller.state.inventory on back-nav',
      (t) async {
    useTallViewport(t);
    final now = DateTime.now();
    // Simulate the user having already passed through screen 12: today,
    // thisWeek, fresh tiers + a custom item.
    final c = OnboardingController()
      ..setInventory([
        InventoryItem(
          name: 'Onion',
          tier: 'perishable',
          isRunningLow: false,
          expiryDate: now.add(const Duration(days: 7)),
        ),
        InventoryItem(
          name: 'Tomato',
          tier: 'perishable',
          isRunningLow: false,
          expiryDate: now.add(const Duration(days: 3)),
        ),
        InventoryItem(
          name: 'Salmon',
          tier: 'perishable',
          isRunningLow: true,
          expiryDate: now,
        ),
        InventoryItem(
          name: 'Star anise',
          tier: 'perishable',
          isRunningLow: false,
          expiryDate: now.add(const Duration(days: 7)),
          category: 'Fresh dairy & herbs',
        ),
      ]);
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    // Footer is "{fresh} fresh · {today} today" — fresh count covers the
    // 'fresh' tier rows only. With our setup: Onion + Star anise = 2 fresh,
    // Salmon = 1 today.
    expect(find.text('2 fresh \u00b7 1 today'), findsOneWidget);
  });

  testWidgets('starts empty when no perishables in controller inventory',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController(); // empty
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();
    expect(find.text('0 fresh \u00b7 0 today'), findsOneWidget);
  });

  testWidgets('back button fires onBack', (t) async {
    useTallViewport(t);
    var backed = false;
    await t.pumpWidget(wrap(Screen12PantryPerishables(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () => backed = true,
    )));
    await t.pump();
    await t.tap(find.byType(BackButton));
    await t.pump();
    expect(backed, isTrue);
  });
}
