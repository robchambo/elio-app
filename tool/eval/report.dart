import 'dart:convert';
import 'dart:io';

import 'fixtures.dart';
import 'judge.dart';
import 'providers/provider.dart';
import 'structural.dart';

// ─────────────────────────────────────────────
// Report — generates markdown summary + raw JSON dump for one eval run.
// ─────────────────────────────────────────────

class CellResult {
  final Fixture fixture;
  final String modelId;
  final ModelResponse response;
  final StructuralReport structural;
  final JudgeReport? judge;

  const CellResult({
    required this.fixture,
    required this.modelId,
    required this.response,
    required this.structural,
    this.judge,
  });

  Map<String, dynamic> toJson() => {
    'fixtureId': fixture.id,
    'modelId': modelId,
    'response': response.toJson(),
    'structural': structural.toJson(),
    if (judge != null) 'judge': judge!.toJson(),
  };
}

class Report {
  final String runId;
  final DateTime startedAt;
  final List<CellResult> results;
  final List<String> models;
  final List<String> fixtureIds;
  final bool judgeEnabled;

  Report({
    required this.runId,
    required this.startedAt,
    required this.results,
    required this.models,
    required this.fixtureIds,
    required this.judgeEnabled,
  });

  /// Write report.md and raw.json to `tool/eval/results/<runId>/`.
  Future<String> write({String baseDir = 'tool/eval/results'}) async {
    final dir = Directory('$baseDir/$runId');
    await dir.create(recursive: true);

    final markdownPath = '${dir.path}/report.md';
    final jsonPath = '${dir.path}/raw.json';

    await File(markdownPath).writeAsString(_renderMarkdown());
    await File(jsonPath).writeAsString(const JsonEncoder.withIndent('  ').convert({
      'runId': runId,
      'startedAt': startedAt.toIso8601String(),
      'models': models,
      'fixtureIds': fixtureIds,
      'judgeEnabled': judgeEnabled,
      'results': results.map((r) => r.toJson()).toList(),
    }));

    return markdownPath;
  }

  String _renderMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# Elio Model Eval — $runId');
    buf.writeln();
    buf.writeln('**Started:** ${startedAt.toIso8601String()}');
    buf.writeln('**Models:** ${models.join(', ')}');
    buf.writeln('**Fixtures:** ${fixtureIds.join(', ')}');
    buf.writeln('**Judge:** ${judgeEnabled ? "Claude Sonnet 4.6" : "disabled"}');
    buf.writeln();

    // ─── Per-fixture tables ───────────────────────────────────────────
    for (final fid in fixtureIds) {
      final fixture = findFixture(fid);
      if (fixture == null) continue;
      buf.writeln('## Fixture: $fid');
      buf.writeln('_${fixture.description}_');
      buf.writeln();

      buf.write('| Model | TTFT (ms) | Total (ms) | Out tok/s | \$ cost | JSON | Perish | Diet | Region |');
      if (judgeEnabled) buf.write(' Judge avg |');
      buf.writeln();
      buf.write('|---|---:|---:|---:|---:|:-:|:-:|:-:|:-:|');
      if (judgeEnabled) buf.write(':-:|');
      buf.writeln();

      for (final m in models) {
        final cell = results.firstWhere(
          (r) => r.fixture.id == fid && r.modelId == m,
          orElse: () => CellResult(
            fixture: fixture,
            modelId: m,
            response: ModelResponse(
              modelId: m,
              rawText: '',
              timeToFirstToken: Duration.zero,
              totalTime: Duration.zero,
              errorMessage: 'No result (skipped)',
            ),
            structural: const StructuralReport([], null),
          ),
        );

        final r = cell.response;
        final modelLabel = r.actualModelUsed != null && r.actualModelUsed != m
            ? '$m → ${r.actualModelUsed}'
            : m;

        if (r.isError) {
          buf.writeln('| $modelLabel | — | — | — | — | ✗ ${_oneLine(r.errorMessage, max: 80)} | — | — | — |${judgeEnabled ? " — |" : ""}');
          continue;
        }

        final tokPerSec = r.tokensPerSecond > 0 ? r.tokensPerSecond.toStringAsFixed(0) : '—';
        final cost = r.estimatedCostUSD != null ? '\$${r.estimatedCostUSD!.toStringAsFixed(4)}' : '—';

        final json = _check(cell.structural, 'json_parses');
        final perish = _check(cell.structural, 'all_required_perishables_used');
        final diet = _check(cell.structural, 'dietary_tags_present');
        final region = _check(cell.structural, 'region_units_correct');

        buf.write('| $modelLabel | ${r.timeToFirstToken.inMilliseconds} | ${r.totalTime.inMilliseconds} | $tokPerSec | $cost | $json | $perish | $diet | $region |');
        if (judgeEnabled) {
          buf.write(' ${cell.judge != null ? cell.judge!.averageScore.toStringAsFixed(2) : "—"} |');
        }
        buf.writeln();
      }
      buf.writeln();
    }

    // ─── Leaderboard ─────────────────────────────────────────────────
    buf.writeln('## Leaderboard');
    buf.writeln();
    buf.write('| Model | Avg TTFT (ms) | Avg Total (ms) | Avg \$ cost | Structural pass rate |');
    if (judgeEnabled) buf.write(' Avg judge |');
    buf.writeln();
    buf.write('|---|---:|---:|---:|---:|');
    if (judgeEnabled) buf.write('---:|');
    buf.writeln();

    final rows = <List<String>>[];
    for (final m in models) {
      final cells = results.where((r) => r.modelId == m && !r.response.isError).toList();
      if (cells.isEmpty) {
        rows.add([m, '—', '—', '—', '—', if (judgeEnabled) '—']);
        continue;
      }

      final avgTtft = cells.map((c) => c.response.timeToFirstToken.inMilliseconds).reduce((a, b) => a + b) / cells.length;
      final avgTotal = cells.map((c) => c.response.totalTime.inMilliseconds).reduce((a, b) => a + b) / cells.length;
      final costs = cells.map((c) => c.response.estimatedCostUSD ?? 0).toList();
      final avgCost = costs.reduce((a, b) => a + b) / cells.length;
      final passRates = cells.map((c) => c.structural.passRate).toList();
      final avgPass = passRates.reduce((a, b) => a + b) / cells.length;

      final row = [
        m,
        avgTtft.toStringAsFixed(0),
        avgTotal.toStringAsFixed(0),
        '\$${avgCost.toStringAsFixed(4)}',
        '${(avgPass * 100).toStringAsFixed(0)}%',
      ];

      if (judgeEnabled) {
        final judged = cells.where((c) => c.judge != null && c.judge!.errorMessage == null).toList();
        if (judged.isEmpty) {
          row.add('—');
        } else {
          final avgJudge = judged.map((c) => c.judge!.averageScore).reduce((a, b) => a + b) / judged.length;
          row.add(avgJudge.toStringAsFixed(2));
        }
      }

      rows.add(row);
    }

    // Sort: highest judge first (or pass rate if no judge), tie-break on TTFT
    rows.sort((a, b) {
      if (judgeEnabled) {
        final aj = double.tryParse(a.last) ?? 0;
        final bj = double.tryParse(b.last) ?? 0;
        if (aj != bj) return bj.compareTo(aj);
      }
      final at = int.tryParse(a[1]) ?? 99999;
      final bt = int.tryParse(b[1]) ?? 99999;
      return at.compareTo(bt);
    });

    for (final row in rows) {
      buf.writeln('| ${row.join(' | ')} |');
    }
    buf.writeln();

    // ─── Notable failures ────────────────────────────────────────────
    final failures = <String>[];
    for (final cell in results) {
      if (cell.response.isError) {
        failures.add('- **${cell.modelId}** on `${cell.fixture.id}`: ${_oneLine(cell.response.errorMessage, max: 200)}');
        continue;
      }
      for (final c in cell.structural.checks) {
        if (!c.passed) {
          failures.add('- **${cell.modelId}** on `${cell.fixture.id}` — ${c.name}: ${_oneLine(c.detail, max: 200) ?? "(no detail)"}');
        }
      }
    }
    if (failures.isNotEmpty) {
      buf.writeln('## Notable failures');
      buf.writeln();
      for (final f in failures) {
        buf.writeln(f);
      }
      buf.writeln();
    }

    // ─── Judge breakdown ─────────────────────────────────────────────
    if (judgeEnabled) {
      buf.writeln('## Judge breakdown by dimension');
      buf.writeln();
      buf.writeln('| Model | Perishables | Dietary | Quality | Instruction-following |');
      buf.writeln('|---|---:|---:|---:|---:|');
      for (final m in models) {
        final judged = results.where((r) => r.modelId == m && r.judge != null && r.judge!.errorMessage == null).toList();
        if (judged.isEmpty) {
          buf.writeln('| $m | — | — | — | — |');
          continue;
        }
        final p = judged.map((c) => c.judge!.perishablesAdherence.score).reduce((a, b) => a + b) / judged.length;
        final d = judged.map((c) => c.judge!.dietaryCompliance.score).reduce((a, b) => a + b) / judged.length;
        final q = judged.map((c) => c.judge!.recipeQuality.score).reduce((a, b) => a + b) / judged.length;
        final i = judged.map((c) => c.judge!.instructionFollowing.score).reduce((a, b) => a + b) / judged.length;
        buf.writeln('| $m | ${p.toStringAsFixed(2)} | ${d.toStringAsFixed(2)} | ${q.toStringAsFixed(2)} | ${i.toStringAsFixed(2)} |');
      }
      buf.writeln();
    }

    return buf.toString();
  }

  String _check(StructuralReport sr, String name) {
    final c = sr.checks.where((c) => c.name == name).toList();
    if (c.isEmpty) return '—';
    return c.first.passed ? '✓' : '✗';
  }

  /// Collapse newlines/runs of whitespace, escape markdown table pipes,
  /// and truncate to `max` chars so error blobs don't shatter the
  /// report's tables or bullets.
  static String? _oneLine(String? s, {int max = 200}) {
    if (s == null) return null;
    var out = s.replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll('|', r'\|');
    if (out.length > max) out = '${out.substring(0, max - 1)}…';
    return out;
  }
}
