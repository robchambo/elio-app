import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_bottom_nav.dart';

void main() {
  testWidgets('tapping Pantry fires onTap with ElioNavTab.pantry', (tester) async {
    ElioNavTab? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: ElioBottomNav(
          active: ElioNavTab.home,
          onTap: (t) => captured = t,
        ),
      ),
    ));
    await tester.tap(find.text('PANTRY'));
    await tester.pump();
    expect(captured, ElioNavTab.pantry);
  });
}
