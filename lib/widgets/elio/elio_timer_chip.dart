// lib/widgets/elio/elio_timer_chip.dart
//
// Sprint 16.6 — cooking timer.
//
// Compact terracotta pill rendered in the sticky timer bar at the
// top of RecipeScreen. Visual matches the mockup at
// `docs/strategy/2026-05-11-cooking-timer-mockup.html` frame 1.
//
// States:
//   - running → terracotta bg, white text, a small pulsing white dot,
//               mm:ss countdown right-aligned. Tap → pauses.
//   - paused  → mocha bg, white text, no dot, "PAUSED · mm:ss" label.
//               Tap → resumes.
//   - done    → terracotta-flash bg, "DONE — tap to dismiss" label.
//               Tap → dismisses.
//
// Long-press on any state → cancels (with confirm dialog at the
// caller's discretion).

import 'package:flutter/material.dart';

import '../../services/cooking_timer_service.dart';
import '../../theme/elio_radii.dart';
import '../../theme/elio_text_styles.dart';
import '../../theme/elio_theme.dart';

class ElioTimerChip extends StatelessWidget {
  final CookingTimer timer;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ElioTimerChip({
    super.key,
    required this.timer,
    required this.now,
    required this.onTap,
    required this.onLongPress,
  });

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final String label;
    final bool showDot;
    switch (timer.status) {
      case TimerStatus.running:
        bg = ElioColors.terracotta;
        label = timer.label;
        showDot = true;
        break;
      case TimerStatus.paused:
        bg = ElioColors.mocha;
        label = timer.label;
        showDot = false;
        break;
      case TimerStatus.done:
        bg = ElioColors.terracotta;
        label = '${timer.label} · DONE';
        showDot = false;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ElioRadii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              const _PulsingDot(),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: ElioTextStyles.bodySmallStyle.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (timer.status != TimerStatus.done) ...[
              const SizedBox(width: 8),
              Text(
                _format(timer.remaining(now)),
                style: ElioTextStyles.bodySmallStyle.copyWith(
                  color: Colors.white,
                  fontFamily: 'DM Mono',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 6×6 white dot that pulses between full opacity and 0.3 every
/// second to signal "alive". Pure animation — no haptic, no sound.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
