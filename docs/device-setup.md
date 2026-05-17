# Elio device setup — runbook

Picking up Elio work on a fresh or new Windows 11 device. Written for Claude to follow, but Rob can also run it directly.

## TL;DR

```powershell
# Open a fresh PowerShell, then:
powershell -ExecutionPolicy Bypass -File scripts\setup-windows.ps1
```

Wait ~20 minutes (mostly waiting on the Android SDK download). Then complete the **MANUAL STEPS REMAINING** list it prints at the end. Total time on a clean machine: 30–40 minutes (most of it parallelisable).

---

## For Claude — when to use this

Trigger this runbook if Rob's opening message is along the lines of:

- "Continuing Elio work from my laptop / desktop / new machine"
- "Setting up Elio on a new device"
- "Get me back to where I was"

…and one or more of these is true:

- `C:\src\elio-app` doesn't exist
- `flutter --version` fails from a fresh PowerShell
- `firebase --version` fails from a fresh PowerShell
- `gh auth status` reports not logged in
- `flutter doctor` flags Android toolchain issues

If unsure, just run the script — it's idempotent and skips anything already done.

---

## What the script handles (no thought required)

| Step | What | Why |
|---|---|---|
| 1 | `winget install` of git, gh, node, Android Studio (if missing) | Baseline dev tools |
| 2 | Adds Flutter SDK + npm-global folder to User PATH | So flutter / firebase / dart resolve bare |
| 2 | Sets `JAVA_HOME` to Android Studio's bundled JBR | Gradle and sdkmanager both need it |
| 3 | Sets PowerShell ExecutionPolicy to RemoteSigned (CurrentUser) | Allows `.ps1` shims from npm globals |
| 4 | `npm install -g firebase-tools` (via `npm.cmd` shim, bypasses ExecutionPolicy quirk) | Firebase CLI |
| 5 | Downloads cmdline-tools zip + extracts into the SDK | Android Studio's wizard often leaves an empty placeholder |
| 6 | Pipes 100 `y`s through `sdkmanager --licenses` | Accepts all 7 Android SDK licenses non-interactively |
| 7 | `git config --global --add safe.directory` for Flutter + elio-app | Avoids "dubious ownership" errors when SDKs are owned by a different Windows user (e.g. Kate's account) |
| 8 | Clones `elio-app` to `C:\src\elio-app` and checks out the target branch | Repo on disk |

---

## What the script can't do (5 manual steps)

These need a browser, a secret, or a Claude Code slash command.

### 1. `gh auth login`
Browser flow — pick GitHub.com, HTTPS, "Authenticate Git with your GitHub credentials? Yes", "Login with a web browser". After it lands, `git push` to `robchambo/*` works without prompts.

### 2. `firebase login`
Same browser pattern. Use the Google account that owns the `elio-prototype` Firebase project (currently `info.autex@gmail.com`).

### 3. `.env.local`
At `C:\src\elio-app\.env.local`:
```
GEMINI_API_KEY=AIza...
REVENUECAT_API_KEY=goog_...   (optional — omit for dry-mode RevenueCat)
```
- Cleanest source: copy from previous device.
- Fallback: create a new Gemini key at https://aistudio.google.com/app/apikey (separate quota from the laptop's key, otherwise identical behaviour).
- RC key: skip if RevenueCat isn't set up yet (Sprint 17 work). Build still succeeds with a warning.

### 4. `google-services.json`
At `C:\src\elio-app\android\app\google-services.json`. Two sources:
- Copy from previous device, OR
- Re-download fresh from https://console.firebase.google.com/project/elio-prototype/settings/general → *Your apps* → Android app `com.elio.elio_app` → download icon.

The script verifies it parses to `project_id: elio-prototype` and `package_name: com.elio.elio_app`. Wrong file = build will fail at Firebase init.

### 5. `lib/firebase_options.dart`
At `C:\src\elio-app\lib\firebase_options.dart`. Generated file containing cross-platform Firebase init constants. Two sources:
- Copy from previous device (same project = identical content), OR
- Regenerate (requires `firebase login` first):
  ```
  dart pub global activate flutterfire_cli
  flutterfire configure --project=elio-prototype --platforms=android
  ```
  This is partly interactive — you'll be asked to confirm the existing `com.elio.elio_app` Android app entry.

Without this file the build fails at the Dart compile step with `Error when reading 'lib/firebase_options.dart': The system cannot find the file specified`.

### 6. Superpowers plugin
In Claude Code (this session):
```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```
Plugins don't sync between devices — has to be installed per-machine.

---

## After setup: verify

```powershell
flutter doctor          # Android toolchain should be green
firebase projects:list  # should include elio-prototype
gh auth status          # should say Logged in as robchambo
```

Then a real test — build the current sprint's APK:
```powershell
cd C:\src\elio-app
.\build.ps1 -sprint <sprint-name>
```

Output lands at `releases\elio-sprint-<sprint>.apk` (~72–76 MB) and creates a local git tag `build/sprint-<sprint>`.

---

## Long-term: make secrets transfer painless

The two secret files (`.env.local` and `google-services.json`) are the only friction on each new device. Options to eliminate this:

- **OneDrive (recommended):** keep a `OneDrive\Elio-secrets\` folder with both files; symlink or copy into the repo after clone. Script could be extended to auto-copy from a configurable secrets path.
- **1Password / Bitwarden CLI:** store as secure notes, retrieve via CLI. Most secure, requires session unlock each time.
- **Encrypted USB stick:** physical, no cloud dependency.

If you want me to extend the setup script with a `-SecretsFrom <path>` flag, ask.

---

## Known quirks to expect

- **PowerShell stderr in parallel tool calls:** PS 5.1 wraps native-command stderr (git clone progress, gh output) as errors and cancels parallel calls. Run things sequentially if exit codes might be non-zero.
- **Sandbox filesystem isolation (Claude Code only):** Writes from Claude's PowerShell tool into `%APPDATA%` / `%USERPROFILE%` may not be visible to Rob's real shell. Have Rob run npm-global installs from his own terminal, or accept that the binaries exist only in the sandbox. `C:\src\*` paths and the Windows registry are NOT sandboxed.
- **Cross-user file ownership (Rob + Kate share this household's desktop):** Flutter SDK at `C:\src\flutter` was installed under `kated`, currently owned by her. `git config --global --add safe.directory` covers the git checks. Don't run `flutter upgrade` from Rob's session — will fail with permission denied; if needed use `takeown /F C:\src\flutter /R /D Y` in an elevated shell.
- **Android Studio's Setup Wizard leaves an empty `cmdline-tools/latest/`** — the script's manual zip-extract step exists specifically to fix this. Don't be confused if you see the dir exists but `sdkmanager.bat` is missing.
