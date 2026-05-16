// ─────────────────────────────────────────────
// Per-model pricing table (USD per 1M tokens).
// Snapshot from May 2026. Update when running fresh evals.
// ─────────────────────────────────────────────

class ModelPricing {
  final double inputPerMillion;
  final double outputPerMillion;
  const ModelPricing(this.inputPerMillion, this.outputPerMillion);

  static const Map<String, ModelPricing> _table = {
    // Google
    'gemini-2.5-flash': ModelPricing(0.30, 2.50),
    'gemini-2.5-flash-lite': ModelPricing(0.10, 0.40),
    'gemini-3.1-flash-lite-preview': ModelPricing(0.25, 1.50),
    // Gemma on AI Studio is free; if Rob ever switches to a paid host
    // (OpenRouter/Together) these need refreshing.
    'gemma-4-26b-a4b-it': ModelPricing(0.0, 0.0),
    'gemma-4-31b-it': ModelPricing(0.0, 0.0),

    // OpenAI
    'gpt-4.1-nano': ModelPricing(0.10, 0.40),

    // Groq (Llama 4 Scout)
    'meta-llama/llama-4-scout-17b-16e-instruct': ModelPricing(0.11, 0.34),

    // Mistral
    'mistral-small-latest': ModelPricing(0.10, 0.30),

    // Anthropic (judge)
    'claude-sonnet-4-6': ModelPricing(3.00, 15.00),
  };

  static ModelPricing? lookup(String modelId) => _table[modelId];
}
