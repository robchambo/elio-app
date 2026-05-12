// test/services/cooking_timer_service_test.dart
//
// Sprint 16.6 — cooking timer.
//
// State-machine tests for the multi-timer service. The service uses
// wall-clock absolute end-times (not periodic countdown counters) so
// backgrounding the app doesn't lose accuracy. Tests inject a
// controllable clock and a callback to verify expiry handling
// without spinning a real Timer.periodic.

import 'package:flutter_test/flutter_test.dart';

import 'package:elio_app/services/cooking_timer_service.dart';

void main() {
  // Fixed reference time; tests advance it explicitly.
  late DateTime now;
  late CookingTimerService service;
  late List<CookingTimer> expiredCalls;

  setUp(() {
    now = DateTime(2026, 5, 11, 18, 0, 0);
    expiredCalls = <CookingTimer>[];
    service = CookingTimerService(
      clock: () => now,
      onExpire: expiredCalls.add,
    );
  });

  tearDown(() => service.dispose());

  // Advance the injected clock and let the service re-check expiries.
  void advance(Duration d) {
    now = now.add(d);
    service.tick();
  }

  group('start', () {
    test('adds a running timer to the list', () {
      final t = service.start(
        label: 'Bake',
        duration: const Duration(minutes: 25),
      );
      expect(service.timers, hasLength(1));
      expect(service.timers.first.id, t.id);
      expect(service.timers.first.label, 'Bake');
      expect(service.timers.first.plannedDuration,
          const Duration(minutes: 25));
      expect(service.timers.first.status, TimerStatus.running);
    });

    test('returns the timer with a unique id', () {
      final a = service.start(label: 'A', duration: const Duration(minutes: 5));
      final b = service.start(label: 'B', duration: const Duration(minutes: 5));
      expect(a.id, isNot(b.id));
    });

    test('remaining duration starts at the planned duration', () {
      final t = service.start(
        label: 'Rest',
        duration: const Duration(minutes: 5),
      );
      expect(t.remaining(now), const Duration(minutes: 5));
    });

    test('rejects zero or negative durations', () {
      expect(
        () => service.start(label: 'Bad', duration: Duration.zero),
        throwsArgumentError,
      );
      expect(
        () => service.start(
          label: 'Bad',
          duration: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
    });

    test('respects the maximum-concurrent-timers cap', () {
      for (var i = 0; i < CookingTimerService.maxConcurrentTimers; i++) {
        service.start(label: 'T$i', duration: const Duration(minutes: 5));
      }
      expect(
        () => service.start(
          label: 'overflow',
          duration: const Duration(minutes: 5),
        ),
        throwsStateError,
      );
    });

    test('notifies listeners', () {
      var calls = 0;
      service.addListener(() => calls++);
      service.start(label: 'A', duration: const Duration(minutes: 1));
      expect(calls, 1);
    });
  });

  group('countdown', () {
    test('remaining decreases as time passes', () {
      final t = service.start(
        label: 'Bake',
        duration: const Duration(minutes: 5),
      );
      expect(t.remaining(now), const Duration(minutes: 5));
      advance(const Duration(minutes: 2));
      // The timer object is immutable; read the current view.
      expect(
        service.timers.first.remaining(now),
        const Duration(minutes: 3),
      );
    });

    test('remaining clamps to zero at expiry', () {
      service.start(label: 'A', duration: const Duration(seconds: 10));
      advance(const Duration(seconds: 15));
      expect(service.timers.first.remaining(now), Duration.zero);
    });

    test(
        'Sprint 16.6.x: tick() notifies listeners on every running-timer tick '
        'even when no status flip happens (so chip mm:ss visibly counts down)',
        () {
      service.start(label: 'Bake', duration: const Duration(minutes: 5));
      var notifies = 0;
      service.addListener(() => notifies++);

      advance(const Duration(seconds: 1));
      expect(notifies, 1,
          reason: 'first tick of a running timer must notify so the chip rebuilds');
      advance(const Duration(seconds: 1));
      expect(notifies, 2,
          reason: 'every subsequent tick of a running timer must notify');
    });

    test(
        'Sprint 16.6.x: tick() does NOT notify when there are no running timers '
        '(idle service is silent so listeners don\'t rebuild for nothing)', () {
      final t = service.start(
        label: 'A',
        duration: const Duration(minutes: 5),
      );
      service.pause(t.id);
      var notifies = 0;
      service.addListener(() => notifies++);

      advance(const Duration(seconds: 5));
      expect(notifies, 0,
          reason: 'paused-only timers should not produce tick notifications');
    });

    test('fires onExpire exactly once when a timer hits zero', () {
      service.start(label: 'A', duration: const Duration(seconds: 10));
      advance(const Duration(seconds: 10));
      expect(expiredCalls, hasLength(1));
      expect(expiredCalls.first.label, 'A');
      // Subsequent ticks don't re-fire for the same timer.
      advance(const Duration(seconds: 5));
      expect(expiredCalls, hasLength(1));
    });

    test('flips status to done at expiry', () {
      service.start(label: 'A', duration: const Duration(seconds: 10));
      advance(const Duration(seconds: 10));
      expect(service.timers.first.status, TimerStatus.done);
    });
  });

  group('pause / resume', () {
    test('pausing freezes the remaining duration', () {
      final t = service.start(
        label: 'A',
        duration: const Duration(minutes: 5),
      );
      advance(const Duration(minutes: 2));
      service.pause(t.id);
      final pausedRemaining = service.timers.first.remaining(now);
      expect(pausedRemaining, const Duration(minutes: 3));
      // Time passing while paused should not reduce remaining.
      advance(const Duration(minutes: 1));
      expect(service.timers.first.remaining(now), const Duration(minutes: 3));
      expect(service.timers.first.status, TimerStatus.paused);
    });

    test('resuming sets a new end-time from now + remaining', () {
      final t = service.start(
        label: 'A',
        duration: const Duration(minutes: 5),
      );
      advance(const Duration(minutes: 2));
      service.pause(t.id);
      advance(const Duration(minutes: 1)); // 1 min "off the clock"
      service.resume(t.id);
      expect(service.timers.first.status, TimerStatus.running);
      // After resume, 3 minutes still remaining.
      expect(service.timers.first.remaining(now), const Duration(minutes: 3));
      // Advancing 3 more minutes should expire it.
      advance(const Duration(minutes: 3));
      expect(expiredCalls, hasLength(1));
    });

    test('pause is a no-op on a done or paused timer', () {
      final t = service.start(
        label: 'A',
        duration: const Duration(seconds: 1),
      );
      advance(const Duration(seconds: 2)); // done
      service.pause(t.id);
      expect(service.timers.first.status, TimerStatus.done);
    });

    test('resume is a no-op on a running or done timer', () {
      final t = service.start(
        label: 'A',
        duration: const Duration(minutes: 5),
      );
      service.resume(t.id); // still running, no-op
      expect(service.timers.first.status, TimerStatus.running);
    });
  });

  group('cancel', () {
    test('removes the timer from the list', () {
      final t = service.start(
        label: 'A',
        duration: const Duration(minutes: 5),
      );
      service.cancel(t.id);
      expect(service.timers, isEmpty);
    });

    test('cancelling does not fire onExpire', () {
      final t = service.start(
        label: 'A',
        duration: const Duration(minutes: 5),
      );
      service.cancel(t.id);
      advance(const Duration(minutes: 10));
      expect(expiredCalls, isEmpty);
    });

    test('cancelling an unknown id is a no-op', () {
      service.start(label: 'A', duration: const Duration(minutes: 5));
      service.cancel('bogus-id');
      expect(service.timers, hasLength(1));
    });
  });

  group('hasActiveTimers', () {
    test('false when empty', () {
      expect(service.hasActiveTimers, isFalse);
    });

    test('true with at least one running or paused timer', () {
      service.start(label: 'A', duration: const Duration(minutes: 5));
      expect(service.hasActiveTimers, isTrue);
    });

    test('false when all timers have expired', () {
      service.start(label: 'A', duration: const Duration(seconds: 10));
      advance(const Duration(seconds: 10));
      expect(service.hasActiveTimers, isFalse);
    });

    test('true when a paused timer exists', () {
      final t = service.start(
        label: 'A',
        duration: const Duration(minutes: 5),
      );
      service.pause(t.id);
      expect(service.hasActiveTimers, isTrue);
    });
  });

  group('dismiss (clear a done timer)', () {
    test('removes a done timer without firing onExpire again', () {
      final t = service.start(
        label: 'A',
        duration: const Duration(seconds: 10),
      );
      advance(const Duration(seconds: 10));
      expect(service.timers, hasLength(1));
      service.dismiss(t.id);
      expect(service.timers, isEmpty);
      // Cumulative expiry call count unchanged.
      expect(expiredCalls, hasLength(1));
    });
  });
}
