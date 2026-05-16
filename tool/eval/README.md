# Elio Model Eval Harness

Compares LLMs head-to-head on Elio's real recipe-generation prompts. Sends the
exact same `buildRecipePrompt(...)` output that production uses to every model,
streams responses via SSE (so we measure true time-to-first-token), runs
structural checks on each output, and optionally scores them with
Claude Sonnet 4.6 as judge.

## Setup

Add API keys to `.env.local` at the repo root:

```
GEMINI_API_KEY=...      # already there for production builds
OPENAI_API_KEY=...      # https://platform.openai.com/api-keys
ANTHROPIC_API_KEY=...   # https://console.anthropic.com (judge only)
GROQ_API_KEY=...        # https://console.groq.com/keys
MISTRAL_API_KEY=...     # https://console.mistral.ai/api-keys
```

Missing keys just skip that provider — a warning is printed.

```
flutter pub get
```

## Run

```
# All models × all fixtures, with judge (default)
dart run tool/eval/run.dart

# Skip Claude judge (faster + cheaper, just structural checks)
dart run tool/eval/run.dart --no-judge

# Single model
dart run tool/eval/run.dart --models gemini-3.1-flash-lite-preview --no-judge

# Single fixture
dart run tool/eval/run.dart --fixtures busy-weeknight-omnivore

# Multiple specific models + fixtures
dart run tool/eval/run.dart \
  --models gemini-2.5-flash,gemini-3.1-flash-lite-preview \
  --fixtures busy-weeknight-omnivore,saver-veg

# Repeat each cell to smooth latency noise — median TTFT is reported
dart run tool/eval/run.dart --runs 3
```

Reports land in `tool/eval/results/<UTC timestamp>/report.md` (markdown summary)
and `raw.json` (full request/response/scores). The `results/` directory is
gitignored.

## Models tested by default

| Model | Why |
|---|---|
| `gemini-2.5-flash` | Current production streaming baseline |
| `gemini-2.5-flash-lite` | Current batch baseline |
| `gemini-3.1-flash-lite-preview` | Sprint 15.9 top candidate |
| `gemma-4-26b-a4b-it` (→ `gemma-4-31b-it` fallback) | Open-source comparison, free on AI Studio |
| `gpt-4.1-nano` | OpenAI cheap tier |
| `meta-llama/llama-4-scout-17b-16e-instruct` (Groq) | Speed wildcard |
| `mistral-small-latest` | Cost+speed wildcard |

To add a new model, edit `_buildProviders()` in `run.dart` and add its pricing
to `providers/pricing.dart`.

## What gets measured

For each (fixture, model) cell:

| Dimension | How |
|---|---|
| Time-to-first-token | Wall clock from POST to first non-empty text chunk |
| Total streaming time | Wall clock from POST to last chunk |
| Output tokens/sec | `completion_tokens / total_seconds` |
| Estimated USD cost | From `pricing.dart` × token counts |
| `json_parses` | Output runs through `extractJsonObject()` cleanly |
| `all_required_perishables_used` | Every fixture-listed perishable appears in `ingredients[]` |
| `dietary_tags_present` | `dietaryTags` non-empty when constraints exist |
| `cost_field_populated` | Both `estimatedCostPerServingUSD` + `GBP` present |
| `region_units_correct` | UK fixtures contain no imperial units |
| Judge: perishables / dietary / quality / instruction-following | 1–5 each, by Claude Sonnet 4.6 with rationale |

## Adding fixtures

Edit `fixtures.dart`. Each fixture is a `Fixture` containing a const
`RecipeGenerationRequest`. The eval uses the same `buildRecipePrompt` the app
calls, so the only thing you tune in a fixture is the request data.

## Updating prices

`providers/pricing.dart` holds per-million-token rates. Snapshot from May 2026 —
refresh when running fresh evals so cost columns are accurate.
