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

# RevenueCat API key (optional — omit for dry mode during development)
$rcKeyMatch = Get-Content $envFile | Select-String "REVENUECAT_API_KEY=(.+)"
$rcKey = if ($rcKeyMatch) { $rcKeyMatch.Matches[0].Groups[1].Value.Trim() } else { "" }
if (-not $rcKey) {
    Write-Host "WARNING: REVENUECAT_API_KEY not found in .env.local — building in dry mode (no purchases)" -ForegroundColor Yellow
}

# Build output paths
$buildOutput = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-prod-release.apk"
$releaseDir  = Join-Path $PSScriptRoot "releases"
$outputName  = "elio-sprint-$sprint.apk"
$outputPath  = Join-Path $releaseDir $outputName

# Ensure releases/ folder exists
if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir | Out-Null
}

Write-Host ""
Write-Host "Building Elio - Sprint $sprint release APK..." -ForegroundColor Cyan
Write-Host ""

# Build
# Build dart-define flags
$dartDefines = "--dart-define=`"GEMINI_API_KEY=$apiKey`""
if ($rcKey) {
    $dartDefines += " --dart-define=`"REVENUECAT_API_KEY=$rcKey`""
}

Invoke-Expression "flutter build apk --release --flavor prod -t lib/main.dart $dartDefines"

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

# Tag the build in git
$tag = "build/sprint-$sprint"
git tag -f $tag 2>&1 | Out-Null
Write-Host "Git tag: $tag" -ForegroundColor DarkGray
Write-Host ""

if ($open) {
    Invoke-Item $releaseDir
}
