// Sprint 16.3 — RecipePreferencesScreen now owns the streaming generation
// phase. These tests cover the picker → generating phase swap, the rotating
// progress messages (no more silent black hole), and the error → retry path.
// The stream itself is injected via the [streamFactory] test seam so we
// never touch GeminiService.
//
// We render the screen at a tall test surface so the Generate CTA at the
// bottom of the SingleChildScrollView is hit-testable without scrolling.
// We also use a 1200-px-tall MaterialApp body so PopScope/Scaffold layout
// matches the real on-device flow.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/models/recipe_models.dart';
import 'package:elio_app/models/recipe_preferences.dart';
import 'package:elio_app/screens/home/recipe_preferences_screen.dart';
import 'package:elio_app/widgets/elio/elio_chip.dart';

// Sprint 16.1: BuildRequestFn became async to allow HomeScreen's
// _buildRequest to refresh UserSettingsService before returning. The
// stub awaits Future.value to match the typedef.
Future<RecipeGenerationRequest> _stubRequest(RecipePreferences _) async =>
    const RecipeGenerationRequest(
      perishables: [],
      alwaysHave: [],
      almostAlwaysHave: [],
      dietaryRequirements: [],
    );

Widget _harness({
  RecipeStreamFactory? streamFactory,
  void Function(GeneratedRecipe, RecipeGenerationRequest)? onComplete,
  bool? proOverrideForTest,
}) {
  return MaterialApp(
    home: RecipePreferencesScreen(
      buildRequest: _stubRequest,
      onRecipeComplete: onComplete ?? (_, __) {},
      isGuest: true,
      streamFactory: streamFactory,
      proOverrideForTest: proOverrideForTest,
    ),
  );
}

Future<void> _tapGenerate(WidgetTester tester) async {
  final btn = find.text('Generate');
  await tester.ensureVisible(btn);
  await tester.tap(btn);
}

void main() {
  // Use a tall surface so the Generate button at the bottom of the picker
  // body is on screen for the initial frame.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
    dispatcher.views.first.physicalSize = const Size(900, 2400);
    dispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
    dispatcher.views.first.resetPhysicalSize();
    dispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets(
    'tapping Generate swaps to the generating phase and shows the first message',
    (tester) async {
      // Stream that never completes — keeps us in the generating phase.
      final ctrl = StreamController<RecipeGenerationStatus>();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_harness(streamFactory: (_) => ctrl.stream));
      expect(find.text('Generate'), findsOneWidget);

      await _tapGenerate(tester);
      await tester.pump(); // start the stream

      // First rotating message lands immediately + spinner is shown.
      expect(find.text('Browsing your pantry…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('rotating messages cycle while generating', (tester) async {
    final ctrl = StreamController<RecipeGenerationStatus>();
    addTearDown(ctrl.close);

    await tester.pumpWidget(_harness(streamFactory: (_) => ctrl.stream));
    await _tapGenerate(tester);
    await tester.pump();

    expect(find.text('Browsing your pantry…'), findsOneWidget);
    // Just past the 1.5s rotation interval — Timer fires and we settle.
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('Choosing flavours…'), findsOneWidget);
  });

  testWidgets('stream error swaps to error phase with Try again CTA', (
    tester,
  ) async {
    final ctrl = StreamController<RecipeGenerationStatus>();
    addTearDown(ctrl.close);

    await tester.pumpWidget(_harness(streamFactory: (_) => ctrl.stream));
    await _tapGenerate(tester);
    await tester.pump();

    ctrl.add(RecipeError(message: 'boom'));
    await tester.pump(); // deliver event
    await tester.pump(); // setState rebuild

    expect(find.text('Something went wrong.'), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    // Retry returns to picker phase.
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Generate'), findsOneWidget);
  });

  testWidgets('Saver and Bulk cook toggles render at the top of the screen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RecipePreferencesScreen(
        buildRequest: _stubRequest,
        onRecipeComplete: (_, __) {},
        isGuest: true,
      ),
    ));
    await tester.pump();

    expect(find.text('Saver mode'), findsOneWidget);
    expect(find.text('Bulk cook'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
  });

  testWidgets(
      'enabling Bulk cook (Pro) opens the slider dialog with default meals/portions',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RecipePreferencesScreen(
        buildRequest: _stubRequest,
        onRecipeComplete: (_, __) {},
        isGuest: true,
        proOverrideForTest: true,
      ),
    ));
    await tester.pump();

    // Tap the Bulk cook switch (second Switch on the page).
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(2));
    await tester.tap(switches.last);
    await tester.pumpAndSettle();

    // Dialog title + slider helper labels.
    expect(find.text('Meals: 2'), findsOneWidget);
    expect(find.text('Portions per meal: 6'), findsOneWidget);
  });

  // Sprint 16.6 row 5b — meal-type row above Time, below Bulk cook.
  // Three chips, none selected by default. Single-select with mutual
  // exclusivity (selecting Dinner deselects Breakfast). Tap-to-deselect
  // (tapping the selected chip clears it to null — no "Any" sentinel).
  group('meal-type row', () {
    ElioChip chipForLabel(WidgetTester tester, String label) {
      // Each label appears exactly once on the page (we don't reuse
      // 'Breakfast' anywhere else as a chip).
      return tester.widget<ElioChip>(
        find.widgetWithText(ElioChip, label),
      );
    }

    testWidgets('renders Breakfast / Lunch / Dinner with none selected',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump();

      // Eyebrow label (ElioEyebrow uppercases the source).
      expect(find.text('MEAL'), findsOneWidget);

      // All three chips render and none are selected.
      for (final label in const ['Breakfast', 'Lunch', 'Dinner']) {
        expect(find.widgetWithText(ElioChip, label), findsOneWidget,
            reason: '$label chip should render in the meal row.');
        expect(chipForLabel(tester, label).selected, isFalse,
            reason: '$label chip must default to unselected.');
      }
    });

    testWidgets('tapping a chip selects it (others stay unselected)',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump();

      await tester.tap(find.widgetWithText(ElioChip, 'Breakfast'));
      await tester.pumpAndSettle();

      expect(chipForLabel(tester, 'Breakfast').selected, isTrue);
      expect(chipForLabel(tester, 'Lunch').selected, isFalse);
      expect(chipForLabel(tester, 'Dinner').selected, isFalse);
    });

    testWidgets(
        'mutual exclusivity — selecting Dinner deselects Breakfast',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump();

      await tester.tap(find.widgetWithText(ElioChip, 'Breakfast'));
      await tester.pumpAndSettle();
      expect(chipForLabel(tester, 'Breakfast').selected, isTrue);

      await tester.tap(find.widgetWithText(ElioChip, 'Dinner'));
      await tester.pumpAndSettle();

      expect(chipForLabel(tester, 'Dinner').selected, isTrue);
      expect(chipForLabel(tester, 'Breakfast').selected, isFalse,
          reason: 'Picking Dinner must clear Breakfast (single-select).');
      expect(chipForLabel(tester, 'Lunch').selected, isFalse);
    });

    testWidgets('tapping the selected chip clears it back to null',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump();

      await tester.tap(find.widgetWithText(ElioChip, 'Lunch'));
      await tester.pumpAndSettle();
      expect(chipForLabel(tester, 'Lunch').selected, isTrue);

      // Tap again → deselect (no "Any" sentinel — null is the state).
      await tester.tap(find.widgetWithText(ElioChip, 'Lunch'));
      await tester.pumpAndSettle();

      expect(chipForLabel(tester, 'Lunch').selected, isFalse);
      expect(chipForLabel(tester, 'Breakfast').selected, isFalse);
      expect(chipForLabel(tester, 'Dinner').selected, isFalse);
    });

    testWidgets('selected meal flows into the RecipePreferences object',
        (tester) async {
      RecipePreferences? captured;
      Future<RecipeGenerationRequest> capturingBuild(
          RecipePreferences p) async {
        captured = p;
        return const RecipeGenerationRequest(
          perishables: [],
          alwaysHave: [],
          almostAlwaysHave: [],
          dietaryRequirements: [],
        );
      }

      final ctrl = StreamController<RecipeGenerationStatus>();
      addTearDown(ctrl.close);

      await tester.pumpWidget(MaterialApp(
        home: RecipePreferencesScreen(
          buildRequest: capturingBuild,
          onRecipeComplete: (_, __) {},
          isGuest: true,
          streamFactory: (_) => ctrl.stream,
        ),
      ));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElioChip, 'Dinner'));
      await tester.pumpAndSettle();
      await _tapGenerate(tester);
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.mealType, 'Dinner');
    });

    testWidgets('unselected meal row leaves prefs.mealType null',
        (tester) async {
      RecipePreferences? captured;
      Future<RecipeGenerationRequest> capturingBuild(
          RecipePreferences p) async {
        captured = p;
        return const RecipeGenerationRequest(
          perishables: [],
          alwaysHave: [],
          almostAlwaysHave: [],
          dietaryRequirements: [],
        );
      }

      final ctrl = StreamController<RecipeGenerationStatus>();
      addTearDown(ctrl.close);

      await tester.pumpWidget(MaterialApp(
        home: RecipePreferencesScreen(
          buildRequest: capturingBuild,
          onRecipeComplete: (_, __) {},
          isGuest: true,
          streamFactory: (_) => ctrl.stream,
        ),
      ));
      await tester.pump();

      await _tapGenerate(tester);
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.mealType, isNull);
    });
  });
}
