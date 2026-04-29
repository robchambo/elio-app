import 'package:flutter/material.dart';

/// Rounded-corner scale for the Sprint 16 rebrand.
///
/// Sourced from spec §6 (`docs/superpowers/specs/2026-04-29-sprint-16-rebrand-design.md`).
class ElioRadii {
  ElioRadii._();

  /// Full pill — used on chips and ingredient pills.
  static const double chip = 999.0;

  /// Primary CTA, peach pill, action tiles.
  static const double button = 20.0;

  /// Bento tiles, option cards, tier rows.
  static const double card = 16.0;

  /// Feedback bar, stat pill row.
  static const double panel = 14.0;

  /// Text fields.
  static const double input = 14.0;

  // Legacy size aliases — kept until widgets migrate. Removed in Task 36.
  static const double small = panel;
  static const double medium = card;
  static const double large = button;

  // Legacy named aliases used by pre-rebrand widgets.
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double pill = 999.0;

  /// Convenience helper: wraps [r] in a [BorderRadius.circular].
  static BorderRadius all(double r) => BorderRadius.circular(r);
}
