import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_top_app_bar.dart';

void main() {
  testWidgets('ElioTopAppBar shows lowercase elio wordmark', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(appBar: ElioTopAppBar()),
    ));
    expect(find.text('elio'), findsOneWidget);
  });

  testWidgets('ElioTopAppBar wordmark uses Bricolage 800', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(appBar: ElioTopAppBar()),
    ));
    final wordmark = tester.widget<Text>(find.text('elio'));
    expect(wordmark.style?.fontFamily, 'Bricolage Grotesque');
    expect(wordmark.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('ElioTopAppBar profile icon is account_circle_outlined in espresso', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(appBar: ElioTopAppBar()),
    ));
    final icon = tester.widget<Icon>(find.byIcon(Icons.account_circle_outlined));
    expect(icon.color, ElioColors.espresso);
  });
}
