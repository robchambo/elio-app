# Elio - one-shot device setup for Windows 11
#
# What this does (idempotent — safe to re-run):
#   1. Installs missing prerequisites via winget (git, gh, node, Android Studio)
#   2. Adds Flutter SDK + npm-global to User PATH
#   3. Sets JAVA_HOME (Android Studio's bundled JBR)
#   4. Loosens PowerShell ExecutionPolicy to RemoteSigned (CurrentUser)
#   5. Installs firebase-tools globally via npm
#   6. Installs Android cmdline-tools (downloads zip, extracts into SDK)
#   7. Accepts all Android SDK licenses (pipes 'y' through stdin)
#   8. Adds git safe.directory entries for the SDKs
#   9. Clones the elio-app repo (or pulls + checks out target branch if present)
#  10. Prints the irreducibly-manual checklist at the end
#
# What this does NOT do (you must do manually — script will prompt at the end):
#   - gh auth login              (browser flow)
#   - firebase login             (browser flow)
#   - Place .env.local           (contains GEMINI_API_KEY secret)
#   - Place google-services.json (Firebase config download)
#   - /plugin install superpowers (Claude Code slash command)
#
# Run with:
#   powershell -ExecutionPolicy Bypass -File scripts\setup-windows.ps1
#
# Optional params:
#   -RepoPath  C:\custom\path     (default C:\src\elio-app)
#   -Branch    sprint/16          (default sprint/16-integration)
#   -SkipClone                    (don't touch the repo, just env)

[CmdletBinding()]
param(
    [string]$RepoPath   = 'C:\src\elio-app',
    [string]$RepoUrl    = 'https://github.com/robchambo/elio-app',
    [string]$Branch     = 'sprint/16-integration',
    [string]$FlutterDir = 'C:\src\flutter',
    [switch]$SkipClone
)

$ErrorActionPreference = 'Continue'

function Section($name) {
    Write-Host ''
    Write-Host "=== $name ===" -ForegroundColor Cyan
}

function Ok($msg)    { Write-Host "  [ok]   $msg" -ForegroundColor Green }
function Skip($msg)  { Write-Host "  [skip] $msg" -ForegroundColor DarkGray }
function Do($msg)    { Write-Host "  [do]   $msg" -ForegroundColor Yellow }
function Warn($msg)  { Write-Host "  [warn] $msg" -ForegroundColor Yellow }

function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

function Add-ToUserPath($entry) {
    $current = [Environment]::GetEnvironmentVariable('Path','User')
    if ($current -split ';' -contains $entry) {
        Skip "PATH already contains $entry"
        return
    }
    [Environment]::SetEnvironmentVariable('Path', "$current;$entry", 'User')
    $env:Path = "$env:Path;$entry"
    Ok "added to User PATH: $entry"
}

#------------------------------------------------------------------------------
Section '1. Prerequisites (winget installs if missing)'
#------------------------------------------------------------------------------
$needWinget = @()
if (-not (Have git))   { $needWinget += 'Git.Git' }
if (-not (Have gh))    { $needWinget += 'GitHub.cli' }
if (-not (Have node))  { $needWinget += 'OpenJS.NodeJS.LTS' }
if (-not (Test-Path 'C:\Program Files\Android\Android Studio')) { $needWinget += 'Google.AndroidStudio' }

if ($needWinget.Count -eq 0) {
    Ok 'git, gh, node, Android Studio all present'
} else {
    if (-not (Have winget)) {
        Warn "winget missing — install these manually: $($needWinget -join ', ')"
    } else {
        foreach ($pkg in $needWinget) {
            Do "winget install $pkg"
            winget install --id $pkg --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
        }
    }
}

if (-not (Test-Path "$FlutterDir\bin\flutter.bat")) {
    Warn "Flutter SDK not found at $FlutterDir. Clone manually:"
    Warn "  git clone https://github.com/flutter/flutter.git -b stable $FlutterDir"
}

#------------------------------------------------------------------------------
Section '2. PATH + JAVA_HOME'
#------------------------------------------------------------------------------
if (Test-Path "$FlutterDir\bin") { Add-ToUserPath "$FlutterDir\bin" }
Add-ToUserPath "$env:APPDATA\npm"

$jbr = 'C:\Program Files\Android\Android Studio\jbr'
if (Test-Path $jbr) {
    $existing = [Environment]::GetEnvironmentVariable('JAVA_HOME','User')
    if ($existing -eq $jbr) {
        Skip "JAVA_HOME already set to $jbr"
    } else {
        [Environment]::SetEnvironmentVariable('JAVA_HOME', $jbr, 'User')
        $env:JAVA_HOME = $jbr
        $env:Path = "$jbr\bin;$env:Path"
        Ok "JAVA_HOME -> $jbr"
    }
} else {
    Warn 'Android Studio JBR not found — install Android Studio first'
}

#------------------------------------------------------------------------------
Section '3. PowerShell ExecutionPolicy'
#------------------------------------------------------------------------------
$pol = Get-ExecutionPolicy -Scope CurrentUser
if ($pol -in 'RemoteSigned','Unrestricted','Bypass') {
    Skip "already $pol (CurrentUser)"
} else {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Ok 'set CurrentUser to RemoteSigned'
}

#------------------------------------------------------------------------------
Section '4. firebase-tools (npm global)'
#------------------------------------------------------------------------------
if (Test-Path "$env:APPDATA\npm\firebase.cmd") {
    Skip 'firebase-tools already installed'
} else {
    if (Test-Path 'C:\Program Files\nodejs\npm.cmd') {
        Do 'npm install -g firebase-tools'
        & 'C:\Program Files\nodejs\npm.cmd' install -g firebase-tools
        Ok 'firebase-tools installed'
    } else {
        Warn 'npm.cmd not found — install Node.js first (step 1)'
    }
}

#------------------------------------------------------------------------------
Section '5. Android SDK cmdline-tools'
#------------------------------------------------------------------------------
$sdk = "$env:LOCALAPPDATA\Android\sdk"
$cmdLatest = "$sdk\cmdline-tools\latest"

if (Test-Path "$cmdLatest\bin\sdkmanager.bat") {
    Skip 'cmdline-tools/latest already populated'
} else {
    if (-not (Test-Path $sdk)) {
        Warn "Android SDK not at $sdk yet. Open Android Studio → run the Setup Wizard, then re-run this script."
    } else {
        $zipUrl = 'https://dl.google.com/android/repository/commandlinetools-win-14742923_latest.zip'
        $tmpZip = "$env:TEMP\cmdline-tools.zip"
        $tmpExt = "$env:TEMP\cmdline-tools-extracted"
        Do "downloading cmdline-tools zip"
        Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing
        if (Test-Path $tmpExt) { Remove-Item $tmpExt -Recurse -Force }
        Expand-Archive -Path $tmpZip -DestinationPath $tmpExt -Force
        New-Item -ItemType Directory -Path $cmdLatest -Force | Out-Null
        Get-ChildItem "$tmpExt\cmdline-tools" -Force | ForEach-Object {
            Copy-Item $_.FullName -Destination $cmdLatest -Recurse -Force
        }
        Ok 'cmdline-tools installed'
    }
}

#------------------------------------------------------------------------------
Section '6. Accept Android SDK licenses'
#------------------------------------------------------------------------------
$licensesDir = "$sdk\licenses"
$expectedLicenses = 7
$currentCount = if (Test-Path $licensesDir) { (Get-ChildItem $licensesDir).Count } else { 0 }

if ($currentCount -ge $expectedLicenses) {
    Skip "all $currentCount license files present"
} elseif (Test-Path "$cmdLatest\bin\sdkmanager.bat") {
    Do "accepting $expectedLicenses Android SDK licenses"
    $tmpYes = "$env:TEMP\sdk-yes.txt"
    Set-Content -Path $tmpYes -Value (("y`r`n" * 100)) -NoNewline
    $env:JAVA_HOME = $jbr
    cmd /c "`"$cmdLatest\bin\sdkmanager.bat`" --licenses < `"$tmpYes`"" | Out-Null
    Remove-Item $tmpYes -Force
    $finalCount = (Get-ChildItem $licensesDir).Count
    Ok "licenses now in place: $finalCount files"
} else {
    Warn 'sdkmanager.bat missing — run step 5 first'
}

#------------------------------------------------------------------------------
Section '7. Git safe.directory'
#------------------------------------------------------------------------------
$safeDirs = @($FlutterDir, $RepoPath) | ForEach-Object { $_ -replace '\\','/' }
foreach ($d in $safeDirs) {
    $existing = (git config --global --get-all safe.directory) -split "`n"
    if ($existing -contains $d) {
        Skip "safe.directory already includes $d"
    } else {
        git config --global --add safe.directory $d
        Ok "added safe.directory $d"
    }
}

#------------------------------------------------------------------------------
Section '8. Clone / sync elio-app repo'
#------------------------------------------------------------------------------
if ($SkipClone) {
    Skip 'SkipClone set'
} elseif (Test-Path "$RepoPath\.git") {
    Do "fetching + checking out $Branch"
    git -C $RepoPath fetch --all --prune
    git -C $RepoPath checkout $Branch
    git -C $RepoPath pull --ff-only
    $head = (git -C $RepoPath log --oneline -1)
    Ok "at: $head"
} else {
    Do "cloning $RepoUrl -> $RepoPath"
    git clone $RepoUrl $RepoPath
    git -C $RepoPath checkout $Branch
    Ok "cloned + on $Branch"
}

#------------------------------------------------------------------------------
Section '9. Final preflight'
#------------------------------------------------------------------------------
$envLocal      = "$RepoPath\.env.local"
$googleSvcs    = "$RepoPath\android\app\google-services.json"
$firebaseOpts  = "$RepoPath\lib\firebase_options.dart"
$envOk         = Test-Path $envLocal
$googleOk      = Test-Path $googleSvcs
$firebaseOk    = Test-Path $firebaseOpts

Write-Host "  .env.local                       : $(if ($envOk) {'OK'} else {'MISSING (secret)'})"
Write-Host "  android/app/google-services.json : $(if ($googleOk) {'OK'} else {'MISSING (secret)'})"
Write-Host "  lib/firebase_options.dart        : $(if ($firebaseOk) {'OK'} else {'MISSING (generated)'})"

#------------------------------------------------------------------------------
Section 'MANUAL STEPS REMAINING'
#------------------------------------------------------------------------------
$manual = @()
if (-not $envOk)      { $manual += 'Create .env.local with: GEMINI_API_KEY=AIza... (get from laptop or https://aistudio.google.com/app/apikey)' }
if (-not $googleOk)   { $manual += 'Download google-services.json from https://console.firebase.google.com/project/elio-prototype/settings/general -> save to android\app\' }
if (-not $firebaseOk) { $manual += 'Bring lib\firebase_options.dart from another device, OR regenerate with: dart pub global activate flutterfire_cli; flutterfire configure --project=elio-prototype --platforms=android' }
$manual += 'Run: gh auth login (browser flow)'
$manual += 'Run: firebase login (browser flow)'
$manual += 'In Claude Code: /plugin marketplace add obra/superpowers-marketplace'
$manual += 'In Claude Code: /plugin install superpowers@superpowers-marketplace'

$i = 1
foreach ($m in $manual) {
    Write-Host "  $i. $m" -ForegroundColor Yellow
    $i++
}

Write-Host ''
Write-Host 'Once all manual steps are done:' -ForegroundColor Cyan
Write-Host "  cd $RepoPath" -ForegroundColor White
Write-Host '  .\build.ps1 -sprint <sprint-name>' -ForegroundColor White
Write-Host ''
