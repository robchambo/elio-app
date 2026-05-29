# Elio - build release APK for distribution
# Usage: .\build.ps1 -sprint 8.1
#        .\build.ps1 -sprint 8.2 -open   (opens output folder after build)

param(
    [Parameter(Mandatory=$true)]
    [string]$sprint,
    [switch]$open
)

# Read API key from .env.local
$envFile = Join-Path $PSScriptRoot ".env.local"
if (-not (Test-Path $envFile)) {
    Write-Host "ERROR: .env.local not found. Create it with: GEMINI_API_KEY=your_key" -ForegroundColor Red
    exit 1
}

$apiKey = (Get-Content $envFile | Select-String "GEMINI_API_KEY=(.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }).Trim()
if (-not $apiKey) {
    Write-Host "ERROR: GEMINI_API_KEY not found in .env.local" -ForegroundColor Red
    exit 1
}

# RevenueCat API key (optional - omit for dry mode during development)
$rcKeyMatch = Get-Content $envFile | Select-String "REVENUECAT_API_KEY=(.+)"
$rcKey = if ($rcKeyMatch) { $rcKeyMatch.Matches[0].Groups[1].Value.Trim() } else { "" }
if (-not $rcKey) {
    Write-Host "WARNING: REVENUECAT_API_KEY not found in .env.local - building in dry mode (no purchases)" -ForegroundColor Yellow
}

# Build output paths
# Sprint 17 — APK filename + git tag drop the legacy `sprint-` prefix.
# Pass `-sprint S17--<DDmmm>-<letter>` (or `S17.<sub>--<DDmmm>-<letter>`
# for sub-sprints) → filename `elio-S17--<DDmmm>-<letter>.apk` + tag
# `build/S17--<DDmmm>-<letter>`. Sprint 16 builds in `releases/` keep
# their legacy `elio-sprint-…` filenames; convention applies forward only.
$buildOutput = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-prod-release.apk"
$releaseDir  = Join-Path $PSScriptRoot "releases"
$outputName  = "elio-$sprint.apk"
$outputPath  = Join-Path $releaseDir $outputName

# Ensure releases/ folder exists
if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir | Out-Null
}

Write-Host ""
Write-Host "Building Elio - Sprint $sprint release APK..." -ForegroundColor Cyan
Write-Host ""

# Sprint 16.6.x — every build gets a unique BUILD_LABEL that the
# Settings → App Version row reads back via String.fromEnvironment.
# Lets Rob/Kate verify they're testing the right APK without
# guessing from filename + manual bookkeeping. Format: 0.<sprint>+<shortHash>.
$shortHash = (& git rev-parse --short HEAD 2>$null).Trim()
if (-not $shortHash) { $shortHash = "nogit" }
$buildLabel = "0.${sprint}+${shortHash}"
Write-Host "Build label: $buildLabel" -ForegroundColor DarkGray

# Build
$buildArgs = @(
    "build", "apk", "--release", "--flavor", "prod",
    "-t", "lib/main.dart",
    "--dart-define=GEMINI_API_KEY=$apiKey",
    "--dart-define=BUILD_LABEL=$buildLabel"
)
if ($rcKey) {
    $buildArgs += "--dart-define=REVENUECAT_API_KEY=$rcKey"
}

# Clear stale plugin-registration state before a release build.
# `flutter test` regenerates GeneratedPluginRegistrant.java + the plugin
# manifest with the integration_test dev-dependency registered. That line
# (`dev.flutter.plugins.integration_test.IntegrationTestPlugin`) doesn't
# exist on the release classpath, so `assembleProdRelease` fails to compile
# whenever a build follows a test run. Deleting both files forces Flutter to
# regenerate them fresh in the release context (which omits the dev dep).
# Targeted on purpose — cheaper than a full `flutter clean` (no recompile),
# fixes only this failure mode.
$staleRegistrant = Join-Path $PSScriptRoot "android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java"
$stalePluginManifest = Join-Path $PSScriptRoot ".flutter-plugins-dependencies"
foreach ($stale in @($staleRegistrant, $stalePluginManifest)) {
    if (Test-Path $stale) {
        Remove-Item $stale -Force -ErrorAction SilentlyContinue
        Write-Host "Cleared stale plugin state: $stale" -ForegroundColor DarkGray
    }
}

# Locate flutter - try PATH first, then known install location
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    $flutterPath = $flutterCmd.Source
} elseif (Test-Path "C:\src\flutter\bin\flutter.bat") {
    $flutterPath = "C:\src\flutter\bin\flutter.bat"
} else {
    Write-Host "ERROR: flutter not found on PATH or at C:\src\flutter\bin\flutter.bat" -ForegroundColor Red
    exit 1
}

& $flutterPath @buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BUILD FAILED" -ForegroundColor Red
    exit 1
}

# Copy to releases/ with sprint name
Copy-Item $buildOutput $outputPath -Force

Write-Host ""
Write-Host "Build complete:" -ForegroundColor Green
Write-Host "  $outputPath" -ForegroundColor White
Write-Host ""

# Tag the build in git (Sprint 17+ convention drops the `sprint-` prefix).
$tag = "build/$sprint"
git tag -f $tag 2>&1 | Out-Null
Write-Host "Git tag: $tag" -ForegroundColor DarkGray
Write-Host ""

if ($open) {
    Invoke-Item $releaseDir
}
