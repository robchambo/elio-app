import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/widgets/elio/elio_backdrop_illustration.dart';

void main() {
  testWidgets('ElioBackdropIllustration renders the kale SVG asset', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(
        body: Stack(children: [ElioBackdropIllustration()]),
      ),
    ));
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ElioBackdropIllustration is wrapped in IgnorePointer (non-interactive)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(
        body: Stack(children: [ElioBackdropIllustration()]),
      ),
    ));
    // Find the IgnorePointer that is a descendant of ElioBackdropIllustration's
    // Positioned wrapper (ignoring: true means pointer events are blocked).
    final ignorePointers = tester.widgetList<IgnorePointer>(find.byType(IgnorePointer));
    expect(ignorePointers.any((w) => w.ignoring == true), isTrue);
  });

  testWidgets('ElioBackdropIllustration applies low opacity (5%)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: elioTheme(),
      home: const Scaffold(
        body: Stack(children: [ElioBackdropIllustration()]),
      ),
    ));
    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, closeTo(0.05, 0.001));
  });
}
