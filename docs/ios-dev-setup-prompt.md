# iOS dev setup — prompt for Claude Code on macOS

Paste the **prompt block** below into a fresh Claude Code session on your Mac (open a Terminal in your local clone of `elio-app` first). It tells Claude Code to bring the machine to a state where the iOS build of Elio runs end-to-end in the simulator and on a real device, verify each prerequisite is actually installed and tested, and stop to ask whenever a step needs you (Apple ID, signing team, secret files).

If you have not cloned the repo yet on this Mac: `git clone https://github.com/robchambo/elio-app.git ~/src/elio-app && cd ~/src/elio-app` first.

---

## The prompt

```
You are setting up iOS development for the Elio Flutter app on a Mac for the first time. The repo is already cloned at the current working directory. The Android build is shipping; iOS has never been built or tested on this machine, and likely not on any machine — Sprint 19 (iOS track) is upcoming work, so expect to find and fix gaps.

Goal: end this session with `flutter run` launching Elio in the iOS Simulator against the prod Firebase project, signed in successfully, Gemini generating a recipe, and every prerequisite verified by actually running it (not just `which` / `--version` checking).

Ground rules:
1. Do not skip verification. After each install step, run the tool and confirm it works. `flutter doctor -v` must end with no red Xs by the time you're done.
2. Stop and ask me when you hit anything that needs me: Apple ID sign-in in Xcode, signing team selection, placing secret files (`.env.local`, `ios/Runner/GoogleService-Info.plist`), or any prompt I have to click through. Do not guess or fabricate values.
3. Read `CLAUDE.md` at the repo root before doing anything. It documents the build flow, the Gemini key injection pattern, and the known iOS gotchas (URL scheme placeholder, missing `GoogleService-Info.plist`).
4. iOS does NOT have a `prod` flavor configured in the Xcode project — Android-only. Do not pass `--flavor prod` on iOS. The Gemini API key is still injected via `--dart-define=GEMINI_API_KEY=...` read from `.env.local`.
5. Commit nothing without my say-so. Do not push. If you change config files (e.g. `ios/Runner/Info.plist` to replace the URL scheme placeholder), show me the diff first.
6. Flutter version pin: 3.27.x. Dart SDK constraint in `pubspec.yaml` is `>=3.4.0 <4.0.0`. If the installed Flutter is on a different channel/version, switch it before continuing.

Work through this checklist in order. After each numbered item, give me a one-line status (`done` / `skipped — already ok` / `blocked — need X`).

### 1. macOS + Xcode baseline
- Print `sw_vers` (macOS version) and `uname -m` (arm64 vs x86_64). Flag if macOS is older than the current Xcode minimum.
- Verify Xcode is installed: `xcode-select -p` should resolve to an `.app` path, not `/Library/Developer/CommandLineTools`. If only CLT is present, stop and ask me to install full Xcode from the App Store — do not attempt to install it yourself.
- `xcodebuild -version` must succeed. If it errors with a licence message, run `sudo xcodebuild -license accept` (this needs my sudo password — ask).
- Ensure iOS Simulator runtime is downloaded: `xcrun simctl list runtimes | grep iOS`. If none, run `xcodebuild -downloadPlatform iOS` and wait for it.

### 2. Homebrew + CLI tools
- Confirm Homebrew: `brew --version`. If missing, install via the official one-liner from brew.sh and ask me to paste the sudo password if prompted.
- Install/verify: `git`, `cocoapods`, `ruby` (Homebrew's, not system), `gh`. Use `brew install` for any missing.
- `pod --version` must succeed and return >= 1.15.
- `gh auth status` — if not authenticated, ask me to run `gh auth login` interactively (browser flow).

### 3. Flutter SDK
- `flutter --version` must report 3.27.x. If on a different channel, run `flutter channel stable && flutter upgrade` until it lands on 3.27.x. If Flutter is missing entirely, install via `brew install --cask flutter` OR clone the SDK to `~/development/flutter` and add to PATH — ask me which I prefer.
- `flutter config --enable-ios` (idempotent).
- `flutter doctor -v`. Walk through every red X. Common ones to expect on a fresh Mac:
  - Xcode → covered above
  - CocoaPods → covered above
  - iOS toolchain → may need `sudo gem install ffi` on Apple Silicon
  - Connected device → fine if no simulator is booted yet
- Re-run `flutter doctor -v` until iOS section is fully green. Do not proceed if it isn't.

### 4. Repo state
- `git status` — confirm clean tree on a sane branch. If anything looks off, ask me before touching it.
- `flutter pub get` from the repo root.
- Check whether `lib/firebase_options.dart` exists and contains an `ios` block. If it's missing or iOS-less, stop and ask me — regenerating it requires the FlutterFire CLI + my Firebase login (`info.autex@gmail.com`, project `elio-prototype`).

### 5. Secrets and config files (manual placement)
Both of these are gitignored. Check whether they exist; if not, stop and ask me to place them. Don't fabricate.

- `.env.local` at repo root. Required key: `GEMINI_API_KEY=AIza...`. Optional: `REVENUECAT_API_KEY=goog_...` (omit for dry-mode RC).
- `ios/Runner/GoogleService-Info.plist`. Downloaded from the Firebase console, project `elio-prototype`, iOS app (bundle id matches `ios/Runner.xcodeproj` — print it for me before asking).

After I've placed them:
- Validate `GoogleService-Info.plist` parses and contains `BUNDLE_ID` matching the Xcode bundle id and `PROJECT_ID` = `elio-prototype`.
- Extract `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` and verify `ios/Runner/Info.plist` no longer contains the literal string `REVERSED_CLIENT_ID_PLACEHOLDER`. If it does, replace it with the real value, show me the diff, and ask before saving. (This is the Sprint 4 TODO flagged as a Known Issue in `CLAUDE.md`.)

### 6. CocoaPods install
- `cd ios && pod install --repo-update` (first run may take 5–10 min while CocoaPods syncs the spec repos). If pods fail with arch errors on Apple Silicon, try `arch -x86_64 pod install` and report back before reattempting.
- Confirm `ios/Podfile.lock` is created/updated and `ios/Pods/` populates.

### 7. Xcode signing (needs me)
- Open the project with `open ios/Runner.xcworkspace` (workspace, not the bare xcodeproj).
- Stop and ask me to: sign into Xcode with my Apple ID (Xcode → Settings → Accounts), then under the Runner target → Signing & Capabilities, select my team and let Xcode auto-manage signing. Tell me the current bundle id and the team-id field name to look for.
- After I've done it, verify the build settings: `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -showBuildSettings | grep -E 'DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER|CODE_SIGN_STYLE'`.

### 8. Simulator smoke test
- Boot a simulator: `xcrun simctl list devices available | grep -i 'iPhone 15'` then `xcrun simctl boot <UDID>` and `open -a Simulator`.
- Load the Gemini key from `.env.local` into a shell var, then run:
  `flutter run -d <simulator-udid> --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY`
  (No `--flavor` on iOS — it's not configured. If you also have a RevenueCat key, add a second `--dart-define`.)
- Watch the boot logs. Expected: Firebase init succeeds, app lands on onboarding (fresh install). If you see a 403 from Gemini, the dart-define didn't pass — diagnose before retrying.
- Once running: tell me to walk the onboarding to screen 13 (first recipe). If the recipe generates and renders, iOS is working. Capture a screenshot via `xcrun simctl io booted screenshot ~/Desktop/elio-ios-smoke.png` and report the path.

### 9. Physical device (optional — ask if I want this now)
If I say yes:
- Plug in the device, trust the Mac, enable Developer Mode (Settings → Privacy & Security → Developer Mode on iOS 16+).
- `flutter devices` should list it.
- `flutter run -d <device-id> --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY`. First run will prompt me on the device to trust the developer profile — tell me when to look.

### 10. Final report
Print a checklist of:
- Tool versions (`xcodebuild`, `flutter`, `dart`, `pod`, `ruby`, `gh`).
- `flutter doctor -v` summary.
- Files verified present: `.env.local`, `ios/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart` with iOS block.
- `REVERSED_CLIENT_ID_PLACEHOLDER` resolved: yes/no.
- Simulator smoke test result.
- Any deferred work (e.g. Apple Sign-In capability for Sprint 19, Siri Shortcuts entitlements).

Do not edit `CLAUDE.md`, `docs/roadmap.md`, or any source file beyond what's strictly required to make iOS run. If you find broken things outside this scope, list them in the final report instead of fixing them.
```

---

## Why these specific things

- **Full Xcode, not just CLT** — Flutter's iOS toolchain needs `xcodebuild`, the iOS SDK, and the Simulator runtime, which CLT doesn't ship.
- **CocoaPods >= 1.15** — required by current `flutter_tools/bin/podhelper`. Older versions fail post-install hooks on Apple Silicon.
- **`REVERSED_CLIENT_ID_PLACEHOLDER`** — see the comment in `ios/Runner/Info.plist`. Google Sign-In's callback URL scheme is the reversed OAuth client ID from `GoogleService-Info.plist`; leaving the placeholder causes silent failure on Google sign-in.
- **No `--flavor prod` on iOS** — Android's `build.ps1` always passes `--flavor prod`, and `CLAUDE.md` makes this a hard rule for Android. The iOS Xcode project has no matching flavor configurations (only the default Debug/Release/Profile), so the same flag would fail. The Gemini key still needs `--dart-define`.
- **Workspace not xcodeproj** — CocoaPods integrates via the `.xcworkspace`. Opening the bare `.xcodeproj` will give you a broken build and is a common first-time mistake.
- **`flutter pub get` before `pod install`** — `ios/Flutter/Generated.xcconfig` is created by `pub get`, and `Podfile` reads `FLUTTER_ROOT` from it.

## What's deliberately out of scope

These are Sprint 19 work and shouldn't block first-build:

- Apple Sign-In capability (and entitlement)
- Siri Shortcuts pre-launch wiring
- TestFlight setup
- App Store Connect listing

Flag them in the final report, don't fix them in this session.
