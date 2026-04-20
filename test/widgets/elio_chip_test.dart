// test/widgets/elio_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_chip.dart';

void main() {
  testWidgets('tapping chip fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: ElioChip(label: 'Vegetarian', selected: false, onTap: () => tapped = true),
    ))));
    await tester.tap(find.text('Vegetarian'));
    expect(tapped, true);
  });
}
