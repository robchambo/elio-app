// test/widgets/pantry_builder_sheet_usuals_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/services/pantry_memory_service.dart';
import 'package:elio_app/widgets/pantry_builder_sheet.dart';

import '../fakes/fake_pantry_memory_storage.dart';

void main() {
  Future<void> _pump(WidgetTester tester, FakePantryMemoryStorage storage) async {
    PantryMemoryService.debugSetTestInstance(
      PantryMemoryService.test(storage: storage),
    );
    addTearDown(() => PantryMemoryService.debugSetTestInstance(null));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PantryBuilderSheet(
          existingItemNames: const [],
          onAddItem: (_, __, ___) async {},
          onRemoveItem: (_) async {},
          dietaryLoaderOverride: () async =>
              (dietary: <String>[], allergies: <String>[]),
        ),
      ),
    ));
    // Two pumps: one for the future to resolve, one for setState.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('"Your usuals" section renders when tierMemory has items',
      (tester) async {
    final storage = FakePantryMemoryStorage()
      ..tierMemoryRows = {
        'carrot': {'name': 'Carrot', 'tier': 'perishable'},
        'rice': {'name': 'Rice', 'tier': 'alwaysHave'},
      };
    await _pump(tester, storage);

    expect(find.text('Your usuals'), findsOneWidget);
    expect(find.text('Carrot'), findsWidgets);
    expect(find.text('Rice'), findsWidgets);
  });

  testWidgets('"Your usuals" section is hidden when tierMemory is empty',
      (tester) async {
    final storage = FakePantryMemoryStorage(); // no rows
    await _pump(tester, storage);

    expect(find.text('Your usuals'), findsNothing);
  });
}
