import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elio_app/models/recipe_models.dart';
import 'package:elio_app/screens/recipe/recipe_screen.dart';
import 'package:elio_app/screens/recipes/recipes_tab_screen.dart';
import 'package:elio_app/services/history_service.dart';

SavedRecipe _fixture({
  required String savedAt,
  required String title,
  bool bookmarked = false,
}) {
  return SavedRecipe(
    recipe: GeneratedRecipe(
      title: title,
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      servings: 2,
      description: 'A simple test recipe.',
      ingredients: const [
        RecipeIngredient(
          name: 'Tomato',
          quantity: '2',
          unit: '',
          fromInventory: true,
        ),
      ],
      steps: const ['Chop tomato.', 'Serve.'],
      substitutions: const [],
      dietaryTags: const [],
    ),
    savedAt: savedAt,
    isBookmarked: bookmarked,
  );
}

Future<void> _seedHistory(List<SavedRecipe> recipes) async {
  final encoded = jsonEncode(recipes.map((r) => r.toJson()).toList());
  // Set mocks BEFORE clearAll so SharedPreferences.getInstance has a
  // values map to read from (the in-memory mock channel resolves on
  // first call). Then clearAll wipes the static cache, and we re-seed
  // so the test sees its fixtures.
  SharedPreferences.setMockInitialValues({
    'elio_recipe_history': encoded,
    // Skip FirestoreService.deduplicateInventory — it triggers Crashlytics
    // on its catch path, and Crashlytics isn't mocked in widget tests. The
    // flag short-circuits dedup at the top.
    'inventory_deduped_v1': true,
  });
  await HistoryService.clearAll();
  SharedPreferences.setMockInitialValues({
    'elio_recipe_history': encoded,
    'inventory_deduped_v1': true,
  });
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(body: RecipesTabScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() async {
    // Default seeding — individual tests override.
    await _seedHistory([
      _fixture(savedAt: '2026-04-25T12:00:00.000', title: 'Test Recipe'),
    ]);
  });

  testWidgets('Saved is the default tab when screen opens', (tester) async {
    await _seedHistory([
      _fixture(
        savedAt: '2026-05-12T08:00:00.000',
        title: 'Bookmarked Stew',
        bookmarked: true,
      ),
      _fixture(
        savedAt: '2026-05-12T09:00:00.000',
        title: 'Unbookmarked Soup',
      ),
    ]);
    await _pump(tester);

    // TabController index is the canonical signal; visual assertions on
    // recipe titles are noisy because TabBarView pre-builds both tabs.
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 0,
        reason: 'Saved should be the default landing tab');
  });

  testWidgets('Tab labels include filtered counts', (tester) async {
    await _seedHistory([
      _fixture(
        savedAt: '2026-05-12T08:00:00.000',
        title: 'Bookmarked One',
        bookmarked: true,
      ),
      _fixture(savedAt: '2026-05-12T09:00:00.000', title: 'History One'),
      _fixture(savedAt: '2026-05-12T10:00:00.000', title: 'History Two'),
    ]);
    await _pump(tester);

    // Saved = 1 bookmarked. History = 3 total (bookmarked + 2 unbookmarked).
    expect(find.text('Saved (1)'), findsOneWidget);
    expect(find.text('History (3)'), findsOneWidget);
  });

  testWidgets('Tapping the History tab activates it', (tester) async {
    await _seedHistory([
      _fixture(
        savedAt: '2026-05-12T08:00:00.000',
        title: 'Bookmarked Stew',
        bookmarked: true,
      ),
      _fixture(savedAt: '2026-05-12T09:00:00.000', title: 'Unbookmarked Soup'),
    ]);
    await _pump(tester);

    // Match by textContaining since label includes a count suffix.
    await tester.tap(find.textContaining('History'));
    await tester.pumpAndSettle();

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 1);
  });

  testWidgets('Saved tab shows empty-state copy when no bookmarks',
      (tester) async {
    await _seedHistory([
      _fixture(savedAt: '2026-05-12T09:00:00.000', title: 'Unbookmarked Soup'),
    ]);
    await _pump(tester);

    // Saved tab is default; with no bookmarks the empty-state text shows.
    expect(
      find.text("You haven't bookmarked any recipes yet."),
      findsOneWidget,
    );
  });

  testWidgets('Makeable-now toggle re-filters and updates tab counts',
      (tester) async {
    await _seedHistory([
      _fixture(
        savedAt: '2026-05-12T08:00:00.000',
        title: 'Bookmarked Stew',
        bookmarked: true,
      ),
      _fixture(savedAt: '2026-05-12T09:00:00.000', title: 'Unbookmarked Soup'),
    ]);
    await _pump(tester);

    // Baseline counts (pantry empty in widget test → makeable-now toggle off).
    expect(find.text('Saved (1)'), findsOneWidget);
    expect(find.text('History (2)'), findsOneWidget);

    // Toggle makeable-now on. Pantry is empty so every recipe is filtered out.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Saved (0)'), findsOneWidget);
    expect(find.text('History (0)'), findsOneWidget);
  });

  testWidgets(
      'Tapping the bookmark icon toggles save without opening the recipe',
      (tester) async {
    // Default seed has one unbookmarked recipe — appears in History only.
    await _pump(tester);

    // Saved tab is default and empty; switch to History to find the icon.
    await tester.tap(find.textContaining('History'));
    await tester.pumpAndSettle();

    // Find the unsaved bookmark icon.
    final bookmark = find.byIcon(Icons.bookmark_outline_rounded).first;
    expect(bookmark, findsOneWidget);

    await tester.tap(bookmark);
    await tester.pumpAndSettle();

    // Recipe was NOT opened.
    expect(find.byType(RecipeScreen), findsNothing);

    // Icon flipped to filled.
    expect(find.byIcon(Icons.bookmark_rounded), findsWidgets);
  });
}
