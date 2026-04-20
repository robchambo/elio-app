import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_chip_text_input.dart';

void main() {
  testWidgets('renders empty by default without crashing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioChipTextInput(values: const [], onChanged: (_) {}),
      ),
    ));
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('onSubmitted appends a new token', (tester) async {
    List<String>? latest;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioChipTextInput(
          values: const [],
          onChanged: (v) => latest = v,
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'kiwi');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(latest, ['kiwi']);
  });

  testWidgets('duplicate token is rejected', (tester) async {
    List<String>? latest;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioChipTextInput(
          values: const ['kiwi'],
          onChanged: (v) => latest = v,
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'Kiwi');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(latest, isNull);
  });

  testWidgets('tapping × removes a chip', (tester) async {
    List<String>? latest;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioChipTextInput(
          values: const ['kiwi', 'mango'],
          onChanged: (v) => latest = v,
        ),
      ),
    ));
    // Tap the first close icon (on "kiwi").
    await tester.tap(find.byIcon(Icons.close).first);
    expect(latest, ['mango']);
  });

  testWidgets('comma commits a token', (tester) async {
    List<String>? latest;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioChipTextInput(
          values: const [],
          onChanged: (v) => latest = v,
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'basil,');
    await tester.pump();
    expect(latest, ['basil']);
  });
}
