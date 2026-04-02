import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// ─────────────────────────────────────────────
// ErrorService
// Lightweight wrapper around Firebase Crashlytics
// for logging non-fatal errors with feature context.
//
// Usage:
//   ErrorService.log('recipe_generation', e, stackTrace);
//   ErrorService.log('receipt_scan', 'Empty response from AI');
// ─────────────────────────────────────────────

class ErrorService {
  static final _crashlytics = FirebaseCrashlytics.instance;

  /// Log a non-fatal error to Crashlytics with feature context.
  /// Shows up in Firebase console under "Non-fatals" with the feature
  /// tag for easy filtering.
  static void log(String feature, dynamic error, [StackTrace? stack]) {
    try {
      _crashlytics.setCustomKey('feature', feature);
      _crashlytics.recordError(
        error is Exception ? error : Exception(error.toString()),
        stack ?? StackTrace.current,
        reason: 'Non-fatal: $feature',
        fatal: false,
      );
    } catch (_) {
      // Crashlytics itself failed — swallow silently
    }
  }
}
