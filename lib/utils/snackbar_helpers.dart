// lib/utils/snackbar_helpers.dart
//
// Sprint 16.7c — defensive timeout enforcement for SnackBars with actions.
//
// Why this exists:
//   Flutter's built-in SnackBar dismiss timer is deliberately suppressed
//   when `MediaQueryData.accessibleNavigation` is true AND the SnackBar
//   has an action (TalkBack, Switch Access, several Samsung One UI
//   accessibility shortcuts can all flip this on, sometimes by accident).
//   The intent is good — give screen-reader users time to read and act —
//   but in practice it leaves "Removed X." Undo snackbars on screen
//   indefinitely on devices where the flag triggers without the user
//   knowing.
//
//   See `_SnackBarState._setUpAccessibleNavigationListener` in the
//   Flutter framework for the original suppression logic.
//
// What this does:
//   `messenger.showSnackBarWithTimer(snackBar)` shows the snackbar
//   normally, then schedules an explicit `Timer(snackBar.duration, ...)`
//   that closes the returned `ScaffoldFeatureController`. The accessibility
//   suppression no longer matters because the timer is ours, not Flutter's.
//
//   The timer is guarded by a `closed` future listener so we don't try
//   to close a snackbar the user has already dismissed (Undo tap, swipe,
//   or another `showSnackBar` taking over).

import 'dart:async';
import 'package:flutter/material.dart';

extension ElioSnackBarHelpers on ScaffoldMessengerState {
  /// Show a SnackBar with a hard-enforced auto-dismiss after
  /// `snackBar.duration`. Bypasses Flutter's accessibility-related
  /// timer suppression. Safe to call on snackbars without actions
  /// too — the duplicate timer is harmless once the snackbar is gone.
  ///
  /// Critical: the Timer is cancelled when the controller's closed
  /// future completes (action tap, swipe-to-dismiss, hideCurrentSnackBar,
  /// another snackbar taking its place, OR the messenger being disposed
  /// at test teardown). Without this cancel, widget tests fail with
  /// `'!timersPending'` because my external Timer outlives the SnackBar
  /// widget's own State (Flutter's built-in Timer is disposed with the
  /// State; mine isn't).
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
      showSnackBarWithTimer(SnackBar snackBar) {
    final controller = showSnackBar(snackBar);
    final timer = Timer(snackBar.duration, controller.close);
    controller.closed.then((_) {
      if (timer.isActive) timer.cancel();
    });
    return controller;
  }
}
