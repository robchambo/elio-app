import 'dart:io';

// ─────────────────────────────────────────────
// Env loader — reads .env.local from repo root
// (same file the Flutter app uses, parsed directly).
// ─────────────────────────────────────────────

class Env {
  static Map<String, String>? _cache;

  /// Load and cache .env.local from the repo root. Missing file is OK —
  /// just returns an empty map and individual providers will warn when
  /// their key is missing.
  static Map<String, String> load({String path = '.env.local'}) {
    if (_cache != null) return _cache!;

    final file = File(path);
    final map = <String, String>{};

    if (!file.existsSync()) {
      stderr.writeln('⚠ .env.local not found at $path — providers without keys will be skipped');
      _cache = map;
      return map;
    }

    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;

      final key = trimmed.substring(0, eq).trim();
      var value = trimmed.substring(eq + 1).trim();

      // Strip surrounding quotes
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
           (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }

      map[key] = value;
    }

    _cache = map;
    return map;
  }

  static String? get(String key) => load()[key];
}
