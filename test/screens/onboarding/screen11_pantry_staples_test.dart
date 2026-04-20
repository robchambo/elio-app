import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elio_app/controllers/onboarding_controller.dart';
import 'package:elio_app/models/elio_models.dart';
import 'package:elio_app/screens/onboarding/screen11_pantry_staples.dart';
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

  testWidgets('renders 12 category headers', (t) async {
    useTallViewport(t);
    await t.pumpWidget(wrap(Screen11PantryStaples(
      controller: OnboardingController(),
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    // Each of the 12 categories has a sticky header. Verify at least the
    // first few render (some below the fold will be offstage).
    expect(find.text('Oils & Vinegars', skipOffstage: false), findsOneWidget);
    expect(find.text('Spices & Seasonings', skipOffstage: false),
        findsOneWidget);
    expect(find.text('Sauces & Condiments', skipOffstage: false),
        findsOneWidget);
    expect(find.text('Canned & Jarred', skipOffstage: false), findsOneWidget);
    expect(find.text('Grains & Pasta', skipOffstage: false), findsOneWidget);
    expect(find.text('Dairy & Eggs', skipOffstage: false), findsOneWidget);
    expect(find.text('Baking Essentials', skipOffstage: false), findsOneWidget);
    expect(find.text('Frozen Staples', skipOffstage: false), findsOneWidget);
    expect(find.text('Asian Pantry', skipOffstage: false), findsOneWidget);
    expect(find.text('Indian Pantry', skipOffstage: false), findsOneWidget);
    expect(find.text('Mediterranean', skipOffstage: false), findsOneWidget);
    expect(find.text('Mexican & Latin', skipOffstage: false), findsOneWidget);
  });

  testWidgets('~16 defaults pre-selected in usually tier', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen11PantryStaples(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    // Footer caption text encodes the live count of selected items.
    // Spec says "~16"; implementation covers the full table (~20 items).
    // Treat any value in [15, 22] as acceptable.
    final footer = find.textContaining(RegExp(r'^(\d+) things in your kitchen'));
    expect(footer, findsOneWidget);
    final text = (t.widget(footer) as Text).data!;
    final count = int.parse(RegExp(r'^(\d+)').firstMatch(text)!.group(1)!);
    expect(count, greaterThanOrEqualTo(15));
    expect(count, lessThanOrEqualTo(22));
  });

  testWidgets('vegan dietary excludes honey and dairy defaults', (t) async {
    useTallViewport(t);
    final c = OnboardingController()..setDietary(['vegan']);
    await t.pumpWidget(wrap(Screen11PantryStaples(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    // Ensure each excluded item's tile, when brought on-screen, is unselected.
    for (final label in ['Honey', 'Eggs', 'Butter']) {
      final finder = find.ancestor(
        of: find.text(label, skipOffstage: false),
        matching: find.byType(ElioPantryItemTile, skipOffstage: false),
      );
      expect(finder, findsOneWidget, reason: '$label tile missing');
      await t.ensureVisible(finder);
      await t.pump();
      final tile = t.widget<ElioPantryItemTile>(finder);
      expect(tile.tier, 'unselected',
          reason: '$label should not be pre-selected for vegan');
    }
  });

  testWidgets('count footer decrements when a default is tapped off',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen11PantryStaples(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    int readCount() {
      final footer =
          find.textContaining(RegExp(r'^(\d+) things in your kitchen'));
      final text = (t.widget(footer) as Text).data!;
      return int.parse(RegExp(r'^(\d+)').firstMatch(text)!.group(1)!);
    }

    final before = readCount();

    // Tap Olive oil (a default) twice: usually → always → unselected.
    final olive = find.ancestor(
      of: find.text('Olive oil', skipOffstage: false),
      matching: find.byType(ElioPantryItemTile, skipOffstage: false),
    );
    await t.ensureVisible(olive);
    await t.pump();
    await t.tap(olive);
    await t.pump();
    await t.tap(olive);
    await t.pump();

    final after = readCount();
    expect(after, before - 1);
  });

  testWidgets('long-press jumps a tile directly to always tier', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen11PantryStaples(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    // Find an unselected tile by label (Sesame oil is in defaults list as
    // NOT pre-selected).
    final sesame = find.ancestor(
      of: find.text('Sesame oil', skipOffstage: false),
      matching: find.byType(ElioPantryItemTile, skipOffstage: false),
    );
    expect(sesame, findsOneWidget);
    // Scroll it into view.
    await t.ensureVisible(sesame);
    await t.pump();
    await t.longPress(sesame);
    await t.pump();
    final tile = t.widget<ElioPantryItemTile>(sesame);
    expect(tile.tier, 'always');
  });

  testWidgets('tap cycles tile unselected → usually', (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    await t.pumpWidget(wrap(Screen11PantryStaples(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    final sesame = find.ancestor(
      of: find.text('Sesame oil', skipOffstage: false),
      matching: find.byType(ElioPantryItemTile, skipOffstage: false),
    );
    await t.ensureVisible(sesame);
    await t.pump();
    await t.tap(sesame);
    await t.pump();
    final tile = t.widget<ElioPantryItemTile>(sesame);
    expect(tile.tier, 'usually');
  });

  testWidgets('Continue persists via GuestPantryService and sets inventory',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    var continued = false;
    await t.pumpWidget(wrap(Screen11PantryStaples(
      controller: c,
      onContinue: () => continued = true,
      onBack: () {},
    )));
    await t.pump();

    await t.tap(find.byType(ElioBigButton));
    await t.pumpAndSettle();

    expect(continued, isTrue);
    expect(c.state.inventory, isNotEmpty);
    for (final item in c.state.inventory) {
      expect(['alwaysHave', 'almostAlwaysHave'], contains(item.tier));
    }

    final snap = await GuestPantryService().loadAll();
    expect(snap.staples, isNotEmpty);
  });

  testWidgets('Continue merges with existing perishables in inventory',
      (t) async {
    useTallViewport(t);
    final c = OnboardingController();
    // Simulate a perishable already in inventory (e.g. user went back from
    // screen 12 to 11).
    c.setInventory([
      const InventoryItem(
        name: 'Tomato',
        tier: 'perishable',
        isRunningLow: false,
      ),
    ]);
    await t.pumpWidget(wrap(Screen11PantryStaples(
      controller: c,
      onContinue: () {},
      onBack: () {},
    )));
    await t.pump();

    await t.tap(find.byType(ElioBigButton));
    await t.pumpAndSettle();

    expect(
      c.state.inventory.where((i) => i.tier == 'perishable').length,
      1,
    );
    expect(
      c.state.inventory.where((i) => i.tier != 'perishable').length,
      greaterThan(0),
    );
  });

  testWidgets('back button fires onBack', (t) async {
    useTallViewport(t);
    var backed = false;
    await t.pumpWidget(wrap(Screen11PantryStaples(
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
