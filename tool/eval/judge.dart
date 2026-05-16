import 'dart:io';

import 'fixtures.dart';
import 'providers/anthropic_provider.dart';

// ─────────────────────────────────────────────
// Judge — Claude Sonnet 4.6 scores each model output on
// 4 dimensions, returning 1-5 + one-sentence rationale per dimension.
// Uses Anthropic tool-use for strict JSON.
// ─────────────────────────────────────────────

class JudgeScore {
  final int score;        // 1–5
  final String rationale;
  const JudgeScore(this.score, this.rationale);

  Map<String, dynamic> toJson() => {'score': score, 'rationale': rationale};
}

class JudgeReport {
  final JudgeScore perishablesAdherence;
  final JudgeScore dietaryCompliance;
  final JudgeScore recipeQuality;
  final JudgeScore instructionFollowing;
  final String? errorMessage;

  const JudgeReport({
    required this.perishablesAdherence,
    required this.dietaryCompliance,
    required this.recipeQuality,
    required this.instructionFollowing,
    this.errorMessage,
  });

  double get averageScore =>
      (perishablesAdherence.score + dietaryCompliance.score + recipeQuality.score + instructionFollowing.score) / 4.0;

  Map<String, dynamic> toJson() => {
    'perishablesAdherence': perishablesAdherence.toJson(),
    'dietaryCompliance': dietaryCompliance.toJson(),
    'recipeQuality': recipeQuality.toJson(),
    'instructionFollowing': instructionFollowing.toJson(),
    'averageScore': averageScore,
    if (errorMessage != null) 'errorMessage': errorMessage,
  };

  factory JudgeReport.failed(String error) => JudgeReport(
    perishablesAdherence: JudgeScore(0, 'Judge call failed'),
    dietaryCompliance: JudgeScore(0, 'Judge call failed'),
    recipeQuality: JudgeScore(0, 'Judge call failed'),
    instructionFollowing: JudgeScore(0, 'Judge call failed'),
    errorMessage: error,
  );
}

const _systemPrompt = '''
You are an impartial judge evaluating recipe generation outputs from an AI cooking app called Elio.
The app prompts a model with the user's pantry, dietary requirements, and preferences, and expects a single recipe back as JSON.

Score each output on 4 dimensions, 1-5 (1 = severe failure, 5 = excellent).
Be strict on hard constraints (perishables, dietary). Be moderate on subjective quality.
Return your scores via the submit_score tool.''';

const _toolSchema = {
  'type': 'object',
  'properties': {
    'perishables_adherence': {
      'type': 'object',
      'properties': {
        'score': {'type': 'integer', 'minimum': 1, 'maximum': 5},
        'rationale': {'type': 'string', 'description': 'One sentence — did the recipe use all required perishables?'},
      },
      'required': ['score', 'rationale'],
    },
    'dietary_compliance': {
      'type': 'object',
      'properties': {
        'score': {'type': 'integer', 'minimum': 1, 'maximum': 5},
        'rationale': {'type': 'string', 'description': 'One sentence — does it violate any dietary requirement?'},
      },
      'required': ['score', 'rationale'],
    },
    'recipe_quality': {
      'type': 'object',
      'properties': {
        'score': {'type': 'integer', 'minimum': 1, 'maximum': 5},
        'rationale': {'type': 'string', 'description': 'One sentence — is the recipe realistic, edible, well-portioned?'},
      },
      'required': ['score', 'rationale'],
    },
    'instruction_following': {
      'type': 'object',
      'properties': {
        'score': {'type': 'integer', 'minimum': 1, 'maximum': 5},
        'rationale': {'type': 'string', 'description': 'One sentence — did it honour style/saver-mode/region/leftover constraints?'},
      },
      'required': ['score', 'rationale'],
    },
  },
  'required': ['perishables_adherence', 'dietary_compliance', 'recipe_quality', 'instruction_following'],
};

class Judge {
  final AnthropicProvider _anthropic;

  Judge(String apiKey) : _anthropic = AnthropicProvider(apiKey: apiKey);

  Future<JudgeReport> score({
    required Fixture fixture,
    required String modelId,
    required String rawOutput,
  }) async {
    final userPrompt = StringBuffer()
      ..writeln('## Fixture: ${fixture.id}')
      ..writeln(fixture.description)
      ..writeln()
      ..writeln('## Hard constraints')
      ..writeln('Region: ${fixture.region.toUpperCase()}, units: ${fixture.measurementUnits}')
      ..writeln('Dietary requirements: ${fixture.request.dietaryRequirements.isEmpty ? "none" : fixture.request.dietaryRequirements.join(", ")}')
      ..writeln('Required perishables (MUST appear): ${fixture.request.perishables.isEmpty ? "n/a" : fixture.request.perishables.join(", ")}');

    if (fixture.request.stylePreference != null && fixture.request.stylePreference != 'Surprise me') {
      userPrompt.writeln('Style required: ${fixture.request.stylePreference}');
    }
    if (fixture.request.isSaverMode) {
      userPrompt.writeln('Saver mode: yes (budget-friendly expected, < £2/\$3 per serving)');
    }
    if (fixture.request.isLeftoverMode) {
      userPrompt.writeln('Leftover mode: ${fixture.request.leftoverItems.join(", ")} must drive the recipe');
    }
    if (fixture.request.likedRecipes.isNotEmpty) {
      userPrompt.writeln('User likes (steer toward): ${fixture.request.likedRecipes.join(", ")}');
    }
    if (fixture.request.dislikedRecipes.isNotEmpty) {
      userPrompt.writeln('User dislikes (steer away): ${fixture.request.dislikedRecipes.join(", ")}');
    }

    userPrompt
      ..writeln()
      ..writeln('## Model under test: $modelId')
      ..writeln('## Raw output:')
      ..writeln(rawOutput.length > 4000 ? '${rawOutput.substring(0, 4000)}...(truncated)' : rawOutput);

    try {
      final result = await _anthropic.callTool(
        systemPrompt: _systemPrompt,
        userPrompt: userPrompt.toString(),
        toolSchema: _toolSchema,
        toolName: 'submit_score',
      );

      return JudgeReport(
        perishablesAdherence: _parseScore(result['perishables_adherence']),
        dietaryCompliance: _parseScore(result['dietary_compliance']),
        recipeQuality: _parseScore(result['recipe_quality']),
        instructionFollowing: _parseScore(result['instruction_following']),
      );
    } catch (e) {
      stderr.writeln('  ⚠ Judge failed for $modelId: $e');
      return JudgeReport.failed(e.toString());
    }
  }

  JudgeScore _parseScore(dynamic node) {
    if (node is Map<String, dynamic>) {
      final score = (node['score'] as num?)?.toInt() ?? 0;
      final rationale = node['rationale'] as String? ?? '';
      return JudgeScore(score, rationale);
    }
    return const JudgeScore(0, 'Missing score');
  }
}
