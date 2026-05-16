import 'dart:async';
import 'dart:convert';
import 'dart:io' show stderr;
import 'package:http/http.dart' as http;

import 'provider.dart';

// ─────────────────────────────────────────────
// GeminiProvider
// Calls Google AI Studio's generativelanguage endpoint via SSE.
// Mirrors GeminiService._streamFromPrompt config exactly so the
// eval reflects production behaviour.
//
// Used for: gemini-2.5-flash, gemini-2.5-flash-lite,
// gemini-3.1-flash-lite-preview, gemma-3-27b-it, gemma-4 (if available).
// ─────────────────────────────────────────────

class GeminiProvider implements Provider {
  @override
  final String modelId;

  @override
  final String displayName;

  /// If the primary modelId returns 404, try this fallback. Useful for
  /// gemma-4 (limited GA) → gemma-3-27b-it on the same endpoint.
  final String? fallbackModelId;

  final String apiKey;
  final int maxOutputTokens;
  final double temperature;
  final int topK;
  final double topP;
  final bool useThinkingBudgetZero;

  /// Defaults match GeminiService production config exactly.
  GeminiProvider({
    required this.modelId,
    required this.apiKey,
    String? displayName,
    this.fallbackModelId,
    this.maxOutputTokens = 1024,
    this.temperature = 0.8,
    this.topK = 40,
    this.topP = 0.95,
    this.useThinkingBudgetZero = true,
  }) : displayName = displayName ?? modelId;

  @override
  String get providerGroup => modelId.startsWith('gemma') ? 'gemma' : 'google';

  static final _client = http.Client();

  @override
  Future<ModelResponse> generate(String prompt, {Duration timeout = const Duration(seconds: 60)}) async {
    // Try primary, then fallback if 404.
    final attempt = await _attempt(modelId, prompt, timeout: timeout);
    if (attempt.isError && fallbackModelId != null && attempt.errorMessage!.contains('404')) {
      stderr.writeln('  ↳ $modelId not available, falling back to $fallbackModelId');
      final fallback = await _attempt(fallbackModelId!, prompt, timeout: timeout);
      return ModelResponse(
        modelId: modelId,
        actualModelUsed: fallbackModelId,
        rawText: fallback.rawText,
        timeToFirstToken: fallback.timeToFirstToken,
        totalTime: fallback.totalTime,
        promptTokens: fallback.promptTokens,
        completionTokens: fallback.completionTokens,
        estimatedCostUSD: fallback.estimatedCostUSD,
        errorMessage: fallback.errorMessage,
      );
    }
    return attempt;
  }

  Future<ModelResponse> _attempt(String model, String prompt, {required Duration timeout}) async {
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse&key=$apiKey';

    final body = <String, dynamic>{
      'contents': [
        {'parts': [{'text': prompt}]}
      ],
      'generationConfig': {
        'temperature': temperature,
        'topK': topK,
        'topP': topP,
        'maxOutputTokens': maxOutputTokens,
        'responseMimeType': 'application/json',
      },
    };

    // thinkingBudget is only honoured by 2.5+ Flash models, not Gemma
    if (useThinkingBudgetZero && model.startsWith('gemini-')) {
      (body['generationConfig'] as Map)['thinkingConfig'] = {'thinkingBudget': 0};
    }

    final request = http.Request('POST', Uri.parse(url));
    request.headers['Content-Type'] = 'application/json';
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
          modelId: model,
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
          final jsonStr = trimmed.substring(6);
          if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

          try {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            final candidates = data['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'] as Map<String, dynamic>?;
              final parts = content?['parts'] as List<dynamic>?;
              if (parts != null) {
                for (final part in parts) {
                  final text = part['text'] as String?;
                  if (text != null && text.isNotEmpty) {
                    ttft ??= stopwatch.elapsed;
                    buffer.write(text);
                  }
                }
              }
            }
            // Token usage in final chunk
            final usage = data['usageMetadata'] as Map<String, dynamic>?;
            if (usage != null) {
              promptTokens = (usage['promptTokenCount'] as num?)?.toInt() ?? promptTokens;
              completionTokens = (usage['candidatesTokenCount'] as num?)?.toInt() ?? completionTokens;
            }
          } catch (_) {
            // Skip malformed chunk
          }
        }
      }

      stopwatch.stop();
      return ModelResponse(
        modelId: model,
        rawText: buffer.toString().trim(),
        timeToFirstToken: ttft ?? stopwatch.elapsed,
        totalTime: stopwatch.elapsed,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        estimatedCostUSD: computeCost(model, promptTokens, completionTokens),
      );
    } catch (e) {
      stopwatch.stop();
      return ModelResponse(
        modelId: model,
        rawText: buffer.toString(),
        timeToFirstToken: ttft ?? Duration.zero,
        totalTime: stopwatch.elapsed,
        errorMessage: e.toString(),
      );
    }
  }
}

