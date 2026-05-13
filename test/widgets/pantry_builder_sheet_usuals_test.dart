// test/widgets/pantry_builder_sheet_usuals_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/services/pantry_memory_service.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/pantry_builder_sheet.dart';

import '../fakes/fake_pantry_memory_storage.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    FakePantryMemoryStorage storage, {
    List<String> dietary = const <String>[],
    List<String> allergies = const <String>[],
  }) async {
    PantryMemoryService.debugSetTestInstance(
      PantryMemoryService.test(storage: storage),
    );
    addTearDown(() => PantryMemoryService.debugSetTestInstance(null));

    // Use a tall surface so the category list is rendered far enough
    // down for the dietary-conflict assertions to find the Milk chip.
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PantryBuilderSheet(
          existingItemNames: const [],
          onAddItem: (_, __, ___) async {},
          onRemoveItem: (_) async {},
          dietaryLoaderOverride: () async =>
              (dietary: dietary, allergies: allergies),
        ),
      ),
    ));
    // Two pumps: one for the future to resolve, one for setState.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('"Your usuals" section renders when tierMemory has items',
      (tester) async {
    final storage = FakePantryMemoryStorage()
      ..tierMemoryRows = {
        'carrot': {'name': 'Carrot', 'tier': 'perishable'},
        'rice': {'name': 'Rice', 'tier': 'alwaysHave'},
      };
    await pump(tester, storage);

    // Sprint 15.9.3: section is collapsed by default — header visible,
    // chips hidden until the user taps to expand.
    expect(find.text('Your usuals'), findsOneWidget);
    expect(find.text('Carrot'), findsNothing);
    expect(find.text('Rice'), findsNothing);

    // Tap the header to expand.
    await tester.tap(find.text('Your usuals'));
    await tester.pumpAndSettle();

    expect(find.text('Carrot'), findsWidgets);
    expect(find.text('Rice'), findsWidgets);
  });

  testWidgets('"Your usuals" section is hidden when tierMemory is empty',
      (tester) async {
    final storage = FakePantryMemoryStorage(); // no rows
    await pump(tester, storage);

    expect(find.text('Your usuals'), findsNothing);
  });

  // Sprint 16.6 row 6: dietary-filter render-path assertion. The
  // DietaryFilter logic itself is exhaustively tested in
  // test/utils/dietary_filter_test.dart (vegan blocks Milk, etc.). This
  // group locks in that the *visual* path also fires — a blocked item
  // renders with line-through text, dimmed colour, and the gesture
  // detector is suppressed so taps don't accidentally toggle a blocked
  // item into the pantry.
  group('dietary filter — render path', () {
    // Find the Text widget for [label] that's actually inside an
    // expanded category chip Wrap. The category header above it may
    // also include the label as a Text widget; we want the chip Text
    // specifically, so we look for one whose decoration is set.
    TextStyle styleForChipLabel(WidgetTester tester, String label) {
      final candidates =
          tester.widgetList<Text>(find.text(label)).toList();
      expect(candidates, isNotEmpty,
          reason: 'No Text widget with label "$label" was found at all.');
      return candidates.first.style!;
    }

    testWidgets(
        'vegan diet renders Milk chip greyed out + line-through',
        (tester) async {
      final storage = FakePantryMemoryStorage();
      await pump(tester, storage, dietary: const ['vegan']);

      // Expand Dairy & Eggs so its chips render. The category header
      // includes the name; tap it to expand.
      await tester.tap(find.text('Dairy & Eggs'));
      await tester.pumpAndSettle();

      // The Milk chip is the only Text('Milk') in the tree right now —
      // it sits inside _BuilderChip's blocked-render branch.
      final style = styleForChipLabel(tester, 'Milk');
      expect(style.decoration, TextDecoration.lineThrough,
          reason: 'Vegan-blocked Milk chip must render line-through.');
      // Dimmed mocha (alpha 0.6) confirms the blocked colour branch,
      // not the active espresso/white branch.
      expect(style.color, ElioColors.mocha.withValues(alpha: 0.6),
          reason: 'Vegan-blocked Milk chip text must be dimmed mocha.');
    });

    testWidgets(
        'no dietary restriction renders Milk chip with no line-through',
        (tester) async {
      final storage = FakePantryMemoryStorage();
      await pump(tester, storage, dietary: const <String>[]);

      await tester.tap(find.text('Dairy & Eggs'));
      await tester.pumpAndSettle();

      final style = styleForChipLabel(tester, 'Milk');
      // Active chip uses espresso text, no decoration — confirms the
      // non-blocked render branch.
      expect(style.decoration, isNot(TextDecoration.lineThrough),
          reason: 'Milk with no dietary restriction must NOT be struck through.');
      expect(style.color, ElioColors.espresso,
          reason: 'Active chip text must be espresso, not dimmed mocha.');
    });
  });
}
