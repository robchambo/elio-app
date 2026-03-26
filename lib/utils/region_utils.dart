import 'dart:ui';

// ─────────────────────────────────────────────
// RegionUtils
// Locale-based region and currency detection.
//
// Elio targets US (primary) and UK (secondary) markets.
// Currency is determined automatically from the device locale —
// no manual setting required. This mirrors the App Store / Play Store
// regional distribution model: users in the UK get the UK build,
// users in the US get the US build.
//
// Extending to new markets (e.g. CA, AU, EU):
//   1. Add a new AppRegion enum value.
//   2. Add the country code(s) to _countryCodeToRegion.
//   3. Add currency symbol and cost getter to RegionUtils.formatCost().
// ─────────────────────────────────────────────

enum AppRegion {
  us,  // United States — USD ($)
  uk,  // United Kingdom — GBP (£)
  // Future: ca (CAD), au (AUD), eu (EUR), etc.
}

class RegionUtils {
  RegionUtils._(); // static-only utility

  /// Country codes that map to each region.
  static const Map<String, AppRegion> _countryCodeToRegion = {
    'US': AppRegion.us,
    'GB': AppRegion.uk,
  };

  /// Detect the device's app region from the platform locale.
  /// Falls back to [AppRegion.us] if the country code is unrecognised.
  static AppRegion get region {
    final locale = PlatformDispatcher.instance.locale;
    final countryCode = locale.countryCode?.toUpperCase() ?? '';
    return _countryCodeToRegion[countryCode] ?? AppRegion.us;
  }

  /// Currency symbol for the current region.
  static String get currencySymbol {
    switch (region) {
      case AppRegion.uk: return '£';
      case AppRegion.us: return '\$';
    }
  }

  /// Format a cost-per-serving label for the current region.
  ///
  /// Pass both [usd] and [gbp] values (as returned by Gemini).
  /// Returns null if no value is available for the current region
  /// (or either currency as a fallback).
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
    }
  }

  /// Whether the current region uses GBP.
  static bool get isUK => region == AppRegion.uk;

  /// Whether the current region uses USD.
  static bool get isUS => region == AppRegion.us;
}
