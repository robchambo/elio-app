// ─────────────────────────────────────────────
// Elio Core Models
// Data structures for the Elio app.
// These mirror the Firestore schema defined in the design document.
// ─────────────────────────────────────────────

// ─── Dietary requirements ─────────────────────────────────────────────────────

enum DietaryRequirement {
  vegetarian('Vegetarian'),
  vegan('Vegan'),
  glutenFree('Gluten-free'),
  dairyFree('Dairy-free'),
  nutFree('Nut-free'),
  halalCertified('Halal'),
  kosher('Kosher'),
  lowFodmap('Low FODMAP'),
  diabeticFriendly('Diabetic-friendly'),
  lowCarb('Low-carb');

  final String label;
  const DietaryRequirement(this.label);
}

// ─── Kitchen presets ─────────────────────────────────────────────────────────

enum KitchenPreset {
  basicCook(
    'Basic Cook',
    'I keep the essentials — oil, salt, pepper, pasta, rice.',
    ['Olive oil', 'Salt', 'Black pepper', 'Pasta', 'Rice', 'Onions', 'Garlic'],
    ['Tinned tomatoes', 'Chicken stock', 'Butter', 'Eggs', 'Plain flour'],
  ),
  homeCook(
    'Home Cook',
    'A well-stocked kitchen with spices and condiments.',
    ['Olive oil', 'Salt', 'Black pepper', 'Pasta', 'Rice', 'Onions', 'Garlic', 'Cumin', 'Paprika', 'Oregano', 'Soy sauce', 'Worcestershire sauce'],
    ['Tinned tomatoes', 'Chicken stock', 'Butter', 'Eggs', 'Plain flour', 'Coconut milk', 'Lentils', 'Chickpeas'],
  ),
  enthusiast(
    'Enthusiast',
    'I have most things — fresh herbs, specialty sauces, the lot.',
    ['Olive oil', 'Extra virgin olive oil', 'Salt', 'Black pepper', 'Pasta', 'Rice', 'Quinoa', 'Onions', 'Garlic', 'Shallots', 'Cumin', 'Paprika', 'Smoked paprika', 'Oregano', 'Thyme', 'Rosemary', 'Bay leaves', 'Chilli flakes', 'Soy sauce', 'Fish sauce', 'Worcestershire sauce', 'Balsamic vinegar', 'Dijon mustard', 'Tahini', 'Miso paste'],
    ['Tinned tomatoes', 'Chicken stock', 'Vegetable stock', 'Butter', 'Eggs', 'Plain flour', 'Coconut milk', 'Lentils', 'Chickpeas', 'Panko breadcrumbs', 'Capers', 'Anchovies', 'Sun-dried tomatoes'],
  );

  final String label;
  final String description;
  final List<String> alwaysHave;
  final List<String> almostAlwaysHave;

  const KitchenPreset(this.label, this.description, this.alwaysHave, this.almostAlwaysHave);
}

// ─── Inventory item ───────────────────────────────────────────────────────────

class InventoryItem {
  final String name;
  final String tier; // 'alwaysHave' | 'almostAlwaysHave'
  final bool isRunningLow;

  const InventoryItem({
    required this.name,
    required this.tier,
    this.isRunningLow = false,
  });

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'tier': tier,
    'runningLow': isRunningLow,
  };

  factory InventoryItem.fromFirestore(Map<String, dynamic> data) {
    return InventoryItem(
      name: data['name'] as String? ?? '',
      tier: data['tier'] as String? ?? 'almostAlwaysHave',
      isRunningLow: data['runningLow'] as bool? ?? false,
    );
  }

  InventoryItem copyWith({String? name, String? tier, bool? isRunningLow}) {
    return InventoryItem(
      name: name ?? this.name,
      tier: tier ?? this.tier,
      isRunningLow: isRunningLow ?? this.isRunningLow,
    );
  }
}

// ─── Household profile ────────────────────────────────────────────────────────

class HouseholdProfile {
  final String name;
  final List<DietaryRequirement> dietaryRequirements;
  final bool isOwner;

  const HouseholdProfile({
    required this.name,
    required this.dietaryRequirements,
    this.isOwner = false,
  });

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'dietaryRequirements': dietaryRequirements.map((d) => d.name).toList(),
    'isOwner': isOwner,
  };

  factory HouseholdProfile.fromFirestore(Map<String, dynamic> data) {
    return HouseholdProfile(
      name: data['name'] as String? ?? '',
      dietaryRequirements: (data['dietaryRequirements'] as List<dynamic>? ?? [])
          .map((d) => DietaryRequirement.values.firstWhere(
                (e) => e.name == d,
                orElse: () => DietaryRequirement.vegetarian,
              ))
          .toList(),
      isOwner: data['isOwner'] as bool? ?? false,
    );
  }
}
