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

  testWidgets('tile never renders an inline glyph icon — colour-only tiers',
      (tester) async {
    // Sprint 16.2 Bug 3: the old glyph (tick/star/leaf/clock/warning)
    // stole vertical space and forced long labels like "Extra virgin
    // olive oil" to clip with an ellipsis. The tile is now
    // colour-coded only — the legend at the top of the screen
    // carries the tier meaning.
    for (final tier in const ['unselected', 'usually', 'always', 'fresh',
        'thisWeek', 'today']) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 80,
            child: ElioPantryItemTile(
              label: 'Extra virgin olive oil',
              tier: tier,
              tiers: const [
                'unselected',
                'usually',
                'always',
                'fresh',
                'thisWeek',
                'today'
              ],
              onCycle: (_) {},
              onLongPress: () {},
            ),
          ),
        ),
      ));
      final iconInside = find.descendant(
        of: find.byType(ElioPantryItemTile),
        matching: find.byType(Icon),
      );
      expect(iconInside, findsNothing,
          reason: 'tier=$tier should render no icon inside the tile');
    }
  });

  testWidgets('selected tier applies tier-specific background colour',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 160,
          height: 80,
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
    // Walk the DecoratedBoxes descended from our tile; one of them
    // should carry the solid-amber "always" fill.
    final decorations = tester
        .widgetList<Container>(find.descendant(
          of: find.byType(ElioPantryItemTile),
          matching: find.byType(Container),
        ))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .toList();
    final hasAmberFill = decorations.any((d) => d.color == const Color(0xFFE37B53));
    expect(hasAmberFill, isTrue,
        reason: '"always" tier should paint solid terracotta fill');
  });
}
