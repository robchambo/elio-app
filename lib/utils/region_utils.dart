import 'dart:ui';

// ─────────────────────────────────────────────
// RegionUtils
// Locale-based region and currency detection.
//
// Elio targets US + UK as the primary cost-display markets, with AU + CA
// as supported regions that fall back to USD-priced cost display (Gemini
// doesn't return AUD/CAD prices yet — `formatCost` returns null for AU/CA
// so the cost label is hidden in the UI rather than showing a wrong-currency
// number). Ingredient nomenclature is still tuned per-region in the Gemini
// prompt (Australian English / Canadian English).
//
// Extending to new markets (e.g. EU):
//   1. Add a new AppRegion enum value.
//   2. Add the country code(s) to _countryCodeToRegion.
//   3. Add currency symbol and cost getter to RegionUtils.formatCost().
// ─────────────────────────────────────────────

enum AppRegion {
  us,  // United States — USD ($)
  uk,  // United Kingdom — GBP (£)
  ca,  // Canada — cost hidden (no CAD support yet)
  au,  // Australia — cost hidden (no AUD support yet)
}

class RegionUtils {
  RegionUtils._(); // static-only utility

  /// Country codes that map to each region.
  static const Map<String, AppRegion> _countryCodeToRegion = {
    'US': AppRegion.us,
    'GB': AppRegion.uk,
    'CA': AppRegion.ca,
    'AU': AppRegion.au,
  };

  /// User-overridden region (set from onboarding or settings).
  static AppRegion? _userOverride;

  /// User-overridden measurement units ("metric" or "imperial").
  static String _measurementUnits = 'metric';

  /// Set the user's preferred region (persists in memory for the session).
  static void setRegion(AppRegion region) {
    _userOverride = region;
  }

  /// Set the user's preferred measurement units ("metric" or "imperial").
  static void setMeasurementUnits(String units) {
    _measurementUnits = units;
  }

  /// Current measurement units. Defaults to "metric".
  static String get measurementUnits => _measurementUnits;

  /// Detect the device's app region from the platform locale.
  /// Returns user override if set, otherwise falls back to locale detection.
  static AppRegion get region {
    if (_userOverride != null) return _userOverride!;
    final locale = PlatformDispatcher.instance.locale;
    final countryCode = locale.countryCode?.toUpperCase() ?? '';
    return _countryCodeToRegion[countryCode] ?? AppRegion.us;
  }

  /// Currency symbol for the current region. AU/CA fall back to `$`
  /// (USD display) since Gemini doesn't price in AUD/CAD yet.
  static String get currencySymbol {
    switch (region) {
      case AppRegion.uk: return '£';
      case AppRegion.us:
      case AppRegion.ca:
      case AppRegion.au:
        return '\$';
    }
  }

  /// Format a cost-per-serving label for the current region.
  ///
  /// Pass both [usd] and [gbp] values (as returned by Gemini).
  /// Returns null if no value is available for the current region
  /// (or either currency as a fallback). AU/CA always return null —
  /// cost display is suppressed for those regions until Gemini returns
  /// AUD/CAD prices.
  ///
  /// Example output: "~£2.80 / serving"  or  "~$3.50 / serving"
  static String? formatCost({
    double? usd,
    double? gbp,
    String suffix = ' / serving',
  }) {
    switch (region) {
      case AppRegion.uk:
        if (gbp != null && gbp > 0) return '~£${gbp.toStringAsFixed(2)}$suffix';
        if (usd != null && usd > 0) return '~\$${usd.toStringAsFixed(2)}$suffix'; // fallback
        return null;
      case AppRegion.us:
        if (usd != null && usd > 0) return '~\$${usd.toStringAsFixed(2)}$suffix';
        if (gbp != null && gbp > 0) return '~£${gbp.toStringAsFixed(2)}$suffix'; // fallback
        return null;
      case AppRegion.ca:
      case AppRegion.au:
        return null;
    }
  }

  /// Whether the current region uses GBP.
  static bool get isUK => region == AppRegion.uk;

  /// Whether the current region uses USD.
  static bool get isUS => region == AppRegion.us;
}
