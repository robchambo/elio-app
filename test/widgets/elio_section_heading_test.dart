import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/theme/elio_text_styles.dart';
import 'package:elio_app/widgets/elio/elio_section_heading.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    theme: elioTheme(),
    home: Scaffold(body: child),
  ));
}

void main() {
  group('ElioSectionHeading', () {
    testWidgets('renders the text', (tester) async {
      await _pump(tester, const ElioSectionHeading('Ingredients'));
      expect(find.text('Ingredients'), findsOneWidget);
    });

    testWidgets('uses sectionHeadingStyle from ElioTextStyles', (tester) async {
      await _pump(tester, const ElioSectionHeading('Pantry Builder'));
      final textWidget = tester.widget<Text>(find.text('Pantry Builder'));
      expect(textWidget.style?.fontFamily, ElioTextStyles.sectionHeadingStyle.fontFamily);
      expect(textWidget.style?.fontWeight, ElioTextStyles.sectionHeadingStyle.fontWeight);
      expect(textWidget.style?.fontSize, ElioTextStyles.sectionHeadingStyle.fontSize);
    });

    testWidgets('does NOT lowercase or recolor any character', (tester) async {
      await _pump(tester, const ElioSectionHeading('Custom allergens or dietary requirements'));
      expect(find.text('Custom allergens or dietary requirements'), findsOneWidget);
    });
  });
}
