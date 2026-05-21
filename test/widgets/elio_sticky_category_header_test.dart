import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_sticky_category_header.dart';

void main() {
  testWidgets('renders title in a CustomScrollView', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: ElioStickyCategoryHeader(title: 'Oils & Vinegars'),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 400)),
          ],
        ),
      ),
    ));
    expect(find.text('Oils & Vinegars'), findsOneWidget);
  });

  testWidgets('renders count badge when count > 0', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: ElioStickyCategoryHeader(
                title: 'Grains',
                count: 4,
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 400)),
          ],
        ),
      ),
    ));
    expect(find.text('Grains'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('omits badge when count is null or 0', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: ElioStickyCategoryHeader(
                title: 'Empty',
                count: 0,
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 400)),
          ],
        ),
      ),
    ));
    expect(find.text('0'), findsNothing);
  });

  testWidgets('shouldRebuild reacts to title/count changes', (_) async {
    final a = ElioStickyCategoryHeader(title: 'A', count: 1);
    final b = ElioStickyCategoryHeader(title: 'A', count: 1);
    final c = ElioStickyCategoryHeader(title: 'B', count: 1);
    expect(a.shouldRebuild(b), false);
    expect(a.shouldRebuild(c), true);
  });
}
