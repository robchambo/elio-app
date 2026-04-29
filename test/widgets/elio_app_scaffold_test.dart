import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_app_scaffold.dart';
import 'package:elio_app/widgets/elio/elio_backdrop_illustration.dart';

void main() {
  group('ElioAppScaffold backdrop integration', () {
    testWidgets('inserts ElioBackdropIllustration behind body', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: elioTheme(),
        home: const ElioAppScaffold(
          body: Center(child: Text('Page content')),
        ),
      ));
      expect(find.byType(ElioBackdropIllustration), findsOneWidget);
      expect(find.text('Page content'), findsOneWidget);
    });
  });
}
