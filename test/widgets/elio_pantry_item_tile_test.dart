import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_pantry_item_tile.dart';

void main() {
  testWidgets('uses RawGestureDetector with LongPressGestureRecognizer',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: ElioPantryItemTile(
            label: 'Olive oil',
            tier: 'unselected',
            tiers: const ['unselected', 'usually', 'always'],
            onCycle: (_) {},
            onLongPress: () {},
          ),
        ),
      ),
    ));

    // There can be multiple RawGestureDetectors in the tree (Material
    // internals). Find the one with our gesture recogniser keys.
    final all = tester
        .widgetList<RawGestureDetector>(find.byType(RawGestureDetector))
        .toList();
    final ours = all.firstWhere(
      (w) => w.gestures.keys.contains(LongPressGestureRecognizer) &&
          w.gestures.keys.contains(TapGestureRecognizer),
    );
    expect(ours.gestures.keys, contains(LongPressGestureRecognizer));
    expect(ours.gestures.keys, contains(TapGestureRecognizer));
  });

  testWidgets('tap cycles tier → next', (tester) async {
    String? next;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: ElioPantryItemTile(
            label: 'Olive oil',
            tier: 'unselected',
            tiers: const ['unselected', 'usually', 'always'],
            onCycle: (v) => next = v,
            onLongPress: () {},
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(ElioPantryItemTile));
    expect(next, 'usually');
  });

  testWidgets('tap wraps around from last tier to first', (tester) async {
    String? next;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: ElioPantryItemTile(
            label: 'Olive oil',
            tier: 'always',
            tiers: const ['unselected', 'usually', 'always'],
            onCycle: (v) => next = v,
            onLongPress: () {},
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(ElioPantryItemTile));
    expect(next, 'unselected');
  });

  testWidgets('long-press fires onLongPress callback', (tester) async {
    var longPressed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: ElioPantryItemTile(
            label: 'Olive oil',
            tier: 'unselected',
            tiers: const ['unselected', 'usually', 'always'],
            onCycle: (_) {},
            onLongPress: () => longPressed = true,
          ),
        ),
      ),
    ));
    await tester.longPress(find.byType(ElioPantryItemTile));
    expect(longPressed, true);
  });

  testWidgets('3-tier (perishable) variant cycles unselected→fresh',
      (tester) async {
    String? next;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: ElioPantryItemTile(
            label: 'Spinach',
            tier: 'unselected',
            tiers: const ['unselected', 'fresh', 'thisWeek', 'today'],
            onCycle: (v) => next = v,
            onLongPress: () {},
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(ElioPantryItemTile));
    expect(next, 'fresh');
  });

  testWidgets('selected tier renders glyph icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: ElioPantryItemTile(
            label: 'Olive oil',
            tier: 'always',
            tiers: const ['unselected', 'usually', 'always'],
            onCycle: (_) {},
            onLongPress: () {},
          ),
        ),
      ),
    ));
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });
}
