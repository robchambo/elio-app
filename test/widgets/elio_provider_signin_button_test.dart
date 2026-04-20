import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/elio_provider_signin_button.dart';

void main() {
  testWidgets('Apple variant renders label + apple icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioProviderSignInButton(
          kind: ProviderButtonKind.apple,
          onPressed: () {},
        ),
      ),
    ));
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.byIcon(Icons.apple), findsOneWidget);
  });

  testWidgets('Google variant renders label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioProviderSignInButton(
          kind: ProviderButtonKind.google,
          onPressed: () {},
        ),
      ),
    ));
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('Email variant renders label + mail icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioProviderSignInButton(
          kind: ProviderButtonKind.email,
          onPressed: () {},
        ),
      ),
    ));
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.byIcon(Icons.mail_outline), findsOneWidget);
  });

  testWidgets('tap fires onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioProviderSignInButton(
          kind: ProviderButtonKind.email,
          onPressed: () => tapped = true,
        ),
      ),
    ));
    await tester.tap(find.byType(ElioProviderSignInButton));
    expect(tapped, true);
  });

  testWidgets('visible=false renders nothing visible', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElioProviderSignInButton(
          kind: ProviderButtonKind.apple,
          visible: false,
          onPressed: () {},
        ),
      ),
    ));
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.byIcon(Icons.apple), findsNothing);
  });
}
