// test/widgets/order_import_screen_test.dart
//
// Sprint 17 — Order import settings sub-screen.
//
// Pro-path: address renders, Copy button visible, service was hit
//   exactly once during initState.
// Error-path: a thrown ensureImportAddress() surfaces an error
//   message and Copy is not shown.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/models/pending_import.dart';
import 'package:elio_app/screens/account/order_import_screen.dart';
import 'package:elio_app/services/order_import_service.dart';
import 'package:elio_app/widgets/order_import_review_sheet.dart';

class _FakeOrderImportService implements OrderImportService {
  _FakeOrderImportService({this.error});
  final Object? error;
  int calls = 0;

  @override
  Future<String> ensureImportAddress() async {
    calls += 1;
    if (error != null) throw error!;
    return 'u_test1234abcde@orders.eliochef.com';
  }

  // Task 7 added this to the seam — OrderImportScreen doesn't use it,
  // but the interface requires it. Emit empty so any future smoke
  // test of the broader nav doesn't trip.
  @override
  Stream<List<PendingImport>> pendingImportsStream() =>
      Stream.value(const <PendingImport>[]);

  // Task 9 added these — OrderImportScreen doesn't touch them. No-op
  // stubs keep the interface honest without leaking apply-flow logic
  // into this widget's tests.
  @override
  Future<void> applyImport(String importId, List<ApplyItem> items) async {}

  @override
  Future<void> discardImport(String importId) async {}

  @override
  Future<Set<String>> currentPantryMatchKeys() async => const <String>{};
}

void main() {
  testWidgets('Pro user: shows the address and a Copy button', (t) async {
    final svc = _FakeOrderImportService();
    await t.pumpWidget(MaterialApp(home: OrderImportScreen(service: svc)));
    await t.pumpAndSettle();

    expect(
      find.textContaining('u_test1234abcde@orders.eliochef.com'),
      findsOneWidget,
    );
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(svc.calls, 1);
  });

  testWidgets('Error path: failed ensureImportAddress shows fallback copy',
      (t) async {
    final svc = _FakeOrderImportService(
      error: StateError('callable boom'),
    );
    await t.pumpWidget(MaterialApp(home: OrderImportScreen(service: svc)));
    await t.pumpAndSettle();

    expect(find.textContaining('Could not load'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
  });
}
