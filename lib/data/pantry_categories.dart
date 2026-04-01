// ─────────────────────────────────────────────
// Pantry Categories
// Canonical list of categories and their items for the Pantry Builder
// and grouped pantry view. Each item maps to exactly one canonical category.
// ─────────────────────────────────────────────

class PantryCategory {
  final String name;
  final String icon; // emoji for display
  final Map<String, List<String>> subcategories; // '' key = no subcategory

  const PantryCategory({
    required this.name,
    required this.icon,
    required this.subcategories,
  });

  List<String> get allItems =>
      subcategories.values.expand((list) => list).toList();
}

class PantryCategories {
  PantryCategories._();

  static const List<PantryCategory> all = [
    PantryCategory(
      name: 'Spices & Seasonings',
      icon: '🌶️',
      subcategories: {
        'Basic': [
          'Salt', 'Black pepper', 'Garlic powder', 'Onion powder', 'Paprika',
          'Cumin', 'Oregano', 'Chilli flakes', 'Cinnamon', 'Mixed herbs',
          'Thyme', 'Rosemary', 'Bay leaves', 'Nutmeg', 'Cayenne pepper',
          'Smoked paprika',
        ],
      },
    ),
    PantryCategory(
      name: 'Asian Pantry',
      icon: '🥢',
      subcategories: {
        '': [
          'Soy sauce', 'Fish sauce', 'Sesame oil', 'Rice vinegar', 'Mirin',
          'Oyster sauce', 'Sriracha', 'Gochujang', 'Hoisin sauce',
          'Ginger (ground)', 'Five-spice', 'Lemongrass', 'Turmeric',
          'Coconut milk', 'Rice (white)', 'Noodles (egg)', 'Noodles (rice)',
          'Rice paper', 'Miso paste', 'Tofu',
        ],
      },
    ),
    PantryCategory(
      name: 'Indian Pantry',
      icon: '🍛',
      subcategories: {
        '': [
          'Garam masala', 'Turmeric', 'Cumin seeds', 'Coriander (ground)',
          'Chilli powder', 'Cardamom', 'Mustard seeds', 'Fenugreek',
          'Curry powder', 'Curry paste', 'Ghee', 'Lentils (red)',
          'Lentils (green)', 'Chickpeas', 'Basmati rice', 'Naan bread',
          'Paneer', 'Tamarind paste',
        ],
      },
    ),
    PantryCategory(
      name: 'Mexican & Latin',
      icon: '🌮',
      subcategories: {
        '': [
          'Chipotle paste', 'Chipotle in adobo', 'Taco seasoning',
          'Tortillas (flour)', 'Tortillas (corn)', 'Black beans',
          'Kidney beans', 'Jalapeños', 'Lime', 'Cilantro',
          'Cumin', 'Smoked paprika', 'Cayenne pepper', 'Refried beans',
          'Salsa', 'Sour cream',
        ],
      },
    ),
    PantryCategory(
      name: 'Mediterranean',
      icon: '🫒',
      subcategories: {
        '': [
          'Olives', 'Capers', 'Sun-dried tomatoes', 'Feta', 'Harissa',
          'Za\'atar', 'Tahini', 'Preserved lemons', 'Halloumi',
          'Hummus', 'Artichoke hearts', 'Pesto', 'Pine nuts',
          'Extra virgin olive oil', 'Balsamic vinegar',
        ],
      },
    ),
    PantryCategory(
      name: 'Oils & Vinegars',
      icon: '🫗',
      subcategories: {
        '': [
          'Olive oil', 'Extra virgin olive oil', 'Vegetable oil',
          'Coconut oil', 'Sesame oil', 'Balsamic vinegar',
          'White wine vinegar', 'Red wine vinegar', 'Apple cider vinegar',
          'Spray oil',
        ],
      },
    ),
    PantryCategory(
      name: 'Dairy & Eggs',
      icon: '🥚',
      subcategories: {
        '': [
          'Eggs', 'Butter', 'Milk', 'Double cream', 'Single cream',
          'Cheddar cheese', 'Parmesan', 'Mozzarella', 'Cream cheese',
          'Greek yoghurt', 'Natural yoghurt', 'Sour cream',
        ],
      },
    ),
    PantryCategory(
      name: 'Canned & Jarred',
      icon: '🥫',
      subcategories: {
        '': [
          'Tinned tomatoes', 'Chopped tomatoes', 'Tomato puree',
          'Coconut milk', 'Chickpeas', 'Kidney beans', 'Black beans',
          'Baked beans', 'Tuna', 'Sweetcorn', 'Peanut butter',
          'Jam', 'Olives', 'Anchovies', 'Passata',
        ],
      },
    ),
    PantryCategory(
      name: 'Grains & Pasta',
      icon: '🍝',
      subcategories: {
        '': [
          'Pasta (spaghetti)', 'Pasta (penne)', 'Pasta (fusilli)',
          'Rice (white)', 'Rice (brown)', 'Basmati rice', 'Couscous',
          'Quinoa', 'Oats', 'Bread', 'Noodles (egg)', 'Noodles (rice)',
          'Orzo', 'Risotto rice', 'Bulgur wheat',
        ],
      },
    ),
    PantryCategory(
      name: 'Baking Essentials',
      icon: '🧁',
      subcategories: {
        '': [
          'Plain flour', 'Self-raising flour', 'Strong bread flour',
          'Baking powder', 'Bicarbonate of soda', 'Vanilla extract',
          'Cocoa powder', 'Caster sugar', 'Brown sugar', 'Icing sugar',
          'Cornflour', 'Yeast', 'Golden syrup', 'Chocolate chips',
        ],
      },
    ),
    PantryCategory(
      name: 'Sauces & Condiments',
      icon: '🍯',
      subcategories: {
        '': [
          'Ketchup', 'Mayonnaise', 'Mustard', 'Dijon mustard',
          'Worcestershire sauce', 'Hot sauce', 'Honey', 'Maple syrup',
          'Tomato puree', 'BBQ sauce', 'Soy sauce',
          'Stock cubes (chicken)', 'Stock cubes (vegetable)',
          'Stock cubes (beef)', 'Mango chutney',
        ],
      },
    ),
    PantryCategory(
      name: 'Frozen Staples',
      icon: '🧊',
      subcategories: {
        '': [
          'Frozen peas', 'Frozen sweetcorn', 'Frozen spinach',
          'Frozen berries', 'Frozen prawns', 'Frozen chips',
          'Ice cream', 'Frozen pastry (puff)', 'Frozen pastry (shortcrust)',
          'Frozen mixed vegetables', 'Frozen edamame',
        ],
      },
    ),
  ];

  /// Flat lookup: item name (lowercase) → category name.
  /// Built lazily on first access.
  static Map<String, String>? _lookupCache;

  static Map<String, String> get _lookup {
    if (_lookupCache != null) return _lookupCache!;
    final map = <String, String>{};
    for (final cat in all) {
      for (final item in cat.allItems) {
        // First category wins — items that appear in multiple categories
        // are assigned to the first one listed (most specific).
        final key = item.toLowerCase().trim();
        map.putIfAbsent(key, () => cat.name);
      }
    }
    _lookupCache = map;
    return map;
  }

  /// Look up the canonical category for an item name.
  /// Returns null if not found in any category.
  static String? categorize(String itemName) {
    return _lookup[itemName.toLowerCase().trim()];
  }

  /// Get a category by name.
  static PantryCategory? byName(String name) {
    for (final cat in all) {
      if (cat.name == name) return cat;
    }
    return null;
  }
}
