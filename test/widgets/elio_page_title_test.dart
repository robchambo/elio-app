import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_page_title.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    theme: elioTheme(),
    home: Scaffold(body: child),
  ));
}

int _countPeriodSpansWithColor(InlineSpan root, Color color) {
  var count = 0;
  void walk(InlineSpan s) {
    if (s is TextSpan) {
      if (s.text == '.' && s.style?.color == color) count++;
      final children = s.children;
      if (children != null) {
        for (final c in children) {
          walk(c);
        }
      }
    }
  }
  walk(root);
  return count;
}

void main() {
  group('ElioPageTitle', () {
    testWidgets('renders the text', (tester) async {
      await _pump(tester, const ElioPageTitle('hey kate'));
      expect(find.textContaining('hey kate'), findsOneWidget);
    });

    testWidgets('preserves authored case (no auto-lowercase)', (tester) async {
      await _pump(tester, const ElioPageTitle('Hey Kate'));
      expect(find.textContaining('Hey Kate'), findsOneWidget);
    });

    testWidgets('renders mid-string . in terracotta', (tester) async {
      await _pump(tester, const ElioPageTitle('hey kate. lets get started'));
      final richText = tester.widget<RichText>(find.byType(RichText).last);
      final count = _countPeriodSpansWithColor(richText.text, ElioColors.terracotta);
      expect(count, 1);
    });

    testWidgets('terminal . is also terracotta', (tester) async {
      await _pump(tester,
          const ElioPageTitle('tonights dinner, from what you already have.'));
      final richText = tester.widget<RichText>(find.byType(RichText).last);
      final count = _countPeriodSpansWithColor(richText.text, ElioColors.terracotta);
      expect(count, 1);
    });

    testWidgets('strings without . have zero terracotta period spans', (tester) async {
      await _pump(tester, const ElioPageTitle('creamy lemon pasta'));
      final richText = tester.widget<RichText>(find.byType(RichText).last);
      final count = _countPeriodSpansWithColor(richText.text, ElioColors.terracotta);
      expect(count, 0);
    });

    testWidgets('? is not terracotta', (tester) async {
      await _pump(tester, const ElioPageTitle('what brought you to elio?'));
      final richText = tester.widget<RichText>(find.byType(RichText).last);
      final count = _countPeriodSpansWithColor(richText.text, ElioColors.terracotta);
      expect(count, 0);
    });

    testWidgets('two . in same string both become terracotta', (tester) async {
      await _pump(tester, const ElioPageTitle('one. two.'));
      final richText = tester.widget<RichText>(find.byType(RichText).last);
      final count = _countPeriodSpansWithColor(richText.text, ElioColors.terracotta);
      expect(count, 2);
    });
  });
}
