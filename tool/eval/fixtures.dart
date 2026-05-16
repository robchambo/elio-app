import 'package:elio_app/models/recipe_models.dart';

// ─────────────────────────────────────────────
// Fixtures — five hand-crafted RecipeGenerationRequests covering
// the prompt's main conditional branches:
//   1. busy-weeknight-omnivore — US, perishables-heavy, no constraints
//   2. saver-veg               — UK, vegetarian + nut-free, saver mode
//   3. high-constraint         — UK, gluten/dairy/shellfish-free + Mediterranean style
//   4. leftover-mode           — US, leftover roast chicken + rice
//   5. taste-profile-loaded    — US, strong like/dislike steering
// ─────────────────────────────────────────────

class Fixture {
  final String id;
  final String description;
  final RecipeGenerationRequest request;
  final String region;             // 'us' or 'uk'
  final String measurementUnits;   // 'metric' or 'imperial'

  const Fixture({
    required this.id,
    required this.description,
    required this.request,
    required this.region,
    required this.measurementUnits,
  });
}

const allFixtures = <Fixture>[
  Fixture(
    id: 'busy-weeknight-omnivore',
    description: 'US household, weekday dinner, no dietary constraints, 3 perishables to use up.',
    region: 'us',
    measurementUnits: 'imperial',
    request: RecipeGenerationRequest(
      perishables: ['chicken breast', 'broccoli', 'lemon'],
      alwaysHave: ['olive oil', 'garlic', 'salt', 'black pepper', 'rice', 'soy sauce'],
      almostAlwaysHave: ['onion', 'butter', 'parmesan'],
      dietaryRequirements: [],
      timePreference: 'Quick (under 30 min)',
      moodPreference: 'Something hearty',
      servings: 2,
      appliances: ['oven', 'stovetop'],
      perishableInventoryDescriptions: [
        'chicken breast (expires in 2d)',
        'broccoli (expires in 3d)',
        'lemon (expires in 5d)',
      ],
    ),
  ),
  Fixture(
    id: 'saver-veg',
    description: 'UK vegetarian + nut-free, saver mode on, 2 perishables.',
    region: 'uk',
    measurementUnits: 'metric',
    request: RecipeGenerationRequest(
      perishables: ['chestnut mushrooms', 'spinach'],
      alwaysHave: ['pasta', 'tinned tomatoes', 'onion', 'garlic', 'olive oil', 'salt', 'pepper', 'paprika'],
      almostAlwaysHave: ['cheddar cheese', 'eggs', 'milk', 'lentils'],
      dietaryRequirements: ['Vegetarian', 'Nut-free'],
      timePreference: '30 minutes',
      servings: 2,
      isSaverMode: true,
      appliances: ['stovetop', 'oven'],
      perishableInventoryDescriptions: [
        'chestnut mushrooms (expires in 2d)',
        'spinach (expires today)',
      ],
    ),
  ),
  Fixture(
    id: 'high-constraint-med',
    description: 'UK, gluten-free + dairy-free + shellfish-free, Mediterranean style enforced.',
    region: 'uk',
    measurementUnits: 'metric',
    request: RecipeGenerationRequest(
      perishables: ['salmon fillet', 'cherry tomatoes', 'courgette'],
      alwaysHave: ['olive oil', 'garlic', 'lemon', 'oregano', 'salt', 'pepper', 'rice', 'capers'],
      almostAlwaysHave: ['red onion', 'olives', 'parsley'],
      dietaryRequirements: ['Gluten-free', 'Dairy-free', 'Shellfish-free'],
      stylePreference: 'Mediterranean',
      timePreference: '30 minutes',
      servings: 2,
      appliances: ['oven', 'stovetop'],
      perishableInventoryDescriptions: [
        'salmon fillet (expires in 1d)',
        'cherry tomatoes (expires in 4d)',
        'courgette (expires in 3d)',
      ],
    ),
  ),
  Fixture(
    id: 'leftover-mode',
    description: 'US, leftover mode — roast chicken + rice need using up.',
    region: 'us',
    measurementUnits: 'imperial',
    request: RecipeGenerationRequest(
      perishables: [],
      alwaysHave: ['olive oil', 'garlic', 'soy sauce', 'rice vinegar', 'sesame oil', 'salt', 'pepper'],
      almostAlwaysHave: ['eggs', 'onion', 'frozen peas', 'spring onion'],
      dietaryRequirements: [],
      isLeftoverMode: true,
      leftoverItems: ['roast chicken (about 1.5 cups, shredded)', 'cooked white rice (about 2 cups)'],
      timePreference: 'Quick (under 20 min)',
      moodPreference: 'Use everything up',
      servings: 2,
      appliances: ['stovetop'],
    ),
  ),
  Fixture(
    id: 'taste-profile-loaded',
    description: 'US, strong taste signal — loves curries, dislikes pasta. Tests adaptive steering.',
    region: 'us',
    measurementUnits: 'imperial',
    request: RecipeGenerationRequest(
      perishables: ['chicken thighs', 'red bell pepper', 'coriander', 'lime'],
      alwaysHave: ['rice', 'onion', 'garlic', 'ginger', 'curry powder', 'turmeric', 'cumin', 'coconut milk', 'olive oil', 'salt'],
      almostAlwaysHave: ['yogurt', 'tomato paste', 'green chilli'],
      dietaryRequirements: [],
      timePreference: '45 minutes',
      servings: 4,
      likedRecipes: [
        'Thai green curry with chicken',
        'Chicken tikka masala',
        'Massaman beef curry',
        'Coconut chicken curry',
        'Goan fish curry',
      ],
      dislikedRecipes: [
        'Spaghetti aglio e olio',
        'Carbonara',
        'Penne arrabbiata',
        'Pesto pasta',
        'Lasagne',
      ],
      appliances: ['stovetop', 'oven'],
      perishableInventoryDescriptions: [
        'chicken thighs (expires in 2d)',
        'red bell pepper (expires in 5d)',
        'coriander (expires in 2d)',
        'lime (expires in 7d)',
      ],
    ),
  ),
];

Fixture? findFixture(String id) {
  for (final f in allFixtures) {
    if (f.id == id) return f;
  }
  return null;
}
