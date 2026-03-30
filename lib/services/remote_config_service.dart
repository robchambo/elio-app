import 'package:firebase_remote_config/firebase_remote_config.dart';

// ─────────────────────────────────────────────
// RemoteConfigService
// Fetches config values from Firebase Remote Config
// with fallback to compile-time dart-define values.
//
// Priority: Remote Config > dart-define > empty string.
// This ensures existing builds keep working even if
// Remote Config isn't set up yet in Firebase Console.
// ─────────────────────────────────────────────

class RemoteConfigService {
  static final RemoteConfigService instance = RemoteConfigService._();
  RemoteConfigService._();

  bool _initialised = false;

  // dart-define fallback (baked into APK at build time)
  static const String _dartDefineApiKey = String.fromEnvironment('GEMINI_API_KEY');

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Defaults: use dart-define value so the app works even before
      // Remote Config is configured in Firebase Console.
      await rc.setDefaults({'gemini_api_key': _dartDefineApiKey});

      await rc.fetchAndActivate();
    } catch (_) {
      // Remote Config fetch failed (offline, not configured, etc.)
      // Dart-define fallback is already set as default — app continues.
    }
  }

  String get geminiApiKey {
    if (!_initialised) return _dartDefineApiKey;
    try {
      final rcValue = FirebaseRemoteConfig.instance.getString('gemini_api_key');
      // Use Remote Config value if it's non-empty, otherwise dart-define
      return rcValue.isNotEmpty ? rcValue : _dartDefineApiKey;
    } catch (_) {
      return _dartDefineApiKey;
    }
  }
}
