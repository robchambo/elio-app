import 'dart:io';

import 'package:elio_app/services/gemini_prompt_builder.dart';

import 'env.dart';
import 'fixtures.dart';
import 'judge.dart';
import 'providers/gemini_provider.dart';
import 'providers/openai_compatible_provider.dart';
import 'providers/provider.dart';
import 'report.dart';
import 'structural.dart';

// ─────────────────────────────────────────────
// Elio Model Eval Harness — entrypoint.
//
// Usage:
//   dart run tool/eval/run.dart                                  # all models × all fixtures + judge
//   dart run tool/eval/run.dart --no-judge                       # skip Claude judge
//   dart run tool/eval/run.dart --models gemini-2.5-flash,gpt-4.1-nano
//   dart run tool/eval/run.dart --fixtures busy-weeknight-omnivore,saver-veg
//   dart run tool/eval/run.dart --runs 3                         # repeat each cell to smooth noise
//
// Reads API keys from .env.local at the repo root. Missing keys → skip that provider.
// Writes report.md + raw.json to tool/eval/results/<timestamp>/.
// ─────────────────────────────────────────────

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);

  // ── Load env + configure providers based on which keys are present
  Env.load();
  final providers = _buildProviders();

  // ── Filter providers by --models flag if set
  final filteredProviders = opts.modelFilter == null
      ? providers
      : providers.where((p) => opts.modelFilter!.contains(p.modelId)).toList();

  if (filteredProviders.isEmpty) {
    stderr.writeln('No providers available. Check API keys in .env.local.');
    exit(1);
  }

  // ── Filter fixtures by --fixtures flag if set
  final fixtures = opts.fixtureFilter == null
      ? allFixtures
      : allFixtures.where((f) => opts.fixtureFilter!.contains(f.id)).toList();

  if (fixtures.isEmpty) {
    stderr.writeln('No matching fixtures.');
    exit(1);
  }

  // ── Judge setup (optional)
  Judge? judge;
  if (!opts.noJudge) {
    final anthropicKey = Env.get('ANTHROPIC_API_KEY');
    if (anthropicKey == null || anthropicKey.isEmpty) {
      stderr.writeln('⚠ ANTHROPIC_API_KEY missing — judge disabled. Pass --no-judge to suppress this warning.');
    } else {
      judge = Judge(anthropicKey);
    }
  }

  stdout.writeln('Elio Model Eval');
  stdout.writeln('────────────────');
  stdout.writeln('Models:   ${filteredProviders.map((p) => p.modelId).join(', ')}');
  stdout.writeln('Fixtures: ${fixtures.map((f) => f.id).join(', ')}');
  stdout.writeln('Judge:    ${judge != null ? "Claude Sonnet 4.6" : "disabled"}');
  stdout.writeln('Runs:     ${opts.runs} per cell');
  stdout.writeln();

  final runId = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-').split('.').first;
  final results = <CellResult>[];

  for (final fixture in fixtures) {
    stdout.writeln('▶ ${fixture.id}');
    final prompt = buildRecipePrompt(
      fixture.request,
      region: fixture.region,
      measurementUnits: fixture.measurementUnits,
    );

    for (final provider in filteredProviders) {
      // Repeat each (fixture, model) cell `runs` times — take the median TTFT
      // and total time, average tokens, keep the LAST raw output for scoring.
      final attempts = <ModelResponse>[];
      for (var run = 1; run <= opts.runs; run++) {
        stdout.write('  ${provider.modelId} (run $run/${opts.runs}) ... ');
        final r = await provider.generate(prompt);
        if (r.isError) {
          stdout.writeln('ERROR — ${r.errorMessage}');
        } else {
          stdout.writeln('${r.timeToFirstToken.inMilliseconds}ms TTFT, ${r.totalTime.inMilliseconds}ms total, ${r.completionTokens ?? "?"} out tok');
        }
        attempts.add(r);
      }

      final aggregated = _aggregateAttempts(attempts);
      final structural = runStructuralChecks(aggregated.rawText, fixture);

      JudgeReport? judgeReport;
      if (judge != null && !aggregated.isError && structural.parsedJson != null) {
        stdout.write('    judging... ');
        judgeReport = await judge.score(
          fixture: fixture,
          modelId: provider.modelId,
          rawOutput: aggregated.rawText,
        );
        stdout.writeln(judgeReport.errorMessage != null
            ? 'FAILED'
            : 'avg ${judgeReport.averageScore.toStringAsFixed(2)}/5');
      }

      results.add(CellResult(
        fixture: fixture,
        modelId: provider.modelId,
        response: aggregated,
        structural: structural,
        judge: judgeReport,
      ));
    }
    stdout.writeln();
  }

  final report = Report(
    runId: runId,
    startedAt: DateTime.now().toUtc(),
    results: results,
    models: filteredProviders.map((p) => p.modelId).toList(),
    fixtureIds: fixtures.map((f) => f.id).toList(),
    judgeEnabled: judge != null,
  );

  final path = await report.write();
  stdout.writeln('✓ Report written to $path');
}

/// Combine repeated attempts: keep last raw text (for judge), median timings, last token counts.
ModelResponse _aggregateAttempts(List<ModelResponse> attempts) {
  if (attempts.length == 1) return attempts.first;

  final successful = attempts.where((r) => !r.isError).toList();
  if (successful.isEmpty) return attempts.last; // all errored — return last error

  final ttfts = successful.map((r) => r.timeToFirstToken.inMilliseconds).toList()..sort();
  final totals = successful.map((r) => r.totalTime.inMilliseconds).toList()..sort();
  final mid = ttfts.length ~/ 2;

  final last = successful.last;
  return ModelResponse(
    modelId: last.modelId,
    actualModelUsed: last.actualModelUsed,
    rawText: last.rawText,
    timeToFirstToken: Duration(milliseconds: ttfts[mid]),
    totalTime: Duration(milliseconds: totals[mid]),
    promptTokens: last.promptTokens,
    completionTokens: last.completionTokens,
    estimatedCostUSD: last.estimatedCostUSD,
  );
}

/// Build the provider list based on which API keys are present in .env.local.
List<Provider> _buildProviders() {
  final out = <Provider>[];

  final geminiKey = Env.get('GEMINI_API_KEY');
  if (geminiKey != null && geminiKey.isNotEmpty) {
    out.add(GeminiProvider(modelId: 'gemini-2.5-flash', apiKey: geminiKey));
    out.add(GeminiProvider(modelId: 'gemini-2.5-flash-lite', apiKey: geminiKey));
    out.add(GeminiProvider(modelId: 'gemini-3.1-flash-lite-preview', apiKey: geminiKey));
    // Gemma 4 — fall back to gemma-3-27b-it (also on AI Studio) if 404
    out.add(GeminiProvider(
      modelId: 'gemma-4',
      apiKey: geminiKey,
      fallbackModelId: 'gemma-3-27b-it',
      useThinkingBudgetZero: false,
    ));
  } else {
    stderr.writeln('⚠ GEMINI_API_KEY missing — Gemini + Gemma providers skipped');
  }

  final openaiKey = Env.get('OPENAI_API_KEY');
  if (openaiKey != null && openaiKey.isNotEmpty) {
    out.add(OpenAICompatibleProvider(
      modelId: 'gpt-4.1-nano',
      baseUrl: 'https://api.openai.com/v1',
      apiKey: openaiKey,
      providerGroup: 'openai',
    ));
  } else {
    stderr.writeln('⚠ OPENAI_API_KEY missing — GPT-4.1 nano skipped');
  }

  final groqKey = Env.get('GROQ_API_KEY');
  if (groqKey != null && groqKey.isNotEmpty) {
    out.add(OpenAICompatibleProvider(
      modelId: 'meta-llama/llama-4-scout-17b-16e-instruct',
      displayName: 'llama-4-scout (Groq)',
      baseUrl: 'https://api.groq.com/openai/v1',
      apiKey: groqKey,
      providerGroup: 'groq',
    ));
  } else {
    stderr.writeln('⚠ GROQ_API_KEY missing — Llama 4 Scout skipped');
  }

  final mistralKey = Env.get('MISTRAL_API_KEY');
  if (mistralKey != null && mistralKey.isNotEmpty) {
    out.add(OpenAICompatibleProvider(
      modelId: 'mistral-small-latest',
      baseUrl: 'https://api.mistral.ai/v1',
      apiKey: mistralKey,
      providerGroup: 'mistral',
    ));
  } else {
    stderr.writeln('⚠ MISTRAL_API_KEY missing — Mistral Small 3.1 skipped');
  }

  return out;
}

class _Options {
  final List<String>? modelFilter;
  final List<String>? fixtureFilter;
  final bool noJudge;
  final int runs;
  const _Options({this.modelFilter, this.fixtureFilter, this.noJudge = false, this.runs = 1});
}

_Options _parseArgs(List<String> args) {
  List<String>? models;
  List<String>? fixtures;
  bool noJudge = false;
  int runs = 1;

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--no-judge') {
      noJudge = true;
    } else if (a == '--models' && i + 1 < args.length) {
      models = args[++i].split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } else if (a == '--fixtures' && i + 1 < args.length) {
      fixtures = args[++i].split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } else if (a == '--runs' && i + 1 < args.length) {
      runs = int.tryParse(args[++i]) ?? 1;
    } else if (a == '-h' || a == '--help') {
      _printUsageAndExit();
    } else {
      stderr.writeln('Unknown arg: $a');
      _printUsageAndExit();
    }
  }

  return _Options(modelFilter: models, fixtureFilter: fixtures, noJudge: noJudge, runs: runs);
}

Never _printUsageAndExit() {
  stdout.writeln('Usage: dart run tool/eval/run.dart [options]');
  stdout.writeln('  --models <a,b,c>     Filter to specific model IDs');
  stdout.writeln('  --fixtures <a,b,c>   Filter to specific fixture IDs');
  stdout.writeln('  --no-judge           Skip the Claude Sonnet 4.6 judge');
  stdout.writeln('  --runs <n>           Repeat each (model, fixture) cell n times (default 1)');
  exit(0);
}
