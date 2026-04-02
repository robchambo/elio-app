# Elio — AI Recipe Generator

Flutter app (Android-primary). Gemini AI recipes from user's actual pantry.

## Build — CRITICAL

```
powershell -ExecutionPolicy Bypass -File build.ps1 -sprint <version>
```
**NEVER** raw `flutter build`. Key comes from `.env.local`. Always `--flavor prod`.

## Quick Reference

- **Status:** Sprint 15.3.2 shipped. Remaining: Recipe Import (Pro). Launch: Sprint 16.
- **Repo:** `https://github.com/robchambo/elio-app` (private, `main`)
- **Run:** `flutter run --flavor prod -t lib/main.dart --dart-define=GEMINI_API_KEY=<key>`
- **Stack:** Flutter/Dart, Firebase (Auth/Firestore/Crashlytics/Analytics/FCM/Remote Config), Gemini (2.5-flash streaming + 2.5-flash-lite batch), RevenueCat, mobile_scanner, shimmer

## Rules

1. **Commit after every confirmed-working build** — never leave more than one sprint uncommitted. Code only exists if it's in git.
2. **Update `docs/roadmap.md` after every successful build** — mark completed tasks, update estimates.
3. **`flutter analyze` before every commit** — zero warnings.
4. **Git via terminal** — never browser.
5. **Tag working builds** — immediately after user confirms on-device.
6. **Test Gemini changes** — never commit untested model/config changes.
7. **Worktree merges: diff first, never blind `cp`**.
8. **`.withValues(alpha: x)`** not `.withOpacity(x)`.
9. **Design: remove friction** — minimal taps, simplicity over completeness.

## Flutter Gotchas (hard-won)

- **No modal bottom sheet inside another bottom sheet** — use `showDialog` instead. The inner sheet fails silently.
- **No `SnackBar` from inside a bottom sheet** — renders behind the sheet. Use inline feedback.
- **`GestureDetector.onLongPress` in scrollable containers** — scroll gesture steals it. Use `RawGestureDetector` with `LongPressGestureRecognizer(duration: Duration(milliseconds: 300))`.
- **Fuzzy matching for toggle UIs** — never. Exact matching only. Fuzzy is for add-item duplicate warnings.
