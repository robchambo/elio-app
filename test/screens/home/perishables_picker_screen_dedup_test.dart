// test/screens/home/perishables_picker_screen_dedup_test.dart
//
// 19 May 2026 — defensive dedup of inventory chips on the perishables
// picker. The Home tab now dedupes upstream, but the picker also runs a
// case-insensitive dedup so legacy duplicated Firestore inventory docs
// (pre-Sprint 15.9.1 InventoryWriter, or any future bypass) don't surface
// as duplicate selectable chips.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/screens/home/perishables_picker_screen.dart';
import 'package:elio_app/widgets/elio/elio_chip.dart';

void main() {
  void useTallViewport(WidgetTester t) {
    t.view.physicalSize = const Size(900, 1800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  Widget wrap(PerishablesPickerScreen screen) =>
      MaterialApp(home: screen);

  group('PerishablesPickerScreen dedup', () {
    testWidgets('renders each pantry name only once even with case-variant '
        'duplicates', (t) async {
      useTallViewport(t);
      await t.pumpWidget(wrap(const PerishablesPickerScreen(
        perishableInventory: [
          'Mushroom',
          'Mushroom',
          'Potato',
          'POTATO',
          'Carrot',
          'carrot',
          'Onion',
        ],
        autoSelectCount: 0,
      )));
      await t.pump();

      // Each name appears in exactly one chip — the case-of-first-occurrence
      // wins. Custom-add field has its own chip parent, so scoping the find
      // to ElioChip is safe.
      final chips = t.widgetList<ElioChip>(find.byType(ElioChip)).toList();
      final labels = chips.map((c) => c.label).toList();
      expect(labels, ['Mushroom', 'Potato', 'Carrot', 'Onion'],
          reason:
              'Case-insensitive dedup must preserve first-occurrence order.');
    });

    testWidgets('autoSelectCount=3 ticks three DIFFERENT items, not three '
        'copies of the same duplicated item', (t) async {
      useTallViewport(t);
      await t.pumpWidget(wrap(const PerishablesPickerScreen(
        perishableInventory: [
          'Mushroom',
          'Mushroom', // dup — must not be re-selected on top of itself
          'Potato',
          'Carrot',
          'Onion',
        ],
      )));
      await t.pump();

      // Pre-fix the auto-select could pick "Mushroom, Mushroom, Potato"
      // (3 items, only 2 distinct). After dedup it must pick the first
      // 3 distinct names: Mushroom, Potato, Carrot. The "Use these (N)"
      // CTA reflects the selection count.
      expect(find.text('Use these (3)'), findsOneWidget);
    });

    testWidgets('strips empty / whitespace-only names', (t) async {
      useTallViewport(t);
      await t.pumpWidget(wrap(const PerishablesPickerScreen(
        perishableInventory: ['Tomato', '', '   ', 'Onion'],
        autoSelectCount: 0,
      )));
      await t.pump();

      final chips = t.widgetList<ElioChip>(find.byType(ElioChip)).toList();
      expect(chips.map((c) => c.label), ['Tomato', 'Onion']);
    });
  });
}
