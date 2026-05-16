// ─────────────────────────────────────────────
// Provider abstraction
// Every model adapter implements Provider.generate(prompt) →
// ModelResponse with timing + raw output + cost estimate.
// ─────────────────────────────────────────────

import 'pricing.dart';

abstract class Provider {
  /// Model identifier (e.g. 'gemini-3.1-flash-lite-preview')
  String get modelId;

  /// Friendly name for reports
  String get displayName;

  /// Provider group ('google', 'openai', 'groq', 'mistral', 'anthropic')
  String get providerGroup;

  /// Generate via SSE streaming. Captures time-to-first-token and total time.
  /// Returns the accumulated raw text plus timing metadata.
  Future<ModelResponse> generate(String prompt, {Duration timeout});
}

class ModelResponse {
  final String modelId;
  final String rawText;
  final Duration timeToFirstToken;
  final Duration totalTime;
  final int? promptTokens;
  final int? completionTokens;
  final double? estimatedCostUSD;
  final String? errorMessage;
  final String? actualModelUsed; // for Gemma fallback notification

  const ModelResponse({
    required this.modelId,
    required this.rawText,
    required this.timeToFirstToken,
    required this.totalTime,
    this.promptTokens,
    this.completionTokens,
    this.estimatedCostUSD,
    this.errorMessage,
    this.actualModelUsed,
  });

  bool get isError => errorMessage != null;

  /// Tokens-per-second from output tokens. Returns 0 if no tokens or zero duration.
  double get tokensPerSecond {
    final secs = totalTime.inMilliseconds / 1000.0;
    if (completionTokens == null || completionTokens! <= 0 || secs <= 0) return 0;
    return completionTokens! / secs;
  }

  Map<String, dynamic> toJson() => {
    'modelId': modelId,
    if (actualModelUsed != null) 'actualModelUsed': actualModelUsed,
    'rawText': rawText,
    'timeToFirstTokenMs': timeToFirstToken.inMilliseconds,
    'totalTimeMs': totalTime.inMilliseconds,
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'estimatedCostUSD': estimatedCostUSD,
    'errorMessage': errorMessage,
    'tokensPerSecond': tokensPerSecond,
  };
}

/// Helper for adapters: compute cost from token counts + the pricing table.
double? computeCost(String modelId, int? promptTokens, int? completionTokens) {
  if (promptTokens == null || completionTokens == null) return null;
  final pricing = ModelPricing.lookup(modelId);
  if (pricing == null) return null;
  return (promptTokens * pricing.inputPerMillion / 1000000) +
      (completionTokens * pricing.outputPerMillion / 1000000);
}
