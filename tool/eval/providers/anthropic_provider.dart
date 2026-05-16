import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────
// AnthropicProvider — non-streaming, used by judge.dart only.
// Tool-use is used to force a strict JSON scorecard.
// ─────────────────────────────────────────────

class AnthropicProvider {
  final String apiKey;
  final String modelId;

  AnthropicProvider({
    required this.apiKey,
    this.modelId = 'claude-sonnet-4-6',
  });

  static final _client = http.Client();

  /// Call Claude with a tool-use forcing function. Returns the tool_use input as JSON.
  Future<Map<String, dynamic>> callTool({
    required String systemPrompt,
    required String userPrompt,
    required Map<String, dynamic> toolSchema,
    required String toolName,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final url = 'https://api.anthropic.com/v1/messages';

    final body = {
      'model': modelId,
      'max_tokens': 1024,
      'system': systemPrompt,
      'tools': [
        {
          'name': toolName,
          'description': 'Submit your scorecard for this model output.',
          'input_schema': toolSchema,
        }
      ],
      'tool_choice': {'type': 'tool', 'name': toolName},
      'messages': [
        {'role': 'user', 'content': userPrompt},
      ],
    };

    final response = await _client.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode(body),
    ).timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('Anthropic call failed (${response.statusCode}): ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>?;
    if (content == null) throw Exception('Empty content from Anthropic');

    for (final block in content) {
      if (block['type'] == 'tool_use' && block['name'] == toolName) {
        return block['input'] as Map<String, dynamic>;
      }
    }
    throw Exception('No tool_use block returned by Anthropic');
  }
}
