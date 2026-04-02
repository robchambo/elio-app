# Elio — AI Recipe Generator

Flutter app (Android-primary). Gemini AI recipes from user's actual pantry.

## Build — CRITICAL

```
powershell -ExecutionPolicy Bypass -File build.ps1 -sprint <version>
```
**NEVER** raw `flutter build`. Key comes from `.env.local`. Always `--flavor prod`.

## Quick Reference

- **Status:** Sprint 15.3.13. Performance + voice control fixes. Launch: Sprint 16.
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
- **`showModalBottomSheet` in immersive/hands-free mode** — fails silently. Use `showDialog` instead.
- **Android speech recogniser beep** — mute NOTIFICATION + MUSIC + SYSTEM streams via platform channel for entire voice session, restore on exit. Per-listen mute/restore doesn't work (restart cycle re-triggers beep).

## Last Session (1 April 2026)

### Completed
- **Performance audit + high-priority fixes**: parallelised cold start (Analytics + RemoteConfig via Future.wait), deferred PurchaseService (lazy init) + NotificationService (split init/permission), static HTTP client in GeminiService, maxOutputTokens reduced (1024 standard / 2048 bulk), extracted shared `_streamFromPrompt()`, taste profile cache in FirestoreService, history cache in HistoryService, batched tier lookups in ScannerService
- **Hands-free voice control fixes**: added RECORD_AUDIO to AndroidManifest (was missing — permissions never requested), added platform channel (com.elio/audio) to mute beep streams during voice sessions, converted voice help overlay from bottom sheet to dialog (fixes "Got It" button in immersive mode), TTS now starts after "Got It" not during dialog, "Hey Elio done" turns off voice only (stays in hands-free mode)
- **Recipe screen bottom padding**: increased 40→80 so "Start Hands-Free Mode" button fully visible
- **Keyboard persistence fix**: FocusScope.unfocus() before recipe generation/navigation

### Needs Testing Tomorrow
- Voice control beep suppression (build 15.3.13) — user hasn't tested yet
- Voice help dialog "Got It" button — should work now as showDialog
- TTS timing — should read step 1 only after dialog dismissed

### Work in Progress
- None — all changes are complete and built

### Known Issues / TODOs
- NotificationService.requestPermissionAndRegister() is deferred but not wired to any trigger yet — needs to be called from home screen or settings
- 5 unpushed commits on main (local only)
- `mockup/` directory untracked (not committed, probably shouldn't be)
- Sprint 16 items all not started (Firestore security rules, GDPR, privacy policy, debug cleanup, regression test, store assets, Play Store submission, Crashlytics webhook)

### Gemini API State
- **Streaming**: gemini-2.5-flash via SSE, maxOutputTokens 1024 (standard) / 2048 (bulk prep), thinking disabled (thinkingBudget: 0), responseMimeType: application/json
- **Batch (receipt/import)**: gemini-2.5-flash-lite, responseMimeType: application/json
- **Connection**: static http.Client reused across calls (no per-request TCP/TLS overhead)
- **Token reduction**: ~75% reduction from previous 4096 limit, well within typical recipe output (300-400 tokens)
