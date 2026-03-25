import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe_models.dart';

// ─────────────────────────────────────────────
// GeminiService
// Calls the Gemini 2.0 Flash API to generate recipes.
// Uses structured JSON output for reliable parsing.
// Cost: ~$0.0004 per recipe generation.
//
// Design decisions:
//   • Dietary requirements are hard constraints — always enforced.
//   • Style/mood/time chips are soft preferences — guide but don't restrict.
//   • Full inventory context is passed so the AI can use what the user has.
//   • Response is parsed into GeneratedRecipe model.
// ─────────────────────────────────────────────

class GeminiService {
  static const String _apiKey = 'AIzaSyDGY-Gf-kb1deC6yZ5o8pq8rYaa-hGmxYM';
  static const String _model = 'gemini-2.0-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static Future<GeneratedRecipe> generateRecipe(RecipeGenerationRequest request) async {
    final prompt = _buildPrompt(request);

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.8,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 2048,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error ${response.statusCode}: ${response.body}');
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No recipe generated. Please try again.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Empty response from AI. Please try again.');
    }

    final jsonText = parts[0]['text'] as String? ?? '';
    final recipeJson = jsonDecode(jsonText) as Map<String, dynamic>;
    return GeneratedRecipe.fromJson(recipeJson);
  }

  static String _buildPrompt(RecipeGenerationRequest request) {
    final buffer = StringBuffer();

    buffer.writeln('You are Elio, a friendly AI cooking assistant. Generate a single recipe based on the user\'s kitchen inventory and preferences.');
    buffer.writeln();
    buffer.writeln('## HARD CONSTRAINTS (must be respected — never override):');

    if (request.dietaryRequirements.isNotEmpty) {
      buffer.writeln('Dietary requirements: ${request.dietaryRequirements.join(', ')}');
      buffer.writeln('These are non-negotiable. Do not include any ingredients that violate these requirements.');
    } else {
      buffer.writeln('No dietary restrictions.');
    }

    buffer.writeln();
    buffer.writeln('## INVENTORY (what the user has):');

    if (request.perishables.isNotEmpty) {
      buffer.writeln('Fresh/perishable items (prioritise using these): ${request.perishables.join(', ')}');
    } else {
      buffer.writeln('No fresh items specified today — generate from pantry staples.');
    }

    if (request.alwaysHave.isNotEmpty) {
      buffer.writeln('Always have (pantry staples): ${request.alwaysHave.join(', ')}');
    }

    if (request.almostAlwaysHave.isNotEmpty) {
      buffer.writeln('Almost always have: ${request.almostAlwaysHave.join(', ')}');
    }

    buffer.writeln();
    buffer.writeln('## SOFT PREFERENCES (guide the recipe, but don\'t restrict):');

    if (request.timePreference != null) {
      buffer.writeln('Time: ${request.timePreference}');
    }
    if (request.stylePreference != null && request.stylePreference != 'Surprise me') {
      buffer.writeln('Style: ${request.stylePreference}');
    } else if (request.stylePreference == 'Surprise me') {
      buffer.writeln('Style: Be creative and surprising — choose any cuisine or style.');
    }
    if (request.moodPreference != null) {
      buffer.writeln('Mood: ${request.moodPreference}');
    }

    buffer.writeln();
    buffer.writeln('Servings: ${request.servings}');

    buffer.writeln();
    buffer.writeln('## INSTRUCTIONS:');
    buffer.writeln('1. Generate a practical, delicious recipe using primarily what the user has.');
    buffer.writeln('2. If a minor ingredient is missing, suggest a substitution from their inventory.');
    buffer.writeln('3. Keep instructions clear and friendly — this is for everyday home cooking.');
    buffer.writeln('4. Mark ingredients that came from the user\'s perishables as fromInventory: true.');
    buffer.writeln('5. Be realistic about cooking times.');

    buffer.writeln();
    buffer.writeln('## RESPONSE FORMAT:');
    buffer.writeln('Return ONLY valid JSON matching this exact schema:');
    buffer.writeln('''
{
  "title": "Recipe name",
  "description": "One or two sentence description of the dish",
  "prepTimeMinutes": 10,
  "cookTimeMinutes": 20,
  "servings": 2,
  "dietaryTags": ["vegetarian", "gluten-free"],
  "ingredients": [
    {
      "name": "chicken breast",
      "quantity": "2",
      "unit": "pieces",
      "fromInventory": true
    }
  ],
  "steps": [
    "Step 1 instruction.",
    "Step 2 instruction."
  ],
  "substitutions": [
    {
      "original": "sour cream",
      "substitute": "Greek yoghurt",
      "tradeOff": "Slightly tangier but works well here."
    }
  ]
}''');

    return buffer.toString();
  }
}
