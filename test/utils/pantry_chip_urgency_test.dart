// test/utils/pantry_chip_urgency_test.dart
//
// Sprint 16.6 — perishable chip urgency colours.
//
// Verifies the bucket boundaries and colour assignments for the
// Pantry-tab perishable chip styling. The helper is pure and takes
// an injected `now` so boundary days (-1 / 0 / 1 / 6 / 7) can be
// asserted deterministically without depending on the system clock.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/theme/elio_theme.dart';
import 'package:elio_app/utils/pantry_chip_urgency.dart';

void main() {
  // Use a fixed `now` so each boundary case is deterministic.
  final fixedNow = DateTime(2026, 5, 11, 14, 0); // 11 May 2026, 14:00 local
  DateTime daysFromFixed(int days) =>
      DateTime(fixedNow.year, fixedNow.month, fixedNow.day + days);

  group('PantryChipUrgency.forExpiry', () {
    test('returns neutral styling when expiryDate is null', () {
      final style = PantryChipUrgency.forExpiry(null, now: fixedNow);
      expect(style.background, ElioColors.cream);
      expect(style.border, ElioColors.rule);
      expect(style.dotColor, isNull);
    });

    // Background-tint hexes updated 2026-05-18 (commit 3fb72ea, Kate
    // Option B): unified onboarding tile palette with the Pantry-tab
    // dot palette. Borders/dots still resolve via the ElioColors
    // tokens, so they're stable across the swap; the tinted fills are
    // re-derived from the new colour family.
    test('returns today styling when expiry is in the past', () {
      final style = PantryChipUrgency.forExpiry(
        daysFromFixed(-3),
        now: fixedNow,
      );
      expect(style.background, const Color(0x1FA43D09));
      expect(style.border, ElioColors.perishToday);
      expect(style.dotColor, ElioColors.perishToday);
    });

    test('returns today styling when expiry is exactly today (days == 0)',
        () {
      final style = PantryChipUrgency.forExpiry(
        daysFromFixed(0),
        now: fixedNow,
      );
      expect(style.background, const Color(0x1FA43D09));
      expect(style.border, ElioColors.perishToday);
      expect(style.dotColor, ElioColors.perishToday);
    });

    test('returns thisWeek styling at the lower boundary (days == 1)', () {
      final style = PantryChipUrgency.forExpiry(
        daysFromFixed(1),
        now: fixedNow,
      );
      expect(style.background, const Color(0x1FFE9D00));
      expect(style.border, ElioColors.perishThisWeek);
      expect(style.dotColor, ElioColors.perishThisWeek);
    });

    test('returns thisWeek styling at the upper boundary (days == 6)', () {
      final style = PantryChipUrgency.forExpiry(
        daysFromFixed(6),
        now: fixedNow,
      );
      expect(style.background, const Color(0x1FFE9D00));
      expect(style.border, ElioColors.perishThisWeek);
      expect(style.dotColor, ElioColors.perishThisWeek);
    });

    test('returns fresh styling at exactly the bucket boundary (days == 7)',
        () {
      final style = PantryChipUrgency.forExpiry(
        daysFromFixed(7),
        now: fixedNow,
      );
      expect(style.background, const Color(0x1F7A876D));
      expect(style.border, ElioColors.freshGreen);
      expect(style.dotColor, ElioColors.freshGreen);
    });

    test('returns fresh styling for far-future expiry', () {
      final style = PantryChipUrgency.forExpiry(
        daysFromFixed(60),
        now: fixedNow,
      );
      expect(style.background, const Color(0x1F7A876D));
      expect(style.border, ElioColors.freshGreen);
      expect(style.dotColor, ElioColors.freshGreen);
    });

    test('time-of-day on the same calendar date is treated as days == 0',
        () {
      // Expiry at 23:59 today should still be "today", not "tomorrow",
      // because we bucket by calendar date, not 24h windows.
      final lateToday = DateTime(
        fixedNow.year,
        fixedNow.month,
        fixedNow.day,
        23,
        59,
      );
      final style = PantryChipUrgency.forExpiry(lateToday, now: fixedNow);
      expect(style.border, ElioColors.perishToday);
    });

    test('time-of-day early-morning tomorrow is treated as days == 1',
        () {
      final earlyTomorrow = DateTime(
        fixedNow.year,
        fixedNow.month,
        fixedNow.day + 1,
        0,
        1,
      );
      final style =
          PantryChipUrgency.forExpiry(earlyTomorrow, now: fixedNow);
      expect(style.border, ElioColors.perishThisWeek);
    });
  });

  group('PantryChipUrgency.forItem', () {
    test('extracts ISO8601 expiryDate from a Map item', () {
      final iso = daysFromFixed(2).toIso8601String();
      final style = PantryChipUrgency.forItem(
        {'name': 'Spinach', 'expiryDate': iso},
        now: fixedNow,
      );
      expect(style.border, ElioColors.perishThisWeek);
    });

    test('returns neutral when item has no expiryDate field', () {
      final style = PantryChipUrgency.forItem(
        {'name': 'Salt'},
        now: fixedNow,
      );
      expect(style.background, ElioColors.cream);
      expect(style.border, ElioColors.rule);
      expect(style.dotColor, isNull);
    });

    test('returns neutral when expiryDate is unparseable', () {
      final style = PantryChipUrgency.forItem(
        {'name': 'Bread', 'expiryDate': 'not-a-date'},
        now: fixedNow,
      );
      expect(style.background, ElioColors.cream);
      expect(style.border, ElioColors.rule);
      expect(style.dotColor, isNull);
    });
  });
}
