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

1. **`flutter analyze` before every commit** — zero warnings.
2. **Git via terminal** — never browser.
3. **Tag working builds** — immediately after user confirms on-device.
4. **Test Gemini changes** — never commit untested model/config changes.
5. **Worktree merges: diff first, never blind `cp`**.
6. **`.withValues(alpha: x)`** not `.withOpacity(x)`.
7. **Design: remove friction** — minimal taps, simplicity over completeness.
