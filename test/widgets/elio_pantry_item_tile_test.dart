import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_pantry_item_tile.dart';

// Top-level no-op callbacks so the Sprint 16.6 blocked-state tests can
// build `ElioPantryItemTile` inside a `const` widget tree (cleaner test
// bodies — no captured-closure setUp ceremony for cases that don't
// actually need to observe the callbacks).
void _noopCycle(String _) {}
void _noopVoid() {}

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

  // ─── Sprint 16.6: dietary blocked-state render path ──────────────────────
  // Sprint 15.9 pre-merge nit was "no widget test asserting dietary filter
  // actually greys a chip — plumbing tested, render path not." These four
  // tests cover the _buildBlocked() branch end-to-end so a future change to
  // the blocked-state visuals can't silently regress dietary filtering on
  // onboarding screens 11/12 + the pantry builder.

  testWidgets(
      'Sprint 16.6: non-empty blockedReasons renders the reason badge',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 160,
          height: 80,
          child: ElioPantryItemTile(
            label: 'Bacon',
            tier: 'always',
            tiers: ['unselected', 'usually', 'always'],
            onCycle: _noopCycle,
            onLongPress: _noopVoid,
            blockedReasons: ['Vegan'],
          ),
        ),
      ),
    ));
    // The reason text appears as a small badge in the top-right of the
    // tile. The tile's main label is also still rendered.
    expect(find.text('Bacon'), findsOneWidget);
    expect(find.text('Vegan'), findsOneWidget);
  });

  testWidgets(
      'Sprint 16.6: blocked tile uses strikethrough label + muted mocha colour',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 160,
          height: 80,
          child: ElioPantryItemTile(
            label: 'Bacon',
            tier: 'always',
            tiers: ['unselected', 'usually', 'always'],
            onCycle: _noopCycle,
            onLongPress: _noopVoid,
            blockedReasons: ['Vegan'],
          ),
        ),
      ),
    ));
    final labelWidget = tester.widget<Text>(find.text('Bacon'));
    // Visual greyed-out signal #1: line-through decoration.
    expect(labelWidget.style?.decoration, TextDecoration.lineThrough);
    // Visual greyed-out signal #2: the label colour is muted-mocha
    // (not the full-espresso colour the active tile uses).
    final colorValue = labelWidget.style?.color?.toARGB32() ?? 0;
    // Just check it isn't the active-tile espresso (0xFF2A1F1A) and
    // it has reduced alpha (the @ 0.7 blend baked into the colour).
    expect(colorValue, isNot(0xFF2A1F1A));
  });

  testWidgets(
      'Sprint 16.6: blocked tile suppresses tap and long-press callbacks',
      (tester) async {
    var cycles = 0;
    var longPresses = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 160,
          height: 80,
          child: ElioPantryItemTile(
            label: 'Bacon',
            tier: 'always',
            tiers: const ['unselected', 'usually', 'always'],
            onCycle: (_) => cycles++,
            onLongPress: () => longPresses++,
            blockedReasons: const ['Vegan'],
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(ElioPantryItemTile));
    await tester.longPress(find.byType(ElioPantryItemTile));
    expect(cycles, 0,
        reason: 'blocked tile must not cycle tier on tap');
    expect(longPresses, 0,
        reason: 'blocked tile must not fire long-press');
  });

  testWidgets(
      'Sprint 16.6: empty blockedReasons leaves the tile interactive',
      (tester) async {
    var cycles = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 160,
          height: 80,
          child: ElioPantryItemTile(
            label: 'Bacon',
            tier: 'unselected',
            tiers: const ['unselected', 'usually', 'always'],
            onCycle: (_) => cycles++,
            onLongPress: () {},
            // Default is `blockedReasons: const []` — leave unset.
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(ElioPantryItemTile));
    expect(cycles, 1,
        reason: 'tile with no block reasons stays interactive');
  });

  testWidgets(
      'selected tier applies tier-specific background colour',
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
