import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/widgets/elio/phone_mockup_recipe_card.dart';
import 'package:elio_app/widgets/elio/elio_pantry_tag_pill.dart';

void main() {
  testWidgets('renders default recipe title', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PhoneMockupRecipeCard()),
    ));
    expect(find.text('Tomato & basil pasta'), findsOneWidget);
  });

  testWidgets('renders 3 default ingredient rows + 3 pills', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PhoneMockupRecipeCard()),
    ));
    expect(find.text('Spaghetti'), findsOneWidget);
    expect(find.text('Cherry tomatoes'), findsOneWidget);
    expect(find.text('Fresh basil'), findsOneWidget);
    expect(find.byType(ElioPantryTagPill), findsNWidgets(3));
  });

  testWidgets('renders custom ingredient list', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PhoneMockupRecipeCard(
          recipeTitle: 'Demo recipe',
          ingredients: const [
            PhoneMockupIngredient(
              name: 'Rice',
              tag: PantryTagKind.alwaysHave,
            ),
            PhoneMockupIngredient(name: 'Plain ingredient'),
          ],
        ),
      ),
    ));
    expect(find.text('Demo recipe'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Plain ingredient'), findsOneWidget);
    expect(find.byType(ElioPantryTagPill), findsOneWidget);
  });
}
