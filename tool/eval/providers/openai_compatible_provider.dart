import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'provider.dart';

// ─────────────────────────────────────────────
// OpenAICompatibleProvider
// Single adapter for OpenAI, Groq, Mistral, and OpenRouter —
// they all expose the same /v1/chat/completions SSE protocol.
// Differs only in base URL + auth header value.
// ─────────────────────────────────────────────

class OpenAICompatibleProvider implements Provider {
  @override
  final String modelId;

  @override
  final String displayName;

  @override
  final String providerGroup;

  final String baseUrl;       // e.g. 'https://api.openai.com/v1'
  final String apiKey;
  final int maxOutputTokens;
  final double temperature;

  /// If true, requests {response_format: {type: 'json_object'}}.
  /// All providers we hit support this except some Groq models — flip off when noisy.
  final bool jsonMode;

  OpenAICompatibleProvider({
    required this.modelId,
    required this.baseUrl,
    required this.apiKey,
    required this.providerGroup,
    String? displayName,
    this.maxOutputTokens = 1024,
    this.temperature = 0.8,
    this.jsonMode = true,
  }) : displayName = displayName ?? modelId;

  static final _client = http.Client();

  @override
  Future<ModelResponse> generate(String prompt, {Duration timeout = const Duration(seconds: 60)}) async {
    final url = '$baseUrl/chat/completions';

    final body = <String, dynamic>{
      'model': modelId,
      'stream': true,
      'temperature': temperature,
      'max_tokens': maxOutputTokens,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'stream_options': {'include_usage': true},
    };

    if (jsonMode) {
      body['response_format'] = {'type': 'json_object'};
    }

    final request = http.Request('POST', Uri.parse(url));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.body = jsonEncode(body);

    final stopwatch = Stopwatch()..start();
    Duration? ttft;
    final buffer = StringBuffer();
    int? promptTokens;
    int? completionTokens;

    try {
      final streamed = await _client.send(request).timeout(timeout);

      if (streamed.statusCode != 200) {
        final errorBody = await streamed.stream.bytesToString();
        return ModelResponse(
          modelId: modelId,
          rawText: '',
          timeToFirstToken: Duration.zero,
          totalTime: stopwatch.elapsed,
          errorMessage: 'HTTP ${streamed.statusCode}: ${errorBody.length > 200 ? errorBody.substring(0, 200) : errorBody}',
        );
      }

      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('data: ')) continue;
          final payload = trimmed.substring(6);
          if (payload.isEmpty || payload == '[DONE]') continue;

          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;

            final choices = data['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map<String, dynamic>?;
              final text = delta?['content'] as String?;
              if (text != null && text.isNotEmpty) {
                ttft ??= stopwatch.elapsed;
                buffer.write(text);
              }
            }

            // Usage info arrives in the final chunk when include_usage:true
            final usage = data['usage'] as Map<String, dynamic>?;
            if (usage != null) {
              promptTokens = (usage['prompt_tokens'] as num?)?.toInt() ?? promptTokens;
              completionTokens = (usage['completion_tokens'] as num?)?.toInt() ?? completionTokens;
            }
          } catch (_) {
            // Skip malformed chunk
          }
        }
      }

      stopwatch.stop();
      return ModelResponse(
        modelId: modelId,
        rawText: buffer.toString().trim(),
        timeToFirstToken: ttft ?? stopwatch.elapsed,
        totalTime: stopwatch.elapsed,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        estimatedCostUSD: computeCost(modelId, promptTokens, completionTokens),
      );
    } catch (e) {
      stopwatch.stop();
      return ModelResponse(
        modelId: modelId,
        rawText: buffer.toString(),
        timeToFirstToken: ttft ?? Duration.zero,
        totalTime: stopwatch.elapsed,
        errorMessage: e.toString(),
      );
    }
  }
}
