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
  lowCarb('Low-carb'),
  highProtein('High-protein');

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
  final String tier; // 'alwaysHave' | 'almostAlwaysHave' | 'perishable'
  final bool isRunningLow;
  final DateTime? expiryDate;
  final String? category; // e.g. 'Spices & Seasonings', 'Asian Pantry', etc.

  const InventoryItem({
    required this.name,
    required this.tier,
    this.isRunningLow = false,
    this.expiryDate,
    this.category,
  });

  /// Whether an expiry date is set.
  bool get hasExpiry => expiryDate != null;

  /// True if the item expires within 1-3 days (inclusive) from now.
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    final diff = expiry.difference(today).inDays;
    return diff >= 1 && diff <= 3;
  }

  /// True if the item expires today or is already past expiry.
  bool get isExpired {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    return expiry.difference(today).inDays <= 0;
  }

  /// Human-readable relative expiry label (e.g. "2d", "1w", "Expired").
  String? get expiryLabel {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    final days = expiry.difference(today).inDays;
    if (days < 0) return 'Expired';
    if (days == 0) return 'Today';
    if (days <= 6) return '${days}d';
    if (days <= 13) return '1w';
    return '${(days / 7).round()}w';
  }

  /// Description with urgency for Gemini prompt.
  String get geminiDescription {
    if (expiryDate == null) return name;
    final label = expiryLabel;
    if (label == 'Expired' || label == 'Today') return '$name (expires today)';
    return '$name (expires in $label)';
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'name': name,
      'tier': tier,
      'runningLow': isRunningLow,
    };
    if (expiryDate != null) {
      map['expiryDate'] = expiryDate!.toIso8601String();
    }
    if (category != null) {
      map['category'] = category;
    }
    return map;
  }

  factory InventoryItem.fromFirestore(Map<String, dynamic> data) {
    DateTime? expiry;
    final rawExpiry = data['expiryDate'];
    if (rawExpiry != null) {
      if (rawExpiry is String) {
        expiry = DateTime.tryParse(rawExpiry);
      }
      // Firestore Timestamp is handled in the service layer
    }
    return InventoryItem(
      name: data['name'] as String? ?? '',
      tier: data['tier'] as String? ?? 'almostAlwaysHave',
      isRunningLow: data['runningLow'] as bool? ?? false,
      expiryDate: expiry,
      category: data['category'] as String?,
    );
  }

  InventoryItem copyWith({String? name, String? tier, bool? isRunningLow, DateTime? expiryDate, bool clearExpiry = false, String? category, bool clearCategory = false}) {
    return InventoryItem(
      name: name ?? this.name,
      tier: tier ?? this.tier,
      isRunningLow: isRunningLow ?? this.isRunningLow,
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
      category: clearCategory ? null : (category ?? this.category),
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
