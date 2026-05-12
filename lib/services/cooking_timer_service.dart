// lib/services/cooking_timer_service.dart
//
// Sprint 16.6 — cooking timer.
//
// Multi-timer state holder. Wall-clock absolute end-times (not
// periodic countdown counters) so backgrounding the app for arbitrary
// durations doesn't lose accuracy — when the app resumes, the
// service reads the current clock and computes remaining time fresh.
//
// Pattern: ChangeNotifier so RecipeScreen can listen and rebuild on
// state changes. Production wires a `Timer.periodic` ticker via
// `startTicker()` so countdowns visibly update once per second; tests
// inject their own clock and call `tick()` manually for deterministic
// state assertions.
//
// On expiry: each newly-expired timer fires the optional `onExpire`
// callback (RecipeScreen wires this to HapticFeedback + SystemSound
// + a snackbar). The expired timer's status flips to `done`; the
// caller dismisses it via `dismiss(id)` or leaves it visible as a
// "DONE — tap to dismiss" chip.

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Current state of a single cooking timer.
enum TimerStatus { running, paused, done }

/// Immutable snapshot of one timer. The service holds these and
/// replaces them when state transitions (start / pause / resume /
/// expire). Equality is by `id` so widget lists can `key:` off it.
class CookingTimer {
  /// Stable identifier across state transitions.
  final String id;

  /// Display label, e.g. "Bake" or "Step 3".
  final String label;

  /// The duration the user originally picked.
  final Duration plannedDuration;

  /// Wall-clock time the timer is scheduled to end. Null while paused
  /// (use [remainingAtPause] instead).
  final DateTime? endsAt;

  /// How much time was left when this timer was paused. Null while
  /// running or done.
  final Duration? remainingAtPause;

  /// Current state.
  final TimerStatus status;

  const CookingTimer._({
    required this.id,
    required this.label,
    required this.plannedDuration,
    this.endsAt,
    this.remainingAtPause,
    required this.status,
  });

  /// Time remaining at the given clock reading. Clamps to zero when
  /// the wall-clock end has passed. For paused timers, returns the
  /// frozen [remainingAtPause]. For done timers, returns zero.
  Duration remaining(DateTime now) {
    switch (status) {
      case TimerStatus.running:
        if (endsAt == null) return plannedDuration;
        final left = endsAt!.difference(now);
        return left.isNegative ? Duration.zero : left;
      case TimerStatus.paused:
        return remainingAtPause ?? Duration.zero;
      case TimerStatus.done:
        return Duration.zero;
    }
  }

  CookingTimer _running(DateTime endsAt) => CookingTimer._(
        id: id,
        label: label,
        plannedDuration: plannedDuration,
        endsAt: endsAt,
        status: TimerStatus.running,
      );

  CookingTimer _paused(Duration remaining) => CookingTimer._(
        id: id,
        label: label,
        plannedDuration: plannedDuration,
        remainingAtPause: remaining,
        status: TimerStatus.paused,
      );

  CookingTimer _done() => CookingTimer._(
        id: id,
        label: label,
        plannedDuration: plannedDuration,
        status: TimerStatus.done,
      );

  @override
  bool operator ==(Object other) => other is CookingTimer && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Multi-timer state holder. Wire `onExpire` to play sound + vibrate.
/// Test code injects a custom `clock` to advance virtual time and
/// calls `tick()` to re-evaluate expiry. Production calls
/// `startTicker()` so a 1-second Timer.periodic does the same.
class CookingTimerService extends ChangeNotifier {
  /// Maximum number of timers that can be active at once. Caps the
  /// visual chip stack and protects against runaway state.
  static const int maxConcurrentTimers = 5;

  final DateTime Function() _clock;
  final void Function(CookingTimer)? onExpire;

  final List<CookingTimer> _timers = [];
  final Set<String> _alreadyFiredExpired = <String>{};

  Timer? _ticker;
  int _idSeq = 0;

  CookingTimerService({
    DateTime Function()? clock,
    this.onExpire,
  }) : _clock = clock ?? DateTime.now;

  /// Current snapshot. Caller should not mutate.
  List<CookingTimer> get timers => List.unmodifiable(_timers);

  /// True when at least one timer is running or paused. Used by
  /// RecipeScreen to decide whether to show the sticky timer bar
  /// (and, in a v1.1 follow-up, whether to hold the wakelock).
  bool get hasActiveTimers => _timers.any(
        (t) => t.status == TimerStatus.running ||
            t.status == TimerStatus.paused,
      );

  /// Start a new timer.
  ///
  /// Throws [ArgumentError] when [duration] is zero or negative,
  /// [StateError] when at the concurrent-timers cap.
  CookingTimer start({
    required String label,
    required Duration duration,
  }) {
    if (duration.inSeconds <= 0) {
      throw ArgumentError.value(
        duration,
        'duration',
        'Timer duration must be positive',
      );
    }
    if (_timers.length >= maxConcurrentTimers) {
      throw StateError(
        'At the $maxConcurrentTimers concurrent-timers cap; '
        'cancel or dismiss one before starting another.',
      );
    }
    final now = _clock();
    final t = CookingTimer._(
      id: 't_${++_idSeq}',
      label: label,
      plannedDuration: duration,
      endsAt: now.add(duration),
      status: TimerStatus.running,
    );
    _timers.add(t);
    notifyListeners();
    return t;
  }

  /// Pause a running timer. No-op on missing / done / already-paused.
  void pause(String id) {
    final i = _timers.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final t = _timers[i];
    if (t.status != TimerStatus.running) return;
    final left = t.remaining(_clock());
    _timers[i] = t._paused(left);
    notifyListeners();
  }

  /// Resume a paused timer. No-op on missing / running / done.
  void resume(String id) {
    final i = _timers.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final t = _timers[i];
    if (t.status != TimerStatus.paused) return;
    final newEndsAt = _clock().add(t.remainingAtPause ?? Duration.zero);
    _timers[i] = t._running(newEndsAt);
    notifyListeners();
  }

  /// Cancel and remove a timer. Does not fire `onExpire`. No-op on
  /// missing ids.
  void cancel(String id) {
    final removed = _timers.length;
    _timers.removeWhere((t) => t.id == id);
    _alreadyFiredExpired.remove(id);
    if (_timers.length != removed) notifyListeners();
  }

  /// Dismiss a done timer (remove from list). No-op on running/paused
  /// to avoid accidental cancels.
  void dismiss(String id) {
    final i = _timers.indexWhere((t) => t.id == id);
    if (i < 0) return;
    if (_timers[i].status != TimerStatus.done) return;
    _timers.removeAt(i);
    _alreadyFiredExpired.remove(id);
    notifyListeners();
  }

  /// Re-evaluate every timer against the current clock. Flips any
  /// just-expired timer to `done` and fires `onExpire` exactly once
  /// per timer. Called manually by tests; called by the 1-second
  /// periodic ticker in production.
  void tick() {
    final now = _clock();
    var changed = false;
    for (var i = 0; i < _timers.length; i++) {
      final t = _timers[i];
      if (t.status != TimerStatus.running) continue;
      if (t.endsAt == null) continue;
      if (!now.isBefore(t.endsAt!)) {
        final done = t._done();
        _timers[i] = done;
        changed = true;
        if (!_alreadyFiredExpired.contains(t.id)) {
          _alreadyFiredExpired.add(t.id);
          onExpire?.call(done);
        }
      }
    }
    if (changed) notifyListeners();
  }

  /// Start the 1-second periodic ticker. Production callers (a
  /// service-locator or the RecipeScreen `initState`) call this once.
  /// Tests don't — they call `tick()` manually.
  void startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// Stop the periodic ticker (used in dispose, or on screen leave).
  void stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    stopTicker();
    super.dispose();
  }
}
