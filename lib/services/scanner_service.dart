import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import 'error_service.dart';
import 'remote_config_service.dart';

// ─────────────────────────────────────────────
// ScannerService
// Handles barcode product lookup, receipt OCR via Gemini Vision,
// tier memory CRUD, non-food filtering, and smart tier assignment.
//
// Cost optimisations (Sprint 15):
//   • Switched to gemini-2.5-flash-lite (~35% cheaper, no thinking tokens)
//   • responseMimeType: application/json — guaranteed clean JSON
//   • Receipt prompt compressed
// ─────────────────────────────────────────────

class ScannerService {
  static ScannerService? _instance;
  static ScannerService get instance => _instance ??= ScannerService._();
  ScannerService._();

  static String get _apiKey => RemoteConfigService.instance.geminiApiKey;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String get _uid => _auth.currentUser!.uid;

  // ── Barcode Lookup ──────────────────────────────────────────────
  // Uses Open Food Facts API (free, no key needed)
  Future<ScannedItem?> lookupBarcode(String barcode) async {
    try {
      final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode'
        '?fields=product_name,brands,categories_tags',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'Elio/1.0'},
      );
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 1) return null;

      final product = json['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final name = product['product_name'] as String? ?? '';
      if (name.isEmpty) return null;

      final brand = product['brands'] as String?;
      final cats =
          (product['categories_tags'] as List?)?.cast<String>() ?? [];
      final category =
          cats.isNotEmpty ? cats.first.replaceAll('en:', '') : null;

      final result = await suggestTier(name, category: category);

      return ScannedItem(
        name: name,
        brand: brand,
        category: category,
        suggestedTier: result.tier,
        isNonFood: false,
        tierFromMemory: result.fromMemory,
      );
    } catch (e) {
      // Network error or unexpected response — return null so the caller
      // can fall back to manual entry.
      return null;
    }
  }

  // ── Receipt OCR ─────────────────────────────────────────────────
  // Sends image bytes to Gemini Vision API, extracts food items + prices.
  Future<ReceiptScanResult> scanReceipt(Uint8List imageBytes) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      const prompt = 'Extract food items from this receipt. For non-food items set isFood:false. Schema: {storeName:string|null, items:[{name:string (clean, no codes), price:string, category:dairy|meat|produce|bakery|frozen|canned|dry_goods|condiment|beverage|snack|other, isFood:bool}]}';

      final content = Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', imageBytes),
      ]);

      final response = await model.generateContent([content]);
      final rawText = response.text ?? '';

      final parsed = _extractJson(rawText);
      final storeName = parsed['storeName'] as String?;
      final rawItems = (parsed['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final List<ScannedItem> foodItems = [];
      int nonFoodCount = 0;

      for (final item in rawItems) {
        final isFood = item['isFood'] as bool? ?? true;
        final name = (item['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;

        if (!isFood) {
          nonFoodCount++;
          continue;
        }

        final category = item['category'] as String?;
        final price = item['price']?.toString();
        final tierResult = await suggestTier(name, category: category);

        foodItems.add(ScannedItem(
          name: name,
          category: category,
          price: price,
          suggestedTier: tierResult.tier,
          isNonFood: false,
          tierFromMemory: tierResult.fromMemory,
        ));
      }

      return ReceiptScanResult(
        storeName: storeName,
        items: foodItems,
        nonFoodFilteredCount: nonFoodCount,
      );
    } catch (e) {
      ErrorService.log('receipt_scan', e);
      // Return empty result on failure so the UI can show an error message
      // rather than crashing.
      return ReceiptScanResult(
        storeName: null,
        items: [],
        nonFoodFilteredCount: 0,
      );
    }
  }

  // ── Tier Memory ─────────────────────────────────────────────────
  // Firestore: users/{uid}/tierMemory/{normalizedName}
  Future<String?> getRememberedTier(String itemName) async {
    try {
      final normalized = itemName.trim().toLowerCase();
      final doc = await _db
          .collection('users')
          .doc(_uid)
          .collection('tierMemory')
          .doc(normalized)
          .get();
      if (!doc.exists) return null;
      return doc.data()?['tier'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTierMemory(String itemName, String tier) async {
    final normalized = itemName.trim().toLowerCase();
    await _db
        .collection('users')
        .doc(_uid)
        .collection('tierMemory')
        .doc(normalized)
        .set(
      {'tier': tier, 'lastSeen': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ── Smart Tier Assignment ───────────────────────────────────────
  // 1. Check tier memory first
  // 2. If not found, guess based on category
  // 3. Fall back to name-based heuristics
  /// Returns (tier, fromMemory) — whether the tier came from user's saved memory.
  Future<({String tier, bool fromMemory})> suggestTier(String itemName, {String? category}) async {
    // 1. Check memory first
    final remembered = await getRememberedTier(itemName);
    if (remembered != null) return (tier: remembered, fromMemory: true);

    // 2. Guess from category
    final cat = (category ?? '').toLowerCase();

    const perishableCategories = [
      'dairy', 'meat', 'fish', 'seafood', 'produce', 'fresh', 'milk',
      'eggs', 'cheese', 'yogurt', 'poultry', 'fruit', 'vegetable', 'bakery',
    ];
    const alwaysHaveCategories = [
      'spice', 'oil', 'pasta', 'rice', 'canned', 'dry_goods', 'condiment',
      'sauce', 'flour', 'sugar', 'salt', 'pepper', 'vinegar',
    ];

    for (final pc in perishableCategories) {
      if (cat.contains(pc)) return (tier: 'perishable', fromMemory: false);
    }
    for (final ac in alwaysHaveCategories) {
      if (cat.contains(ac)) return (tier: 'alwaysHave', fromMemory: false);
    }

    // 3. Name-based heuristics
    final lower = itemName.toLowerCase();

    if (lower.contains('milk') ||
        lower.contains('chicken') ||
        lower.contains('beef') ||
        lower.contains('pork') ||
        lower.contains('fish') ||
        lower.contains('salmon') ||
        lower.contains('prawn') ||
        lower.contains('lettuce') ||
        lower.contains('tomato') ||
        lower.contains('cheese') ||
        lower.contains('yogurt') ||
        lower.contains('cream') ||
        lower.contains('butter') ||
        lower.contains('egg')) {
      return (tier: 'perishable', fromMemory: false);
    }

    if (lower.contains('oil') ||
        lower.contains('rice') ||
        lower.contains('pasta') ||
        lower.contains('flour') ||
        lower.contains('sugar') ||
        lower.contains('salt') ||
        lower.contains('spice') ||
        lower.contains('tinned') ||
        lower.contains('canned')) {
      return (tier: 'alwaysHave', fromMemory: false);
    }

    return (tier: 'almostAlwaysHave', fromMemory: false);
  }

  // ── JSON Extraction ─────────────────────────────────────────────
  // With responseMimeType: application/json, direct parse should always work.
  // Minimal fallback kept as safety net.
  static Map<String, dynamic> _extractJson(String text) {
    text = text.trim();

    if (text.startsWith('{')) {
      try {
        return jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {}
    }

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      try {
        return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Could not parse receipt JSON: ${e.toString().substring(0, 80)}');
      }
    }

    throw Exception('No JSON object found in Gemini response.');
  }
}

// ── Data Models ─────────────────────────────────────────────────────

class ScannedItem {
  final String name;
  final String? brand;
  final String? category;
  final String? price;
  final String suggestedTier;
  final bool isNonFood;

  /// Whether the tier was loaded from tier memory (previous scan).
  final bool tierFromMemory;

  /// Optional expiry label chosen during receipt review (e.g. "3 days", "1 week").
  final String? expiryLabel;

  const ScannedItem({
    required this.name,
    this.brand,
    this.category,
    this.price,
    required this.suggestedTier,
    this.isNonFood = false,
    this.tierFromMemory = false,
    this.expiryLabel,
  });

  ScannedItem copyWith({
    String? name,
    String? brand,
    String? category,
    String? price,
    String? suggestedTier,
    bool? isNonFood,
    bool? tierFromMemory,
    String? expiryLabel,
  }) {
    return ScannedItem(
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      price: price ?? this.price,
      suggestedTier: suggestedTier ?? this.suggestedTier,
      isNonFood: isNonFood ?? this.isNonFood,
      tierFromMemory: tierFromMemory ?? this.tierFromMemory,
      expiryLabel: expiryLabel ?? this.expiryLabel,
    );
  }

  @override
  String toString() =>
      'ScannedItem(name: $name, brand: $brand, tier: $suggestedTier)';
}

class ReceiptScanResult {
  final String? storeName;
  final List<ScannedItem> items;
  final int nonFoodFilteredCount;

  const ReceiptScanResult({
    this.storeName,
    required this.items,
    required this.nonFoodFilteredCount,
  });

  @override
  String toString() =>
      'ReceiptScanResult(store: $storeName, items: ${items.length}, '
      'filtered: $nonFoodFilteredCount)';
}
