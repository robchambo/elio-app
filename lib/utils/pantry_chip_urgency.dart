// lib/utils/pantry_chip_urgency.dart
//
// Sprint 16.6 — perishable chip urgency colours.
//
// Pure helper that maps a perishable-item expiry date to a chip
// styling triple (background tint, saturated border, urgency dot).
// Used by the Pantry-tab `_TierItemChip` so colour communicates
// urgency at a glance, replacing the legacy "· Expired" / "· 3d"
// text suffix that was removed in the Sprint 16 rebrand pass.
//
// Palette matches the onboarding pantry-tile legend in
// `ElioPantryTierLegend.perishables()` and the tile-tier swatches
// in `ElioPantryItemTile._defaultStyles` so the Pantry tab and
// onboarding speak the same colour language:
//
//   - today/expired (days <= 0)  → tinted red bg + perishToday border + dot
//   - this week     (days 1..6)  → tinted orange bg + perishThisWeek border + dot
//   - fresh         (days >= 7)  → tinted green bg + freshGreen border + dot
//   - no expiry / unparseable    → cream bg + rule border + no dot
//
// The helper is exported as a static factory plus a top-level
// `forItem` convenience that pulls `expiryDate` (ISO8601 string)
// out of a Map<String, dynamic> as stored on `users/{uid}/inventory/*`
// docs. Both accept an injected `now` so boundary days can be
// unit-tested deterministically.

import 'package:flutter/widgets.dart';

import '../theme/elio_theme.dart';

/// A chip's resolved urgency styling — background fill, border
/// colour, and an optional leading-dot colour. All fields are
/// const-friendly so the helper's bucket presets are compile-time
/// constants and never re-allocated.
class PantryChipUrgency {
  final Color background;
  final Color border;
  final Color? dotColor;

  const PantryChipUrgency({
    required this.background,
    required this.border,
    this.dotColor,
  });

  /// Resolve urgency styling from a [DateTime] expiry. Pass an
  /// optional [now] to override `DateTime.now()` — used by tests
  /// to assert boundary buckets deterministically.
  static PantryChipUrgency forExpiry(DateTime? expiryDate, {DateTime? now}) {
    if (expiryDate == null) return _neutral;
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final exp =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final days = exp.difference(today).inDays;
    if (days <= 0) return _today;
    if (days <= 6) return _thisWeek;
    return _fresh;
  }

  /// Resolve urgency styling for a Pantry inventory item shaped as
  /// `Map<String, dynamic>` (the existing shape used by
  /// `pantry_screen.dart`'s `_TierItemChip`). Returns neutral when
  /// `expiryDate` is missing or unparseable.
  static PantryChipUrgency forItem(
    Map<String, dynamic> item, {
    DateTime? now,
  }) {
    final raw = item['expiryDate'];
    if (raw is! String) return _neutral;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return _neutral;
    return forExpiry(parsed, now: now);
  }

  // ── Bucket presets ──────────────────────────────────────────────────
  // Background tints are 12% alpha (`0x1F`) — same convention as
  // `ElioPantryItemTile._defaultStyles` so the visual language is
  // consistent across onboarding tiles and Pantry-tab chips.
  static const _neutral = PantryChipUrgency(
    background: ElioColors.cream,
    border: ElioColors.rule,
    dotColor: null,
  );
  static const _today = PantryChipUrgency(
    background: Color(0x1FE06C5E),
    border: ElioColors.perishToday,
    dotColor: ElioColors.perishToday,
  );
  static const _thisWeek = PantryChipUrgency(
    background: Color(0x1FF08C14),
    border: ElioColors.perishThisWeek,
    dotColor: ElioColors.perishThisWeek,
  );
  static const _fresh = PantryChipUrgency(
    background: Color(0x1F3D9970),
    border: ElioColors.freshGreen,
    dotColor: ElioColors.freshGreen,
  );
}
