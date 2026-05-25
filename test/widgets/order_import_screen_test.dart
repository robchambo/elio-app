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

import 'package:elio_app/screens/account/order_import_screen.dart';
import 'package:elio_app/services/order_import_service.dart';

class _FakeOrderImportService implements OrderImportService {
  _FakeOrderImportService({this.error});
  final Object? error;
  int calls = 0;

  @override
  Future<String> ensureImportAddress() async {
    calls += 1;
    if (error != null) throw error!;
    return 'u_test1234abcde@orders.elio.app';
  }
}

void main() {
  testWidgets('Pro user: shows the address and a Copy button', (t) async {
    final svc = _FakeOrderImportService();
    await t.pumpWidget(MaterialApp(home: OrderImportScreen(service: svc)));
    await t.pumpAndSettle();

    expect(
      find.textContaining('u_test1234abcde@orders.elio.app'),
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
