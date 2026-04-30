import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_feedback_bar.dart';

void main() {
  testWidgets('ElioFeedbackBar renders cream-deep panel with thumb buttons', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: Scaffold(body: ElioFeedbackBar(onRated: (_) {})),
    ));
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ElioFeedbackBar), matching: find.byType(DecoratedBox)).first,
    );
    expect((box.decoration as BoxDecoration).color, ElioColors.creamDeep);
    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
  });
}
